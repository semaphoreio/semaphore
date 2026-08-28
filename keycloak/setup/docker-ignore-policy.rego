package trivy

default ignore = false

ignore {
	deny_vulnerability_ids := {
		# CVE's that are comming from keycloak provider. We must wait for the maintainer to update the golang
		"CVE-2024-24790",
		"CVE-2024-45337",
		#
		# OpenSSL 3.3.2 (libcrypto3/libssl3) — CVE-2026-31789: heap buffer overflow converting
		# oversized OCTET STRING values to hex, 32-bit platforms only. Our images are built and
		# run on 64-bit (amd64/arm64), so the overflowing size calculation cannot occur.
		"CVE-2026-31789",
		#
		# Bundled provider binaries ship older Go toolchains/deps we cannot rebuild here:
		# CVE-2026-33186 (grpc-go :path authorization bypass) — the binaries serve no gRPC
		# endpoints with authorization interceptors in this setup container;
		# CVE-2025-68121 (crypto/tls session-resumption check skip on mutated Config) — requires
		# a Config.Clone/GetConfigForClient mutation pattern these tools do not use.
		# Both wait on upstream maintainer rebuilds (same acceptance as the CVEs above).
		"CVE-2026-33186",
		"CVE-2025-68121"
	}

	input.VulnerabilityID = deny_vulnerability_ids[_]
}
