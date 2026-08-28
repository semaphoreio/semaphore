package trivy

default ignore = false

ignore {
	deny_vulnerability_ids := {
		#
		# github.com/jackc/pgx/v5 v5.5.4 baked into the shipped binary — memory-safety issues,
		# fixed in a later v5 release. pgx is an indirect dependency; database connections go to
		# the service's own trusted Postgres instance, so exploitation requires a compromised
		# database server. Bump tracked on the coordinated dep-bump branch.
		"CVE-2026-33815",
		"CVE-2026-33816"
	}

	input.VulnerabilityID = deny_vulnerability_ids[_]
}
