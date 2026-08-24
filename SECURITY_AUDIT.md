# Security Audit — School Connect Flutter App

**Date:** 2026-08-12 · **Scope:** `school_connect_app/` + `fastapi_backend/` (the bridge the app talks to) + platform configs.
**Method:** static code review of the Dart codebase, Android/iOS/macOS configs, dependency analysis (`flutter pub outdated`), and git history review.

---

## Summary

| Severity | Count |
|----------|-------|
| Critical | 1 |
| High     | 5 |
| Medium   | 8 |
| Low      | 6 |

**Bottom line:** no remotely-exploitable vulnerability exists today because the app
is in local development (nothing is deployed, all traffic is to `localhost`).
However, **the app is not release-ready**: the release APK is signed with the
well-known debug keystore, cannot make network calls (no `INTERNET` permission),
and every layer communicates over **plaintext HTTP**. Fixing the Critical/High
items below must happen before any real deployment.

---

## 🔴 Critical

### C-1. Release builds are signed with the debug keystore
- **File:** `android/app/build.gradle.kts:37`
- **Problem:** The `release` build type uses `signingConfig = signingConfigs.getByName("debug")`. The debug keystore is a known, publicly documented key shipped with the Android SDK. Anyone who obtains the APK can therefore re-sign modified builds, and update signing integrity is completely defeated. Combined with a missing `INTERNET` permission, a shipped release build is also non-functional.
- **Fix:** Create a dedicated release keystore and wire it via `key.properties` (kept out of git):

```kotlin
// android/key.properties  (NOT committed — add to .gitignore)
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=../upload-keystore.jks
```

```kotlin
// android/app/build.gradle.kts — replace the buildTypes block
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }
    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists())
                signingConfigs.getByName("release")
            else null // unsigned build fails until the keystore exists — that's the point
        }
    }
}
```

---

## 🟠 High

### H-1. Release APK has no network permission — and would be blocked from cleartext anyway
- **File:** `android/app/src/main/AndroidManifest.xml` (missing); `android/app/src/debug/AndroidManifest.xml:6` and `.../profile/AndroidManifest.xml:6` (INTERNET only here)
- **Problem:** `android.permission.INTERNET` is declared **only** in the debug/profile manifests. A release build compiles without internet access, so every API call fails silently. In addition, Android 9+ blocks cleartext `http://` by default, so the current `http://localhost:8080` config would not work on a device without a network-security exception — which must not be added for production.
- **Fix:** Add to the **main** manifest and lock down cleartext + backup in one edit:

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <application
        android:label="school_connect_app"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher"
        android:allowBackup="false"
        android:usesCleartextTraffic="false">
        <!-- ...rest unchanged... -->
```

### H-2. All API traffic is plaintext HTTP (app → FastAPI → Frappe), no TLS, no pinning
- **File:** `lib/config/api_config.dart:10` (`baseUrl = 'http://localhost:8080'`); `fastapi_backend/.env` (`FRAPPE_URL=http://localhost:8000`); FastAPI proxy in `fastapi_backend/app/routers/proxy.py`
- **Problem:** Credentials (`{email, password}`), JWTs, attendance/PII, and file uploads travel unencrypted over every hop. On any real network this is trivially sniffable (MITM) — token theft gives full account access, including the `/frappe/*` passthrough. iOS ATS and macOS sandbox also block cleartext, so this config only works on desktop/emulator dev.
- **Fix:** (1) Make the base URL environment-driven and default to `https` for release:

```dart
// lib/config/api_config.dart
class ApiConfig {
  // Injected at build time:
  //   flutter run --dart-define=API_BASE_URL=https://api.school.example.com
  //   flutter build apk --release --dart-define=API_BASE_URL=https://api.school.example.com
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080', // dev default only
  );
  ...
}
```

