---
description: Ubuntu 24.04 (ARM) Image Reference
---

# Ubuntu 24.04 (ARM)







This is a customized ARM image based on [Ubuntu 24.04](https://wiki.ubuntu.com/NobleNumbat/ReleaseNotes) (Noble Numbat LTS).

This OS can only be paired with [R1 ARM machines](../machine-types#r1).

<Tabs groupId="editor-yaml">
<TabItem value="editor" label="Editor">

To use this operating system, and choose `ubuntu2404` in the **OS Image** selector. This OS can be paired with [R1 machines](../machine-types#r1).

![Selecting the Ubuntu 24.04 using the workflow editor](./img/ubuntu2404-arm-selector.jpg)

</TabItem>
<TabItem value="yaml" label="YAML">

To use this operating system, you must select an [`r1-standard-4`] machine and use `ubuntu2404` as the `os_image`:

```yaml
version: 1.0
name: Ubuntu2404 Based Pipeline
agent:
  machine:
  # highlight-start
    type: r1-standard-4
    os_image: ubuntu2404
  # highlight-end
```

</TabItem>
</Tabs>

The following section describes the software pre-installed on the image.

## Toolbox

The image comes with the following [toolbox utilities](../toolbox) preinstalled:

- [sem-version](../toolbox#sem-version): manage language versions on Linux

## Version control

Following version control tools are pre-installed:

- Git 2.51.2
- Git LFS (Git Large File Storage) 3.7.1
- GitHub CLI 2.80.0
- Mercurial 6.7.2
- Svn 1.14.3

### Browsers and Headless Browser Testing

- Firefox 140.4.0esr
- Geckodriver 0.36.0
- Chromium 142
- Chromium Driver 142
- Xvfb (X Virtual Framebuffer)

Chrome and Firefox both support headless mode. You shouldn't need to do more
than install and use the relevant Selenium library for your language.
Refer to the documentation of associated libraries when configuring your project.

### Docker

Docker toolset is installed and the following versions are available:

- Docker 28.4.0
- Docker-compose 2.39.4 (used as `docker compose version`)
- Docker-buildx 0.29.1
- Docker-machine 0.16.2
- Dockerize 0.9.6
- Buildah 1.33.7
- Podman 4.9.3
- Skopeo 1.13.3

### Cloud CLIs

- Aws-cli 2.31.1 (used as `aws`)
- Azure-cli 2.79.0
- Eb-cli 3.25
- Ecs-cli 1.21.0
- Doctl 1.142.0
- Gcloud 540.0.0
- Gke-gcloud-auth-plugin 540.0.0
- Kubectl 1.29.1
- Terraform 1.13.3
- Helm 3.19.0

### Network utilities

- Httpie 3.2.3
- Curl 8.5.0
- Rsync 3.2.7

## Compilers

- gcc: 11, 12, 13 (default)

## Languages

### Erlang and Elixir

Erlang versions are installed and managed via [kerl](https://github.com/kerl/kerl).
Elixir versions are installed with [kiex](https://github.com/taylor/kiex).

- Erlang: 24.3, 25.x, 26.x, 27.x (27.0 as default), 28.x
- Elixir: 1.14.x, 1.15.x, 1.16.x, 1.17.x (1.17.3 as default), 1.18.x, 1.19.x

Additional libraries:

- Rebar3: 3.24.0

### Go

Versions:

- 1.19.x
- 1.20.x
- 1.21.x
- 1.22.x
- 1.24.x
- 1.25.x

The default installed Go version is 1.25.1

### Java and JVM languages

- Java: 11.0.28, 17.0.16 (default), 21.0.8
- Scala: 3.2.2
- Leiningen: 2.12.0 (Clojure)
- Sbt 1.11.6

### Additional Java build tools

- Maven: 3.9.11
- Gradle: 9.1.0

### JavaScript via Node.js

Node.js versions are managed by [nvm](https://github.com/nvm-sh/nvm).
You can install any version you need with `nvm install [version]`.
Installed version:

- v22.19.0 (set as default, with alias 22.19), includes npm 10.9.3

### Additional JS tools

- Yarn: 1.22.19

### PHP

PHP versions are managed by [phpbrew](https://github.com/phpbrew/phpbrew).
Available versions:

- 8.1.x
- 8.2.x
- 8.3.x

The default installed PHP version is `8.1.33`.

### Additional PHP libraries

PHPUnit: 9.5.28

### Python

Python versions are installed and managed by
[virtualenv](https://virtualenv.pypa.io/en/stable/). Installed versions:

- 3.10.19
- 3.11.14
- 3.12.3 (default)

Supporting libraries:

- pypy3: 7.3.19
- pip: 25.3
- venv: 20.34.0

### Ruby

Available versions:

- 3.2.x
- 3.3.x
- 3.4.x

The default installed Ruby version is `3.4.6`.

### Rust

- 1.91.0

### Swiftly

- 1.1.0

## See also

- [Installing packages on Ubuntu](../os-ubuntu)
- [Machine types](../machine-types)
- [Semaphore Toolbox](../toolbox)
- [Pipeline YAML refence](../pipeline-yaml)
