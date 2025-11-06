---
description: Uninstall Semaphore and remove all its data from your systems
---


# Uninstall Semaphore

This page explains how to uninstall Semaphore and delete all its data.

:::danger

If you uninstall Semaphore, you will lose access to all your projects, workflows, and logs. You cannot undo this action.

:::

To uninstall Semaphore, follow these steps:

<Steps>

1. If required, SSH into the Semaphore server

2. Run the following command to uninstall Semaphore

    ```shell title="Uninstall Semaphore control plane"
    helm uninstall semaphore
    ```

3. Remove the persistent volumes claims

    ```shell title="Delete PVCs"
    kubectl delete pvc \
      minio-artifacts-storage-minio-artifacts-0 \
      minio-cache-storage-minio-cache-0 \
      minio-logs-storage-minio-logs-0 \
      postgres-storage-postgres-0 \
      rabbitmq-storage-rabbitmq-0 \
      redis-data-redis-0
    ```

4. Uninstall the agents in any [self-hosted agents](../using-semaphore/self-hosted) you were using

</Steps>

## See also

- [How to upgrade Semaphore](./upgrade-semaphore)
