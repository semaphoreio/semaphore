---
description: Ubuntu 24.04 Image Reference
---

# Ubuntu 24.04 (x86_64)

This is a customized x86_64 image based on [Ubuntu 24.04](https://releases.ubuntu.com/noble/) (Noble Numbat LTS).

<Tabs groupId="editor-yaml">
<TabItem value="editor" label="Editor">

To use this operating system, and choose `ubuntu2404` in the **OS Image** selector.

![Selecting the Ubuntu 24.04 using the workflow editor](./img/ubuntu2404-selector.jpg)

</TabItem>
<TabItem value="yaml" label="YAML">

To use this operating system, you must select a machine type and use `ubuntu2404` as the `os_image`:

```yaml
version: 1.0
name: Ubuntu2404 Based Pipeline
agent:
  machine:
  # highlight-start
    type: f1-standard-4
    os_image: ubuntu2404
  # highlight-end
```

</TabItem>
</Tabs>

The following section describes the software pre-installed on the image.

## Toolbox

The image comes with the following [toolbox utilities](../toolbox) preinstalled:

- [sem-version](../toolbox#sem-version): manage language versions on Linux
- [sem-service](../toolbox#sem-service): manage databases and services on Linux

## Version control

Following version control tools are pre-installed:

- Git 2.52.0
- Git LFS (Git Large File Storage) 3.7.1
- GitHub CLI 2.85.0
- Mercurial 6.1.1
- Svn 1.14.1

### Browsers and Headless Browser Testing

- Firefox 102.11.0 (`102`, `default`, `esr`)
- Geckodriver 0.36.0
- Google Chrome 144.0.7559.59
- ChromeDriver 144.0.7559.59
- Xvfb (X Virtual Framebuffer)
- Phantomjs 2.1.1

Chrome and Firefox both support headless mode. You shouldn't need to do more
than install and use the relevant Selenium library for your language.
Refer to the documentation of associated libraries when configuring your project.

### Docker

 Docker toolset is installed and the following versions are available:

- Docker 29.1.4
- Docker-compose 1.29.2 (used as `docker-compose --version`)
- Docker-compose 5.0.1 (used as `docker compose version`)
- Docker-buildx 0.30.1
- Docker-machine 0.16.2
- Dockerize 0.9.9
- Buildah 1.33.7
- Podman 4.9.3
- Skopeo 1.13.3

### Cloud CLIs

- Aws-cli v2 (used as `aws`) 2.33.1
- Azure-cli 2.82.0
- Ecs-cli 1.21.0
- Doctl 1.148.0
- Gcloud 552.0.0
- Gke-gcloud-auth-plugin 552.0.0
- Kubectl 1.29.1
- Heroku 10.16.0
- Terraform 1.14.3
- Helm 4.0.5
- Helmfile 1.2.3

### Network utilities

- Httpie 3.2.4
- Curl 8.5.0
- Rsync 3.2.7

## Compilers

- gcc: 11, 12, 13 (default)

## Languages

### Erlang and Elixir

Erlang versions are installed and managed via [kerl](https://github.com/kerl/kerl).
Elixir versions are installed with [kiex](https://github.com/taylor/kiex).

- Erlang: 24.3, 25.x, 26.x, 27.x (27.0 as default), 28.x
- Elixir: 1.12.x, 1.13.x, 1.14.x, 1.15.x, 1.16.x, 1.17.x (1.17.3 as default), 1.18.x, 1.19.x

Additional libraries:

- Rebar3: 3.24.0

### Go

Versions:

- 1.10.x
- 1.11.x
- 1.12.x
- 1.13.x
- 1.14.x
- 1.15.x
- 1.16.x
- 1.17.x
- 1.18.x
- 1.19.x
- 1.20.x
- 1.21.x
- 1.22.x
- 1.23.x
- 1.24.x
- 1.25.x

The default installed Go version is 1.25.6.

### Java and JVM languages

- Java: 11.0.29, 17.0.17 (default), 21.0.9
- Scala: 3.2.2
- Leiningen: 2.12.0 (Clojure)
- Sbt 1.12.0

### Additional Java build tools

- Maven: 3.9.12
- Gradle: 9.3.0
- Bazel: 9.0.0

### JavaScript via Node.js

Node.js versions are managed by [nvm](https://github.com/nvm-sh/nvm).
You can install any version you need with `nvm install [version]`.
Installed version:

- 24.13.0 (set as default, with alias 24.13), includes npm 11.6.2

### Additional JS tools

- Bun: 1.3.6
- Yarn: 1.22.22

### PHP

PHP versions are managed by [phpbrew](https://github.com/phpbrew/phpbrew).
Available versions:

- 8.1.x
- 8.2.x
- 8.3.x
- 8.4.x
- 8.5.x

The default installed PHP version is 8.1.34.

### Additional PHP libraries

PHPUnit: 9.5.28

### Python

Python versions are installed and managed by
[virtualenv](https://virtualenv.pypa.io/en/stable/). Installed versions:

- 3.10.19 (default)
- 3.11.14
- 3.12.9

Supporting libraries:

- pypy3: 7.3.19
- pip: 25.3
- virtualenv: 20.36.1

### Ruby

Available versions:

- 3.0.x
- 3.1.x
- 3.2.x
- 3.3.x
- 3.4.x
- 4.0.x
- jruby-9.4.1.0

The default installed Ruby version is 3.4.8.

### Rust

- 1.93.0

### Swiftly

- 1.1.1

## See also

- [Installing packages on Ubuntu](../os-ubuntu)
- [Machine types](../machine-types)
- [Semaphore Toolbox](../toolbox)
- [Pipeline YAML refence](../pipeline-yaml)
