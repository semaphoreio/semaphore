# rbac/ce — Dependency CVE Reachability Report

Investigation of the 13 unsuppressed `mix_audit` advisories in `rbac/ce`, plus a
correction to the single suppression already present in `.mix-audit.txt`.

**Scope:** investigation only. No dependency bumps, no `.pb` regeneration, no
suppression edits were made as part of this report. Recommended `.mix-audit.txt`
entries are proposed below for a follow-up change.

## Service architecture (evidence for every verdict below)

`rbac/ce` is an **internal gRPC service**. It runs a gRPC **server** and also
acts as a gRPC **client** to sibling internal services.

- **gRPC server** — started at [`lib/rbac/application.ex:24`](rbac/ce/lib/rbac/application.ex:24)
  (`GRPC.Server.Supervisor, servers: grpc_services(), port: 50_051, start_server: true`).
  Registered servers: `Rbac.GrpcServers.RbacServer` (`InternalApi.RBAC.RBAC.Service`)
  at [`lib/rbac/grpc_servers/rbac_server.ex:2`](rbac/ce/lib/rbac/grpc_servers/rbac_server.ex:2)
  and a health check at [`lib/rbac/grpc_servers/health_check.ex:2`](rbac/ce/lib/rbac/grpc_servers/health_check.ex:2).
- **Not internet-facing.** The k8s Service is `type: NodePort`
  ([`helm/templates/service.yaml:8`](rbac/ce/helm/templates/service.yaml:8)), exposing
  port 50051; there is **no Ingress and no LoadBalancer** in `helm/templates/`.
  Reached only by sibling services inside the deployment, never by end users.
- **No custom codec / no compression opt-in.** A grep for `Erlpack`, `GRPC.Codec`,
  `codecs:`, `GRPC.Compressor` across `lib/` and `config/` returns **nothing**.
- **gRPC client uses the Gun adapter (default).** All three client call sites pass
  only an endpoint, no `adapter:` option:
  [`lib/rbac/api/organization.ex:9`](rbac/ce/lib/rbac/api/organization.ex:9),
  [`lib/rbac/api/user.ex:39-40`](rbac/ce/lib/rbac/api/user.ex:39),
  [`lib/rbac/api/project.ex:8-10`](rbac/ce/lib/rbac/api/project.ex:8).
  `GRPC.Stub.connect/2` in grpc 0.8.1 defaults to
  `GRPC.Client.Adapters.Gun` (`adapter = Keyword.get(opts, :adapter) || GRPC.Client.Adapters.Gun`,
  verified in the upstream v0.8.1 source). **`mint` is compiled in as a grpc
  dependency but is never on any runtime path.**
- **Client endpoints are static config**, never user-controlled:
  [`config/runtime.exs:28-30`](rbac/ce/config/runtime.exs:28) reads
  `INTERNAL_API_URL_USER` / `INTERNAL_API_URL_PROJECT` / `INTERNAL_API_URL_ORGANIZATION`
  (defaulting to `localhost:50052`).
- **No other HTTP client.** `rbac/ce` has no `hackney`, `httpoison`, `tesla`,
  `finch`, or `req` dependency (unlike `ee/rbac`), and no direct `gun`/`mint` use
  in `lib/`. `mint` and `gun` enter the tree **only** via `grpc`.

Consequences that fall out of the above:

- **`mint` advisories are dead code** in `rbac/ce` — the Gun adapter is used, so
  the Mint client adapter code never executes. This is a *stronger* verdict than
  the internal-trust argument.
- **`gun` advisories are on a live path** (Gun is the client transport) but are
  bounded by the internal trust boundary: `rbac/ce` only ever connects Gun to the
  three static internal endpoints above, and the request lines it emits are gRPC
  method paths, not user-controlled strings.
- **grpc server advisories** split into reachable (availability-only, internal
  callers) vs unreachable (feature not enabled), exactly as `ee/rbac` documents.

---

## grpc 0.8.1 (server + client; fixed in grpc 1.0.0, breaking major)

### GHSA-grp7-v8xh-rj7h — RCE / atom-table exhaustion via `:erlang.binary_to_term` in `GRPC.Codec.Erlpack.decode/2` (CRITICAL)
- **Verdict: UNREACHABLE (dead code).**
- **Evidence:** exploiting this needs a server that registers the Erlpack codec
  and accepts `application/grpc+erlpack`. `rbac/ce` registers no custom codec —
  grep for `Erlpack`, `GRPC.Codec`, `codecs:` across `lib/` and `config/` is empty.
- **Impact:** none as configured.
- **Action:** suppress with reachability rationale (port from `ee/rbac`). Real fix
  is the grpc 1.0.0 monorepo migration.

### GHSA-6ccx-9c9f-327w — gzip decompression bomb in `GRPC.Compressor.Gzip.decompress/1` (HIGH)
- **Verdict: REACHABLE, availability-only, internal callers only.**
- **Evidence:** fires on frames arriving at the server with `grpc-encoding: gzip`.
  The server is live ([`application.ex:24`](rbac/ce/lib/rbac/application.ex:24)) but
  internal-only (`NodePort`, no Ingress). No compression is explicitly enabled, but
  the decompressor is exercised by the server on request.
