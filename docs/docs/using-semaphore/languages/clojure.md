---
description: Clojure Guide
sidebar_position: 13
---

# Clojure

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
import Available from '@site/src/components/Available';
import VideoTutorial from '@site/src/components/VideoTutorial';
import Steps from '@site/src/components/Steps';

This guide will help build Clojure projects on Semaphore.

## Overview

The Leiningen tool is pre-installed in Linux machines. You can switch the active interpreter using [sem-version](../../reference/toolbox#sem-version).

## How to switch Clojure versions {#versions}

Leiningen reads the Clojure version number from `project.clj`. The correct version is activated automatically.

For example the presence of this project file activates Clojure v1.10.0:

```clojure
(defproject hw "0.1.0-SNAPSHOT"
  :main two.core
  :dependencies [[org.clojure/clojure "1.10.0"]])
```

## How to run Leiningen {#run}

To run a Clojure project with Leiningen, use the following commands in a job:

```shell
checkout
lein run
```



