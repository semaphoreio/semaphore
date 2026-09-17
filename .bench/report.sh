#!/usr/bin/env bash

set -uo pipefail

IN="${1:-db-bench}"
OUT="${2:-REPORT.md}"

if ! ls "$IN"/*.tsv >/dev/null 2>&1; then
  echo "no result files under $IN" >&2
  exit 1
fi

{
  echo "# CI database bench"
  echo
  echo "Postgres crash-safety config and a tmpfs data directory, measured against this repo's test suites."
  echo "Each job ran its arms on one VM in counterbalanced order (\`stock … stock\`), so the config"
  echo "comparison is paired and host variance cancels. Independent jobs supply the replicates."
  echo
  echo "## Paired result per job"
  echo
  echo "One row per VM. **drift** is the gap between that job's first and last \`stock\` arm — the"
  echo "control. A row with double-digit drift is not usable no matter what its delta says."
  echo
  echo "| app | pg | job | stock | config | +tmpfs | config Δ | tmpfs Δ | drift |"
  echo "|---|---|---|---:|---:|---:|---:|---:|---:|"

  awk -F'\t' '
    FNR == 1 { next }
    {
      f = FILENAME
      sub(/.*\//, "", f); sub(/\.tsv$/, "", f)
      if ($5 == "NA" || $5 == "DOWN") { broken[f] = broken[f] " " $3; next }
      app[f] = $1; pg[f] = $2
      sum[f, $3] += $5; n[f, $3]++
      if ($3 == "stock") { if (!(f in sf)) sf[f] = $5; sl[f] = $5 }
    }
    END {
      for (k in app) {
        s  = n[k, "stock"]        ? sum[k, "stock"] / n[k, "stock"]               : 0
        c  = n[k, "config"]       ? sum[k, "config"] / n[k, "config"]             : 0
        t  = n[k, "config_tmpfs"] ? sum[k, "config_tmpfs"] / n[k, "config_tmpfs"] : 0
        cd = (s > 0 && c > 0) ? sprintf("%+.1f%%", (c - s) / s * 100) : "—"
        td = (s > 0 && t > 0) ? sprintf("%+.1f%%", (t - s) / s * 100) : "—"
        dr = (sf[k] > 0) ? sprintf("%+.1f%%", (sl[k] - sf[k]) / sf[k] * 100) : "—"
        printf "| %s | %s | `%s` | %.1f | %s | %s | %s | %s | %s |\n",
          app[k], pg[k], k, s,
          (c > 0 ? sprintf("%.1f", c) : "—"),
          (t > 0 ? sprintf("%.1f", t) : "—"),
          cd, td, dr
        if (k in broken) printf "| %s | %s | `%s` | **arms failed:**%s | | | | | |\n", app[k], pg[k], k, broken[k]
      }
    }
  ' "$IN"/*.tsv | sort -t'|' -k2,2 -k3,3 -k4,4

  echo
  echo "## Engine comparison"
  echo
  echo "Across jobs, so this one is **not** paired — agents vary ~2x by physical host. Read the range,"
  echo "not the mean."
  echo
  echo "| app | pg | jobs | stock median | stock range |"
  echo "|---|---|---:|---:|---|"

  awk -F'\t' '
    FNR == 1 { next }
    $3 == "stock" && $5 != "NA" && $5 != "DOWN" {
      k = $1 SUBSEP $2
      v[k] = v[k] " " $5
      f = FILENAME; sub(/.*\//, "", f)
      if (!(k SUBSEP f in seen)) { seen[k SUBSEP f] = 1; jobs[k]++ }
      app[k] = $1; pg[k] = $2
    }
    END {
      for (k in v) {
        cnt = split(v[k], a, " ")
        m = 0
        for (i = 1; i <= cnt; i++) if (a[i] != "") { x[++m] = a[i] + 0 }
        for (i = 1; i < m; i++) for (j = i + 1; j <= m; j++) if (x[j] < x[i]) { tmp = x[i]; x[i] = x[j]; x[j] = tmp }
        med = (m % 2) ? x[(m + 1) / 2] : (x[m / 2] + x[m / 2 + 1]) / 2
        printf "| %s | %s | %d | %.1f | %.1f – %.1f |\n", app[k], pg[k], jobs[k], med, x[1], x[m]
        delete x
      }
    }
  ' "$IN"/*.tsv | sort -t'|' -k2,2 -k3,3

  echo
  echo "## How to read this"
  echo
  echo "- **config Δ** — tuned suite time against stock on the same VM. Negative is faster."
  echo "- **drift** — the same stock config, measured twice on one VM. This is the noise floor."
  echo "  A config Δ smaller than drift means nothing was measured."
  echo "- Arms applied \`fsync=off\`, \`full_page_writes=off\`, \`synchronous_commit=off\` by"
  echo "  \`ALTER SYSTEM\` + reload. \`wal_level=minimal\` is postmaster-context and out of reach"
  echo "  without replacing \`sem-service\` with a direct \`docker run\`."
  echo
  echo "Raw arms: \`artifact pull workflow db-bench\`"
} > "$OUT"

echo "wrote $OUT"
