package trivy

default ignore = false

ignore {
	deny_vulnerability_ids := {
		#
		# golang.org/x/net v0.48.0 + golang.org/x/text v0.32.0, fixed upstream in later releases;
		# bump tracked on the coordinated dep-bump branch.
		# CVE-2026-25681 / CVE-2026-27136: x/net/html Render produces an unexpected tree from
		# crafted HTML (XSS in sanitize-then-render flows). This service parses/renders no HTML.
		"CVE-2026-25681",
		"CVE-2026-27136",
		# CVE-2026-33814: x/net/http2 infinite CONTINUATION loop on SETTINGS_MAX_FRAME_SIZE=0.
		# Availability-only; service is reachable only from inside the cluster.
		"CVE-2026-33814",
		# CVE-2026-39821: idna ToASCII/ToUnicode accept malformed Punycode; no hostname-based
		# privilege checks are done here.
		"CVE-2026-39821",
		# CVE-2026-46600: x/net/dns panic on invalid SVCB/HTTPS RR; resolver input comes from
		# cluster DNS, not attacker-supplied records.
		"CVE-2026-46600",
		# CVE-2026-56852: x/text norm.Iter infinite loop on invalid UTF-8; no untrusted text
		# normalization in this service.
		"CVE-2026-56852",
		#
		# google.golang.org/grpc v1.79.3 — GHSA-hrxh-6v49-42gf: xDS RBAC fail-open + HTTP/2
		# rapid-reset mitigation bypass. xDS/RBAC is not used anywhere in this repo; the
		# rapid-reset variant is availability-only on an internal, cluster-only listener.
		"GHSA-hrxh-6v49-42gf"
	}

	input.VulnerabilityID = deny_vulnerability_ids[_]
}
