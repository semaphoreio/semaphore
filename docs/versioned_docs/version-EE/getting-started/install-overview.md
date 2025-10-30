---
description: Semaphore installation overview for Semaphore EE
---

# Install Semaphore (WIP)

## Prerequisites

To install Semaphore, you need:

- An Enterprise Edition [License](./license), which might be free of cost if [you qualify as a small company or team](./license#free)
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