- **Impact:** memory pressure / DoS of the rbac pod, triggerable only by an
  in-cluster caller. No RCE, no data disclosure.
- **Action:** suppress as availability-only + internal (port from `ee/rbac`).

### GHSA-q8gf-9rvj-gmgj — unbounded request-body accumulation in `read_full_body/3` (HIGH)
- **Verdict: REACHABLE, availability-only, internal callers only.**
- **Evidence:** part of the server request read loop, which is live. Same internal
  boundary as above.
- **Impact:** memory exhaustion DoS from an in-cluster caller. Availability only.
- **Action:** suppress as availability-only + internal (port from `ee/rbac`).

### GHSA-mwr4-5g34-j5cq — path bindings overridable by query string / request body (HIGH)
- **Verdict: UNREACHABLE.**
- **Evidence:** requires HTTP/JSON transcoding of gRPC path bindings. `rbac/ce`
  exposes only native gRPC (`use GRPC.Server` handlers, no transcoding / grpc-gateway
  config anywhere in `lib/` or `config/`).
- **Impact:** none — feature not exposed.
- **Action:** suppress as unreachable (port from `ee/rbac`).

---

## mint 1.6.2 (grpc's alternative client adapter — NOT selected; fixed in 1.9.0)

All four `mint` advisories share the same verdict.

- **Verdict: UNREACHABLE (dead code).**
- **Evidence:** `mint` is present only because `grpc` declares it a non-optional
  dependency. The runtime client adapter is **Gun** (default; no `adapter:` passed
  at any `GRPC.Stub.connect` site — see architecture section). The server side uses
  the Cowboy adapter, not Mint. No code path in `rbac/ce` reaches
  `GRPC.Client.Adapters.Mint` or `Mint.*`.
- **Impact:** none as configured. Even if the Mint adapter *were* selected, every
  one of these is an HTTP-response / request-construction issue and `rbac/ce`'s only
  peers are static, trusted internal endpoints.
- **Action:** suppress all four with a shared "Mint adapter not selected; Gun is the
  active transport" rationale. `ee/rbac` does **not** currently carry mint entries —
  this rationale is new and should be authored here (and is worth back-porting to
  `ee/rbac`, which has the same default-adapter situation).

| Advisory | Severity | Issue |
|---|---|---|
| GHSA-2p26-p43x-fhp8 | high | CONTINUATION/HEADERS frame flood (unbounded accumulation) |
| GHSA-g586-ccqf-7x4r | high | unbounded `streams` map growth via PUSH_PROMISE without HEADERS |
| GHSA-mjqx-c6f6-7rc2 | moderate | Content-Length accepts non-RFC values |
| GHSA-2pg6-44cx-c49v | low | CRLF injection in request line via method/target |

---

## gun 2.1.0 (active gRPC client transport; fixed in 2.4.0 / cowlib 2.16.0)

Gun **is** the transport `rbac/ce` uses for outbound gRPC. All four are on a live
path but bounded by the internal trust boundary: connections go only to the three
static internal endpoints, and request lines are gRPC method paths.

### GHSA-2j82-37xg-f9wp — unexpected status code / return value (HIGH)
- **Verdict: REACHABLE transport, not exploitable by end users; availability-only.**
- **Evidence:** triggered by a malformed **server response**. `rbac/ce`'s Gun peers
  are trusted internal services at [`config/runtime.exs:28-30`](rbac/ce/config/runtime.exs:28).
- **Impact:** a malformed response could crash an outbound rbac→peer call. Requires
  a compromised/buggy in-cluster peer. Availability only.
- **Action:** suppress as internal-transport + availability-only.

### GHSA-r53j-fjj5-mv77 — uncontrolled resource consumption / unbounded HTTP/1.1 response buffering (HIGH)
- **Verdict: REACHABLE transport, not exploitable by end users; availability-only.**
- **Evidence:** response-side buffering; same trusted-peer boundary. gRPC is HTTP/2,
  so the HTTP/1.1 buffering path is only reached on a protocol fallback from an
  internal peer.
- **Impact:** memory pressure driven by a compromised in-cluster peer. Availability only.
- **Action:** suppress as internal-transport + availability-only.

### GHSA-36w4-95hv-5vwg — `gun_http2` origin validation error / cross-origin cookie injection via PUSH_PROMISE authority (MODERATE)
- **Verdict: NOT EXPLOITABLE.**
- **Evidence:** requires a server pushing PUSH_PROMISE frames with a crafted
  authority, **and** a client that consumes the resulting cookies. `rbac/ce` uses Gun
  purely as a gRPC transport; it does not maintain or act on an HTTP cookie store, and
  its peers are trusted internal services.
- **Impact:** none in this usage.
- **Action:** suppress as not-applicable (no cookie handling; internal peers).

### GHSA-w4f7-4cxr-rv3c — cowboy/gun HTTP request/response splitting via CRLF (MODERATE; `<2.16.0` range is cowlib's numbering, over-matches gun)
- **Verdict: NOT EXPLOITABLE.**
- **Evidence:** request splitting needs user-controlled CRLF in the request line or
  headers. `rbac/ce`'s Gun requests carry gRPC method paths and static targets; no
  free-form user input reaches the request line. This is the shared cowboy/gun
  advisory whose range over-matches gun.
