---
description: Install Semaphore on your hardware
---

# Install Semaphore CE

import { NiceButton, ButtonContainer } from '@site/src/components/NiceButton';
import { GKEIcon, EKSIcon, UbuntuIcon, GCPCompute, AWSEC2Icon } from '@site/src/components/CustomIcons';

To install Semaphore, you need:

- A domain
- Minimum memory: **16GB RAM**
- Minimum compute: **8 CPUs**


## Semaphore Architecture

A Semaphore installation consists of two components:

- **Control plane**: the control plane orchestrates jobs, serves the web application and public API, handles logging, manages permissions, and connects with your repositories.
- [**Agents**](../using-semaphore/self-hosted): the only purpose of an agent is to run jobs. The default Semaphore installation includes one agent that runs on the same cluster as the control plane but you can add more to expand capacity and build on multiple architectures.

![Semaphore architecture](./img/arch-semaphore.jpg)


## Choose your platform {#install-method}

You can install Semaphore on a single Linux machine or in a Kubernetes cluster.

<ButtonContainer>
   <NiceButton
    icon={UbuntuIcon}
    title="Install on Linux"
    subtitle="Single Machine with k3s"
    url="./install-single-machine"
  />
  <NiceButton
    icon={GKEIcon}
    title="Install on Kubernetes"
    subtitle="Kubernetes Cluster Install"
    url="./install-kubernetes"
  />
</ButtonContainer>

Each platform presents trade-off. Use the following table as a guide:


| Facility | Single machine | Kubernetes cluster |
|--|--|--|
| Backup and restore | Simple | Complex |
| Infrastructure costs | Lower | Higher |
| Scalability of control plane | Low  <div class="tooltip">ⓘ<span class="tooltiptext">Can only be scaled vertically with a more powerful machine.</span></div> | High <div class="tooltip">ⓘ<span class="tooltiptext">Can be scaled horizontally and vertically.</span></div> |
| Scalability of job runner (agents) | High | High |
| Redundancy | None | High |
| Availability | Low <div class="tooltip">ⓘ<span class="tooltiptext">Server is single point of failure.</span></div> | High <div class="tooltip">ⓘ<span class="tooltiptext">If a node goes down, Kubernetes can autoheal.</span></div> |


