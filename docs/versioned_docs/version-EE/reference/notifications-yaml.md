---
description: Notifications YAML reference
---

# Notifications YAML

This page specifies the YAML syntax and rules for notifications on Semaphore.

## Overview

Use this reference in conjunction with the [Semaphore Command Line](./semaphore-cli) to manage and configure notifications on Semaphore.

Notifications can be sent only when a pipeline is finished.

## apiVersion {#apiVersion}

Defines the version of the YAML syntax for this file.

The only supported value is: `v1alpha`

## kind {#kind}

Defines the type of resource.

For notification resources use the kind: `Notification`

## metadata {#metadata}

Defines metadata about the notification.

Supports the following properties:

- [`name`](#name-in-metadata)
- [`id`](#id-in-metadata)
- [`create_time`](#create-time-in-metadata)
- [`update_time`](#update-time-in-metadata)

### name {#name-in-metadata}

A string defining the name of the notification.

### id {#id-in-metadata}

A unique identifier populated by Semaphore. It should not be modified.

### create_time {#create-time-in-metadata}

The notification creation time in UNIX epoch format. Automatically populated by Semaphore.

### update_time {#update-time-in-metadata}

The last notification update time in UNIX epoch format. Automatically populated by Semaphore.

## spec {#spec}

The `spec` property holds a list of notification [`rules`](#rules-in-spec)

## rules {#rules-in-spec}

Notifications must have at least one rule. Semaphore evaluates the rule in the order defined and triggers the notification when a match is found.

This property contains:

- [`name`](#name-in-rules)
- [`notify`](#notify-in-rules)
- [`filter`](#filter-in-rules)

## name {#name-in-rules}

A string defining the name of the rule.

## filter {#filter-in-rules}

Specifies conditions for the notification to trigger. It consists of a list of rules. For every rule that matches, Semaphore sends a notification using the  [`notify`](#notify-in-rules) properties specified for that rule.

Each item list in `filter` contains the following properties:

- [`projects`](#projects-in-filter)
- [`branches` or `tags`](#branches-in-filter)
- [`pipelines`](#pipelines-in-filter)

For a filter to match, the `projects` property must evaluate to `true`, the `pipelines` property must match when provided, and at least one of the branch or tag constraints needs to be satisfied. When both `branches` and `tags` are present, the rule passes if either a listed branch **or** a listed tag matches the event. If any property contains multiple values, at least one of those values must match.

:::note

You can use regular expressions by wrapping the filtering properties values in slashes, e.g. `/^dev.*/`

:::

### projects {#projects-in-filter}

Mandatory property. Contains a list of project names where the notification rule applies.

### branches or tags {#branches-in-filter}

Optional properties. Use the `branches` list to filter by Git branches and the `tags` list to filter by Git tags. If only one of the lists is defined, the rule requires a match in that list. If both lists are present, the rule passes when either a listed branch or a listed tag matches the event, enabling combinations such as matching the `main` branch or a `v1.0.0` tag with a single rule.

#### pipelines {#pipelines-in-filter}

Optional property. A list of pipeline filenames. If specified, the rule can only trigger events originating from one of the listed pipelines.

## notify {#notify-in-rules}

Specifies how to send the notification.

This property may contain these sub-properties:

- [`slack`](#slack-in-notify): configuration to send Slack notifications
- [`webhook`](#webhook-in-notify): configuration to send notifications to webhook-enabled services

## slack {#slack-in-notify}

Specifies how to send a notification to Slack.

Supports the following properties:

- [`endpoint`](#endpoint-in-slack)
- [`channels`](#channels-in-slack)

### endpoint {#endpoint-in-slack}

Mandatory property. Specifies the URL for the Slack Incoming WebHook.

See [Incoming WebHooks](https://slack.com/apps/A0F7XDUAZ-incoming-webhooks) for more information on configuring the URL.

:::note

It is not possible to override the channel configuration for a given webhook. Each webhook is restricted to notify the configured channels or users.

:::

### channels {#channels-in-slack}

A list of Slack channels or users. Channels begin with the hash (`#`) symbol and users with the at (`@`) symbol.

This property is optional. If not specified, the notification is sent to the default channel associated with the webhook.

## webhook {#webhook-in-notify}

Specifies how to send notifications to webhook-enabled services.

Supports the following properties:

- [`endpoint`](#endpoint-in-webhook)
- [`action`](#action-in-webhook)
- [`timeout`](#timeout-in-webhook)
- [`secret`](#secret-in-webhook)

### endpoint {#endpoint-in-webhook}

Mandatory property. Specifies the URL to contact to send the notification.

The `endpoint` property holds the URL to which Semaphore will send the notification.

### action {#action-in-webhook}

Defines the HTTP method to use for sending the notification.

This property is optional and defaults to `POST`.

### timeout {#timeout-in-webhook}

Defines the timeout for the notification request expressed in milliseconds. The value must be between 1 and 1000.

This property is optional and defaults to `500`.

### secret {#secret-in-webhook}

An optional property used to sign the notification payload. This property is the name of an organization-level [secret](../using-semaphore/secrets).

If this property is not provided, the notification payload is not signed.

## Examples {#examples}

The following example has two rules:

1. Sends a Slack notification to the `#devops` channel and to the user `#mtsukalos` on events related to the "API-docs" project
2. Sends a signed notification to a webhook-enabled service on the following conditions:
   - Project name is "website", "docs", or matches regexp "/.*api$/"
   - Branch is "master" or matches regexp "/^feature-.*/"
   - Pipeline is "semaphore.yaml" (default pipeline)

```yaml title="Example"
apiVersion: v1alpha
kind: Notification
metadata:
  name: docs
  id: 2222f08c-93f9-459b-8825-ab8be49c9d19
  create_time: "1542024088"
  update_time: "1542280192"
spec:
  rules:
  - name: Send notifications for docs project
    filter:
      projects:
      - API-docs
    notify:
      slack:
        endpoint: https://hooks.slack.com/services/XXTXXSSA/ABCDDAS/XZYZWAFDFD
        channels:
        - '#devops'
        - '@mtsoukalos'
  - name: On finished pipelines for S1, docs, or .*-api projects
    filter:
      projects:
      - website
      - /.*-api$/
      - docs
      pipelines:
      - semaphore.yml
      branches:
      - /^feature-.*/
      - master
      tags:
      - /.*-rc$/
    notify:
      webhook:
        endpoint: https://example.org/postreceiver
        secret: docs-notification-secret
```

## See Also

- [Jobs YAML reference](./jobs-yaml)
- [Pipeline YAML reference](./pipeline-yaml)
- [Projects YAML reference](./project-yaml)
- [Secret YAML reference](./secret-yaml)
- [Deployment targets YAML reference](./deployment-target-yaml)
- [Agents YAML reference](./agent-yaml)
- [Semaphore Command Line](./semaphore-cli)
