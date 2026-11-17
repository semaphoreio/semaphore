---
description: Manage people, permissions, and costs
---

# Managing Semaphore

This page explains how to set up [notifications](./notifications) and what settings are available in your Semaphore instance. On Semaphore Enterprise Edition, we use the terms server, instance, and organization interchangeably.

## Overview {#overview}

In order to access any non-public resources on Semaphore you must be invited to the Semaphore instance.

If you are trying out Semaphore for the first time, we suggest the [Quickstart](../getting-started/quickstart), where we show how to get started quickly.

A Semaphore instance has:

- zero or more [projects](./projects)
- one or more owners
- users [role-based permissions](./rbac)
- a dedicated URL, for example, `https://semaphore.example.com`

## Instance settings {#org-settings}

To access your settings, open the server menu and click on **Settings**.

![Server settings location](./img/org-settings-location.jpg)

### General settings {#general-settings}

This page shows the main settings for your instance. Here, you can change its name, and control how [workflows](./workflows) run.

![General settings](./img/organization-settings-general.jpg)

:::info

The *URL of your server* is the URL that leads to the Home page in your Semaphore instance. For example `semaphore.example.com`

:::

### Notifications {#slack-notifications}

You can set up Slack and other webhook-based notifications to get your team notified whenever there [project](./projects) finishes running.

To learn more, see the [notification documentation](./notifications.md)

### Initialization agent {#init-agent}

Some types of pipelines require [initialization job](./pipelines#init-job) to evaluate and compile the them before the workload beings.

Semaphore tries to pick the best type of agent automatically but you change it for the whole server. This is particularly useful when you are using [self-hosted agents](./self-hosted).

To change the initialization job agent for all your [projects](./projects) in your Semaphore instance, follow these steps:

<Steps>

1. Select **Initialization job** from the settings menu
2. Select the **Environment type**
3. Select the **Machine type**
4. Select the **OS image** (if available)
5. Press **Save**

  ![Customizing a the initialization job agent](./img/organization-settings-initialization.jpg)

</Steps>

:::info

If you experience errors during initialization, see the [initialization job logs](./pipelines#init-logs) to help troubleshoot the issue.

:::

### Okta integration {#okta-integration}

Integration with Okta allows you to automate user management within your Semaphore server, as well as to use Okta apps for Single Sign On.

For more information, see the [Okta integration page](./okta.md)

## Audit logs {#audit-log}

<VideoTutorial title="How to view audit logs" src="https://www.youtube.com/embed/o5yXSvjcz7s"/>

To support compliance, accountability, and security, Semaphore provides logs of audited events. Audit Log events are events that affect your server, projects, users, or any other resources in Semaphore. Events contain information about when who and what was the performed activity.

You can find audit logs in your server settings under **Audit Logs**.

![Audit logs location](./img/audit-log-location.jpg)

The audit logs shows all the [audited events](../reference/audit-events) in reverse chronological order. Latest events are shown first.

![Audit log example](./img/audit-logs-example.jpg)

### How to export audit logs {#audit-export}

Audit logs can be exported in two ways:

- CSV file
- Streaming to an S3-compatible bucket

To export the logs as CSV, press the **Export as CSV** button.

![Exporting as CSV](./img/audit-export-csv.jpg)

To configure streaming to an S3-compatible bucket, press the **Configure Streaming** button and:

<Steps>

1. Select between AWS and Google Cloud
2. Type the region (AWS only)
3. Type the bucket name
4. Type the access token

    - **AWS**: provide the Access Key ID and Access Key Secret for the IAM account
    - **Google Cloud**: provide the [HMAC Key](https://cloud.google.com/storage/docs/authentication/managing-hmackeys#command-line) for a service account

    The service account credentials provided must have write and read access to the bucket

5. Press **Looks Good**

  ![Configuring Audit log streaming](./img/audit-log-streaming.jpg)

</Steps>

:::info

Audit logs are streamed to the bucket once per day.

:::

## Project queues {#queue}

You can use queues to control the order in which pipelines are executed in your instance. See [named queues](./pipelines#named-queues) for more information.

## Activity monitor {#activity-monitor}

The activity monitor show the [agent](./pipelines#agents) utilization and the currently running pipelines.

To view the activity monitor, open your server menu and select **Activity Monitor**.

![Activity monitor location](./img/activity-monitor-location.jpg)

In the activity monitor, you can see the machine quota utilization for your instance. Here, you can have an overview on how Semaphore Cloud machines and [self-hosted agents](./self-hosted) are being used.

![Activity monitor quotas](./img/activity-monitor-quotas.jpg)

In the lower part of the activity monitor you can find the currently running workflows for all the [projects](./projects) in your instance. Use this to know what [jobs](./jobs) are running, and see which ones are waiting in the queue to debug usage issues.

![Activity monitor workflows](./img/activity-monitor-workflows.jpg)

## See also

- [How to configure notifications](./notifications)
- [How to configure projects](./projects)
