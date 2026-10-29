---
description: Where everything begins
---

# Workflows

A *workflow* is a series of steps to build, test, release, or deploy your application. This page explains workflows, how they are triggered, and their settings.

:::tip

If this is your first time using Semaphore, check out [Quickstart](../getting-started/quickstart).

:::

## Overview

In the context of Continuous Integration and Delivery (CI/CD) a workflow implements automation to manage the development cycle from code to deployment.

Workflows in Semaphore consist of one or more [pipelines](./pipelines). A pipeline defines the sequence of tasks to achieve goals like build, release, or deploy to production.

![Workflows in Semaphore](./img/workflows.jpg)

Before you can run a workflow in Semaphore you need:

- A Semaphore account
- A repository on GitHub or BitBucket
- A Semaphore project linked to the repository
- One or more pipelines

The [project page](./projects#view-projects) shows all the recent workflows for the project.

![Types of workflows](./img/workflow-types.jpg)

## Visual workflow editor {#workflow-editor}

<VideoTutorial title="How to use the workflow builder" src="https://www.youtube.com/embed/dg2jDQmYJ_4" />

You can define most aspects of your workflows using the visual editor.

To access the editor, open one of your projects on and press **Edit Workflow**. All your changes are stored as YAML pipeline definitions on your Git repository. You can make changes using the visual editor, or edit the YAML directly by clicking on the pipeline YAML file.

![Workflow editor button](./img/workflow-editor.jpg)

See the [jobs page](./jobs) to learn how to define jobs and blocks.

## Workflow History Retention {#workflow-retention}

Any workflows and [artifacts](./artifacts) older than this limit are automatically deleted and won't be available in the UI or via the [public API](../reference/api).

## Modeling Complex Workflows {#modeling-complex-workflows}

This section provides guides to model complex, non-linear CI/CD processes.

### Fan-out Fan-In {#fan-out-fan-in}

<VideoTutorial title="Fan Out - Fan In" src="https://www.youtube.com/embed/HKv-jMkC7T0" />

The Fan-Out Fan-In workflow provides consistency and maximum parallelization. It can be split into 3 stages:

1. **Build stage**: you build your project once
2. **Fan-Out stage**: all your tests fan out from the build stage and run in parallel
3. **Fan-In stage**: once tested, the workflow fans in to a release or deploy stage

![Fan-Out Fan-In](./img/fan-out-fan-in.jpg)

<Tabs groupId="editor-yaml">
<TabItem value="editor" label="Editor" default>

<Steps>

1. Create your build [job](./jobs). Depending on the nature of your project, you can save the built artifact to the [artifact store](./artifacts) or push it to a [Docker registry](./containers/docker)

      ![Build stage](./img/fan-out-stage1.jpg)

2. Add your test jobs. Set dependencies so all your tests depend on the build job created on Step 1

      ![Fan-out stage](./img/fan-out-stage2.jpg)

3. Add the release/deploy job. Use dependencies so the new job depends on all your tests. This will make the release/job run only if all tests have passed

      ![Fan-in stage](./img/fan-out-stage3.jpg)

</Steps>

</TabItem>
<TabItem value="yaml" label="YAML">

You can create a Fan-Out Fan-In workflow by setting the dependencies in your blocks. The Fan-Out stage is achieved by defining `dependencies`. For example:

```yaml
blocks:
  - name: "Build"
    dependencies: []
    ...

  - name: "Unit tests"
    dependencies: ["Build"]
    ...

  - name: "Integration tests"
    dependencies: ["Build"]
    ...

  - name: "E2E tests"
    dependencies: ["Build"]
    ...

  - name: "Release candidate"
    dependencies: ["Integration tests", "Unit tests", "E2E tests"]
    ...
```

Find below a complex example of a Fan-Out, Fan-In for a Node-based workflow:

```yaml
version: v1.0
name: Continuous Integration Pipeline
agent:
  machine:
    type: f1-standard-2
    os_image: ubuntu2204
blocks:
  - name: Build Stage
    dependencies: []
    task:
      jobs:
        - name: Build Project
          commands:
            - 'checkout'
            - 'npm run build'
            - 'artifact push workflow build/'
  - name: End to end tests
    dependencies:
      - Build Stage
    task:
      jobs:
        - name: Run E2E tests
          commands:
            - 'checkout'
            - 'artifact pull workflow build/'
            - 'npm run test:e2e'
  - name: Integration Tests
    dependencies:
      - Build Stage
    task:
      jobs:
        - name: Run integration tests
          commands:
            - 'checkout'
            - 'artifact pull workflow build/'
            - 'npm run test:integration'
  - name: Unit tests
    dependencies:
      - Build Stage
    task:
      jobs:
        - name: Run unit tests
          commands:
            - 'checkout'
            - 'artifact pull workflow build/'
            - 'npm run test:unit'
  - name: Release candidate
    dependencies:
      - End to end tests
      - Integration Tests
      - Unit tests
    task:
      jobs:
        - name: Generate RC
          commands:
            - 'checkout'
            - 'artifact pull workflow build/'
            - 'npm run package'
```

</TabItem>
</Tabs>

## Workflow triggers

The following events or actions trigger workflows by default:

- Pushing commits into any branch
- Pushing Git tags
- Changing any pipelines
- Manually re-running workflows
- Running pipelines using [Tasks](./tasks)

Additionally, you can configure workflows to be triggered by:

- Pull requests (not available on BitBucket projects)
- Pull request on forked repositories

The reason for the trigger can be determined at runtime by examining the Semaphore environment variables in the job. See the [environment variable reference page](../reference/env-vars#semaphore) for more details.

### How pull requests are handled {#pr}

Semaphore starts a workflow for every push to a pull request originating from a forked repository. For security reasons, secrets are disabled in jobs triggered in this way. You can [create an allow list](#project-triggers) with the secrets you want to expose in the project settings.

:::note

By default, instead of building the HEAD commit of the pull request, Semaphore uses the MERGE commit between the source and the upstream branch. On GitHub projects, you can [build the HEAD commit instead](#pr-commit). You can find the SHA of the HEAD commit of the Pull Request in the [`SEMAPHORE_GIT_PR_SHA`](../reference/env-vars#pr-sha) environment variable.

:::

### How to customize triggers {#project-triggers}

Triggers are configured in the [project settings](./projects#general). To change what actions can trigger a workflow, follow these steps:

<Steps>

1. Open your project on Semaphore
2. Go to the **Settings** tab

    ![General Settings](./img/project-settings.jpg)

3. In the **General** section scroll down to **What to build**
4. Change the settings and press **Save**

</Steps>

Selecting **Do not run on any events** disables all triggers, effectively pausing the project. You can, however, still run workflows manually or with [tasks](./tasks).

![Pausing the project](./img/pause-project.jpg)

Selecting **Run on** allows you to configure what triggers are enabled for the project.

- The **Branches** option allows you to run workflows on all branches or configure an allow list with branch names. Regular expressions are supported

- The **Tags** options work the same but for Git tags

![Branch and tag triggers](./img/project-general-settings-2.jpg)

:::note

**Whitelisted only** only affects branches and tags created *after* enabling this setting. Branches and tags that existed before the setting is enabled are not affected and are always built.

:::

- Enabling **Pull requests** option allows Semaphore to run workflows on pull requests originating in the same repository
- The **Forked pull request** works the same for pull requests originating from forked pull requests. [To prevent security leaks](#pr), you can configure a list of allowed secrets and GitHub/BitBucket/GitLab usernames that can trigger workflows in this way
- When either pull request option is enabled, **Commit to build for pull requests** selects whether pull request workflows build the merge commit or the head commit. See [commit to build for pull requests](#pr-commit)
![Pull request triggers](./img/project-general-settings-3.jpg)

### Commit to build for pull requests {#pr-commit}

On projects connected to GitHub, with the [GitHub App](./connect-github) or a [GitHub OAuth token](./connect-github-oauth), you can choose which commit pull request workflows build. Change it in the [project settings](#project-triggers) under **Commit to build for pull requests**, shown when the **Pull requests** or **Forked pull requests** option is enabled.

- **Merge commit** (default): the pull request merged into its base branch, as prepared by GitHub. Semaphore waits for GitHub to prepare the merge, so pull requests with merge conflicts are not built
- **Head commit**: the latest commit on the pull request branch. Workflows start right away without waiting for GitHub's mergeability check, and pull requests with merge conflicts are built too (GitHub still blocks merging them)

:::note

When building the head commit, the workflow doesn't test your changes combined with the base branch. Teams usually pair this option with a merge queue or with a branch protection rule that requires branches to be up to date before merging.

:::

The setting applies to every pull request workflow of the project: workflows started by pull request events from GitHub, by [`/sem-approve`](#sem-approve) on forked pull requests, and for a pull request reference through the [API](../reference/api) or the command line. Re-running a workflow builds the same commit as the original run.

You can also change it with the [`pull_request_commit`](../reference/project-yaml#pull-request-commit-in-repository) property in the project YAML or with [`sem-ai project update`](../reference/sem-ai-cli#project-update).

In both modes, pull request jobs get these environment variables:

- [`SEMAPHORE_GIT_SHA`](../reference/env-vars#commit-sha): the commit being built
- [`SEMAPHORE_GIT_PR_SHA`](../reference/env-vars#pr-sha): the head commit of the pull request
- [`SEMAPHORE_GIT_PR_BASE_SHA`](../reference/env-vars#pr-base-sha): the commit of the base branch reported with the pull request event. It can be behind the current tip of the base branch

With enough Git history in the job, for example after a [full clone](../reference/toolbox#full-clone), you can use them to list the files changed by the pull request, or merge `SEMAPHORE_GIT_PR_BASE_SHA` to test the changes combined with the base branch. For example:

```shell
git diff --name-only "$SEMAPHORE_GIT_PR_BASE_SHA...$SEMAPHORE_GIT_PR_SHA"
```

### Approving PRs with `/sem-approve` {#sem-approve}

Blocked pull requests can be manually approved by posting a new PR comment whose **entire content** is exactly `/sem-approve` (optionally followed by the options below) — nothing else in the comment. The command is deliberately ignored if the comment contains any other text, or if `/sem-approve` appears in prose, a quoted reply or blockquote, a code block (of any style), or an HTML comment. A plain `/sem-approve` can be posted by any Semaphore user with access to the project (`project.view`) whose GitHub account is connected to Semaphore. Using any option below additionally requires permission to start pipelines in the project, the same permission as rerunning or rebuilding a workflow (`project.job.rerun`). A `/sem-approve` comment from someone without the required permission is ignored.

By default, `/sem-approve` keeps forked pull request protections in place:

- secrets are filtered according to the forked PR allow list
- cache is disabled for forked pull requests

Project maintainers can allow extra `/sem-approve` options in **Project settings > General > Forked pull requests**:

- **Allow `/sem-approve --include-secrets`**: approved runs receive **all** project secrets referenced by the workflow, bypassing the forked-PR allowed-secrets list (still limited to the secrets the project is allowed to access). Use with care — it exposes those secrets to externally-authored fork code.
- **Allow `/sem-approve --enable-cache`**: enables approved runs to use cache. The fork run gets read/write access to the project cache, so treat cache entries it writes as untrusted. (`--include-cache` is accepted as an alias for `--enable-cache`.)

When these settings are enabled, an authorized approver can approve with the SHA of the fork commit they reviewed (at least the first 12 characters, or in full):

- `/sem-approve <sha> --include-secrets`
- `/sem-approve <sha> --enable-cache`
- `/sem-approve <sha> --include-secrets --enable-cache`

The SHA is required whenever an option is used. A comment with options but no SHA is not treated as an approval, nor is one whose SHA prefix matches more than one commit pushed to the pull request (use more characters or the full SHA). The run only starts if the named commit is still the head of the pull request. A plain `/sem-approve` can also be given a SHA to approve that specific commit.

If a `/sem-approve` comment requests an option that is **not available** — either an unrecognized option (a typo) or one the project has not enabled — the command is **not** treated as an approval, rather than silently approving without it. The blocked workflow is left untouched, so you can enable the option (or fix the spelling) and re-issue the command.

These options are currently available for GitHub pull request approvals.

Approving forked pull requests is limited to newly created comments: editing an existing comment does not trigger — or re-trigger — an approval. An approval is bound to the fork commit that was present when the comment was written, or to the commit named by its SHA: if the fork pushes a new commit before the run starts, the run is not executed. Review the new commit, then approve it again with its SHA. Due to security concerns, `/sem-approve` will work only once. Subsequent pushes to the forked pull request must be approved again.

## How to skip commits {#skip}

If you don't want to start a workflow, type one of the following strings in the commit message.

- `[ci skip]`
- `[skip ci]`

For example, this push does not trigger a Semaphore pipeline execution, it is completely ignored:

```shell title="Skipping a commit"
git add -A
git commit -m "[skip ci] Initial commit"
git push origin main
```

:::note notes

- Skip doesn't work when [pushing tags](./promotions#tagged)
- Be careful when squashing commits as they can contain skip messages

:::
