---
description: JavaScript and Node Guide
sidebar_position: 2
---

# JavaScript and Node

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
import Available from '@site/src/components/Available';
import VideoTutorial from '@site/src/components/VideoTutorial';
import Steps from '@site/src/components/Steps';

This guide will help build JavaScript projects on Semaphore.

## Overview

Node.js is pre-installed in the Linux and macOS Semaphore environments. You can switch the active interpreter using [sem-version](../../reference/toolbox#sem-version).

You may also use Docker images.

## How to select Node versions {#switch}

Change the active Node.js versions on Linux and macOS with [sem-version](../../reference/toolbox#sem-version).

```shell
sem-version node 20.17.0
```

Semaphore uses `nvm` to switch versions for Node. This means you can install and activate Node.js with a pre-existing `.nvmrc` like this:

```shell
nvm use
```

You can also install any other version of Node.js with:

```shell
nvm install --lts carbon
sem-version node --lts carbon
```

### Using Docker containers {#containers}

The `sem-version` tool does not work on Docker containers. You must use a pre-built Docker image with the language versions you need and run the job using [Docker environments](../../using-semaphore/pipelines#docker-environments).

You can use the pre-built [Node images](../../using-semaphore/containers/container-registry#node) or build your own. Find Dockerfiles to build your custom images in the [semaphoreci/docker-images](https://github.com/semaphoreci/docker-images) repository.

## How to cache Node dependencies {#cache}

The [cache](../../reference/toolbox#cache) can detect `package-lock.json` and `yarn.lock` and automatically cache `node_modules`.

The first job must install and cache dependencies:

```shell
checkout
cache restore
npm install
cache store
```

All successive jobs can reuse `node_modules` from the cache with:

```shell
checkout
cache restore
```

You can alternative use `yarn` instead of `npm` and the cache should work correctly.

## How to perform semantic releases? {#semantic}

Semaphore provides integration with [semantic-release](https://github.com/semantic-release/semantic-release) to automate the workflow Node package releases.

If you continuously release packages, Docker images, or libraries, this guide can help you automate the release process:

- determine the next version number
- generate release notes
- publish the package to the GitHub repository

To perform semantic releases, follow these steps

<Steps>

1. Create a [Secret] with your GitHub Token.

    - The token should have write permissions on the repository
    - The secret name should be `semantic-release-credentials`
    - Prefer to use [project secrets](../secrets#create-project-secrets)
    - The secret must contain the environment variable `GH_TOKEN` or `GITHUB_TOKEN`
2. Configure a continuous delivery pipeline

    - Use [promotions](../promotions) to create a new release pipeline
    - Consider using auto-promotions and Git tags to automate the process

3. Optionally, [configure Semantic Release](https://github.com/semantic-release/semantic-release/blob/master/docs/usage/configuration.md#configuration)
  
4. Create a release job with the following contents

    ```shell
    checkout
    sem-semantic-release
    ```

5. Create a release to test the process

    ```shell
    git pull
    git commit -m "Commit message"
    # optionally add a tag
    git tag -a v2.1.0 -m "xyz feature is released in this tag."
    git push origin v2.1.0
    ```

</Steps>

See [`sem-semantic-release`](../../reference/toolbox#sem-semantic-release) for more details on the tool.

## How to set up test reports {#test-results}

This section explains how to set up [test reports](../../using-semaphore/tests/test-reports) (and flaky tests) for JavaScript and Jest.

<Steps>

1. Install the `jest-junit` package in your project. Add the following line to Gemfile

    ```shell
    npm install --save-dev jest-junit
    ```

2. Configure your Jest config to output using the JUnit format

    ```js title="jest.config.js"
    {
        "reporters": [ "default", "jest-junit" ]
    }
    ```

3. Add a test script on `packages.json` and push changes to repository

    ```js
    scripts: {
        "test": "jest --ci --reporters=default --reporters=jest-junit"
        // ...
    }
    ```

4. Run your test in CI/CD with `npm test`
5. Create an [after_pipeline job](../../using-semaphore/pipelines#after-pipeline-job) with the following command:

    ```shell
    test-results publish junit.xml
    ```

</Steps>

<details>
<summary>Example pipeline definition</summary>
<div>

```yaml title="Using test reports on Node"
- name: Tests
  task:
    prologue:
      commands:
        - checkout
        - cache restore
        - npm install
        - cache store

    job:
      name: "Tests"
      commands:
        - checkout
        - cache restore
        - npm test

    epilogue:
      always:
        commands:
          - test-results publish junit.xml
```

</div>
</details>
