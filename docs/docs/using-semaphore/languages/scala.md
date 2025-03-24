---
description: Scala Guide
sidebar_position: 9
---

# Scala

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
import Available from '@site/src/components/Available';
import VideoTutorial from '@site/src/components/VideoTutorial';
import Steps from '@site/src/components/Steps';

This guide will help build Scala projects on Semaphore.

## Overview

The Scala toolchain is pre-installed in Linux machines. You can switch the active compiler using [sem-version](../../reference/toolbox#sem-version).

## How to switch Scala versions {#versions}

Use [sem-version](../../reference/toolbox#sem-version) to switch between Scala versions. This only works on Linux machines.

```shell
checkout
sem-version scala 2.12
scala hello.scala
```

See [artifacts](../artifacts) to learn how to save and persist the built binary.

Semaphore does not provide prebuilt Scala images for [Docker Environments](../../using-semaphore/pipelines#docker-environments).  Find Dockerfiles to build your custom images in the [semaphoreci/docker-images](https://github.com/semaphoreci/docker-images) repository.

