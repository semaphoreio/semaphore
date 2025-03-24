---
description: Swift Guide
sidebar_position: 12
---

# Swift

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
import Available from '@site/src/components/Available';
import VideoTutorial from '@site/src/components/VideoTutorial';
import Steps from '@site/src/components/Steps';

This guide will help build Swift projects on Semaphore.

## Overview

Semaphore allows the building, testing, and releasing of Swift, Objective-C, and React Native applications using macOS environments.

See [macOS](../../reference/os-apple) to view the available Xcode versions.

## Building Swift code {#compile}

To build a Swift application, select one of the macOS environments and compile your code with `xcodebuild`.

```shell
checkout
xcodebuild
```

See [artifacts](../artifacts) to learn how to save and persist the built binary.