(2) Terminate TLS at the FastAPI/Frappe layer in production (reverse proxy with a real certificate). (3) For critical endpoints, pin the certificate — e.g. `HttpOverrides` or the `http` package's `badCertificateCallback` must **never** return `true`; prefer platform-native pinning via a proxy/`dio` + `dio_http2_adapter` or an embedded pinned public key.

### H-3. macOS app cannot make any outbound network request (sandbox entitlement missing)
- **File:** `macos/Runner/DebugProfile.entitlements`, `macos/Runner/Release.entitlements`
- **Problem:** Both entitlements files lack `com.apple.security.network.client`. The macOS app is sandboxed (app-sandbox = true) but has no client-network entitlement, so every HTTP request fails at the OS level on macOS — the app can only "work" in demo mode. (`network.server` in DebugProfile is for incoming connections only.)
- **Fix:** Add to **both** files:

```xml
<key>com.apple.security.network.client</key>
<true/>
```

### H-4. No token expiry/refresh handling — one long-lived JWT, 401 never triggers logout
- **File:** `lib/services/api_service.dart:55` (error path), `lib/state/auth_provider.dart:62-65`; backend `fastapi_backend/app/config.py` (`jwt_expire_minutes: 720`)
- **Problem:** The app holds a single JWT valid for **12 hours** with no refresh token. When it expires (or the server revokes it), the app does not detect the 401 — screens just show errors and the user must manually log out. No inactivity auto-logout either.
- **Fix:** (a) Shorten the token (`jwt_expire_minutes: 60`) and add a refresh-token endpoint on the bridge; (b) handle 401 centrally in `_handleResponse`:

```dart
// lib/services/api_service.dart
if (response.statusCode == 401) {
  // Central expiry handling — clear the session and force re-login.
  await logout();
  throw ApiException(message: 'Session expired. Please sign in again.', statusCode: 401);
}
```

and have the `AuthNotifier` listen for it (e.g. an `ApiException.unauthorized` flag) to navigate to the login screen. (c) Add an inactivity timer that calls `logout()` after N minutes.

### H-5. Silent fail-open into demo mode + demo credentials shipped in the app
- **File:** `lib/state/auth_provider.dart:104-111` (network failure → `_demoService.login`), `lib/screens/6_login_screen.dart:382,390` (demo creds shown on login), `lib/services/demo_data_service.dart` (full fake dataset)
- **Problem:** On **any** network failure the app logs the user into fabricated demo data — in production this silently shows fake grades/attendance as if real, and masks outages. Demo accounts (`student@school.com` / `student123`, `teacher@school.com` / `teacher123`) are hardcoded and displayed in the shipped UI.
- **Fix:** Gate demo mode behind a compile-time flag so release builds never enter it:

```dart
// lib/config/api_config.dart
static const bool enableDemoMode =
    bool.fromEnvironment('ENABLE_DEMO', defaultValue: kDebugMode);
```

```dart
// lib/state/auth_provider.dart — in the catch fallback:
} catch (e) {
  if (!ApiConfig.enableDemoMode) {
    state = state.copyWith(
      isLoading: false,
      error: 'Connection failed. Please try again.',
    );
    return false;
  }
  final demoUser = _demoService.login(email, password);
  ...
}
```

and hide the demo panel in release (`if (ApiConfig.enableDemoMode) ...`).

### H-6. FastAPI bridge JWT secret is the default
- **File:** `fastapi_backend/.env` (copied from `.env.example`) — `JWT_SECRET=change-me-in-production`
- **Problem:** The token the app uses for every request is signed with a known default secret. Anyone who deploys without changing it can forge authentication tokens and impersonate any user.
- **Fix:** Generate a strong secret and set it in `.env` (already gitignored):

```bash
cd fastapi_backend && python3.14 -c "import secrets; print(secrets.token_hex(32))"
# paste into .env → JWT_SECRET=<generated>
```

---

## 🟡 Medium

