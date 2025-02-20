package trivy

default ignore = false

ignore {
	deny_vulnerability_ids := {
		#
		# Trivy still complains about this in the /usr/bin/migrate binary.
		# Nothing we can about it until the maintainer updates that dependency on their end.
		# See: https://github.com/golang-migrate/migrate/issues/1211
		#
		"CVE-2024-45337",
		"CVE-2024-45338"
	}

	input.VulnerabilityID = deny_vulnerability_ids[_]
}
