---
description: OpenID Connect (OIDC) token reference
---

# OIDC Tokens

This page describes how [OpenID Connect (OIDC)](../using-semaphore/openid) tokens are generated.

<Available plans={['Enterprise']}/>

## Reference

Semaphore generates a unique OIDC token for every job. The token is injected into the job environment as a variable named `SEMAPHORE_OIDC_TOKEN`.

The token consists of a JWT token signed by Semaphore and contains the following claims.

Sure, here is the reordered list presented in a table with three columns: Claim, Description, Example.

| Claim       | Description                                               | Example                              |
|-------------|-----------------------------------------------------------|--------------------------------------|
| iss         | The issuer of the token. The full URL of the organization | `https://<org-name>.semaphoreci.com` |
| aud         | The intended audience of the token. The full URL of the organization | `https://<org-name>.semaphoreci.com` |
| sub         | The subject of the token. A combination of org, project, repository, and git reference for which this token was issued<br/>Template:<br/> `org:<org-name>:`<br/>`project:{project-id}:`<br/>`repo:{repo-name}:`<br/>`ref_type:{branch or pr or tag}:`<br/>`ref:{git_reference}`<br/><br/>**Note**: This field often exceeds Google Cloud's 127-byte limit for attribute mapping. Use the `sub127` claim (outlined below) or individual claims like `repo`, `branch`, or `prj` when you need a shorter value. | `org:{org-name}:`<br/>`project:936a5312-a3b8-4921-8b3f-2cec8baac574:`<br/>`repo:web:`<br/>`ref_type:branch:`<br/>`ref:refs/heads/main` |
| sub127      | Compact subject (`org:project_id:repo:ref_type:ref`) sanitized for attribute mapping. Removes `:` characters, shortens ref types to two letters (`br`, `tg`, `pr`), drops the leading `refs/` prefix from refs, and caps the final value at 127 characters. Component limits: `org ≤ 25`, `repo ≤ 25`, `ref ≤ 35` characters (project ID stays at 36 characters). Designed for providers with strict length limits such as Google Cloud. | `acme:936a5312-a3b8-4921-8b3f-2cec8baac574:web:br:heads/main` |
| exp         | The UNIX timestamp when the token expires  | `1660317851` |
| iat         | The UNIX timestamp when the token was issued | `1660317851` |
| nbf         | The UNIX timestamp before which the token is not valid | `1660317851` |
| jti         | The Unique ID of the JWT token | `2s557dchalv2mv76kk000el1` |
| branch      | The name of the branch on which the job is running. If the job was triggered by a pull request, then the value is the target branch of the pull request that triggered that job | `main` |
| pr_branch   | The name of the source branch of the Pull Request which triggered a job | `feature-branch` |
| pr          | The number of the Pull Request for which the token was issued  | `123` |
| ref         | The full git reference for which the token was issued  | `refs/heads/main` |
| ref_type    | The type of git reference that triggered the job  | `branch`, `tag`, or `pull-request` |
| tag         | The name of the git tag for which the token was issued    | `v1.0.0`   |
| repo        | The name of the repository for which the token was issued | `web` |
| repo_slug   | Specifies the repository's name in the format `owner_name/repository_name` for the current Semaphore project. It is associated with the environment variable `SEMAPHORE_GIT_REPO_SLUG` | `semaphoreci/docs`  |
| org         | The organization name for which the token was issued | `semaphore` |
| org_id      | The organization ID for which the token was issued | `d7dd33ad-9317-498c-9cc6-51c250749be7` |
| prj         | The project name for which the token was issued | `docs` |
| prj_id      | The project ID for which the token was issued | `1e1fcfb5-09c0-487e-b051-2d0b5514c42a` |
| wf_id       | The ID of the workflow for which the token was issued | `1be81412-6ab8-4fc0-9d0d-7af33335a6ec` |
| ppl_id      | The pipeline ID for which the token was issued | `1e1fcfb5-09c0-487e-b051-2d0b5514c42a` |
| job_type    | The type of the job based on the way it was created <br/>The possible values are:<ul><li>`pipeline_job`: A regular job that is the part of a pipeline</li><li>`debug_job`: A job that was created to debug the other job via the sem debug job `<JOB_ID>` command</li><li>`project_debug_job`:A job that was created to debug the project via the sem debug project `<PROJECT_NAME>` command</li></ul> | `pipeline_job` |
| job_id      | The ID of the job for which the token was issued | `c117e453-1189-4eaf-b03a-dd6538eb49b2` |
| trg         | Indicates how the workflow was triggered, including information about workflow reruns and pipeline rebuilds<br/>Template: `{triggerer_type}:{workflow_rerun}-{pipeline_type}:{pipeline_rebuild}`<br/>Where:<ul><li>`{triggerer_type}`: How the workflow was initiated<ul><li>`a`: API triggered</li><li>`h`: Hook (webhook) triggered</li><li>`s`: Scheduler/Task triggered</li><li>`m`: Manually run task</li></ul></li><li>`{workflow_rerun}`: Whether this is a rerun of an existing workflow<ul><li>`t`: This is a rerun</li><li>`f`: This is the initial run</li></ul></li><li>`{pipeline_type}`: Type of pipeline execution<ul><li>`u`: Auto promotion</li><li>`n`: Manual promotion</li><li>`i`: Initial pipeline</li></ul></li><li>`{pipeline_rebuild}`: Whether this is a rebuild of a pipeline<ul><li>`t`: This is a rebuild</li><li>`f`: This is the initial build</li></ul></li></ul> | <br/>`h:f-i:t`<br/>(Hook triggered workflow, not a rerun, initial pipeline, pipeline rebuilt)<br/><br/>`s:t-i:f`<br/>(Scheduler/Task triggered workflow, workflow rerun, initial pipeline, not rebuilt) |