- **Impact:** none in this usage.
- **Action:** suppress. **`ee/rbac` already documents this exact advisory** — port
  its rationale verbatim (adjusting "ee/rbac" → "rbac/ce").

---

## Correction to the existing suppression

### GHSA-rhv4-8758-jx7v — decimal (already suppressed in `.mix-audit.txt`)
- **Description mismatch — fix it.** The current
  [`rbac/ce/.mix-audit.txt`](rbac/ce/.mix-audit.txt) comment calls this
  *"unvalidated field values"*. The advisory is actually **"unbounded exponent in
  `Decimal.new`"** (as `ee/rbac`'s file correctly states). The suppression *decision*
  is still correct — only the description is wrong.
- **Verdict stands: not reachable.** `decimal` 2.4.1 is pinned by `ecto` 3.12.5
  (`{:decimal, "~> 2.0"}`); the fix is decimal 3.0.0, which requires an Ecto major
  upgrade. Note `postgrex` 0.22.2 already allows `~> 3.0`, so **Ecto is the sole
  remaining cap** — the CE comment's "Ecto major upgrade" reasoning is the accurate
  one (more accurate than `ee/rbac`, which still blames postgrex 0.19.3). `rbac/ce`
  does not parse attacker-controlled input into `Decimal`.
- **Action:** rewrite the comment to name the real advisory ("unbounded exponent in
  `Decimal.new`"); keep the suppression.

---

## Summary

| Advisory | Dep | Sev | Verdict | Action |
|---|---|---|---|---|
| GHSA-grp7-v8xh-rj7h | grpc | critical | Unreachable (no codec) | Suppress — port from ee/rbac |
| GHSA-6ccx-9c9f-327w | grpc | high | Reachable, availability-only, internal | Suppress — port from ee/rbac |
| GHSA-q8gf-9rvj-gmgj | grpc | high | Reachable, availability-only, internal | Suppress — port from ee/rbac |
| GHSA-mwr4-5g34-j5cq | grpc | high | Unreachable (no transcoding) | Suppress — port from ee/rbac |
| GHSA-2p26-p43x-fhp8 | mint | high | Dead code (Gun adapter used) | Suppress — new rationale |
| GHSA-g586-ccqf-7x4r | mint | high | Dead code (Gun adapter used) | Suppress — new rationale |
| GHSA-mjqx-c6f6-7rc2 | mint | moderate | Dead code (Gun adapter used) | Suppress — new rationale |
| GHSA-2pg6-44cx-c49v | mint | low | Dead code (Gun adapter used) | Suppress — new rationale |
| GHSA-2j82-37xg-f9wp | gun | high | Reachable transport, availability-only, internal | Suppress — new rationale |
| GHSA-r53j-fjj5-mv77 | gun | high | Reachable transport, availability-only, internal | Suppress — new rationale |
| GHSA-36w4-95hv-5vwg | gun | moderate | Not exploitable (no cookie use) | Suppress — new rationale |
| GHSA-w4f7-4cxr-rv3c | gun | moderate | Not exploitable (static request lines) | Suppress — port from ee/rbac |
| GHSA-rhv4-8758-jx7v | decimal | moderate | Not reachable (already suppressed) | Fix description; keep suppression |

**No advisory is exploitable by an untrusted / internet-facing actor.** The gRPC
server is internal-only (`NodePort`, no Ingress); the two genuinely-reachable server
paths (gzip bomb, unbounded body) are availability-only and reachable solely by
in-cluster callers; all `mint` advisories are dead code under the default Gun
adapter; all `gun` advisories are bounded by connections to static, trusted internal
endpoints.

### Entries to port from `ee/rbac/.mix-audit.txt`
- The four **grpc** advisories — `ee/rbac` already carries reachability rationale for
  all four (`GHSA-grp7-v8xh-rj7h`, `GHSA-6ccx-9c9f-327w`, `GHSA-q8gf-9rvj-gmgj`,
  `GHSA-mwr4-5g34-j5cq`). Port near-verbatim (the server-is-internal argument is
  identical).
- The **gun** `GHSA-w4f7-4cxr-rv3c` advisory — `ee/rbac` documents it; port it.

### Entries `rbac/ce` needs that `ee/rbac` does not have
- The three other **gun** advisories (`GHSA-2j82-37xg-f9wp`, `GHSA-r53j-fjj5-mv77`,
  `GHSA-36w4-95hv-5vwg`) — not in `ee/rbac`'s file; author fresh.
- All four **mint** advisories — `ee/rbac` has no mint entries. Author a shared
  "Mint adapter not selected" rationale (and consider back-porting to `ee/rbac`).
- Note: `ee/rbac`'s hackney/protobuf/postgrex/cowlib entries do **not** apply —
  `rbac/ce` has no hackney (no outbound non-gRPC HTTP), and its protobuf/postgrex/
  cowlib versions differ.
