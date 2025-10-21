---
description: Open source security scans in your CI pipelines
sidebar_position: 2
---

# Trivy Vulnerability Scanning







This page explains how to run the open source [Trivy security scanner](https://github.com/aquasecurity/trivy) in Semaphore.

## Overview

Trivy is a comprehensive security scanner that detects various security issues across different targets.

It can scan:

- container images
- software dependencies
- Git repositories
- VM images and OS packages
- Kubernetes environments
- Infrastructure-as-Code (IaC) files
- filesystems for misconfigurations, leaked secrets, and license check

Trivy works with most programming languages and operating systems. You can check if your stack is supported in the [Trivy scanning coverage page](https://trivy.dev/latest/docs/coverage/).

## Install Trivy in Semaphore {#install}

You must install Trivy in the CI environment or use a Docker image with Trivy already installed.

To install Trivy in your CI environment, follow these steps:

<Steps>

1. Find the [latest Trivy release](https://github.com/aquasecurity/trivy/releases)
2. Install Trivy using the package manager (or build from source)

    ```shell
    # replace with the latest release
    wget https://github.com/aquasecurity/trivy/releases/download/v0.65.0/trivy_0.65.0_Linux-32bit.deb
    sudo dpkg -i trivy_0.65.0_Linux-32bit.deb
    ```

3. Run Trivy to scan your project. Use the `--exit-code 1` option to exit with error when the scan detects a problem

    For example:

    ```shell
    checkout
    trivy fs --exit-code 1 .
    ```

</Steps>

You must repeat Step 2 in every job that uses Trivy. Use the [prologue](../pipelines#prologue) if multiple jobs require Trivy.

## Enabling the cache {#cache}

Trivy keeps the last scans and vulnerability database in a local folder in the CI environment. You can speed up scanning jobs by caching this directory.

Trivy stores its database in `$HOME/.cache/trivy` by default, you can change it by specifing the [`--cache-dir`](https://trivy.dev/latest/docs/configuration/cache/) option. To persist this directory, use the [cache](../cache) command.

The following example runs a [file scan](#files) using the cache:

```shell
cache restore trivy-db
trivy fs --exit-code 1 .
cache store trivy-db $HOME/.cache/trivy
```

You can use this pattern with all types of scanning.

## Scan Files {#files}

Trivy filesystem scan finds problems in your local directories. In the CI environment, you must run [`checkout`](../../reference/toolbox#checkout) to clone the repository in the CI machine.

To run filesystem scan use `trivy fs`.
Filesystem scan can find:

- vulnerabilies
- misconfigurations
- leaked secrets
- license checks

### Vulnerabilities and leaked secrets {#vulnerabilities}

To find vulnerabilities or leaked secrets in your code or dependencies, execute `trivy fs` as follows:

```shell
checkout
trivy fs --exit-code 1 path/to/src 
```

### Misconfigurations {#misconfigurations}

By default, Trivy doesn't try to find misconfigurations, to enable this option, follow this example:

```shell
checkout
trivy --scanners misconfig --exit-code 1 path/to/src
```

### License {#license}

To perform [license scanning](https://trivy.dev/latest/docs/scanner/license/) execute Trivy as follows:

```shell
checkout
trivy fs --scanners license --exit-code 1 path/to/src
```

## Scan Container images

To scan your container images, including OS packages, use the following command. You might need to [authenticate with the Docker registry](../containers/docker#auth) first.

```shell
docker pull IMAGE_NAME:TAG
trivy image --exit-code 1 IMAGE_NAME:TAG
```

As with filesystem scans, you can enable [misconfigurations](#misconfigurations) and [license](#license) scans in the container image.

## Generate SBOM

Trivy can generate a [Software Bill of Materials (SBOM)](https://trivy.dev/latest/docs/supply-chain/sbom/).

For example, these command generate the SBOM using the CycloneDX format:

```shell
checkout
trivy fs --format cyclonedx --output sbom.json path/to/src
artifact push workflow sbom.json
```

You can also generate SBOMs for Docker images with:

```shell
docker pull IMAGE_NAME:TAG
trivy image --format cyclonedx --output sbom.json IMAGE_NAME:TAG
artifact push workflow sbom.json
```

## See also

- [Trivy repository](https://github.com/aquasecurity/trivy)
- [Trivy Documentation](https://trivy.dev/latest/docs/)
- [Continuous Container Vulnerability Testing with Trivy](https://semaphore.io/blog/continuous-container-vulnerability-testing-with-trivy#h-vulnerability-testing-for-dependencies)
