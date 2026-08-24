# SchoolConnect Web Consoles — Commands

Commands for running the two **web admin consoles** (React + Vite apps):

- `schooladmin/` — **School Admin Console** (teachers, classes, students, timetable)
- `superadmin/` — **Super Admin Console** (schools + school admins, network overview)

> Terminal: PowerShell or Git Bash on Windows. Everything below runs from the project root (`C:\Users\dell\Desktop\Ranbros`) — the root `package.json` wires up both consoles.

---

## 1. First-time setup

```powershell
npm install                  # root runner deps (concurrently)
cd schooladmin && npm install
cd superadmin && npm install
```

Requires **Node 18+** (built and tested on Node 24). No backend is needed — each app ships with an in-browser mock backend.

## 2. Run the consoles (development)

```powershell
npm run dev:all              # BOTH consoles together
npm run dev:schooladmin      # school admin console only
npm run dev:superadmin       # super admin console only
```

- **School Admin:** http://localhost:5173/
- **Super Admin:** http://localhost:5175/
- Hot reload: edits to `src/` show up instantly. Both stop with `Ctrl + C` in their terminal.

## 3. Check code quality

```powershell
npm run lint:schooladmin
npm run lint:superadmin
```

Expect `Found 1 warning and 0 errors` in each — that one warning is benign (React Fast Refresh).

## 4. Build the production version

```powershell
npm run build:schooladmin    # outputs to schooladmin/dist
npm run build:superadmin     # outputs to superadmin/dist
```

To serve a *built* app locally, `cd` into that app and run `npm run preview` (serves on http://localhost:5173/ by default). `dev` is for daily work.

---

## 5. Mock mode vs. live backend

The app has two modes, controlled by an env var:

| Mode | Env var | What happens |
|---|---|---|
| **Mock** (default) | `VITE_APP_MODE=mock` | No server needed. Data is seeded + stored in your browser's `localStorage`. |
| **Live (SQLite)** | `VITE_APP_MODE=live` + `VITE_API_URL` | Talks to the local `sc_backend/` databases (ports 8090/8091) — real persistence, no Frappe needed. |
| **Live (Frappe)** | `VITE_APP_MODE=live` | With a local Frappe bench on `:8000` (dev proxy) or a remote `VITE_API_URL`. |

**Easiest: everything in one command (SQLite backend + both consoles):**

```powershell
npm run dev:live      # sc_backend (:8090/:8091) + schooladmin (:5173) + superadmin (:5175)
```

Or individually:

```powershell
npm run dev:db                   # databases + API only (uses Node's built-in SQLite — no install)
npm run dev:schooladmin:live     # schooladmin → http://localhost:8090 (port 5173)
npm run dev:superadmin:live      # superadmin  → http://localhost:8091 (port 5175)
```

The `:live` scripts use each console's `.env.live` (`VITE_APP_MODE=live`, `VITE_API_URL=...`) via Vite's `--mode live`. The default `npm run dev` still runs mock mode — nothing about the demo flow changes.

To point at a remote server instead: `$env:VITE_APP_MODE = "live"` + `$env:VITE_API_URL = "https://your-server.com"` (clear with `Remove-Item Env:VITE_APP_MODE`).

## 6. Demo accounts & resetting demo data

This console is **School Admin only** — super admins sign in from the separate `superadmin/` console. Quick logins (all on the login page as one-click "demo" buttons too):

| Role | Email | Password |
|---|---|---|
| School Admin · Springfield | `priya@springfield.edu` | `admin123` |
| School Admin · Riverside | `ravi@riverside.edu` | `admin123` |
| School Admin · Sunrise | `aman@sunrise.edu` | `admin123` |

**Reset the demo data** — two ways, depending on mode:

- **Mock mode:** open the browser DevTools console and run:

```js
localStorage.removeItem('sc_schooladmin_db_v1')
localStorage.removeItem('sc_schooladmin_session')
location.reload()
```

- **Live (SQLite) mode:** wipe and re-seed both databases from the repo root:

```powershell
npm run db:reset
```

Both restore the original demo dataset (4 schools, 7 classes, 127 students).

> Each console keeps its own storage namespace, so they never collide:
> `sc_schooladmin_*` for this app, `sc_superadmin_*` for the Super Admin
> console (`superadmin/`), which has its own separate demo database
> (schools + school admins, managed at **http://localhost:5175/schools**).

---

## 7. Git workflow

The local branch is `master`; the GitHub branch is `main` (remote `origin` already configured).

```powershell
# Pull the latest from GitHub (origin/main)
git pull

# Push your commits to GitHub
git push origin master:main
```

**Make `git push` / `git pull` plain (no branch gymnastics) — rename once:**

```powershell
git branch -m master main
git push -u origin main
```

**First commit on a fresh machine** (repo has no author identity configured — set once):

```powershell
git config user.name "Your Name"
git config user.email "you@example.com"
```

**Typical commit flow:**

```powershell
git status          # see what changed
git add schooladmin # stage only the web app work (avoid git add . — sweeps in cache noise)
git commit -m "Describe the change"
git push origin master:main
```

---

## 8. Useful shortcuts

| Task | Command |
|---|---|
| Run both consoles | `npm run dev:all` |
| See what's changed | `git status` |
| See a summary of the diff | `git diff --stat` |
| Stash everything safely | `git stash push -u -m "wip"` |
| Restore a stash | `git stash pop` |
| Check the dev server is up | `curl -s -o /dev/null -w "%{http_code}" http://localhost:5173/` |
| Which port is Vite on? | `netstat -ano \| grep ":5173\|:5175" \| grep LISTEN` |

---

## 9. Other apps in this repo (not the web console)

- `sc_backend/` — **SQLite databases + API** for the web consoles (ports 8090/8091). Zero-install (Node built-in SQLite); seeded from the mock universes. See its `README.md`.
- `school_connect_app/` — the **Flutter mobile app** (students & teachers). Runs with `flutter run`.
- `demoapp/` — the newer Flutter app (school picker, export). Runs with `flutter run` from its folder.
- `school_connect/` — the **Frappe backend** (Python). Runs via `bench start` (port 8000) — the real API the web app connects to in **live (Frappe)** mode.
- `sc_auth/` — a Frappe app for multi-school auth/registry (school sites + super-admin registry site).
- `fastapi_backend/` — a FastAPI bridge app (Python). Check its own `README` for run steps.

The web console's mock mode means you can build and demo **without** any of these running.
