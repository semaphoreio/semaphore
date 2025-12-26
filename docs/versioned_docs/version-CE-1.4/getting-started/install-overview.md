---
description: Semaphore installation overview for Semaphore CE
---

# Install Overview







import { NiceButton, ButtonContainer } from '@site/src/components/NiceButton';
import { GKEIcon, EKSIcon, UbuntuIcon, GCPCompute, AWSEC2Icon } from '@site/src/components/CustomIcons';

A Semaphore installation consists of two components:

- **Control plane**: the control plane orchestrates jobs, serves the web application and public API, handles logging, manages permissions, and connects with your repositories. The control plane requires a Kubernetes cluster or a server running [k3s](https://k3s.io/).
- **Agents**: the only purpose of an agent is to run jobs. The default Semaphore installation includes one agent that runs on the same cluster as the control plane. Agents connect to the control plane, waiting for jobs to be scheduled. See [self-hosted agents](../using-semaphore/self-hosted) to learn how to scale your Semaphore setup.

![Semaphore architecture](./img/arch-semaphore.jpg)

## Prerequisites

To install Semaphore, you need:

- A DNS domain
- The ability to create A, AAAA, or CNAME records for your domain
- A Kubernetes cluster or a Ubuntu machine
  - Minimum hardware: **16 GB of RAM and 8 CPUs**
- Installation time
  - Ubuntu machine: 20 to 30 minutes
  - Kubernetes cluster: up to 1 hour

:::note

Ensure that your VMs are running with hardware-supported virtualization mode enabled. Without virtualization feature enabled Semaphore might run slowly or not at all even if when the minimum hardware requirements are met.

:::

## Choose your platform {#install-method}

You can install Semaphore on a single Linux/Ubuntu machine or in a Kubernetes cluster.

Each platform presents trade-off. Use the following table as a guide:

| Facility | Single-alone machine | Kubernetes cluster |
|--|--|--|
| Backup and restore | Simple | Complex |
| Infrastructure costs | Lower | Higher |
| Scalability of control plane | Low  <div class="tooltip">ⓘ<span class="tooltiptext">Can only be scaled vertically with a more powerful machine.</span></div> | High <div class="tooltip">ⓘ<span class="tooltiptext">Can be scaled horizontally and vertically.</span></div> |
| Scalability of job runner (agents) | High | High |
| Redundancy | None | High |
| Availability | Low <div class="tooltip">ⓘ<span class="tooltiptext">Server is single point of failure.</span></div> | High <div class="tooltip">ⓘ<span class="tooltiptext">If a node goes down, Kubernetes can autoheal.</span></div> |

### Single-machine installation

<ButtonContainer>
   <NiceButton
    icon={UbuntuIcon}
    title="Install on Ubuntu"
    subtitle="Ubuntu Machine with k3s"
    url="./install-ubuntu"
  />
  <NiceButton
    icon={GCPCompute}
    title="Install on Google VM"
    subtitle="Google Cloud Compute"
    url="./install-gcompute"
  />
  <NiceButton
    icon={AWSEC2Icon}
    title="Install on EC2"
    subtitle="Amazon EC2 VM"
    url="./install-aws-ec2"
  />
</ButtonContainer>

### Kubernetes installation

<ButtonContainer>
  <NiceButton
    icon={GKEIcon}
    title="Install on GKE"
    subtitle="Google Cloud Kubernetes"
    url="./install-gke"
  />
  <NiceButton
    icon={EKSIcon}
    title="Install on EKS"
    subtitle="Amazon Elastic Kubernetes"
    url="./install-eks"
  />
</ButtonContainer>

## See also

- [Installation overview](./install-overview.md)
- [Quickstart](./quickstart)
- [Migration guide](./migration-overview)
