#!/usr/bin/env bash

set -uo pipefail

export MIX_ENV=test
export CI=true
export BRANCH=main

PG_VERSION="${PG_VERSION:-9.6}"
ARMS="${ARMS:-9.6/stock 9.6/config 17/stock 17/config 17/config 17/stock 9.6/config 9.6/stock}"
TMPFS_SIZE="${TMPFS_SIZE:-2G}"
APP="$(basename "$PWD")"
OUT="${OUT:-$PWD/out/db-bench}"
mkdir -p "$OUT"

log() { echo "[bench $APP $(date -u +%H:%M:%S)] $*"; }

pg_down() {
  docker rm -f postgres >/dev/null 2>&1
  sudo umount /var/tmp/postgres >/dev/null 2>&1
  sudo rm -rf /var/tmp/postgres
}

pg_query() {
  docker exec postgres psql -U postgres -tAc "$1" 2>/dev/null | tr -d '[:space:]'
}

pg_tune() {
  docker exec postgres psql -U postgres -v ON_ERROR_STOP=1 \
    -c "ALTER SYSTEM SET fsync = off" \
    -c "ALTER SYSTEM SET full_page_writes = off" \
    -c "ALTER SYSTEM SET synchronous_commit = off" \
    -c "SELECT pg_reload_conf()" >/dev/null
}

run_arm() {
  local ver="$1" mode="$2" iter="$3" label t0 t1 logfile finished served settings
  label="pg${ver}-${mode}-${iter}"
  logfile="$OUT/${label}.log"

  log "=== arm $iter: postgres $ver / $mode"
  pg_down
  if [ "$mode" = "config_tmpfs" ]; then
    sudo mkdir -p /var/tmp/postgres
    sudo mount -t tmpfs -o "size=$TMPFS_SIZE,mode=0777" tmpfs /var/tmp/postgres || { log "tmpfs mount FAILED"; return 1; }
    log "tmpfs $TMPFS_SIZE on /var/tmp/postgres"
  fi

  sem-service start postgres "$ver" >/dev/null 2>&1
  served=$(pg_query "SHOW server_version")
  if [ -z "$served" ]; then
    log "postgres $ver did not come up - skipping arm"
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$APP" "$ver" "$mode" "$iter" "DOWN" "0" >> "$OUT/results.tsv"
    return 1
  fi

  case "$mode" in
    config|config_tmpfs) pg_tune ;;
  esac
  settings=$(pg_query "SELECT current_setting('fsync')||'/'||current_setting('full_page_writes')||'/'||current_setting('synchronous_commit')")
  log "server_version=$served fsync/fpw/sync_commit=$settings"

  t0=$(date +%s)
  make test.ex >"$logfile" 2>&1
  t1=$(date +%s)

  finished=$(grep -oE 'Finished in [0-9]+(\.[0-9]+)? seconds' "$logfile" | tail -1 | grep -oE '[0-9]+(\.[0-9]+)?' | head -1)
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$APP" "$ver" "$mode" "$iter" "${finished:-NA}" "$(( t1 - t0 ))" >> "$OUT/results.tsv"
  log "arm $iter (pg$ver/$mode): exunit=${finished:-NA}s wall=$(( t1 - t0 ))s"
  if [ "${finished:-NA}" = "NA" ]; then
    log "no ExUnit timing - tail of log:"
    tail -20 "$logfile"
  fi
  return 0
}

log "machine: $(nproc) vCPU / $(free -g | awk '/Mem:/{print $2}') GiB"
log "arms: $ARMS"
printf 'app\tpg\tarm\titer\texunit_s\twall_s\n' > "$OUT/results.tsv"

log "priming image + rabbitmq (untimed)"
make build >"$OUT/build.log" 2>&1 || { log "make build FAILED"; tail -25 "$OUT/build.log"; exit 1; }
sem-service start rabbitmq 3.8 >/dev/null 2>&1

i=0
for spec in $ARMS; do
  i=$((i + 1))
  case "$spec" in
    */*) run_arm "${spec%%/*}" "${spec##*/}" "$i" ;;
    *)   run_arm "$PG_VERSION" "$spec" "$i" ;;
  esac
done

pg_down
log "results:"
column -t "$OUT/results.tsv"

mkdir -p "$OUT/self"
cp "$OUT/results.tsv" "$OUT/self/${APP}.tsv"
bash "$(dirname "$0")/report.sh" "$OUT/self" "$OUT/REPORT.md" >/dev/null && log "job report: $OUT/REPORT.md"
