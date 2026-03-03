---
description: Java Guide
sidebar_position: 5
---

# Java








This guide will help build Java projects on Semaphore.

## Overview

Java and related tools are pre-installed in Linux machines. You can switch the active compiler using [sem-version](../../reference/toolbox#sem-version).

### How to change Java versions {#versions}


Java is available on Linux [Ubuntu](../../reference/os-ubuntu) machines. To change active Java versions use `sem-version`. For example to switch to v11:

```shell
sem-version java 11
```

See [artifacts](../artifacts) to learn how to save and persist the built JARs.

### Using Docker containers {#containers}

Semaphore does not distribute pre-build images for Java. You, can, however, build your own images and use them with [Docker Environments](../../using-semaphore/pipelines#docker-environments).

See the [semaphoreci/docker-images](https://github.com/semaphoreci/docker-images) repository for examples of Dockerfiles.

## How to cache dependencies in Java {#cache}

The [cache](../../reference/toolbox#cache) tool automatically detects the presence of Maven directories and cache dependencies.

The first job in the pipeline must cache the dependencies:

```shell
export MAVEN_OPTS=-Dmaven.repo.local=.m2
checkout
cache restore
mvn -q dependency:go-offline test-compile
cache store
```

The rest of the jobs can use the cache directly to retrieve dependencies and compiled code:

```shell
export MAVEN_OPTS=-Dmaven.repo.local=.m2
checkout
cache restore
```

## How to set up test reports {#test}

This section explains how to set up [test reports](../../using-semaphore/tests/test-reports) (and flaky tests) for Java and Maven.

<Steps>

1. Add the Surefire plugin to the `pom.xml`

    ```xml
    <build>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-surefire-plugin</artifactId>
                <version>3.0.0-M5</version>
                <configuration>
                    <reportFormat>xml</reportFormat>
                    <outputDirectory>/tmp</outputDirectory>
                </configuration>
            </plugin>
        </plugins>
    </build>
    ```

2. Run the tests

    ```shell
    mvn test
    ```

3. Create an [after_pipeline job](../../using-semaphore/pipelines#after-pipeline-job) with the following command:

    ```shell
    test-results publish /tmp/junit.xml
    ```

</Steps>

<details>
<summary>Complete example</summary>
<div>

```yaml
version: v1.0
name: Java & Maven Example
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2404

blocks:
  - name: Setup
    task:
      env_vars:
        # Set maven to use a local directory. This is required for
        # the cache util. It must be set in all blocks.
        - name: MAVEN_OPTS
          value: "-Dmaven.repo.local=.m2"
      jobs:
        - name: Dependencies
          commands:
            - checkout
            - cache restore
            # Download all JARs possible and compile as much as possible
            # Use -q to reduce output spam
            - mvn -q dependency:go-offline test-compile
            - cache store
  - name: Tests
    task:
      env_vars:
        - name: MAVEN_OPTS
          value: "-Dmaven.repo.local=.m2"
      prologue:
        commands:
          - checkout
          - cache restore
      jobs:
        - name: Everything
          commands:
            - mvn test
            - mvn -q package
    epilogue:
      always:
        commands:
          - test-results publish /tmp/junit.xml
```

</div>
</details>
