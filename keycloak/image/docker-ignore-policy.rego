package trivy

default ignore = false

ignore {
	deny_vulnerability_ids := {
		#
		# org.bouncycastle:bcprov-jdk18on 1.78.1 shipped inside the upstream Keycloak
		# distribution — CVE-2025-14813: broken cryptographic algorithm in
		# G3413CTRBlockCipher (GOST cipher family). Keycloak does not use GOST ciphers, and
		# the jar is bundled by upstream; nothing to change on our side until Keycloak ships
		# a bumped BouncyCastle.
		"CVE-2025-14813"
	}

	input.VulnerabilityID = deny_vulnerability_ids[_]
}
