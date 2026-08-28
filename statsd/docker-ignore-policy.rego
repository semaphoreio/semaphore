package trivy

default ignore = false

ignore {
	deny_vulnerability_ids := {
		#
		# node-tar 6.2.0 — CVE-2026-59873: no hard bounds on decompressed size/entry count, so a
		# crafted gzip bomb exhausts disk/CPU during extraction (fixed in node-tar 7.5.19). The
		# statsd sidecar never extracts untrusted archives; tar arrives transitively via npm
		# tooling in the image, not in a request path.
		"CVE-2026-59873"
	}

	input.VulnerabilityID = deny_vulnerability_ids[_]
}
