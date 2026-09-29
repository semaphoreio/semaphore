package trivy

default ignore = false

ignore {
	deny_vulnerability_ids := {
		#
		# Trivy complains about this in the /usr/bin/migrate binary.
		# Nothing we can about it until the maintainer updates that dependency on their end.
		# See: https://github.com/golang-migrate/migrate/issues/1357
		#
		"CVE-2026-33186",
		"CVE-2025-68121"
	}

	input.VulnerabilityID = deny_vulnerability_ids[_]
}
