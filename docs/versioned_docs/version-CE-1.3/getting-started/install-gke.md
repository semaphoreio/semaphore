---
description: Install Semaphore on Google Kubernetes Engine (GKE)
---

# Google Cloud Kubernetes (GKE)

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
import Available from '@site/src/components/Available';
import VideoTutorial from '@site/src/components/VideoTutorial';
import Steps from '@site/src/components/Steps';
import FeatureNotAvailable from '@site/src/components/FeatureNotAvailable';

This page explains how to create a Kubernetes cluster using [Google Cloud Kubernetes Engine (GKE)](https://cloud.google.com/kubernetes-engine) and install Semaphore Community Edition.

## Overview

If this is your first time using Semaphore we suggest trying out [Semaphore Cloud](../../../docs/getting-started/guided-tour.md) to see if the platform fits your needs. You can create a free trial account without a credit card and use every feature.

The self-hosted installation is recommended for users and teams familiar with Semaphore.

:::note macOS users

There is a known issue that blocks Docker on macOS. If you have trouble running Helm and you're using macOS, check the following [outstanding issue](https://github.com/docker/for-mac/issues/7520#issuecomment-2593247448) for a workaround.

:::

## Prerequisites {#prerequisites}

- A DNS domain
- A Google Cloud account

## Step 1 - Install dependencies {#dependencies}

Install the following tools before starting the installation:

- [Google Cloud SDK](https://cloud.google.com/sdk): command line tools to create and manage your Google Cloud services
- [Certbot](https://certbot.eff.org/): to create TLS certificates for your domain
- [Helm](https://helm.sh/docs/intro/install/): to install Semaphore

## Step 2 - Set up Google project {#setup}

It is recommended to [create a Google Cloud Project](https://cloud.google.com/resource-manager/docs/creating-managing-projects) for your Semaphore installation. Once you have created your project, take note of the **Google Project ID**.

Append the following lines to your configuration file. Adjust the values to match your Project ID and the zone where the Kubernetes cluster runs. We'll call this file `google-config`

```shell title="google-config"
export DOMAIN="<domain-to-install-semaphore>"
export GOOGLE_CLOUD_PROJECT_ID="<your-project-id>"
export GOOGLE_STATIC_IP_NAME="<id-for-semaphore-ip>"
export GOOGLE_CERTIFICATE_NAME="<your-tls-certificate-name>"
export GOOGLE_CLOUD_ZONE=<your-zone-id>
export GOOGLE_CLOUD_CLUSTER_NAME="<your-cluster-name>"
```

:::info Important

We highly recommend **installing Semaphore on a subdomain**, e.g. `semaphore.example.com`. Installing Semaphore on your main domain is discouraged as its operation might interfere with other services running on the same domain.

For example, if your domain is `example.com`, consider installing Semaphore on `semaphore.example.com`. See the example below.

```shell title="example of semaphore-config file"
export DOMAIN="semaphore.example.com"
export IP_ADDRESS=1.2.3.4
```

:::

Once you have modified the configuration file, you should have something like the following example:

```shell title="google-config'
export DOMAIN="semaphore.example.com"
export GOOGLE_CLOUD_PROJECT_ID="my-semaphore-443021"
export GOOGLE_CERTIFICATE_NAME="my-semaphore-certificates"
export GOOGLE_STATIC_IP_NAME="my-semahore-ip"
export GOOGLE_CLOUD_ZONE=us-central1-a
export GOOGLE_CLOUD_CLUSTER_NAME="my-semaphore-gke"
```

Load your Google config file with the following command:

```shell title="Load configuration"
source google-config
```

Authenticate with your Google Cloud account before continuing. The command opens a browser to log in to your account.

```shell title="Login to GCP"
gcloud auth login
```

Once logged in, activate to your Semaphore project on the terminal with the following commands:

```shell title="Switch to your Semaphore project"
gcloud config set project "${GOOGLE_CLOUD_PROJECT_ID}"
```

## Step 3 - Reserve a public IP {#ip}

Reserve a public IP address for the Kubernetes ingress with the following commands:

```shell title="Reserve IP"
gcloud compute addresses create "${GOOGLE_STATIC_IP_NAME}" \
    --project "${GOOGLE_CLOUD_PROJECT_ID}" \
    --global
```

Run the following command to access your assigned IP address:

```shell title="Retrieve reserved IP"
export IP_ADDRESS=$(gcloud compute addresses describe "${GOOGLE_STATIC_IP_NAME}" \
    --project "${GOOGLE_CLOUD_PROJECT_ID}" \
    --global \
    --format='get(address)')
echo export IP_ADDRESS=$IP_ADDRESS >> google-config
```

Take note of the IP address as you'll need it later.

```shell
$ echo $IP_ADDRESS

34.25.122.100
````

## Step 4 - Create TLS certificates {#certs}

:::note

You may skip this section if you already have wildcard certificates, e.g. `*.semaphore.example.com` for the domain where you are installing Semaphore.

:::

We can use [certbot](https://certbot.eff.org/) to create a free wildcard TLS certificate with the following command:

```shell title="remote shell - create certificates with certbot"
source google-config
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


## Step 5 - Install TLS certificates

Install the TLS certificates [created before](#certs) using the following command:

```shell title="Install certificates"
gcloud compute ssl-certificates create "${GOOGLE_CERTIFICATE_NAME}" \
 --certificate="certs/live/${DOMAIN}/fullchain.pem" \
 --private-key="certs/live/${DOMAIN}/privkey.pem" \
 --project="${GOOGLE_CLOUD_PROJECT_ID}"
```

## Step 6 - Create DNS records {#dns}

Configure your DNS by creating two A records that point to the reserved IP:

<Steps>

1. Go to your domain provider's DNS settings
2. Create root domain A record

      - Type: A
      - Name: `semaphore` (e.g. `semaphore.example.com`)
      - Value: the public IP address of your Linux machine

3. Create a wildcard record

      - Type: A
      - Name: `*.semaphore` (e.g. `*.semaphore.example.com`
      - Value: the public IP address of your Linux machine

4. Wait for DNS propagation (typically a few minutes)

    You can verify the creation of the TXT record in the [Online Dig Tool](https://toolbox.googleapps.com/apps/dig/#A/) for:

      - `semaphore.example.com`
      - `*.semaphore.example.com`

</Steps>

## Step 7 - Create Kubernetes Cluster {#k8s}

In this section, we create a 1-node cluster with the smallest machine that can run Semaphore with default parameters.

First, install the GKE plugin for the Google Cloud SDK:

```shell title="Install plugins"
gcloud components install gke-gcloud-auth-plugin
```

Next, enable the Kubernetes API for your project:

```shell title="Enable Kubernetes API"
gcloud services enable container.googleapis.com --project ${GOOGLE_CLOUD_PROJECT_ID}
```

Finally, create the cluster. You may adjust the commands if you want to create more nodes or use more powerful machines. The command might take several minutes to complete.

```shell title="Create GKE instance"
gcloud container clusters create "${GOOGLE_CLOUD_CLUSTER_NAME}" \
    --project "${GOOGLE_CLOUD_PROJECT_ID}" \
    --zone "${GOOGLE_CLOUD_ZONE}" \
    --num-nodes 1 \
    --machine-type e2-custom-8-16384 \
    --network "default" \
    --subnetwork "default" \
    --enable-ip-alias \
    --cluster-version latest \
    --no-enable-master-authorized-networks
```

Once done, ensure you can access the cluster with:

```shell
kubectl get nodes
```

## Step 8 - Install CRDs {#crds}

Semaphore requires the [Emissary CRDs] to be installed on the cluster. Install the Custom Resource Definitions (CRDs) with the following commands:

```shell title="Install CRDs"
kubectl apply -f https://app.getambassador.io/yaml/emissary/3.9.1/emissary-crds.yaml
kubectl wait --timeout=90s --for=condition=available deployment emissary-apiext -n emissary-system
```

## Step 9 - Install Semaphore {#semaphore}

Sanity check that the environment is ready for the installation. The commands should not fail and return valid values:

```shell
source google-config
echo "DOMAIN=${DOMAIN}"
echo "IP_ADDRESS=${IP_ADDRESS}"
echo "GOOGLE_CERTIFICATE_NAME=${GOOGLE_CERTIFICATE_NAME}"
echo "GOOGLE_STATIC_IP_NAME=${GOOGLE_STATIC_IP_NAME}"
ls certs/live/${DOMAIN}/privkey.pem certs/live/${DOMAIN}/fullchain.pem
```

Run the following to install Semaphore:

```shell title="Install Semaphore"
helm upgrade --install semaphore oci://ghcr.io/semaphoreio/semaphore \
  --debug \
  --version v1.3.0 \
  --timeout 20m \
  --set global.domain.ip=${IP_ADDRESS} \
  --set global.domain.name="${DOMAIN}" \
  --set ingress.staticIpName="${GOOGLE_STATIC_IP_NAME}" \
  --set ingress.enabled=true \
  --set ingress.ssl.enabled=true \
  --set ingress.ssl.certName="${GOOGLE_CERTIFICATE_NAME}" \
  --set ingress.ssl.type="google"
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

### Verify installation {#verify}

You can check that for possible installation issues by following these steps:

<Steps>

1. Ensure all pods are running. All pods should be in `Running` state with `READY` status showing all containers ready (e.g., `2/2`).

    ```shell
    kubectl get pods
    ```

2. Verify ingress configuration. The ingress should show the IP address you configured and no error messages.

    ```shell
    kubectl get ingress semaphore
    ```

3. Verify SSL certificate. The certificate should be in `ACTIVE` state.

    ```shell
    gcloud compute ssl-certificates describe "${GOOGLE_CERTIFICATE_NAME}"

</Steps>

## Step 10 - First login {#login}

:::note

On new installations, the system may take up to 30 minutes to finish all setup tasks. If you cannot login right away, wait a few minutes and try again.

:::

Open a browser and navigate to the domain to `id.<your-domain>/login`. For example: `id.semaphore.example.com/login`

Fill in the username and password obtained at the end of [step 9](#semaphore).

![Log in screen for Semaphore](./img/first-login.jpg)

Once logged in, select the Semaphore organization to continue.

![Select your organization screen](./img/first-login-organization.jpg)

You should be greeted with the onboarding guide.

![Onboarding guide screen](./img/on-boarding-guide.jpg)

## Post installation tasks

Once your have Semaphore up and running, check out the following pages to finish setting up:

- [Connect with GitHub](../using-semaphore/connect-github.md): connect your instance with GitHub to access your repositories
- [Invite users](../using-semaphore/organizations#people): invite users to your instance so they can start working on projects
- [Guided tour](./guided-tour): complete the guided tour to get familiarized with Semaphore Community Edition
- [Add self-hosted agents](../using-semaphore/self-hosted): add more machines to scale up the capacity of your CI/CD platform

## How to Upgrade Semaphore {#upgrade}

To upgrade Semaphore, follow these steps:

<Steps>

1. Connect to your Google project (see [Step 2](#setup))
2. Check that you can access the Kubernetes cluster:

    ```shell
    kubectl get nodes
    ```
3. Load the configuration file and ensure the certificates are in the correct folder. See [Step 4](#certs) if you need to recreate the certificates.

    ```shell
    source google-config
    echo "DOMAIN=${DOMAIN}"
    echo "IP_ADDRESS=${IP_ADDRESS}"
    echo "GOOGLE_CERTIFICATE_NAME=${GOOGLE_CERTIFICATE_NAME}"
    echo "GOOGLE_STATIC_IP_NAME=${GOOGLE_STATIC_IP_NAME}"
    ls certs/live/${DOMAIN}/privkey.pem certs/live/${DOMAIN}/fullchain.pem
    ```
4. Check the expiration date of the certificate. If it has expired, [regenerate the certificate](#certs) before upgrading

    ```shell
    openssl x509 -enddate -noout -in certs/live/${DOMAIN}/fullchain.pem
    ```

5. Run the following command to upgrade to `v1.3.0`

    ```shell
    helm upgrade --install semaphore oci://ghcr.io/semaphoreio/semaphore \
      --debug \
      --version v1.4.0 \
      --timeout 30m \
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

## How to Uninstall Semaphore from GKE

If you want to completely uninstall Semaphore, follow these steps.

:::danger

If you uninstall Semaphore you will lose access to all your projects, workflows and logs. You cannot undo this action.

:::

First, uninstall Semaphore with the following command:

```shell title="Uninstall Semaphore"
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
helm uninstall semaphore
```

Delete the persistent volume claims:

```shell
kubectl delete pvc \
  minio-artifacts-storage-minio-artifacts-0 \
  minio-cache-storage-minio-cache-0 \
  minio-logs-storage-minio-logs-0 \
  postgres-storage-postgres-0 \
  rabbitmq-storage-rabbitmq-0 \
  redis-data-redis-0
```

Next, release the IP address and remove the TLS certificate:

```shell
source google-config
gcloud compute addresses delete "${GOOGLE_STATIC_IP_NAME}" --global
gcloud compute ssl-certificates delete "${GOOGLE_CERTIFICATE_NAME}"
```

Finally, if you are no longer using the Kubernetes cluster, you may delete it with the following command. This completely destroys the Kubernetes cluster with any other things you might be running there.

```shell
source google-config
gcloud container clusters delete --zone "${GOOGLE_CLOUD_ZONE}" "${GOOGLE_CLOUD_CLUSTER_NAME}" 
```

## See also

- [Installation guide](./install.md)
- [Getting started guide](./guided-tour)
- [Migration guide](./migration/overview)

