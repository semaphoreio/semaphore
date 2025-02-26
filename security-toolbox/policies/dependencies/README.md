# Dependency security

Run the security scan with:

```
./dependencies --language go|js|elixir
```

The tool used depends on the language:
- Golang and Javascript: [trivy](https://github.com/aquasecurity/trivy)
- Elixir: [mix_audit](https://github.com/mirego/mix_audit)

By default, if the tool required isn't installed, the scan will fail. If you want to automatically install it, use the `-d` flag.

## Options

- `-l, --language LANGUAGE`: required; language of the dependencies to scan.
- `-k, --skip-files SKIP_FILES`: comma-separated list of files to skip when scanning docker files. Default is `Dockerfile.dev`.
- `-s, --severity SEVERITY`: comma-separated list of severity levels to filter when scanning docker image. Default is `HIGH,CRITICAL` (trivy) and `medium` (sobelow).
- `-p, --ignore-policy IGNORE_POLICY_PATH`: path to the ignore policy file used by Trivy when scanning Golang or Javascript projects. Default is none.
- `-i, --ignore-packages IGNORE_PACKAGES`: comma-separated list of packages to ignore by `MixAudit` when scanning Elixir projects. Default is none.
- `-w, --whitelist-license-for-packages WHITELIST_LICENSES_FOR_PACKAGES`: comma-separated list of packages to ignore for their licenses when scanning Elixir or Ruby projects. Default is none.
- `-d, --dependencies`: install missing dependencies
