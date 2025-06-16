---
description: Projects YAML reference
---

# Projects YAML

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
import Available from '@site/src/components/Available';
import VideoTutorial from '@site/src/components/VideoTutorial';


This document is the YAML syntax reference used for adding and editing Semaphore projects via [Semaphore Command Line](./semaphore-cli).

## Overview

The syntax described here is required to use [`sem create`](./semaphore-cli#sem-create) for creating a project using the command line.

## apiVersion {#apiVersion}

The `apiVersion` property defines the version of the YAML grammar that will be used to define the YAML file. Different YAML versions might have different features.

The only allowed value is: `v1alpha`

## kind {#kind}

The value of the `kind` property is a string that specifies the type of the resource to create.

To create a project `kind` value must be `Project`

## metadata {#metadata}

The metadata supports the `name` property. This is the name of the project.

The value of the `name` property should be unique among all Semaphore projects belonging to the same server and must only contain alphanumeric characters ([a-z], [A-Z], or [0-9]). Dashes, underscores, hyphens, and spaces are not allowed.

## spec {#spec}

The `spec` property must contain a [`repository`](#repository-in-spec) property.

It can also optionally include:

- [`schedulers`](#schedulers-in-spec) (DEPRECATED)
- [`tasks`](#tasks-in-spec)

### schedulers {#schedulers-in-spec}

:::note

This property is deprecated and will be removed in the future. Please use [`tasks`](#tasks-in-spec) instead.

:::

<details>
<summary>Show deprecated property</summary>
<div>

The schedulers property can contain a list of schedulers defined in the project.

A scheduler is a way to run a pre-defined pipeline on a project at a pre-defined time. All times are interpreted as UTC.

A scheduler has the following properties:

- `name`: uniquely identifies each scheduler within an server
- `branch`: specifies which branch will be used for running the pipeline. The chosen branch must have at least one workflow initiated by a push in order for the scheduler to be valid
- `at`: defines the schedule under which the pipeline will be run expressed in [standard cron syntax](https://en.wikipedia.org/wiki/Cron). For a simple way to define your cron syntax, visit [crontab.guru](https://crontab.guru/).
- `pipeline_file`: contains the relative path to the pipeline definition file from the root of the project
- `status`: can be `ACTIVE` or `INACTIVE`

</div>
</details>

### tasks {#tasks-in-spec}

The tasks property can contain a list of tasks defined in the project.

A task is a way to run a pre-defined pipeline on a project at a pre-defined time or on demand. All times are interpreted as UTC.

A task has the following properties:

- `name`: uniquely identifies each task within a project.
- `description`: provides additional comment for a task. It is optional and can be omitted.
- `scheduled`: it's a boolean value `true` or `false`. If `true` the task is active and the `at` property must be set
- `at`: mandatory if `scheduled: true`. This is the schedule to run the pipeline expressed in the [standard cron syntax](https://en.wikipedia.org/wiki/Cron).
- `branch`: specifies which branch will be used for running the pipeline.
- `pipeline_file`: defines the relative path to the pipeline definition file from the root of the project
- `status`: `ACTIVE` if the scheduler is currently enabled, or `INACTIVE` if the scheduler is currently disabled. 
- [`parameters`](#parameters-in-spec): list of parameters to pass to the workflow

:::tip

For a simple way to define your cron syntax, visit [crontab.guru](https://crontab.guru/).

:::

See [Pipeline YAML Reference](./pipeline-yaml) for more information on the pipeline syntax.

### tasks parameters {#parameters-in-spec}


The `parameters` property contains a list of parameters passed to the triggered workflow.  Those parameters are accessible in the job environment as environment variables. By default, `parameters` is an empty list.

Each parameter has the following properties:

| Property | Required | Description |
|--|--|--|
|`name` | Yes | Unique parameter name |
|`required`| Yes | Either `true` or `false`. Determines if the parameter is required |
|`description`| No | A descriptive string for the parameter |
|`default_value`| No | The parameter's default value. Required if `required: true` |
|`options`| No | A list of possible values to show on the Semaphore website |

## repository {#repository-in-spec}

This property describes the GitHub or BitBucket repository.

It must contain the following properties:

- [`url`](#url-in-repository)
- [`run_on](#run-on-in-repository)
- [`forked_pull_requests`](#forked-pull-requests-in-repository)
- [`pipeline_file`](#pipeline-file-in-repository)
- [`status`](#status-in-repository)

### url {#url-in-repository}

The `url` property is a string that specifies the URL of the GitHub or BitBucket repository. 

The format of the `url` value should be as follows:

``` txt
git@github.com:github_username/github_repository.git
```

An invalid URL prompts the following error:

```text
error: http status 422 with the message "{"message":"repository \"repo-name\" not found"}" received from upstream
```

If the URL is not in SSH format, you will get the following error:

```text
error: http status 422 with message "{"message":"repository url must be an SSH url"}" received from upstream
```

If the project name is already taken in your active server you will see the following error:

```text
error: http status 422 with message "{"message":"project name \"repo-name\" is already taken"}" received from upstream
```

### run_on {#run-on-in-repository}

This property is an array of events that can trigger a workflow for this project.

The possible values are:

- `branches`
- `tags`
- `pull_requests`
- `forked_pull_requests`

## pipeline_file {#pipeline-file-in-repository}

Used for setting the initial pipeline file that is executed when a post-commit hook is received by Semaphore.

The default value is `.semaphore/semaphore.yml`.

:::note

When modifying the initial pipeline file it is necessary to also update the corresponding [status check](#status-in-repository).

::::

## forked_pull_requests {#forked-pull-requests-in-repository}

This property is used for holding the following properties:

- [`allowed_secrets`](#allowed-secrets-in-forked-pull-requests) 
- [`allowed_contributors`](#allowed-secrets-in-forked-pull-requests)

### allowed_secrets {#allowed-secrets-in-forked-pull-requests}

Specifies the array of secrets' names that are allowed to be exported into jobs triggered by `forked-pull-requests`. If the array is empty, no secrets will be exported.

### allowed_contributors {#allowed-secrets-in-forked-pull-requests}

Specifies an array of secrets (i.e. their names) that are allowed to be exported into jobs triggered by `forked-pull-requests`. If the array is empty, no secrets will be exported.


## status {#status-in-repository}

This property specifies the pipelines that Semaphore submits to GitHub or BitBucket pull request status.

A pipeline can create a single status check as a result of a whole pipeline.  Or each block in a pipeline can create its own status check.

### pipeline_files {#pipeline-files-in-status}

A list of pipeline files for which Semaphore submits status checks.

Each item has two properties:

- `path`: defines the pipeline to use in status checks
- `level`: defines the granularity of status checks. The possible values are:
  - `block`
  - `pipeline`

The default value is:

```yaml title="Default value for pipeline_files"
- path: .semaphore/semaphore.yml
  level: pipeline
```

## Examples

This section shows project YAML examples.

<details>
<summary>Simple project</summary>
<div>

``` yaml
apiVersion: v1alpha
kind: Project
metadata:
  name: goDemo
spec:
  repository:
    url: "git@github.com:renderedtext/goDemo.git"
    run_on:
      - branches
      - tags
    pipeline_file: ".semaphore/semaphore.yml"
    status:
      pipeline_files:
        - path: ".semaphore/semaphore.yml"
          level: "pipeline"
```

</div>
</details>

<details>
<summary>Project with schedulers</summary>
<div>


``` yaml
apiVersion: v1alpha
kind: Project
metadata:
  name: goDemo
spec:
  repository:
    url: "git@github.com:renderedtext/goDemo.git"
    run_on:
      - branches
      - tags
    pipeline_file: ".semaphore/semaphore.yml"
    status:
      pipeline_files:
        - path: ".semaphore/semaphore.yml"
          level: "pipeline"
  schedulers:
    - name: first-scheduler
      branch: master
      at: "5 4 * * *"
      pipeline_file: ".semaphore/cron.yml"
    - name: second-scheduler
      branch: master
      at: "5 3 * * *"
      pipeline_file: ".semaphore/semaphore.yml"
      status: ACTIVE
```


</div>
</details>


<details>
<summary>Project with tasks</summary>
<div>

``` yaml
apiVersion: v1alpha
kind: Project
metadata:
  name: goDemo
spec:
  repository:
    url: "git@github.com:renderedtext/goDemo.git"
    run_on:
      - branches
      - tags
    pipeline_file: ".semaphore/semaphore.yml"
    status:
      pipeline_files:
        - path: ".semaphore/semaphore.yml"
          level: "pipeline"
  tasks:
    - name: first-scheduler
      scheduled: true
      branch: master
      at: "5 4 * * *"
      pipeline_file: ".semaphore/cron.yml"
      status: ACTIVE
    - name: second-task
      description: "second-task description"
      scheduled: false
      branch: develop
      at: ""
      pipeline_file: ".semaphore/canary.yml"
      status: ACTIVE
      parameters:
      - name: CANARY_VERSION
        required: true
        default_value: "1.0.0"
      - name: DEBUG_INFO
        required: false
        default_value: "false"
        options:
        - "true"
        - "false"
```

</div>
</details>

## See also

- [Jobs YAML reference](./jobs-yaml)
- [Pipeline YAML reference](./pipeline-yaml)
- [Secrets YAML reference](./secret-yaml)
- [Agents YAML reference](./agent-yaml)
- [Notifications YAML reference](./notifications-yaml)
- [Semaphore Command Line reference](./semaphore-cli)