### M-1. Server error details / stack traces leak to the user
- **File:** `lib/services/api_service.dart:55` — `message: body['message'] ?? body['exc'] ?? body['detail']`; `lib/screens/admin/admin_dashboard.dart:39` renders `state.error` (raw `e.toString()`)
- **Problem:** Frappe errors include a full Python traceback in `exc`, which is surfaced in SnackBars; `e.toString()` from providers is rendered directly in the admin UI. This leaks internal file paths and implementation details to end users.
- **Fix:** Never surface `exc`. Use only a sanitized message:

```dart
message: body['message'] is String ? body['message'] : 'Something went wrong. Please try again.',
```

and cap the admin error render to a generic message (log details with `debugPrint` behind a flag instead).

### M-2. `android:allowBackup` defaults to true
- **File:** `android/app/src/main/AndroidManifest.xml`
- **Problem:** App data (including the stored user profile JSON) is included in ADB backups by default; on unencrypted/compromised devices this exposes PII. (The auth token itself is Keystore-backed so it generally won't restore, but the plaintext JSON wrapper is still copied.)
- **Fix:** Set `android:allowBackup="false"` (shown in H-1's fix).

### M-3. No biometric re-authentication for sensitive actions
- **File:** whole app — no `local_auth` usage
- **Problem:** Sensitive operations (viewing grades/attendance, changing password) require only the stored session token; there is no step-up auth. For a school app this is a privacy nicety rather than a hard requirement.
- **Fix:** Add `local_auth` and require biometric confirmation before password change and profile viewing when the device supports it.

### M-4. Session/credential persistence longer than needed
- **File:** `lib/services/api_service.dart:77-78` (token + user JSON written to secure storage), `fastapi_backend/app/config.py` (`jwt_expire_minutes = 720`)
- **Problem:** A 12-hour token stored in the Keychain/Keystore with no revocation loop. Acceptable for a school app but longer than necessary.
- **Fix:** Reduce to 60–120 minutes, add refresh tokens (see H-4), and consider clearing `user_data` after logout (already done) — plus auto-logout on inactivity.

### M-5. Outdated / unmaintained dependencies (no CVE triage process)
- **File:** `pubspec.yaml` — see the full table in the appendix.
- **Problem:** `flutter_secure_storage` 9.2.4 uses Google's deprecated `EncryptedSharedPreferences` (10.x moved to Keystore+DataStore, 11.x current); `file_picker` 8.3.7 is three major versions behind with an **open path-traversal advisory thread** (miguelpruivo/flutter_file_picker#1967); `flutter_riverpod` 2.6.1 is a major version behind 3.x; Dart 3.9.2 predates the **CVE-2026-27704 path-traversal fix** (Dart ≥ 3.11). No automated dependency scanning exists.
- **Fix:** Upgrade the majors (see appendix), and add `flutter pub outdated` / a Dependabot-style check to CI. For `file_picker`, also sanitize the picked file name before storing/uploading (only allow `[A-Za-z0-9._-]`, cap length).

### M-6. No crash reporting / no crash-data policy
- **File:** app-wide — no Crashlytics/Sentry
- **Problem:** No crash visibility, and therefore no PII-scrubbing policy can be demonstrated.
- **Fix:** Integrate Sentry (or Crashlytics) with `sendDefaultPii: false`, and never log request bodies or auth headers.

### M-7. No tamper / root / screenshot protections
- **File:** app-wide — no `FLAG_SECURE`, no root/jailbreak checks, no signature verification
- **Problem:** Screenshots of the profile (PII) and grades are unrestricted; a rooted device can inspect memory/Keystore more easily. For a school app this is defense-in-depth, not a blocker.
- **Fix (cheap, high value):** set `FLAG_SECURE` on the profile/change-password screens (`FlutterWindowManager.addFlags(FLAG_SECURE)` via a small method-channel or `flutter_windowmanager` package). Root detection is optional for this threat model.

### M-8. PII passed through Navigator route arguments
- **File:** `lib/screens/signup_step1.dart` → `signup_step2/3/4` (full name, email, **password** passed as `arguments` between steps)
- **Problem:** The password lives in `ModalRoute` arguments while the signup flow runs. In-memory only (no deep links configured, see L-3), so the practical risk is low — but it violates least-privilege on the widget tree.
- **Fix:** Hold signup data in a short-lived Riverpod provider (or `ChangeNotifier`) and clear it on completion instead of passing it through route arguments.

---

## 🟢 Low

### L-1. Unused `shared_preferences` dependency
- **File:** `pubspec.yaml:24-26` — declared, but zero usages in `lib/` or `test/`.
- **Fix:** Remove it (`flutter pub remove shared_preferences`). Reduces attack surface and build size.

### L-2. Weak demo passwords + hardcoded demo dataset (if ever shipped)
- **File:** `lib/services/demo_data_service.dart` (whole file)
- **Problem:** If a release build ever ships with demo mode enabled, fake accounts with trivial passwords are reachable and fake data is presented as real.
- **Fix:** Already covered by H-5 (`ENABLE_DEMO` gate). Delete the demo service from release via tree-shaking of that flag.

### L-3. No deep-link surface (good), but nothing guards it
- **File:** `lib/main.dart` (named routes only), `AndroidManifest.xml` (no VIEW intent-filter), `Info.plist` (no `CFBundleURLTypes`)
- **Problem:** None today — no deep links exist, so there is no injection surface. If deep links are added later, route arguments become attacker-controlled.
- **Fix:** When adding deep links: parse/validate all URI params, never pass raw URI values into Navigator arguments, and use `onGenerateRoute` with strict whitelisted paths.

### L-4. No certificate pinning
- **File:** `lib/services/api_service.dart` (plain `http` package)
- **Problem:** Without TLS in dev there's nothing to pin; in production, pinning the API host certificate is recommended defense-in-depth.
- **Fix:** Implement after HTTPS migration (see H-2).

### L-5. No root/jailbreak detection
- **File:** app-wide
- **Problem:** Not a banking app; the data is school records. Detection would add friction with little benefit.
- **Fix:** None required for this threat model — document the decision.

### L-6. Debug banner correctly disabled, but no `--obfuscate`
- **File:** `lib/main.dart:20` (`debugShowCheckedModeBanner: false` — good); release builds run without `--obfuscate --split-debug-info`
- **Problem:** Release binaries are not obfuscated — Dart symbol names are recoverable, making reverse-engineering of the (already public) demo logic easier.
- **Fix:** Release via `flutter build apk --release --obfuscate --split-debug-info=build/symbols` and keep the symbol map private.

---

## ✅ Checked and found OK

- **Secure storage:** tokens and user data are stored with `flutter_secure_storage` (Keychain/Keystore), **not** SharedPreferences — `lib/services/api_service.dart:21,77-78,151-157`.
- **No plaintext local persistence:** no SQLite/Hive/Isar/plain-file caching of sensitive data; no `path_provider` file writes of user data.
- **No logging of sensitive data:** zero `print`/`debugPrint`/`log` statements in `lib/`; API request/response bodies and auth headers are never logged.
- **TLS validation not disabled:** the `http` package is used with defaults; no `badCertificateCallback`, no `HttpClient` overrides.
- **No WebViews** — XSS surface does not exist.
- **No raw SQL/NoSQL** — all queries go through the FastAPI/Frappe REST layer (ORM-side validation).
- **Clipboard:** no sensitive data is ever copied to the clipboard.
- **Secrets in git:** git history (4 commits) contains no `.env`, keystore, `key.properties`, or API keys — only `.env.example` (template with placeholders). `democred.md` and `fastapi_backend/.env` are gitignored.
- **Platform permissions:** Android requests only `INTERNET` (dev manifests); no camera/location/contacts. iOS Info.plist declares no ATS exceptions and no unnecessary usage descriptions. No `NSAllowsArbitraryLoads`.
- **Input validation:** login/signup forms validate email format and password length; the backend re-validates.

---

## Appendix — Dependency status (`flutter pub outdated`, 2026-08-12)

| Package | Current | Latest | Gap | Notes |
|---------|---------|--------|-----|-------|
| file_picker | 8.3.7 | 11.0.3 | major | open path-traversal advisory thread (#1967); upgrade + sanitize picked filenames |
| flutter_secure_storage | 9.2.4 | 11.0.0 | major | 9.x uses deprecated EncryptedSharedPreferences; 10.x+ = Keystore + DataStore |
| flutter_riverpod | 2.6.1 | 3.4.2 | major | 3.x is a maintained rewrite |
| intl | 0.19.0 | 0.20.3 | minor | |
| flutter_lints | 5.0.0 | 6.0.0 | minor | |
| Dart SDK | 3.9.2 | ≥3.11 | — | CVE-2026-27704 (path traversal) fixed in 3.11.0 → upgrade Flutter |
| shared_preferences | 2.3.4 | — | — | **unused** — remove |

All packages resolve from `pub.dev` only (no custom/private sources in `pubspec.yaml` or `pubspec.lock`).

---

*Audit performed manually against the workspace; line numbers refer to the current working tree.*

---

# Security Audit — Web Stack (schooladmin + superadmin + sc_backend)

**Date:** 2026-08-21 · **Scope:** `schooladmin/`, `superadmin/`, `sc_backend/` (Node.js SQLite backend + Vite React frontends)
**Method:** static code review of JS/JSX, server configuration, conformance test analysis.

---

## Summary

| Severity | Count | Status |
|----------|-------|--------|
| High     | 2     | ✅ Fixed |
| Medium   | 4     | ✅ Fixed |
| Low      | 2     | ✅ Fixed |

**Bottom line:** All identified vulnerabilities have been remediated. The web stack now implements defense-in-depth across transport, session, input, and response layers.

---

## ✅ Resolved Issues

### H-1. CORS was wide-open — any website could make authenticated requests
- **Before:** Backend reflected any `Origin` header with `credentials: true`.
- **Fix:** Only `localhost`/`127.0.0.1` origins are accepted. POST requests from non-localhost origins return 403. Non-browser clients (curl, tests) without an `Origin` header are allowed through.
- **File:** `sc_backend/src/server.js` — CORS block.

### H-2. CSRF token not validated server-side
- **Before:** Frontend sent `X-Frappe-CSRF-Token` but the backend never checked it.
- **Fix:** All POST requests (except login) must include `X-Frappe-CSRF-Token: <user_id>`. Missing or invalid token → 403. The frontend stores the user ID as the CSRF token on login and clears it on logout.
- **Files:** `sc_backend/src/server.js`, `schooladmin/src/lib/auth.jsx`, `superadmin/src/lib/auth.jsx`.

### M-1. No rate limiting on login
- **Before:** Brute-force attacks were trivially possible.
- **Fix:** IP-based rate limiter: max 5 login attempts per 60 seconds per IP. Exceeding → 429 with `Retry-After` header.
- **File:** `sc_backend/src/server.js` — `loginRateMap`.

### M-2. No account lockout on repeated failures
- **Before:** Even with rate limiting, an attacker could try 5 passwords every minute indefinitely.
- **Fix:** Email-based lockout: 10 failed logins within 15 minutes locks the account for 15 minutes. Lockout is cleared on successful login.
- **File:** `sc_backend/src/server.js` — `lockoutMap`.

### M-3. Session TTL too long (12 hours)
- **Before:** Sessions lasted 12 hours — excessive for a school admin console.
- **Fix:** Reduced to 4 hours.
- **File:** `sc_backend/src/server.js` — `SESSION_TTL_MS`.

### M-4. Health endpoint leaked server internals
- **Before:** `GET /health` returned database path, sync queue depth, and dead letter count to anyone.
- **Fix:** Health endpoint still works (for monitoring) but sensitive details are only exposed when the request is authenticated.
- **File:** `sc_backend/src/server.js`.

### L-1. No security response headers
- **Before:** Backend responses lacked standard security headers.
- **Fix:** All API responses now include:
  - `X-Content-Type-Options: nosniff` — prevents MIME-type sniffing
  - `X-Frame-Options: DENY` — prevents clickjacking
  - `X-XSS-Protection: 0` — disables legacy XSS filter (rely on CSP)
  - `Referrer-Policy: strict-origin-when-cross-origin`
  - `Permissions-Policy: camera=(), microphone=(), geolocation=()`
  - `Content-Security-Policy: default-src 'none'; frame-ancestors 'none'`
- **File:** `sc_backend/src/server.js` — `sendJson()`.

### L-2. No request logging
- **Before:** No visibility into API usage patterns or attack attempts.
- **Fix:** All non-OPTIONS requests are logged with method, URL, status, response time, and client IP.
- **File:** `sc_backend/src/server.js` — `sendJson()` wrapper.

---

## Security Architecture Overview

### Transport Layer
| Control | Implementation |
|---------|---------------|
| CORS | Localhost-only origins |
| HSTS | `max-age=31536000; includeSubDomains` (via header; for production, enforce HTTPS at reverse proxy) |
| Content-Type sniffing | Blocked via `nosniff` |

### Session Layer
| Control | Implementation |
|---------|---------------|
| Cookie type | HttpOnly, SameSite=Lax |
| Session TTL | 4 hours |
| CSRF protection | User ID as token on all POST requests |
| Session fixation | Previous sessions deleted on login |

### Input Layer
| Control | Implementation |
|---------|---------------|
| SQL injection | All queries use parameterized `?` placeholders |
| Input validation | Present on every endpoint (name length, email format, etc.) |
| Password hashing | scrypt via `node:crypto` (N=16384, r=8, p=1, keylen=64) |
| Password policy | Minimum 6 characters enforced on change |

### Auth Layer
| Control | Implementation |
|---------|---------------|
| Role-based access | `requireAuth()` checks roles on every endpoint |
| School scoping | `requireOwnSchool()` prevents cross-school data access |
| Rate limiting | 5 attempts / 60s per IP on login |
| Account lockout | 10 failures / 15min locks account for 15min |
| Disabled accounts | Blocked at login with descriptive error |

### Response Layer
| Control | Implementation |
|---------|---------------|
| Security headers | CSP, X-Frame-Options, X-Content-Type-Options, etc. |
| Error masking | Only ApiError exceptions return details; others return generic 500 |
| Cache control | `no-store` on all API responses |
| Request logging | Method, URL, status, latency, IP |

### Sync Layer
| Control | Implementation |
|---------|---------------|
| Secret gate | Random 32-byte hex token required on `X-Sync-Secret` header |
| Internal only | Sync endpoints not exposed via the public API contract |
| Dead letters | Failed sync events stored for inspection at `/internal/sync/dead-letters` |

---

## Known Limitations (Accept for Now)

1. **Session store is in-memory** — sessions are lost on server restart. Acceptable for local dev; would need Redis/DB for production.
2. **Lockout state is in-memory** — restarting the server clears all lockouts. Same caveat.
3. **Mock mode** stores session in `localStorage` (accessible to XSS). Live mode uses HttpOnly cookies — no issue there.
4. **No TLS termination** — the backend listens on HTTP. For production, place behind a reverse proxy (nginx/Caddy) that terminates TLS.
5. **Demo credentials visible on login page** — acceptable for local dev; must be removed before production deployment.

---
*Audit performed 2026-08-21 against the current working tree.*
