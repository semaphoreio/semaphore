package trivy

default ignore = false

ignore {
	deny_vulnerability_ids := {
		#
		# Dead code: the service has no SSH surface. `go mod why
		# golang.org/x/crypto/ssh` reports "main module does not need package",
		# and govulncheck finds no call path. Trivy matches on the module list
		# embedded in the binary rather than the linked package set, so it
		# reports packages that were never compiled in.
		# Fixed in x/crypto v0.55.0.
		#
		"CVE-2026-56854",
		"CVE-2026-39828",
		"CVE-2026-39829",
		"CVE-2026-39830",
		"CVE-2026-39831",
		"CVE-2026-39832",
		"CVE-2026-39835",
		"CVE-2026-42508",
		"CVE-2026-46595",
		"CVE-2026-46597",
		#
		# Dead code or imported-but-uncalled: govulncheck finds no path to the
		# vulnerable symbols in x/net.
		# Fixed in x/net v0.56.0.
		#
		"CVE-2026-25681",
		"CVE-2026-27136",
		"CVE-2026-33814",
		"CVE-2026-39821",
		"CVE-2026-46600",
		#
		# pgx is linked via gorm.io/driver/postgres, but govulncheck finds no
		# path to the vulnerable symbols for these two. Fixed in pgx v5.9.0 —
		# blocked because pgx v5.9.0+ requires Go 1.25 while the builder is
		# golang:1.24 and go.mod declares go 1.24.0.
		#
		"CVE-2026-33815",
		"CVE-2026-33816",
		#
		# Requires a hostile or compromised broker: the payload is
		# broker-controlled and RABBITMQ_URL is a fixed internal endpoint with
		# no user-controlled surface. Patched version not stated in the
		# advisory; latest is v1.14.0.
		#
		"CVE-2026-79921",
		#
		# xDS only: the panic is in the routing interceptor that
		# `xds.NewGRPCServer` installs. This service never calls it — both
		# servers use plain `grpc.NewServer` — and `xds` does not appear in
		# go.sum at all, so the vulnerable code is not in the module graph, let
		# alone compiled in. Fixed in grpc v1.82.2 / v1.83.2.
		#
		"CVE-2026-84445",
		#
		# REACHABLE — suppressed only to unblock CI, not because they are safe.
		# Both are availability-only and confined to the internal gRPC server on
		# :50051 (ClusterIP, not in the ingress, no ambassador gRPC mapping), but
		# govulncheck does find a call path:
		#   pkg/internalapi/server.go:64 -> grpc.Server.Serve -> http2Server.HandleStreams
		# Remove these two, and CVE-2026-84445 above, by bumping grpc to
		# v1.83.2.
		#
		"GHSA-hrxh-6v49-42gf",
		"CVE-2026-84304",
		#
		# REACHABLE — suppressed only to unblock CI. Infinite loop on invalid
		# input, reached through the DB layer:
		#   pkg/database/advisorylock.go:39 -> gorm.DB.Begin -> norm.Form.Transform
		# Remove this by bumping x/text to v0.39.0.
		#
		"CVE-2026-56852"
	}

	input.VulnerabilityID = deny_vulnerability_ids[_]
}
