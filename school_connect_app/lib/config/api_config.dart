/// API Configuration for School Connect.
///
/// Live backend: Frappe v17 + Education + the `sc_auth` custom app.
/// Each school runs its own Frappe site + MariaDB; the app talks to the
/// school site that authenticates the user (auto-detected at login).
///
/// URLs are driven by environment variables so the same app binary runs
/// against localhost dev benches and against deployed hosts:
///   SC_BACKEND_URL     - school site base URL (default http://localhost:8000)
///   SC_SUPERADMIN_URL  - super-admin registry site (default http://localhost:8002)
///   SC_WEB_ADMIN_URL   - school admin web dashboard (default http://localhost:5173)
/// No plaintext secrets live in this file. The JWT signing key is a Frappe
/// site-config value (`sc_auth_jwt_secret`), set per site — never shipped
/// in the app bundle.
class ApiConfig {
  static String get backendHost {
    return const String.fromEnvironment('SC_BACKEND_URL',
        defaultValue: 'http://localhost')
        .replaceAll('\\', '/');
  }

  static int get backendPort {
    return int.tryParse(
        const String.fromEnvironment('SC_BACKEND_PORT', defaultValue: '8000')) ?? 8000;
  }

  /// Full backend base URL for the mobile app (the school site that
  /// authenticated the current user).
  static String get backendBaseUrl => '$backendHost:$backendPort';

  static String get superAdminHost {
    return const String.fromEnvironment('SC_SUPERADMIN_URL',
        defaultValue: 'http://localhost')
        .replaceAll('\\', '/');
  }

  static int get superAdminPort {
    return int.tryParse(
        const String.fromEnvironment('SC_SUPERADMIN_PORT', defaultValue: '8002')) ?? 8002;
  }

  static String get superAdminBaseUrl => '$superAdminHost:$superAdminPort';

  /// Web admin dashboard URL (for the mobile redirect screen).
  static String get webAdminUrl {
    return const String.fromEnvironment('SC_WEB_ADMIN_URL',
        defaultValue: 'http://localhost:5173');
  }

  /// Timeout settings.
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
