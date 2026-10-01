---
description: Semaphore change log for Semaphore CE.
---

# Change Log

Thank you for using Semaphore!

This page shows changes in all Semaphore CE versions.

## Version 1.6.0

- The bundled MinIO object store is replaced by RustFS. Artifacts, job logs, and cache entries stored before the upgrade are not migrated, and the old `minio-*` persistent volume claims are kept until you delete them. See [Upgrade from a release with MinIO](./upgrade-semaphore#minio).
- The credentials of the bundled stores are generated for each installation and kept across upgrades. Set `global.artifacts.username`, `global.artifacts.password`, and the same keys under `global.cache` and `global.logs` only when you render the chart outside the cluster.
- The `cache.<domain>` and `logs.<domain>` hostnames are no longer served. Only `artifacts.<domain>` stays reachable, for presigned URLs.
- Rolling back to 1.5 works only while the node still has the MinIO image cached, because that image is no longer published.
