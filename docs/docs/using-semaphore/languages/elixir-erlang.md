---
description: Elixir and Erlang Guide
sidebar_position: 10
---

# Elixir and Erlang

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
import Available from '@site/src/components/Available';
import VideoTutorial from '@site/src/components/VideoTutorial';
import Steps from '@site/src/components/Steps';

This guide will help build Elixir and Erlang projects on Semaphore.

## Overview

The Elixir and Erlang toolchains are pre-installed in Linux machines. You can switch the active compiler using [sem-version](../../reference/toolbox#sem-version).

## How to change Elixir versions {#elixir-version}

Elixir is available on Linux [Ubuntu](../../reference/os-ubuntu) machines and [Docker Environments](../../using-semaphore/pipelines#docker-environments).

On Linux machines use `sem-version`. For example to switch to v1.16:

```shell
sem-version elixir 1.16
```

### Using Docker containers {#containers}

Semaphore distributes the pre-built `semaphoreci:elixir` image on the [Semaphore Container Registry](../../using-semaphore/containers/container-registry#elixir). Find Dockerfiles to build your custom images in the [semaphoreci/docker-images](https://github.com/semaphoreci/docker-images) repository.

## How to cache Elixir dependencies {#cache}

The [cache](../../reference/toolbox#cache) tool automatically detects the presence Mix dependencies and compiled code

The first job in the pipeline must cache the dependencies:

```shell
checkout
mix local.hex --force
mix local.rebar --force
# highlight-next-line
cache restore
mix do deps.get, compile
# highlight-next-line
cache store
```

The rest of the jobs can use the cache directly to retrieve dependencies and compiled code:

```shell
checkout
cache restore
```

## How to set up test reports {#test-results1}

This section explains how to set up [test reports](../../using-semaphore/tests/test-reports) (and flaky tests) for Elixir and mix.

<Steps>

1. Add  junit-formatter to your `mix.exs` dependencies

    ```elixir
    defp deps do
    [
        # ...
        {:junit_formatter, "~> 3.1", only: [:test]}
    ]
    end
    ```

2. Install dependencies

    ```shell
    mix deps.get
    ```

3. Extend your `config/test.exs`

    ```elixir
    config :junit_formatter,
    report_dir: "/tmp",
    report_file: "junit.xml", # Save output to "/tmp/junit.xml"
    print_report_file: true, # Adds information about file location when suite finishes
    include_filename?: true, # Include filename and file number for more insights
    include_file_line?: true
    ```

4. Extend your `tests/test_helper.exs`

    ```elixir
    ExUnit.configure(formatters: [JUnitFormatter, ExUnit.CLIFormatter])
    ExUnit.start()
    ```

5. Create an [after_pipeline job](../../using-semaphore/pipelines#after-pipeline-job) with the following command:

    ```shell
    test-results publish /tmp/junit.xml
    ```

</Steps>

<details>
<summary>Example pipeline definition</summary>
<div>

```yaml title="Test reports in Elixir"
- name: Tests
  task:
    prologue:
      commands:
        - checkout
        - mix deps.get
    jobs:
      - name: Elixir Tests
        commands:
          - mix test
    epilogue:
      always:
        commands:
          - test-results publish /tmp/junit.xml
```

</div>
</details>

## How to change Erlang versions {#erlang-version}

Elixir is available on Linux [Ubuntu](../../reference/os-ubuntu) machines and [Docker Environments](../../using-semaphore/pipelines#docker-environments).

On Linux machines use `sem-version`. For example to switch to v25

```shell
sem-version erlang 25
```

## How to run Erlang projects {#erlang-run}

Use `earlc` to compile an Erlang source code to binary.

For instance, with a source file called `hello.erl`:

```earlang
%% Programmer: Mihalis Tsoukalos
%% Date: Friday 21 December 2018

-module(hello).
-export([helloWorld/0]).

helloWorld() -> io:fwrite("hello, world\n").
```

We can compile and run with:

```shell
checkout
sem-version erlang 25
erlc hello.erl
erl -noshell -s hello helloWorld -s init stop
```
