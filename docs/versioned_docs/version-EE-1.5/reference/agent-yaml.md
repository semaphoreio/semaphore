---
description: Agent Types YAML reference
---

# Agent Types YAML






This page explains the YAML syntax for agent types required to configure [self-hosted agent types](../using-semaphore/self-hosted).

## Overview

The YAML syntax described on this page is used to set up and configure self-hosted agents with the [Semaphore Command Line](./semaphore-cli#sem-get-agents).

## apiVersion {#apiVersion}

Indicates the version of the syntax used.

The only valid value is: `v1alpha`

## kind {#kind}

Defines the type of resource.

For self-hosted agent types the value should be: `SelfHostedAgentType`

## metadata {#metadata}

Defines metadata for the self-hosted agent type.

Contains the following properties:

- [`name`](#name-in-metadata)
- [`create_time`](#create-time-in-metadata)
- [`update_time`](#update-time-in-metadata)

### name {#name-in-metadata}

Represents the name of the type for the self-hosted agent. All self-hosted agent-type names begin with the `s1-` prefix.

The property supports alphanumerical, dashes, underscores, slash, and plus characters.

### create_time {#create-time-in-metadata}

The UTC time when the self-hosted agent type was created. Automatically populated by Semaphore.

### update_time {#update-time-in-metadata}

The UTC time when the self-hosted agent type was last updated. Automatically populated by Semaphore.

## spec {#spec}

Describes the specification for the agent type.

Contains one property: [`agent_name_settings`](#agent-name-settings-in-spec)

## agent_name_settings {#agent-name-settings-in-spec}

Describes the settings for the agent name.

Contains the following properties:

- [`assignment_origin`](#assignment-origin-in-agent-name-settings)
- [`release_after`](#release-after-in-agent-name-settings)
- [`aws`](#aws-in-agent-name-settings)


### release_after {#release-after-in-agent-name-settings}

This property defines how long the agent name is to be reserved before being released. The value is expressed in seconds.

If the value is 0 the name is reusable immediately after the agent disconnects.

Non-zero values must be greater than 60.

### assignment_origin {#assignment-origin-in-agent-name-settings}

Defines how the agent name is assigned.

Supports the following values:

- `assignment_origin_agent`: the agent can choose its own name after registration
- `assignment_origin_aws_sts`: the agent name is assigned using a pre-signed AWS STS GetCallerIdentity URL. Requires defining the [`aws`](#aws-in-agent-name-settings) property

### aws {#aws-in-agent-name-settings}

This property is used when `assignment_origin: assignment_origin_aws_sts`. It defines the AWS values required to validate pre-signed AWS STS GetCallerIdentity URLs.

It contains these properties:

- `account_id`: string containing the AWS account allowed to use pre-signed AWS STS URLs to register agents
- `role_name_patterns`: a string containing a comma-separated list of AWS IAM role names allowed to register agents. It allows wildcards using asterisks (`*`)

## Examples {#examples}

The following YAML is returned by running [`sem get agent_type s1-example`](./semaphore-cli#sem-get-agent-types-props).

```yaml title="Example"
apiVersion: v1alpha
kind: SelfHostedAgentType
metadata:
  name: s1-example
  create_time: 1701093702
  update_time: 1701096126
spec:
  agent_name_settings:
    assignment_origin: assignment_origin_aws_sts
    aws:
      account_id: 1234567890
      role_name_patterns: role1,role2
    release_after: 60
```

## See also

- [Jobs YAML reference](./jobs-yaml)
- [Pipeline YAML reference](./pipeline-yaml)
- [Projects YAML reference](./project-yaml)
- [Secret YAML reference](./secret-yaml)
- [Deployment targets YAML reference](./deployment-target-yaml)
- [Notifications YAML reference](./notifications-yaml)
- [Semaphore Command Line](./semaphore-cli)
