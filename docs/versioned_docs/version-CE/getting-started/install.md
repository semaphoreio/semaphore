---
description: Install Semaphore on your hardware
---

# Install Semaphore Community Edition (CE)

To install Semaphore Community Edition control plane, you need:

- A domain and public IP address
- Minimum hardware: **16GB RAM** and **8 vCPUs**
- Ports SSH (22), HTTP (80) and HTTPS (443) must be open


:::info Important

In addition, it's highly recommended to add several [self-hosted agents](../using-semaphore/self-hosted.md) to act as runners for your jobs. The amount of agents required depends on your workload. You can always add or remove agents to adjust to your team's demands.

:::

## Choose your platform {#install-method}

You can install Semaphore Community Edition on a single Linux server or in a Kubernetes cluster.

<Columns>
  <Column className='text--center'>
 <Card shadow='md' style={{marginBottom:10 + 'px'}}>
    <CardHeader>
      <h3>Single Machine</h3>
    </CardHeader>
    <CardBody>
          Simple to manage <br/>
          Low infrastructure costs<br/>
          No high availability
    </CardBody>
    <CardFooter>
      <a href="/CE/getting-started/install-single-machine">
        <button className='button button--secondary button--block'>Install on a Linux Server</button>
      </a>
    </CardFooter>
  </Card>
  </Column>
  <Column className='text--center'>
 <Card shadow='md' style={{marginBottom:10 + 'px'}}>
    <CardHeader>
      <h3>Kubernetes</h3>
    </CardHeader>
    <CardBody>
          More complex operation <br/>
          High infrastructure costs <br/>
          High availability and scalability <br/>
    </CardBody>
    <CardFooter>
      <a href="/CE/getting-started/install-kubernetes">
        <button className='button button--secondary button--block'>Install in Kubernetes</button>
      </a>
    </CardFooter>
  </Card>
  </Column>
</Columns>

Each platform presents trade-off. Use the following table as a guide:


| Facility | Single machine | Kubernetes cluster |
|--|--|--|
| Backup and restore | Simple | Complex |
| Infrastructure costs | Lower | Higher |
| Scalability of control plane | Low  <div class="tooltip">ⓘ<span class="tooltiptext">Can only be scaled vertically with a more powerful machine.</span></div> | High <div class="tooltip">ⓘ<span class="tooltiptext">Can be scaled horizontally and vertically.</span></div> |
| Scalability of job runner (agents) | High | High |
| Redundancy | None | High |
| Availability | Low <div class="tooltip">ⓘ<span class="tooltiptext">Server is single point of failure.</span></div> | High <div class="tooltip">ⓘ<span class="tooltiptext">If a node goes down, Kubernetes can autoheal.</span></div> |


