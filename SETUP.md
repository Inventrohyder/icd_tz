# ICD-TZ Setup

ICD-TZ is a Frappe app. It needs Frappe Bench, ERPNext, MariaDB, Redis, Node/Yarn, and Python.

Use the dev container for repeatable development. Use the native Mac setup when you want everything installed directly on the Mac.

This setup targets the current Frappe/ERPNext v16 stack: Frappe `version-16`, ERPNext `version-16`, Python 3.14, Node 24, MariaDB 11.8, and Redis 8.

## Option 1: Dev Container

Best for sharing with other developers.

```bash
brew install --cask docker visual-studio-code
code --install-extension ms-vscode-remote.remote-containers
```

Install Docker Desktop and VS Code Dev Containers.

```bash
git clone https://github.com/Aakvatech-Limited/icd_tz.git
cd icd_tz
code .
```

Open the repo in VS Code, then run:

```text
Dev Containers: Reopen in Container
```

Terminal equivalent:

```bash
make dev-up
```

The dev container creates the generated Bench at this container path:

```text
/workspace/development/frappe-bench
```

That path is backed by the Docker named volume `bench-data`, not by a checked-in repo folder. The ignored `development/` path is only a safety net for native setup or accidental host-side Bench folders.

It installs Frappe v16, ERPNext v16, ICD-TZ, MariaDB 11.8, and Redis 8. Dev Container defaults live in `.devcontainer/docker-compose.yml` next to the service that uses them; the setup scripts consume those values instead of defining a second setup surface.

Start the app from the Mac host:

```bash
make dev-start
```

Useful host commands:

```bash
make dev-status
make dev-stop
make dev-shell
```

Inside the Dev Container, use the Bench targets directly:

```bash
make bench-start
make bench-status
make bench-stop
```

VS Code equivalent:

```text
Terminal > Run Task > ICD-TZ: Start Bench (Dev Container)
```

Open:

```text
http://127.0.0.1:8000/app/icd
```

Login:

```text
Administrator / admin
```

Notes:

- The first run can be slow because Docker must pull `frappe/bench:latest` and install Frappe/ERPNext dependencies.
- Dev Containers uses Docker Compose internally. Use `devcontainer up` or VS Code as the normal entry point; use `docker compose` directly only for low-level debugging.
- To reset all generated dev data, run `docker compose -f .devcontainer/docker-compose.yml down --volumes --remove-orphans`.
- `make dev-start` intentionally keeps the Bench logs in the terminal. Stop it with `Ctrl+C` or run `make dev-stop` from another terminal.
- ICD-TZ is installed locally with `bench get-app --soft-link icd_tz /workspace/icd_tz --skip-assets`. This is the local equivalent of the README's GitHub `bench get-app` command, but it keeps `apps/icd_tz` linked to the checked-out workspace.
- `--skip-assets` avoids repeated intermediate asset builds during setup. The setup script runs one final `bench build` after Frappe, ERPNext, and ICD-TZ are installed.

## Option 2: Native New Mac Setup

Best when you do not want Docker.

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"
```

Install Homebrew.

```bash
brew install git uv node@24 yarn redis mariadb
uv python install 3.14
export PATH="$(brew --prefix node@24)/bin:$HOME/.local/bin:$PATH"
```

Install Frappe runtime dependencies.

```bash
brew services start mariadb
mariadb -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'root'; FLUSH PRIVILEGES;"
```

Start MariaDB and set a dev-only root password.

```bash
mkdir -p ~/Developer/icd-tz
cd ~/Developer/icd-tz
uv tool install --python 3.14 frappe-bench
export PATH="$HOME/.local/bin:$PATH"
```

Install Bench with uv.

```bash
bench init frappe-bench --frappe-branch version-16 --python python3.14
cd frappe-bench
bench get-app --branch version-16 erpnext
bench get-app --branch main https://github.com/Aakvatech-Limited/icd_tz --skip-assets
```

Create the Frappe bench and add ERPNext plus ICD-TZ.

```bash
bench new-site icdtz.localhost \
  --db-host 127.0.0.1 \
  --db-port 3306 \
  --mariadb-root-username root \
  --mariadb-root-password root \
  --admin-password admin \
  --set-default
```

Create the site.

```bash
bench --site icdtz.localhost install-app erpnext
bench --site icdtz.localhost install-app icd_tz
bench --site icdtz.localhost migrate
bench build
bench start
```

Install apps, migrate, build assets, and run.

Open:

```text
http://127.0.0.1:8000/app/icd
```

Login:

```text
Administrator / admin
```

## Alternative: Frappe Manager

Frappe Manager is a good Frappe-specific container workflow. It is not the same as a repo-native devcontainer, because developers must install and use `fm`.

```bash
uv tool install --python 3.14 frappe-manager
fm create icdtz --apps erpnext:version-16 --apps Aakvatech-Limited/icd_tz:main --python 3.14 --node 24 --admin-pass admin
fm start icdtz
```

Use it when you want a managed Frappe Docker bench. Use the checked-in devcontainer when you want VS Code/Codex to recreate the environment from files in this repo.

## Non-Working Paths

- Running `icd_tz` directly with Python fails because it is a Frappe app, not a standalone service.
- Installing `icd_tz` without ERPNext fails because it depends on ERPNext doctypes like `Sales Order`, `Sales Invoice`, `Price List`, and `Item`.
- MySQL 8 fails with Frappe schema issues such as `TEXT/BLOB/JSON column can't have a default value`; use MariaDB.
- Mixing Frappe v16 with ERPNext v15, or the reverse, fails because Frappe and ERPNext branches must match.
- Bench installed in a venv without `PATH` exported can fail with `No process manager found` or `No such file or directory: bench`.
- Manually editing `sites/apps.txt` is fragile. Use `bench get-app`, including `bench get-app --soft-link app_name /path/to/app` for local development, so Bench owns app registration.
- Running `bench doctor` before `bench start` shows Redis errors because Redis is not running yet.
- A normal single production container is not ideal for development because ICD-TZ needs editable source, Bench commands, MariaDB, Redis, workers, socketio, and file watching.
- Running `docker compose up` directly is not the normal devcontainer workflow; it starts services, but skips the Dev Containers lifecycle unless you also run the setup commands yourself.
