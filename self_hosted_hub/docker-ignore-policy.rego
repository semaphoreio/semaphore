package trivy

default ignore = false

ignore {
	deny_vulnerability_ids := {
		#
		# Dead code: no SSH surface in this service. `go mod why
		# golang.org/x/crypto/ssh` reports "main module does not need package".
		# Trivy matches on the module list embedded in the binary rather than
		# the linked package set. Fixed in x/crypto v0.55.0.
		#
		"CVE-2026-56854",
		#
		# pgx is linked via gorm.io/driver/postgres, but govulncheck finds no
		# path to the vulnerable symbols. Fixed in pgx v5.9.0 — blocked because
		# pgx v5.9.0+ requires Go 1.25 while the builder is golang:1.24.
		#
		"CVE-2026-33815",
		"CVE-2026-33816"
	}

	input.VulnerabilityID = deny_vulnerability_ids[_]
}
