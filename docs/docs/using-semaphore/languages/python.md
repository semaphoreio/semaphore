---
description: Python Guide
sidebar_position: 4
---

# Python

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
import Available from '@site/src/components/Available';
import VideoTutorial from '@site/src/components/VideoTutorial';
import Steps from '@site/src/components/Steps';

This guide will help build Python projects on Semaphore.

## Overview

The Python interpreter is pre-installed in the Linux and macOS Semaphore environments. You can switch the active interpreter using [sem-version](../../reference/toolbox#sem-version). You may also use Docker images.

## How to select Python versions {#switch}

Change the active Python versions on Linux with [sem-version](../../reference/toolbox#sem-version).

```shell
sem-version python 3.12
```

### Using Docker containers {#containers}

The `sem-version` tool does not work on Docker containers. You must use a pre-built Docker image with the language versions you need and run the job using [Docker environments](../../using-semaphore/pipelines#docker-environments).

You can use the pre-build [Python images](../../using-semaphore/containers/container-registry#python) or build your own. Find Dockerfiles to build your custom images in the [semaphoreci/docker-images](https://github.com/semaphoreci/docker-images) repository.

## How to cache packages {#caching}

To cache downloaded Python packages, you must download them to the `.pip_cache/` folder relative to the current directory.

So, the first job on the pipeline should contain the following commands:

```shell
export PATH=$HOME/.local/bin:$PATH
checkout
mkdir .pip_cache
cache restore
pip install --user --cache-dir .pip_cache -r requirements.txt
cache store
```

## How to set up test reports {#test-results}

This section explains how to set up [test reports](../../using-semaphore/tests/test-reports) (and flaky tests) for Python and pytest.

<Steps>

1. Set the name of your test suite in the pytest config file

    ```toml
    [pytest]
    junit_suite_name = my_suite
    ```

2. Run your tests with the `--junitxml` argument

    ```shell
    pytest --junitxml=junit.xml
    ```

3. Create an [after_pipeline job](../../using-semaphore/pipelines#after-pipeline-job) with the following command:

    ```shell
    test-results publish junit.xml
    ```

</Steps>

<details>
<summary>Example pipeline definition</summary>
<div>

```yaml title="Using test reports on Python"
- name: Tests
  task:
    prologue:
      commands:
        - export PATH=$HOME/.local/bin:$PATH
        - checkout
        - mkdir .pip_cache
        - cache restore
        - pip install --user --cache-dir .pip_cache -r requirements.txt
        - cache store

    job:
      name: "Tests"
      commands:
        - pytest --junitxml=junit.xml tests/*.py

    epilogue:
      always:
        commands:
          - test-results publish junit.xml
```

</div>
</details>
