package trivy

default ignore = false

ignore {
	deny_vulnerability_ids := {
		# CVE's that are comming from keycloak provider. We must wait for the maintainer to update the golang
		"CVE-2024-24790",
		"CVE-2024-45337"
	}

	input.VulnerabilityID = deny_vulnerability_ids[_]
}
