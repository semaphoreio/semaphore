---
description: Install Semaphore on Ubuntu
---

# Ubuntu Machine








This page explains how to install Semaphore Community Edition on a Linux Ubuntu machine.

## Overview

If this is your first time using Semaphore we suggest trying out [Semaphore Cloud](/getting-started/quickstart) to see if the platform fits your needs. You can create a free trial account without a credit card and use every feature.

The self-hosted installation is recommended for users and teams that are already familiar with Semaphore.

## Prerequisites {#prerequisites}

- A DNS domain
- A Linux machine running Ubuntu. Preferably Ubuntu 24.04 LTS
- At least 8 CPUs and 16 GB of RAM
- A public IP address. Firewall rules should allow SSH (22), HTTP (80) and HTTPS (443) traffic
- SSH access to the machine
- Sudo or root permissions in the machine

## Step 1 - Create DNS records {#dns}

Configure your DNS by creating two A records that point to the server's IP.

:::note

We highly recommend using a subdomain for Semaphore. The subdomain can have any value, in the example below the subdomain is `ci` and the domain is `example.com`.

:::

<Steps>

1. Go to your domain provider's DNS settings
2. Create root domain A record

      - Type: A
      - Name: `ci` (e.g. `ci.example.com`)
      - Value: the public IP address of your Linux machine

3. Create a wildcard record

      - Type: A
      - Name: `*.ci` (e.g. `*.ci.example.com`)
      - Value: the public IP address of your Linux machine

4. Wait for DNS propagation (typically a few minutes)

    You can verify the creation of the A record in the [Online Dig Tool](https://toolbox.googleapps.com/apps/dig/#A/) for:

      - `ci.example.com`
      - `id.ci.example.com`

</Steps>

## Step 2 - Install tools {#install-tools}


Next, run the following commands to install the required tools:

```shell title="remote shell - install tools"
sudo apt-get update
sudo apt-get -y install certbot
```





## Step 8 - Set the initialization agent

Define the agent type that handles pipeline initialization:

1. Open the [server settings menu](../using-semaphore/organizations#org-settings)
2. Select **Initialization jobs**
3. Select one agent from the list
4. Press **Save Changes**, *you must save changes even if the correct option was already selected*

## Post-installation tasks

Once you have Semaphore up and running, check out the following pages to finish setting up:

- [Connect with GitHub](../using-semaphore/connect-github.md): connect your instance with GitHub to access your repositories
- [Quickstart](./quickstart): complete the Quickstart to get familiarized with Semaphore Community Edition
- [Invite users](../using-semaphore/user-management#people): invite users to your instance so they can start working on projects
- [Add self-hosted agents](../using-semaphore/self-hosted): add more machines to scale up the capacity of your CI/CD platform

## How to Upgrade Semaphore {#upgrade}

To upgrade Semaphore, follow these steps:

<Steps>

1. Connect to your server running Semaphore via SSH
2. Check that you can access the Kubernetes cluster (k3s):

    ```shell
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    kubectl get nodes
    ```

3. Source your configuration file and ensure your certificates are located in the expected folders. See [Step 4](#certs)

    ```shell
    source semaphore-config
    ls certs/live/${DOMAIN}/fullchain.pem 
    ls certs/live/${DOMAIN}/privkey.pem
    ```

4. Check the expiration date of the certificate. If it has expired, [regenerate the certificate](#certs) before upgrading

    ```shell
    openssl x509 -enddate -noout -in certs/live/${DOMAIN}/fullchain.pem
    ```

5. Run the following command to upgrade to `v1.3.0`

    ```shell
    helm upgrade --install semaphore oci://ghcr.io/semaphoreio/semaphore \
      --debug \
      --version v1.3.0 \
      --timeout 20m \
      --set global.domain.ip=${IP_ADDRESS} \
      --set global.domain.name=${DOMAIN} \
      --set ingress.enabled=true \
      --set ingress.ssl.enabled=true \
      --set ingress.className=traefik \
      --set ingress.ssl.type=custom \
      --set ingress.ssl.crt=$(cat certs/live/${DOMAIN}/fullchain.pem | base64 -w 0) \
      --set ingress.ssl.key=$(cat certs/live/${DOMAIN}/privkey.pem | base64 -w 0)
    ```

</Steps>

## How to Uninstall Semaphore

If you want to completely uninstall Semaphore, follow these steps.

:::danger

If you uninstall Semaphore you will lose access to all your projects, workflows and logs. You cannot undo this action.

:::

First, connect to your server and uninstall Semaphore with the following command:

```shell title="remote shell - uninstall Semaphore"
ssh <user>@<public-IP-address-of-machine>
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
helm uninstall semaphore
```

Delete the persistent volume claims:

```shell title="remote shell - delete PVCs"
kubectl delete pvc \
  minio-artifacts-storage-minio-artifacts-0 \
  minio-cache-storage-minio-cache-0 \
  minio-logs-storage-minio-logs-0 \
  postgres-storage-postgres-0 \
  rabbitmq-storage-rabbitmq-0 \
  redis-data-redis-0
```

## See also

- [Installation overview](./install-overview.md)
- [Quickstart](./quickstart)
- [Migration guide](./migration-overview)
