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

</Steps>

## See also

- [How to uninstall Semaphore](./uninstall-semaphore)

