---
description: Install Semaphore on your hardware
---

# Install Semaphore

Semaphore has two self-hostable production-ready editions: 

- **Community Edition**: is open source (Apache-2), free forever, and perfect for small teams and companies.
- **Enterprise Edition**: is source available, requires a license, and supports Enterprise-level features such as [advanced workflows](../using-semaphore/promotions), [audit logs](../using-semaphore/organizations#audit-log), and advanced Role-Based Access Controls.

See the [feature comparison](./features) to decide which edition of Semaphore is best for you.

<Columns>
  <Column className='text--center'>
 <Card shadow='md' style={{marginBottom:10 + 'px'}}>
    <CardHeader>
      <h3>Community Edition</h3>
    </CardHeader>
    <CardBody>
          Free <br/>
          Open source<br/>
          For small teams
    </CardBody>
    <CardFooter>
      <a href="/CE/getting-started/install">
        <button className='button button--secondary button--block'>Install Semaphore CE</button>
      </a>
    </CardFooter>
  </Card>
  </Column>
  <Column className='text--center'>
 <Card shadow='md' style={{marginBottom:10 + 'px'}}>
    <CardHeader>
      <h3>Enterprise Edition</h3>
    </CardHeader>
    <CardBody>
          Requires a license <br/>
          Source available <br/>
          For big teams and companies
    </CardBody>
    <CardFooter>
      <a href="/EE/getting-started/install">
        <button className='button button--secondary button--block'>Install Semaphore EE</button>
      </a>
    </CardFooter>
  </Card>
  </Column>
</Columns>

:::info Development builds

Developers interested in contributing to the [Semaphore repository](https://github.com/semaphoreio/semaphore) should use a [local development build](https://github.com/semaphoreio/semaphore/blob/main/LOCAL-DEVELOPMENT.md).

:::

## Other Tools

The following free tools complement your Semaphore installation:

- [Semaphore CLI](../reference/semaphore-cli): manage your projects from the command line.
- [Self hosted agents](../using-semaphore/self-hosted.md): expand capacity by running jobs on your hardware.
- [K9s](https://k9scli.io/): TUI application to manage and observe your Semaphore installation.
