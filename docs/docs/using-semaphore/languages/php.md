---
description: PHP Guide
sidebar_position: 7
---

# PHP

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
import Available from '@site/src/components/Available';
import VideoTutorial from '@site/src/components/VideoTutorial';
import Steps from '@site/src/components/Steps';

This guide will help build PHP projects on Semaphore.

## Overview

The PHP interpreter is pre-installed in the Linux Semaphore environment. You can switch the active interpreter using [sem-version](../../reference/toolbox#sem-version). You may also use Docker images.

## How to select PHP version {#switch}

Change the active Ruby versions on Linux with [sem-version](../../reference/toolbox#sem-version).

```shell
sem-version php 8.2.20
```

You can also use `phpbrew` to build a specific PHP version from source. This is slower than using `sem-version`.

```shell
phpbrew --no-progress install 8.2.20
```

### Using Docker containers {#containers}

The `sem-version` tool does not work on Docker containers. You must use a pre-built Docker image with the language versions you need and run the job using [Docker environments](../../using-semaphore/pipelines#docker-environments).

You can use the pre-build [PHP images](../../using-semaphore/containers/container-registry#php) or build your own. Find Dockerfiles to build your custom images in the [semaphoreci/docker-images](https://github.com/semaphoreci/docker-images) repository.

## How to cache dependencies {#caching}

Composer is preinstalled, so you can use the [`cache`](../../reference/toolbox#cache) command to store and restore the `vendor/` directory.

The first job in the pipeline should install and cache the dependencies:

```shell
checkout
cache restore
composer install
cache store
```

The rest of the jobs can now use dependencies cached in the vendor folder.

```shell
checkout
cache restore
export PATH=$PWD/vendor/bin:${PATH}
```

## How to set up test reports {#test-results}

This section explains how to set up [test reports](../../using-semaphore/tests/test-reports) (and flaky tests) for PHP and PHPUnit.

<Steps>

1. Run your tests using the `--log-junit` argument

    ```shell
    phpunit --log-junit junit.xml path/to/tests
    ```

2. Create an [after_pipeline job](../../using-semaphore/pipelines#after-pipeline-job) with the following command:

    ```shell
    test-results publish junit.xml
    ```

</Steps>

<details>
<summary>Example pipeline definition</summary>
<div>

```yaml title="Using test reports on PHP"
- name: Tests
  task:
    prologue:
      commands:
        - checkout
        - cache restore
        - composer install
        - cache store

    job:
      name: "Tests"
      commands:
        - checkout
        - cache restore
        - export "PATH=./vendor/bin:${PATH}"
        - phpunit --log-junit junit.xml tests/*.php

    epilogue:
      always:
        commands:
          - test-results publish junit.xml
```

</div>
</details>
