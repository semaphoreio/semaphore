---
description: Install Semaphore on Ubuntu
---

# Ubuntu Machine








This page explains how to install Semaphore Community Edition on a Linux Ubuntu machine.

## Overview

If this is your first time using Semaphore we suggest trying out [Semaphore Cloud](../../../docs/getting-started/quickstart.md) to see if the platform fits your needs. You can create a free trial account without a credit card and use every feature.

The self-hosted installation is recommended for users and teams that are familiar with Semaphore.

## Prerequisites {#prerequisites}

- An Enterprise Edition [License](./license)
- A DNS domain
- A Linux machine running Ubuntu. Preferably Ubuntu 24.04 LTS
- At least 8 CPUs and 16 GB of RAM
- A public IP address. Firewall rules should allow SSH (22), HTTP (80) and HTTPS (443) traffic
- SSH access to the machine
- Sudo or root permissions in the machine

## Step 1 - Create DNS records {#dns}

Configure your DNS by creating two A records that point to the reserved IP:

<Steps>

1. Go to your domain provider's DNS settings
2. Create root domain A record

      - Type: A
      - Name: `semaphore` (e.g. `semaphore.example.com`)
      - Value: the public IP address of your Linux machine

3. Create a wildcard record

      - Type: A
      - Name: `*.semaphore` (e.g. `*.semaphore.example.com`)
      - Value: the public IP address of your Linux machine

