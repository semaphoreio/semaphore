---
description: Secrets YAML reference
---

# Secrets YAML 






This document is the reference for the YAML syntax used for creating Semaphore secrets.

## Overview

A [secret](../using-semaphore/secrets) is a bucket that stores environment variables and files.

A secret (along with its contents) is created for the current server. Additionally, a secret is visible to all the users of an server.

## apiVersion {#apiVersion}

The `apiVersion` property defines the version of the YAML grammar that will be used in the current YAML file. Different versions might have different features.

The only possible value for this property is: `v1beta`

## kind {#kind}

The `kind` property defines the purpose of the YAML file.

Possible values are:

- `Secret`: server-level secrets
- `ProjectSecret`: for [project-level secrets](../using-semaphore/projects#project-secrets)

## metadata {#metadata}

The `metadata` property defines the metadata of the Secrets YAML file. 

It can have only one of two properties:

- [`name`](#name-in-metadata)
- [`project_id_or_name`](#project-id-or-name-in-metadata)


### name {#name-in-metadata}

The value of the `name` property, which is a string, defines the name of the secret in the `metadata` context. 

This `name` value will be used in the Pipeline YAML file for importing a specific secret.

The value of each `name` property should be unique for all secrets that exist under the same server and must only contain alphanumerical characters ([a-z], [A-Z], or [0-9]). Dashes, underscores, hyphens, and spaces are not allowed.

### project_id_or_name {#project-id-or-name-in-metadata}

This is a required field for project-level secrets. It must contain either the project name or project ID of the project the secret is scoped to.

## org_config {#org-config}

The `org_config` property holds server access policy fields, which are enabled for server on a Cloud plan or higher. 

This property can contain the following:

- [`projects_access`](#projects-access-in-org-config)
- [`projects_ids`](#projects-ids-in-org-config)
- [`debug_access`](#debug-access-in-org-config) 
- [`attach_access`](#attach-access-in-org-config)

### projects_access {#projects-access-in-org-config}

This field can be set to one of three values: 

- `ALL`: all projects in the server can use this secret in jobs
- `ALLOWED`:  the secret is available to projects in the allowed list 
- `NONE`: does not allow use of the secret by any project

### projects_ids {#projects-ids-in-org-config}

This field is a list of project IDs to be added to the allowlist to use a secret when `projects_access` is 
set to `ALLOWED`. 

If `projects_access` is set to `ALL` or `NONE` this whitelist is ignored.

### debug_access {#debug-access-in-org-config}

This field controls whether jobs containing the secret can be [started for debugging](../using-semaphore/jobs#debug-jobs).

The possible values are:

- `JOB_DEBUG_YES` 
- `JOB_DEBUG_NO`

### attach_access {#attach-access-in-org-config}

This field controls if a job containing the secret can be [attached for debugging](../using-semaphore/jobs#attach-job).

The possible values are:

- `JOB_ATTACH_YES` 
- `JOB_ATTACH_NO`

## data {#data}

The mandatory `data` property holds a single [`env_vars`](#env-vars-in-data) paris or a single [`files`](#files-in-data) property.

### env_vars {#env-vars-in-data}

The `env_vars` property is a list of key-value pairs to define environment variables that will be
inserted into a secret.

Each key-value pair is an item of an array with these properties:

- `name`: name of the environment variable. It should follow [these guidelines](http://pubs.opengroup.org/onlinepubs/000095399/basedefs/xbd_chap08.html)
- `value`: value for the environment variable


### files {#files-in-data}

The `files` property holds a list of path-content pairs used for storing files.

Each path-content pair is an item of an array with these properties:

- `path`: the path to inject the file once the secret is imported into the job
- `content`: a Base64 encoded representation of the contents of the file

## Example with variables {#example-vars}

This example defines a secret named `a-secret-name`, which contains two environment variables named `SECRET_ONE` and `SECRET_TWO`, which have the values `This is the value of SECRET_ONE` and `This is the value of SECRET_TWO`, respectively.

```yaml title="Example"
apiVersion: v1beta
kind: Secret
metadata:
  name: a-secret-name
data:
  env_vars:
    - name: SECRET_ONE
      value: "This is the value of SECRET_ONE"
    - name: SECRET_TWO
      value: "This is the value of SECRET_TWO"
```

The following example is equivalent:

```yaml title="Example"
apiVersion: v1beta
kind: Secret
metadata:
  name: a-secret-name
data:
  env_vars:
    - name: SECRET_ONE
      value: "This is the value of SECRET_ONE"
    - name: SECRET_TWO
      value: "This is the value of SECRET_TWO"
  files: []
```

## Example with files {#example-files}

The following example shows a secret with a base64 encoded file. The file is restored in the job as `file.txt`

```yaml title="Example"
apiVersion: v1beta
kind: Secret
metadata:
  name: my-secrets
data:
  env_vars:
  - name: SECRET_ONE
    value: This is a little secret
  files:
  - path: file.txt
    content: SGVsbG8gU2VtYXBob3JlIDIuMAo=
```


## Example with an empty secret {#example-empty}

If you want to create an `empty` secret, you can define the `data` block as follows:

``` yaml
apiVersion: v1beta
kind: Secret
metadata:
  name: empty-secret
data:
  env_vars: []
  files: []
```

## See also

- [Jobs YAML reference](./jobs-yaml)
- [Pipeline YAML reference](./pipeline-yaml)
- [Projects YAML reference](./project-yaml)
- [Deployment targets YAML reference](./deployment-target-yaml)
- [Agents YAML reference](./agent-yaml)
- [Notifications YAML reference](./notifications-yaml)
- [Semaphore Command Line reference](./semaphore-cli)

