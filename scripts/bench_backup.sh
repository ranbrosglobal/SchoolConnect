#!/usr/bin/env bash
# School Connect — Frappe bench backup + restore helpers.
#
# Backs up the school site (default library.localhost) and the super-admin
# site (default superadmin.localhost) using `bench backup`.
#
# Prerequisites:
#   - The bench must be running (start.sh brings it up).
#   - MariaDB + Redis up for the sites being backed up.
#
# Usage:
#   ./scripts/bench_backup.sh              # backup both sites into backups/
#   ./scripts/bench_backup.sh --site library.localhost   # backup one site
#   ./scripts/bench_backup.sh --list                  # list existing backups
#   ./scripts/bench_backup.sh --restore <backup.tar>   # restore a backup (DANGEROUS)
#
# Restore notes:
#   - Restoring overwrites the site's database. Test on a copy first.
#   - After restore, run `bench build` and restart the site.
#   - Media files (user uploads) are NOT covered by this script; back them up
#     separately from ~/Documents/frappe/frappe-bench/sites/<site>/private/files
#     and public/files if you need them.
#
# Environment:
#   FRAPPE_BENCH_DIR  (default ~/Documents/frappe/frappe-bench)
#   FRAPPE_SITE       (default library.localhost) — used for --site omission

set -euo pipefail

BENCH_DIR="${FRAPPE_BENCH_DIR:-"$HOME/Documents/frappe/frappe-bench"}"
SITES_DIR="$BENCH_DIR/sites"
BACKUP_DIR="$(pwd)/backups"
DEFAULT_SITE="${FRAPPE_SITE:-library.localhost}"
SUPER_SITE="${FRAPPE_SUPER_SITE:-superadmin.localhost}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Frappe bench backup + restore helpers for the School Connect sites.

Options:
  (no args)            Backup both the school site and the super-admin site.
  --site <site>        Backup a single site (default: $DEFAULT_SITE).
  --list               List backups in $BACKUP_DIR.
  --restore <file>     Restore a backup archive (DANGEROUS — overwrites DB).
  --help               This message.

Environment:
  FRAPPE_BENCH_DIR  Bench directory (default: $BENCH_DIR)
  FRAPPE_SITE       Default school site (default: $DEFAULT_SITE)

Backups are written to: $BACKUP_DIR
EOF
}

list_backups() {
  if [[ ! -d "$BACKUP_DIR" ]]; then
    echo "No backup directory found at $BACKUP_DIR."
    return
  fi
  echo "Backups in $BACKUP_DIR:"
  ls -1 "$BACKUP_DIR" 2>/dev/null || echo "  (empty)"
}

backup_site() {
  local site="$1"
  local site_dir="$SITES_DIR/$site"
  if [[ ! -d "$site_dir" ]]; then
    echo "ERROR: site directory not found: $site_dir"
    return 1
  fi

  mkdir -p "$BACKUP_DIR"
  local ts
  ts="$(date +%Y%m%d_%H%M%S)"
  local out="$BACKUP_DIR/${site}_${ts}.tar"
  echo "Backing up $site -> $out ..."

  (
    cd "$BENCH_DIR"
    bench backup --site "$site" --with-files --backup-dir "$BACKUP_DIR" >/dev/null 2>&1
  )

  # bench backup creates <site>_<ts>.sql.gz + files tar; bundle them together.
  local file_gz="$BACKUP_DIR/${site}_${ts}.sql.gz"
  local files_tar="$BACKUP_DIR/${site}_files_${ts}.tar"
  if [[ -f "$file_gz" ]] && [[ -f "$files_tar" ]]; then
    tar -cf "$out" -C "$BACKUP_DIR" "$(basename "$file_gz")" "$(basename "$files_tar")"
    rm -f "$file_gz" "$files_tar"
    echo "Bundle created: $out ($(du -h "$out" | cut -f1))"
  elif [[ -f "$out" ]]; then
    echo "Backup artifact exists: $out"
  else
    echo "WARNING: backup may have failed — no artifact found."
    return 1
  fi
}

restore_site() {
  local backup="$1"
  if [[ ! -f "$backup" ]]; then
    echo "ERROR: backup file not found: $backup"
    exit 1
  fi

  echo "RESTORING $backup — this OVERWRITES the site's database."
  echo "Press Ctrl-C now to abort, or wait 5 seconds..."
  sleep 5

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  tar -xf "$backup" -C "$tmp_dir"

  local sql_gz="$(ls "$tmp_dir"/*.sql.gz 2>/dev/null | head -n 1)"
  if [[ -z "$sql_gz" ]]; then
    echo "ERROR: no .sql.gz found in the backup bundle."
    rm -rf "$tmp_dir"
    exit 1
  fi

  local site_name
  site_name="$(basename "$backup" .tar | sed 's/_.*//')"

  echo "Restoring site '$site_name' from $sql_gz ..."
  (
    cd "$BENCH_DIR"
    gunzip -c "$sql_gz" | bench --site "$site_name" restore --with-public-files "$tmp_dir" --backup-version 15 >/dev/null 2>&1
  )

  rm -rf "$tmp_dir"
  echo "Restore complete for $site_name."
  echo "Next steps:"
  echo "  1. bench build (if JS/CSS changed)"
  echo "  2. restart the site: bench --site $site_name serve --port <port>"
  echo "  3. re-run seed_data.py if you need demo data re-seeded"
}

main() {
  local mode="backup"
  local site=""
  local restore=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help) usage; exit 0 ;;
      --list) mode="list" ;;
      --site) site="$2"; shift ;;
      --restore) restore="$2"; shift ;;
      *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
    esac
    shift
  done

  if [[ "$mode" == "list" ]]; then
    list_backups
    exit 0
  fi

  if [[ -n "$restore" ]]; then
    restore_site "$restore"
    exit $?
  fi

  if [[ -n "$site" ]]; then
    backup_site "$site"
  else
    echo "Backing up school site ($DEFAULT_SITE) and super-admin site ($SUPER_SITE)..."
    backup_site "$DEFAULT_SITE" || true
    backup_site "$SUPER_SITE" || true
    echo "Backups written to: $BACKUP_DIR"
  fi
}

main "$@"
