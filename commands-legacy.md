# SchoolConnect Web Admin — Commands

All commands for running and operating the **web admin console** (React + Vite app in `schooladmin/`).

> Terminal: PowerShell or Git Bash on Windows. Everything below is run from the project root (`C:\Users\dell\Desktop\Ranbros`) unless it says `cd schooladmin` first.

---

## 1. First-time setup

```powershell
cd schooladmin
npm install
```

Requires **Node 18+** (built and tested on Node 24). No backend is needed to run the app — it ships with an in-browser mock backend.

## 2. Run the app (development)

```powershell
cd schooladmin
npm run dev
```

- Open **http://localhost:5173/** in your browser.
- Hot reload: edits to `src/` show up instantly.
- Stops with `Ctrl + C`.

## 3. Check code quality

```powershell
cd schooladmin
npm run lint
```

Expect `Found 1 warning and 0 errors` — that one warning is benign (React Fast Refresh).

## 4. Build & preview the production version

```powershell
cd schooladmin
npm run build      # outputs the production bundle to schooladmin/dist
npm run preview    # serves the built app locally (default http://localhost:5173/)
```

`preview` serves the *built* app — use it to verify what the production build looks like. `dev` is for daily work.

---

## 5. Mock mode vs. real backend

The app has two modes, controlled by an env var:

| Mode | Env var | What happens |
|---|---|---|
| **Mock** (default) | `VITE_APP_MODE=mock` | No server needed. Data is seeded + stored in your browser's `localStorage`. |
| **Live** | `VITE_APP_MODE=live` | Talks to the real Frappe backend (`school_connect.api.*`). |

```powershell
# mock (default — nothing to set)
npm run dev

# live — with a local Frappe bench running on :8000 (dev proxy already configured)
$env:VITE_APP_MODE = "live"
npm run dev

# live — pointing at a remote server
$env:VITE_APP_MODE = "live"
$env:VITE_API_URL = "https://your-server.com"
npm run dev
```

To clear a set env var in PowerShell: `Remove-Item Env:VITE_APP_MODE`.

## 6. Demo accounts & resetting demo data

Quick logins (all on the login page as one-click "demo" buttons too):

| Role | Email | Password |
|---|---|---|
| Super Admin | `admin@schoolconnect.app` | `admin123` |
| School Admin · Springfield | `priya@springfield.edu` | `admin123` |
| School Admin · Riverside | `ravi@riverside.edu` | `admin123` |
| School Admin · Sunrise | `aman@sunrise.edu` | `admin123` |

**Reset the demo data** (removes everything you created/edited and restores the clean seed). Open the browser DevTools console and run:

```js
localStorage.removeItem('sc_mock_db_v1')
localStorage.removeItem('sc_admin_session')
location.reload()
```

That's it — the app rebuilds the original demo dataset (4 schools, 7 classes, 127 students).

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
| See what's changed | `git status` |
| See a summary of the diff | `git diff --stat` |
| Stash everything safely | `git stash push -u -m "wip"` |
| Restore a stash | `git stash pop` |
| Check the dev server is up | `curl -s -o /dev/null -w "%{http_code}" http://localhost:5173/` |
| Which port is Vite on? | `netstat -ano \| grep ":5173" \| grep LISTEN` |

---

## 9. Other apps in this repo (not the web console)

- `school_connect_app/` — the **Flutter mobile app** (students & teachers). Runs with `flutter run`.
- `school_connect/` — the **Frappe backend** (Python). Runs via `bench start` (port 8000) — this is the real API the web app connects to in **live** mode.
- `fastapi_backend/` — a FastAPI bridge app (Python). Check its own `README` for run steps.

The web console's mock mode means you can build and demo **without** any of these running.
