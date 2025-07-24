---
description: Ruby Guide
sidebar_position: 3
---

# Ruby

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
import Available from '@site/src/components/Available';
import VideoTutorial from '@site/src/components/VideoTutorial';
import Steps from '@site/src/components/Steps';

This guide will help build Ruby projects on Semaphore.

## Overview

The Ruby interpreters are pre-installed in the Linux and macOS Semaphore environments. You can switch the active interpreter using [sem-version](../../reference/toolbox#sem-version). You may also use Docker images.

## How to select Ruby versions {#switch}

Change the active Ruby versions on Linux and macOS with [sem-version](../../reference/toolbox#sem-version). This command ignores `.ruby-versions`

```shell
sem-version ruby 3.2.2
```

Semaphore uses `rbenv` to switch versions for Ruby. The available Ruby versions depend on the OS image you're using. You can check the available Ruby versions by executing the following command inside a Semaphore job:

```shell
rbenv install --list
```

### Using Docker containers {#containers}

The `sem-version` tool does not work on Docker containers. You must use a pre-built Docker image with the language versions you need and run the job using [Docker environments](../../using-semaphore/pipelines#docker-environments).

You can use the pre-build [Ruby images](../../using-semaphore/containers/container-registry#ruby) or build your own. Find Dockerfiles to build your custom images in the [semaphoreci/docker-images](https://github.com/semaphoreci/docker-images) repository.

## How to cache Gems {#caching}

To cache downloaded Gems, you must download them to the `vendor/bundle` folder relative to the current directory.

So, the first job on the pipeline should contain the following commands:

```shell
checkout
cache restore
bundle install --deployment --path vendor/bundle
cache store
```

All successive jobs can reuse Gems from the cache with:

```shell
checkout
cache restore
bundle install --deployment --path vendor/bundle
```

## How to set up test reports {#test-results}

This section explains how to set up [test reports](../../using-semaphore/tests/test-reports) (and flaky tests) for Ruby and RSpec.

<Steps>

1. Install the `rspec_junit_formatter` Gem in your project. Add the following line to Gemfile

    ```ruby
    gem "rspec_junit_formatter", :group => [:test]
    ```

2. Install the dependencies

    ```shell
    bundle install
    ```

3. Configure RSpec to use the Gem. This can be achieved in two ways:

    - Extending `.rspec` file configuration like this:

        ```text
        --format RspecJunitFormatter
        --out junit.xml
        --format documentation
        ```

    - Or, changing the `rspec` invocation

        ```shell
        bundle exec rspec --format RspecJunitFormatter --out junit.xml --format documentation
        ```

4. Follow Step 3 for every job in your pipeline that executes tests
5. Create an [after_pipeline job](../../using-semaphore/pipelines#after-pipeline-job) with the following command:

    ```shell
    test-results publish junit.xml
    ```

</Steps>

<details>
<summary>Example pipeline definition</summary>
<div>

```yaml title="Using test reports on Ruby"
- name: Tests
  task:
    prologue:
      commands:
        - checkout
        - cache restore
        - bundle install --deployment --path vendor/bundle
        - cache store

    job:
      name: "Tests"
      commands:
        - checkout
        - cache restore
        - bundle install --deployment --path vendor/bundle
        # Or bundle exec rspec if using .rspec configuration file
        - bundle exec rspec --format RspecJunitFormatter --out junit.xml --format documentation

    epilogue:
      always:
        commands:
          - test-results publish junit.xml
```

</div>
</details>

## How to parallelize tests

You can run RSpec and Cucumber tests in parallel automatically using [job parallelism](../../using-semaphore/jobs#job-parallelism).

For RSpec, follow these steps:

<Steps>

1. Enable job parallelism
2. Change your test command in the CI to:

    ```shell
    gem install semaphore_test_boosters
    rspec_booster --job $SEMAPHORE_JOB_INDEX/$SEMAPHORE_JOB_COUNT
    ```

</Steps>

On Cucumber, we use `cucumber_booster` instead:

<Steps>

1. Enable job parallelism
2. Change your test command in the CI to:

    ```shell
    gem install semaphore_test_boosters
    cucumber_booster --job $SEMAPHORE_JOB_INDEX/$SEMAPHORE_JOB_COUNT
    ```

</Steps>
