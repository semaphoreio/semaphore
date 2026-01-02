---
description: Semaphore Cloud Machines Specifications
---

# Machine Types

This page gives technical specifications for the machines available on Semaphore Cloud.

## Overview

A machine type defines what virtualized hardware to use in your [agents](../using-semaphore/pipelines#agents).

The machines described in this page only apply to Semaphore Cloud. You can add more types of machines using [self-hosted agents](../using-semaphore/self-hosted).

## Linux machines {#linux}

Linux machines are provided in four generations. The following table shows what operating systems each generation supports and if they support [Docker environments](../using-semaphore/pipelines#docker-environments).

| Generation | Arch | OS Supported | Docker environments |
|--|--|--|--|
| [E1](#e1) | Intel x86_64 | [Ubuntu 20.04](./os-ubuntu-images/ubuntu-2004-image) |  Yes |
| [E2](#e2) | Intel x86_64 | [Ubuntu 22.04](./os-ubuntu-images/ubuntu-2204-image)<br/>[Ubuntu 20.04](./os-ubuntu-images/ubuntu-2004-image) | Yes |
| [F1](#f1) | Intel x86_64 | [Ubuntu 24.04](./os-ubuntu-images/ubuntu-2404-image) <br/> [Ubuntu 22.04](./os-ubuntu-images/ubuntu-2204-image)<br/>[Ubuntu 20.04](./os-ubuntu-images/ubuntu-2004-image) | Yes |
| [R1](#r1) | ARM | [Ubuntu 24.04 ARM](./os-ubuntu-images/ubuntu-2404-arm-image) | No |

### E1 generation {#e1}

This is the entry-level, cost-effective machine type. E1s are a good choice for less compute and memory intensive tasks.

Implementation details:

- **CPU**: hyperthreaded on a 3.4GHz Max Turbo 4.0GHz Intel® Core™ i7
- **Memory**: DDR4 RAM
- **Disk**: RAM drive (DDR4)

The E1 generation is presented in the following types:

| Type | Virtual CPUs | Memory (GB) | Disk (GB) |
|--|--|--|--|
| `e1-standard-2` | 2 | 4 | 25 |
| `e1-standard-4` | 4 | 8 | 35 |
| `e1-standard-8` | 8 | 16 | 45 |

E1 Generation machine types can be paired with:

- [`ubuntu2404`](../reference/os-ubuntu-images/ubuntu-2004-image)
- [Docker-based environment](../using-semaphore/pipelines#docker-environments).

### E2 generation {#e2}

The E2 generation balances power with cost. It is a good choice for most tasks.

Implementation details:

- **CPU**: hyperthreaded on a 3.6GHZ [AMD Ryzen 5 3600](https://www.amd.com/en/product/8456)
- **Memory**: DDR4 RAM
- **Disk**: NvME storage

The E2 generation is presented in the following types:

| Type | Virtual CPUs | Memory (GB) | Disk (GB) |
|--|--|--|--|
| `e2-standard-2` | 2 | 8 | 45 |
| `e2-standard-4` | 4 | 16 | 65 |

E2 machines can also be paired with:

- [`ubuntu2404`](../reference/os-ubuntu-images/ubuntu-2404-image)
- [`ubuntu2204`](../reference/os-ubuntu-images/ubuntu-2204-image)
- [`ubuntu2404`](../reference/os-ubuntu-images/ubuntu-2004-image)
- [Docker-based environments](../using-semaphore/pipelines#docker-environments).

### F1 generation {#f1}

This generation is intended for compute-intensive tasks. They provide the most performance amongst the machines offered in Semaphore Cloud.

Implementation details:

- **CPU**: hyperthreaded on a 4.6GHz 12th generation [Intel i5 125000](https://ark.intel.com/content/www/us/en/ark/products/96144/intel-core-i512500-processor-18m-cache-up-to-4-60-ghz.html)
- **Memory**: DDR4 RAM
- **Disk**: NvME storage

The F1 generation is presented in the following types:

| Type | Virtual CPUs | Memory (GB) | Disk (GB) |
|--|--|--|--|
| `f1-standard-2` | 2 | 8 | 45 |
| `f1-standard-4` | 4 | 16 | 65 |

F1 machines can be paired with:

- [`ubuntu2404`](../reference/os-ubuntu-images/ubuntu-2404-image)
- [`ubuntu2204`](../reference/os-ubuntu-images/ubuntu-2204-image)
- [`ubuntu2404`](../reference/os-ubuntu-images/ubuntu-2004-image)
- [Docker-based environments](../using-semaphore/pipelines#docker-environments).

### R1 generation {#r1}

These are ARM machines.

Implementation details:

- **CPU**: emulated ARM on [Ampere Altra Q80-30](https://amperecomputing.com/briefs/ampere-altra-family-product-brief)
- **Memory**: DDR4 RAM
- **Disk**: NvME storage

The r1 generation is presented in the following types:

| Type | Virtual CPUs | Memory (GB) | Disk (GB) |
|--|--|--|--|
| `r1-standard-2` | 2 | 4 | 55 |
| `r1-standard-4` | 4 | 8 | 65 |

R1 Generation machine types can only be paired with:

- [`ubuntu2404`](../reference/os-ubuntu-images/ubuntu-2404-arm-image) ARM version

## Apple machines {#macos}

Semaphore Cloud provides the following Apple machine types:

| Type | Virtual CPUs | Architecture | OS Supported | Memory | Disk |
|--|--|--|--|--|--|
| `a2-standard-4` | 4 | Apple Silicon | [macOS Xcode16](./os-apple#mac-16)<br/>[macOS Xcode26](./os-apple#mac-26) | 8 | 150 |

A2 machines can be paired with:

- [macOS Xcode16](./os-apple#mac-16)
- [macOS Xcode26](./os-apple#mac-26)

## See also

- [How to configure agents](../using-semaphore/pipelines#agents)
- [Self-hosted agents](../using-semaphore/self-hosted)
- [Linux Ubuntu images reference](./os-ubuntu)
- [Apple macOS images reference](./os-apple)

