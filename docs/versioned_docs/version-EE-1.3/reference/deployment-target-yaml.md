---
description: Deployment Targets YAML reference
---

# Deployment Targets YAML

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
import Available from '@site/src/components/Available';
import VideoTutorial from '@site/src/components/VideoTutorial';

This page describes the YAML syntax used to configure [deployment targets (environments)](../using-semaphore/promotions#deployment-targets).

## Overview

Deployment targets enable the enforcement of strict conditions for triggering pipeline promotions. 

You can restrict who and when a promotion can be triggered.  By integrating promotions with Deployment Targets, you can establish secure Continuous Deployment pipelines that seamlessly align with your current setup.

A deployment target is created within a project and exclusively employed for multiple promotions.

## apiVersion {#apiVersion}

Indicates the version of the syntax used.

The only supported value is: `v1alpha`

## kind {#kind}

Determines the type of resource to create.

For deployment targets, the value is: `DeploymentTarget`

## metadata {#metadata}

Defines metadata properties for the deployment target.

Contains the following values:

- [`id`](#id-in-metadata)
- [`name`](#name-in-metadata)
- [`project_id`](#project-id-in-metadata)
- [`organization_id`](#organization-id-in-metadata)
- [`created_by`](#created-by-in-metadata)
- [`created_at`](#created-at-in-metadata)
- [`updated_by`](#updated-by-in-metadata)
- [`updated_at`](#updated-at-in-metadata)
- [`description`](#description-in-metadata)
- [`url`](#url-in-metadata)

### id {#id-in-metadata}

This property is automatically generated. It is a unique identification for the deployment target.

### name {#name-in-metadata}

A descriptive name for the deployment target. 

The name should only include alphanumerical characters, dashes, underscores, and dots.

### project_id {#project-id-in-metadata}

This property identifies the project to attach this deployment target. The value must be a valid project ID.

### organization_id {#organization-id-in-metadata}

This property identifies the organization to which this deployment target belongs. The value must be a valid organization ID.

### created_by {#created-by-in-metadata}

The unique ID for the individual that created the deployment target.

### created_at {#created-at-in-metadata}

The UTC time when the deployment target was created. Automatically populated by Semaphore.

### updated_by {#updated-by-in-metadata}

The unique ID for the individual that last updated the deployment target.

### updated_at {#updated-at-in-metadata}

The UTC time when the deployment target was last updated. Automatically populated by Semaphore.

### description {#description-in-metadata}

A string to describe the deployment target.

### url {#url-in-metadata}

A URL string associated with the deployment target.

## spec {#spec}

The `spec` property contains a list of deployment target properties.

- [`state`](#state-in-spec)
- [`state_message`](#state-message-in-spec)
- [`active`](#active-in-spec)
- [`env_vars`](#env-vars-in-spec)
- [`files`](#files-in-spec)
- [`bookmark_parameter1`](#bookmark-parameter1-in-spec)
- [`bookmark_parameter2`](#bookmark-parameter2-in-spec)
- [`bookmark_parameter3`](#bookmark-parameter3-in-spec)
- [`subject_rules`](#subject-rules-in-spec)
- [`object_rules`](#object-rules-in-spec)

### state {#state-in-spec}

Indicates the state of the deployment target. The value should not be modified.

Possible values are:

- `SYNCING`
- `USABLE`
- `UNUSABLE`
- `CORDONED`

### state_message {#state-message-in-spec}

Provides a string message associated with the deployment target [`state`](#state-in-spec).

### active {#active-in-spec}

A boolean value indicates if the deployment target is active. It should not be modified.

### bookmark_parameter1 {#bookmark-parameter1-in-spec}

This property can hold values to be used as filters for the deployment history. 

For instance, if you set the parameter value to `environment` and then create a parameterized promotion with `environment: ['staging', 'production']`, you can use the filtering function in the Semaphore website to view deployment history per environment.

### bookmark_parameter2 {#bookmark-parameter2-in-spec}

This property can hold values to be used to filter the deployment history. Works just like [`bookmark_parameter1`](#bookmark-parameter1-in-spec).

### bookmark_parameter3 {#bookmark-parameter3-in-spec}

This property can hold values to be used to filter the deployment history. Works just like [`bookmark_parameter1`](#bookmark-parameter1-in-spec).

### env_vars {#env-vars-in-spec}

A list of environment variables for the deployment target.

Each item list consists of a pair of properties:

- `name`: the name of the environment variable
- `value`: the value of the variable

### files {#files-in-spec}

This property consists of a list of files to be used in the deployment target.

Each item in the list consists of these properties:

- `path`: path to the file in the job environment
- `content`: base64 encoded content of the file. If the value includes the suffix `[md5]`, this indicates that a hashed value has been received for security reasons
- `source`: represents the path on your host machine of the file you want to assign to the deployment target. It is only used when creating or updating the file property

## subject_rules {#subject-rules-in-spec}

The `subject_rules` property holds a list of subject rules that determine who
can trigger promotions when the deployment target is associated with them.

Each item in the list can contain these properties:

- [`type`](#type-in-subject-rules)
- [`subject_id](#subject-id-in-subject-rules)
- [`git_login`](#git-login-in-subject-rules)

### type {#type-in-subject-rules}

Used to define subject rules in the deployment target. The contents of this property are a list with rules to allow deployment targets to be used.

Semaphore processes the rules in the supplied order and allows the promotion when one rule is matched.

The `type` property can take the following values:

- `ANY`: all users can trigger the promotion
- `USER`: a [specific user](#subject-id-in-subject-rules) can trigger the promotion
- `ROLE`: the [role that can trigger the promotion](#subject-id-in-subject-rules). Users with this rule are allowed
- `AUTO`: allows auto-promotion conditions to trigger the promotion

### subject_id {#subject-id-in-subject-rules}

This property is used in combination with `type: USER` and `type: ROLE`. 

Allow users to add their user IDs. 

To allow roles, add their role name, e.g. `Admin` or `Contributor`.

### git_login {#git-login-in-subject-rules}

This property is used in combination with `type: USER`.

It defines the Git username in GitHub or BitBucket that can trigger the promotion.

This property can be used instead of [subject_id](#subject-id-in-subject-rules).

## object_rules {#object-rules-in-spec}

The `object_rules` property holds a list of object rules that determine when a promotion can be triggered.

Each item in the list can contain these properties:

- [`type`](#type-in-object-rules)
- [`match_mode](#match-mode-in-object-rules)
- [`pattern`](#pattern-in-object-rules)


### type {#type-in-object-rules}

Used to define object rules in the deployment target. The contents of this property are a list with rules to allow deployment targets to be used.

Semaphore processes the rules in the supplied order and allows the promotion when one rule is matched.

The `type` property can take the following values:

- `BRANCH`: evaluate Git branch names
- `TAG`: evaluate Git tag names
- `PR`: allow pull requests

### match_mode {#match-mode-in-object-rules}

Determines what type of matching is used in pattern matching the object rule. This property is used in conjunction with [`type`](#type-in-object-rules).

The possible values for this property are:

- `ALL`: do not perform pattern matching
- `EXACT`: matches string literals only
- `REGEX`: allows regular expression matches. 

:::note

The regular expressions are Perl-compatible, and you can find more information about the syntax in the [the Erlang re module documentation](https://www.erlang.org/doc/man/re.html)

:::

### pattern {#pattern-in-object-rules}

This property defines the string used to match the rule. It is only used when `match_mode: EXACT` or `match_mode: REGEX`.

The value of `pattern` is evaluated according to the `match_mode` and if a match is found the rule passes.

This property is used to define the Git branch and tag names.

:::note

When `type: PR` the `pattern` and `match_mode` are ignored. The rule passes for all pull requests

:::

## Examples {#examples}

The following example provides the definition of a deployment target as returned by [`sem get dt <deployment-target-id>`](./semaphore-cli#sem-get-dt).

```yaml title="Example"
apiVersion: v1alpha
kind: DeploymentTarget
metadata:
  id: 0d4d4184-c80a-4cbb-acdd-b75e3a03f795
  name: my-dt
  project_id: a426b4db-1919-483d-926d-06ba1320b209
  organization_id: 7304b7f9-7482-46d4-9b95-3cd5a6ef2e6f
  created_by: 02984c87-efe8-4ea1-bcac-9511a34a3df3
  updated_by: 02984c87-efe8-4ea1-bcac-9511a34a3df3
  created_at: 2023-06-09T05:46:23Z
  updated_at: 2023-06-09T07:46:49Z
  description: new description
  url: newurl321.zyx
spec:
  state: CORDONED
  state_message: ""
  subject_rules:
  - type: ROLE
    subject_id: Contributor
  - type: USER
    subject_id: 02984c87-efe8-03a2-bcac-9511a34a3df3
    git_login: example_login_24ac3
  object_rules:
  - type: BRANCH
    match_mode: EXACT
    pattern: main
  - type: TAG
    match_mode: ALL
    pattern: ""
  - type: PR
    match_mode: REGEX
    pattern: .*[feat].*
  active: false
  bookmark_parameter1: b1
  bookmark_parameter2: ""
  bookmark_parameter3: ""
  env_vars:
  - name: X
    value: ef836f1a81645fd778adb189377aed1d [md5]
  files:
  - path: /home/dev/app/my.conf
    content: 0c2606ba4ac1ee72b5cc6f91648bf28c [md5]
    source: ""

```

## See also

- [Jobs YAML reference](./jobs-yaml)
- [Pipeline YAML reference](./pipeline-yaml)
- [Projects YAML reference](./project-yaml)
- [Secret YAML reference](./secret-yaml)
- [Deployment targets YAML reference](./deployment-target-yaml)
- [Agents YAML reference](./agent-yaml)
- [Notifications YAML reference](./notifications-yaml)
- [Semaphore Command Line](./semaphore-cli)

