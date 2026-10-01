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

## Upgrade from a release with MinIO {#minio}

Semaphore stores artifacts, job logs, and the cache in RustFS instead of MinIO. Upgrading from a version that still runs MinIO does not migrate the stored data: artifacts, job logs, and cache entries saved before the upgrade are not available afterwards.

The new stores start with credentials that the chart generates during the upgrade and reuses on every later upgrade, so no credentials appear in the chart. If you render the chart outside the cluster, for example with `helm template`, Argo CD, or Flux, set `global.artifacts.username`, `global.artifacts.password`, and the same two keys under `global.cache` and `global.logs` yourself, because every render would otherwise generate new credentials.

To prevent this data loss from happening by accident, the upgrade stops with an error while the MinIO StatefulSets from the previous version are present. To upgrade anyway, add the following argument to the Helm upgrade command:

```shell title="Acknowledge the removal of MinIO"
--set global.objectStorage.acknowledgeMinioRemoval=true
```

The upgrade keeps the persistent volume claims used by MinIO. Once you no longer need their data, delete them:

```shell title="Delete MinIO PVCs"
kubectl delete pvc \
  minio-artifacts-storage-minio-artifacts-0 \
  minio-cache-storage-minio-cache-0 \
  minio-logs-storage-minio-logs-0
```

## See also

- [How to uninstall Semaphore](./uninstall-semaphore)

