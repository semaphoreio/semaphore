---
description: Semaphore change log for Semaphore EE.
---

# Change Log

Thank you for using Semaphore!

This page shows changes in all Semaphore EE versions.

## Version 1.6.0

- The bundled MinIO object store is replaced by RustFS. Artifacts, job logs, and cache entries stored before the upgrade are not migrated, and the old `minio-*` persistent volume claims are kept until you delete them. See [Upgrade from a release with MinIO](./upgrade-semaphore#minio).
- The credentials of the bundled stores are generated for each installation and kept across upgrades. Set `global.artifacts.username`, `global.artifacts.password`, and the same keys under `global.cache` and `global.logs` only when you render the chart outside the cluster.
- The `cache.<domain>` and `logs.<domain>` hostnames are no longer served. Only `artifacts.<domain>` stays reachable, for presigned URLs.
- Rolling back to 1.5 works only while the node still has the MinIO image cached, because that image is no longer published.
- Keycloak is upgraded from 25.0.6 to 26.8.0. Keycloak migrates its database on the first start and the migration cannot be undone, so back up the `keycloak` database before you upgrade. See [Upgrade from a release with Keycloak 25](./upgrade-semaphore#keycloak).
- The API v2 service is no longer deployed by default: the `public-api` subchart is behind `public-api.enabled`, which defaults to `false`. Use the v1alpha API.
- The MCP server is deployed by default and served at `mcp.<domain>`. Set `mcp-server.enabled=false` to turn it off.
- Rerunning a failed pipeline reruns only the jobs that failed, and carries over the passed jobs without running them again. Set `partial_rerun: block` on a pipeline or block whose jobs must run together, such as a dynamically split test suite.
- `SEMAPHORE_WORKFLOW_TRIGGERED_BY` holds the triggerer's login on the repository's Git provider. A rerun of a push or pull request workflow reports the original pusher instead of the person who reran it.
- `after_pipeline` jobs without their own `execution_time_limit` inherit the pipeline's limit instead of the 24-hour job default.
- Pipelines with circular dependencies between blocks fail at initialization.
- On GitHub, stopped and canceled pipelines report the `error` commit status instead of `failure`.
- GitHub merge queue builds report under the pull request status instead of the push status. If your merge queue requires the push status, switch it to the pull request status.
- Service accounts can create a GitHub App project only for a repository owner that the organization already has a GitHub App project for.

For all changes in this release, see the [v1.6.0 release notes](https://github.com/semaphoreio/semaphore/releases/tag/v1.6.0).