4. Wait for DNS propagation (typically a few minutes)

    You can verify the creation of the TXT record in the [Online Dig Tool](https://toolbox.googleapps.com/apps/dig/#A/) for:

      - `semaphore.example.com`
      - `*.semaphore.example.com`

</Steps>

## Step 2 - Install tools {#install-tools}

Open a terminal into your Linux machine, e.g. using SSH:

```shell title="Connect to your machine"
ssh <user>@<public-IP-address-of-machine>
```

Next, run the following commands to install the required tools:

```shell title="remote shell - install tools"
sudo apt-get update
sudo apt-get -y install certbot
```

## Step 3 - Define your configuration {#env}

Create a folder to store the configuration and certificates:

```shell title="remote shell - create install folder"
mkdir semaphore-install
cd semaphore-install
```

Create a file with the following environment variables. For the rest of the guide, we'll call this file `semaphore-config`. Change the values as needed:

```shell title="contents of semaphore-config file"
export DOMAIN="<your-domain>"
export IP_ADDRESS=<public-IP-address-of-machine>
```

:::info Important

We highly recommend **installing Semaphore on a subdomain**, e.g. `semaphore.example.com`. Installing Semaphore on your main domain is discouraged as its operation might interfere with other services running on the same domain.

For example, if your domain is `example.com`, consider installing Semaphore on `semaphore.example.com`. See the example below.

```shell title="example of semaphore-config file"
export DOMAIN="semaphore.example.com"
export IP_ADDRESS=1.2.3.4
```

:::

## Step 4 - Create TLS certificates {#certs}

:::note

You may skip this section if you already have wildcard certificates, e.g. `*.semaphore.example.com` for the domain where you are installing Semaphore.

:::

We can use [certbot](https://certbot.eff.org/) to create a free wildcard TLS certificate with the following command:

```shell title="remote shell - create certificates with certbot"
source semaphore-config
mkdir -p certs
certbot certonly --manual --preferred-challenges=dns \
    -d "*.${DOMAIN}" \
    --register-unsafely-without-email \
    --work-dir certs \
    --config-dir certs \
    --logs-dir certs
```

When you are prompted to create a DNS TXT record to verify domain ownership. For example:

```text
Please deploy a DNS TXT record under the name:

_acme-challenge.semaphore.example.com.

with the following value:

EL545Zty7vUUvIHQRSkwxXTWsirldw91enasgB5uOHs
```

Create the DNS TXT record before continuing the certificate generation. Follow the instructions on the terminal.

:::tip

You can verify the creation of the TXT record in the [Google Dig Tool](https://toolbox.googleapps.com/apps/dig/#TXT/). Type the challenge DNS TXT record and check if its value corresponds to the correct value.

:::

Once done, you should get a message like this:

```shell
Successfully received certificate.
Certificate is saved at: certs/live/semaphore.example.com/fullchain.pem
Key is saved at:         certs/live/semaphore.example.com/privkey.pem
This certificate expires on 2025-02-27.
These files will be updated when the certificate renews.
```

Check the existence of the certificate files on the following paths. You will require both files during the Semaphore installation.

- **Full chain certificate**: `./certs/live/$DOMAIN/fullchain.pem`
- **Private key certificate**: `./certs/live/$DOMAIN/privkey.pem`

You may delete the TXT record from your domain at this point. It's no longer needed.

## Step 5 - Install k3s and Helm {#k3s}

Still inside the remote shell in your Linux machine, install Helm with:

```shell title="remote shell - install Helm"
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 && chmod 700 get_helm.sh && ./get_helm.sh
```

Next, install k3s:

```shell title="remote shell - install k3s"
curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" sh -
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
```

## Step 6 - Install Semaphore {#install}

We recommend running the following sanity checks to confirm you're ready for installation. The commands should not fail and return valid values.

```shell title="remote shell - check if ready to install"
source semaphore-config
echo "DOMAIN=${DOMAIN}"
echo "IP_ADDRESS=${IP_ADDRESS}"
ls certs/live/${DOMAIN}/fullchain.pem certs/live/${DOMAIN}/privkey.pem
```

Before installing Semaphore, we need the [Emissary Ingress Controller](https://www.getambassador.io/docs/latest/topics/install/yaml-install/) to manage the ingress resources. Install it with:

```shell title="remote shell - install Emissary CRD"
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl apply -f https://app.getambassador.io/yaml/emissary/3.9.1/emissary-crds.yaml
kubectl wait --timeout=90s --for=condition=available deployment emissary-apiext -n emissary-system
```

Finally, install Semaphore with Helm. This step assumes that you have copied your [license file](./license) into the machine. If you don't provide a license during installation, you can follow the [upgrade procedure] to install the license later and remove the missing license message.

```shell title="remote shell - install Semaphore"
helm upgrade --install semaphore oci://ghcr.io/semaphoreio/semaphore \
  --debug \
  --version v1.4.0 \
  --timeout 30m \
  --set global.edition=ee \
  --set global.license=$(cat path/to/license-file.txt) \
  --set global.domain.ip=${IP_ADDRESS} \
  --set global.domain.name=${DOMAIN} \
  --set ingress.enabled=true \
  --set ingress.ssl.enabled=true \
  --set ingress.className=traefik \
  --set ingress.ssl.type=custom \
  --set ingress.ssl.crt=$(cat certs/live/${DOMAIN}/fullchain.pem | base64 -w 0) \
  --set ingress.ssl.key=$(cat certs/live/${DOMAIN}/privkey.pem | base64 -w 0)
```

Once the installation is done, you the following command should appear in the terminal:

```text
=============================================================================================
Congratulations, Semaphore has been installed successfully!

To start using the app, go to https://id.semaphore.example.com/login

You can fetch credentials for the login by running this command:

echo "Email: $(kubectl get secret semaphore-authentication -n default -o jsonpath='{.data.ROOT_USER_EMAIL}' | base64 -d)"; echo "Password: $(kubectl get secret semaphore-authentication -n default -o jsonpath='{.data.ROOT_USER_PASSWORD}' | base64 -d)"; echo "API Token: $(kubectl get secret semaphore-authentication -n default -o jsonpath='{.data.ROOT_USER_TOKEN}' | base64 -d)"

=============================================================================================
```

Execute the shown command to retrieve the login credentials.

```shell title="remote shell - get login credentials"
$ echo "Email: $(kubectl get secret semaphore-authentication -n default -o jsonpath='{.data.ROOT_USER_EMAIL}' | base64 -d)"; echo "Password: $(kubectl get secret semaphore-authentication -n default -o jsonpath='{.data.ROOT_USER_PASSWORD}' | base64 -d)"; echo "API Token: $(kubectl get secret semaphore-authentication -n default -o jsonpath='{.data.ROOT_USER_TOKEN}' | base64 -d)"

Email: root@example.com
Password: AhGg_2v6uHuy7hqvNmeLw0O4RqI=
API Token: nQjnaPKQvW6TqXtpTNSx
```

## Step 7 - First login {#login}

:::note

On new installations, the system may take up a few minutes to finish all setup tasks. If you cannot login right away, wait a few minutes and try again.

:::

Open a browser and navigate to the domain to `id.<your-domain>/login`. For example: `id.semaphore.example.com/login`

Fill in the username and password obtained at the end of [step 6](#install).

![Log in screen for Semaphore](./img/first-login.jpg)

Once logged in, select the Semaphore organization to continue.

![Select your organization screen](./img/first-login-organization.jpg)

You should be greeted with the onboarding guide.

![Onboarding guide screen](./img/on-boarding-guide.jpg)

## Post-installation tasks

Once you have Semaphore up and running, check out the following pages to finish setting up:

- [Connect with GitHub](../using-semaphore/connect-github.md): connect your instance with GitHub to access your repositories
- [Quickstart](./quickstart): complete the Quickstart to get familiarized with Semaphore Community Edition
- [Invite users](../using-semaphore/organizations#people): invite users to your instance so they can start working on projects
- [Add self-hosted agents](../using-semaphore/self-hosted): add more machines to scale up the capacity of your CI/CD platform

## Upgrade Semaphore and renew license/certs {#upgrade}

Follow these steps if you need to upgrade Semaphore, install a new [license](./license), or renew the TLS certificates.

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
    ls license*.txt
    ```

4. Check the expiration date of the certificate. If it has expired, [regenerate the certificate](#certs) before upgrading

    ```shell
    openssl x509 -enddate -noout -in certs/live/${DOMAIN}/fullchain.pem
    ```

5. Run the following command to upgrade to `v1.3.0`. This step assumes that you have copied your [license file](./license) into the machine

    ```shell
    helm upgrade --install semaphore oci://ghcr.io/semaphoreio/semaphore \
      --debug \
      --version v1.3.0 \
      --timeout 20m \
      --set global.edition=ee \
      --set global.license=$(cat path/to/license-file.txt) \
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
