---
description: Upgrade Semaphore versions or renew expired certificates
---

# Upgrade Semaphore

This page explains how to upgrade Semaphore in place and how to deal with expired certificates.

## Renew expired TLS certificates {#renew}

TLS certificates generated during the installation are only valid for **3 months**. The certificates **do not autorenew**. Follow these steps to generate and install the new certificates.

<Steps>

1. If required, SSH into the Semaphore server

2. Go to the `semaphore-install` directory and load the `semaphore-config` used in the original installation

    ```shell title="Load Semaphore and cloud configuration"
    cd semaphore-install
    source semaphore-config
    ```

3. Re-run the certbot command and follow the on-screen instructions

    ```shell title="Create certificates with certbot"
    certbot certonly --manual --preferred-challenges=dns \
        -d "*.${DOMAIN}" \
        --register-unsafely-without-email \
        --work-dir certs \
        --config-dir certs \
        --logs-dir certs
    ```

4. Follow the [upgrade steps to Semaphore](#upgrade)

</Steps>

## Renew Enterprise Edition License {#renew-license}

Semaphore server shows an warning message when the license is close to expiring or has expired already.

To renew your license, follow these steps.

<Steps>

1. Obtain a new license. See the [how to obtain a license page](./license) for instructions

2. If required, SSH into the Semaphore server

3. Copy the new license file into the server

4. Update the `semaphore-config` inside your `semaphore-install` directory. Update the value of `LICENSE_FILE`

    ```shell title="Update the value of LICENSE_FILE"
    export LICENSE_FILE="your-new-license-file-name.txt"
    ```

5. Follow the [upgrade steps to Semaphore](#upgrade)

</Steps>


## Upgrade Semaphore {#upgrade}

To upgrade Semaphore, you must re-run the `helm upgrade` command used to install it in the first place.

<Steps>

1. If required, SSH into the Semaphore server

2. Go to the `semaphore-install` directory and load the `semaphore-config` used in the original installation

    ```shell title="Load Semaphore and cloud configuration"
    cd semaphore-install
    source semaphore-config
    ```

3. Re-run the Helm upgrade command used in the initial installation. You may select a different `--version` argument to upgrade or downgrade your Semaphore version. The installation usually takes between 10 and 30 minutes

    ```shell title="Remote shell: install Semaphore"
    helm upgrade --install semaphore "oci://ghcr.io/semaphoreio/semaphore" \
      --debug \
      --version v1.5.0 \
      --timeout 30m \
      --set global.edition=ee \
      --set global.license="$(cat ${LICENSE_FILE})"\
      --set global.rootUser.email="${ROOT_EMAIL}" \
      --set global.rootUser.name="${ROOT_NAME}" \
      --set global.domain.ip="${IP_ADDRESS}" \
      --set global.domain.name="${DOMAIN}" \
      --set ingress.enabled=true \
      --set ingress.ssl.enabled=true \
      --set ingress.className=traefik \
      --set ingress.ssl.type=custom \
      --set ingress.ssl.crt="$(cat certs/live/${DOMAIN}/fullchain.pem | base64 -w 0)" \
      --set ingress.ssl.key="$(cat certs/live/${DOMAIN}/privkey.pem | base64 -w 0)"
    ```

</Steps>

## See also

- [How to uninstall Semaphore](./uninstall-semaphore)