A token with the above claims is exported into jobs as the `SEMAPHORE_OIDC_TOKEN` environment variable, which can then be presented to the cloud provider as an authorization token.

If the cloud provider is configured to accept OIDC tokens, it will receive the token, verify its signature by connecting back to `<org-url>.semaphoreci.com.well-known/jwts`, and if the token is valid, it will respond with a short-lived token for this specific job that can be used to fetch and modify cloud resources.

## `oidc_tokens` block

Jobs can declare additional OIDC tokens with custom audiences using a per-job `oidc_tokens:` block. This is needed for consumers that strictly verify a specific `aud` value (such as [PyPI's trusted publishers](https://docs.pypi.org/trusted-publishers/), which requires `aud="pypi"`).

```yaml
jobs:
  - name: Publish
    oidc_tokens:
      <ENV_VAR_NAME>:
        aud: <string-or-list-of-strings>
    commands:
      - ...
```

### Schema

| Field | Required | Type | Description |
|---|---|---|---|
| `<ENV_VAR_NAME>` (the yaml key) | yes | string | Name of the environment variable. Must match `^[A-Z_][A-Z0-9_]*$`. The reserved name `SEMAPHORE_OIDC_TOKEN` is not allowed (it's the auto-injected default). |
| `aud` | yes | string OR non-empty list of strings | Value of the JWT `aud` claim. A string becomes JWT `"aud": "<value>"`; a list becomes JWT `"aud": [<values>]` per [RFC 7519 §4.1.3](https://www.rfc-editor.org/rfc/rfc7519#section-4.1.3). Up to 8 audiences allowed; each up to 256 characters. |

A job may declare up to 16 entries.

### Behavior

- Each entry in `oidc_tokens` produces one additional minted token, exposed as the named environment variable (the yaml key).
- The default `SEMAPHORE_OIDC_TOKEN` is always still injected when the OIDC feature is enabled — `oidc_tokens` is purely additive.
- All tokens share the same TTL and the same claim set as the default token, except for `aud` (per the request) and `jti` (always unique per token).

### Validation errors

| Error | Cause |
|---|---|
| Schema validation failure on `oidc_tokens` | Yaml key doesn't match the env var name regex, `aud` is missing or wrong shape, or extra unknown properties present |
| `'SEMAPHORE_OIDC_TOKEN' is reserved; use a different env var name` | Reserved key used as a custom token name |

See the [Custom audiences](../using-semaphore/openid#custom-audiences) section of the OIDC guide for usage examples.

## See also

- [Pipeline YAML](./pipeline-yaml)
