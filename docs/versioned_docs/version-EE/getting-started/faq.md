---
description: Frequently Asked Questions (EE)
---

# FAQ

This page contains Frequently Asked Questions.

## Architecture

### What's the difference between Semaphore Enterprise Edition (EE) and Semaphore Cloud?

- **Semaphore Cloud**: is a cloud-based, fully-managed CI-as-a-Service platform. Meant for individuals and companies that don't wish to maintain a CI/CD system. Head to semaphoreci.com to access Semaphore Cloud
- **Semaphore EE**: is a fully featured self-hostable version of Semaphore. Running Semaphore Enterprise Edition requires a [license](./license).

### Where can I run Semaphore EE?

You can run Semaphore EE on any Linux machine or Kubernetes cluster. We provide detailed [installation instructions](./install.md) for popular cloud vendors and generic systems.

### Help! My Semaphore installation is too slow

First, check that your hardware meets the minimum requisites. See the [installation page](./install) to view what are the minimum hardware requisites.

If your machines meet the minimum requisites and your Semaphore Enterprise Edition runs slowly or has timeout problems, ensure you have activated all hardware-virtualization features in your VM. Failure to activate the proper virtualization mode can result in a slow or unresponding service.

### Help! Docker fails with "toomanyrequests"

This is commonly due to a rate-limit of third-party providers such as Docker Hub. These services limit how many unauthenticated pulls you can do in an hour, often based on IP. The machine or cluster running the jobs might have already tripped the IP rate limit.

You can bypass this issue by creating a free account on Docker Hub, and then [authenticating with Docker](../using-semaphore/containers/docker#auth) within the job. This way, the [pulls are limited by your account (100 per hour)](https://docs.docker.com/docker-hub/usage/), and not by the IP of the machine.

:::tip

If you cannot authenticate, you can use other third-party Docker registries such as the [ECR Public Gallery](https://gallery.ecr.aws/).

:::

### Can I use self-signed certificates with private Docker registries?

Yes. To use a private Docker registry with a self-signed SSL certificate you must:

1. Import the self-signed certificate files as a [secret](../using-semaphore/secrets) with the filename `domain.crt`
2. Use the following command to your pipeline:

    ```shell
    sudo mv $SEMAPHORE_GIT_DIR/domain.crt /etc/docker/certs.d/myregistrydomain.com:5000/ca.crt
    ```

This will allow a connection to a private remote registry using the provided certificate.

## Git, GitHub, BitBucket, and GitLab

### I am getting the error "Error while setting deploy keys on GitHub". How do I fix it?

This can happen if your GitHub organization has deploy keys disabled.

To enable deploy keys, see the [GitHub deploy keys page](../using-semaphore/connect-github#deploy-keys).

### Can I build a project with git submodules?

Yes. To do that, follow these steps:

<Steps>

1. Append the these commands in the [prologue](../using-semaphore/jobs#prologue)

    ```shell
    git submodule init
    git submodule update
    ```

2. Append the these commands in the [epilogue](../using-semaphore/jobs#epilogue)

    ```shell
    git submodule deinit --force .
    ```

</Steps>

Make sure that Semaphore has permissions to clone your submodules repository.

### Can I redeliver webhooks from Github to Semaphore?

Yes. Rarely Semaphore does not receive a webhook from GitHub. This results in a workflow not being triggered. When this happens, you can redeliver the webhook to trigger the workflow.

These are the steps to redeliver webhooks from Github:

1. Go to your repository on GitHub
2. Click **Settings**
3. Click **Webhooks**
4. Click **Edit** for the webhook you want to redeliver
5. Scroll down to Recent Deliveries and search for the one that failed
6. Press the ... symbol, then Press **Redeliver**

### Can I send a comment on a pull request on GitHub from a workflow?

Yes. You can use the [GitHub API](https://docs.github.com/en/rest/issues?apiVersion=2022-11-28#create-an-issue-comment) to comment on pull requests.

For example:

```shell
curl -X POST -H "Authorization: token <OAUTH_TOKEN>" \
    https://api.github.com/repos/<owner>/<repo-name>/issues/<number>/comments \
    -d '{"body":"body"}'
```

## Pipelines

### Can I insert multiline commands?

Yes. You can only add multiline commands by editing the pipeline YAML file directly.

To create a multiline command begin the command with `>-`. For example:

```yaml
commands:
  - >-
    if [ "foo" = "foo" ];
    then commands...;
    else commands...;
    fi;
```

There are two other indicators you can use:

- **Block Style Indicator**: The block style indicates how new lines inside the block should behave. If you want to keep each line as a new line, use the literal style, indicated by a pipe `|`. If you want them to be replaced by spaces instead, use the folded style, indicated by a right angle bracket `>`.

- **Block Chomping Indicator**: The chomping indicator controls what should happen with new lines at the end of the string. The default, clip, puts a single newline at the end of the string. To remove all new lines, strip them by putting a minus sign `-` after the style indicator. Both clip and strip ignore how many new lines are actually at the end of the block; to keep them all put a plus sign `+` after the style indicator.

### Can I use different agents in the same pipeline?

Yes. Use the [agent override](../using-semaphore/jobs#agent-override) in a block to use a different agent.

### Can I use YAML anchors in Semaphore?

Yes. Semaphore uses [YAML version 1.2](https://yaml.org/) and it accepts all official YAML features.

The following example of uses anchors and aliases:

```yaml
version: v1.0
name: Aliases test
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004
blocks:
  - name: Block 1
    task:
      prologue: &common_prologue
        commands:
          - echo hello
      jobs:
        - name: Job 1
          commands:
            - echo hello1
  - name: Block 2
    task:
      prologue: *common_prologue
      jobs:
        - name: Job 2
          commands:
            - echo hello2
  - name: Block 3
    task:
      jobs:
        - name: Job 3
          commands:
            - echo hello3
```

### Can I change the timezone?

The default timezone is UTC. The timezone can be changed in 2 ways in Linux agents:

- Assign a different value to the TZ environment variable:

 ```shell
    export TZ=Europe/Belgrade
 ```

- Create a symlink in `/etc/localtime` to one of the available timezones:

 ```shell
    sudo ln -sf /usr/share/zoneinfo/Europe/Belgrade /etc/localtime
 ```

### What tools can I use to split a test suite for parallel jobs?

We recommend using [semaphore_test_boosters gem](https://docs.semaphoreci.com/programming-languages/ruby/#running-rspec-and-cucumber-in-parallel). This gem spreads tests across parallel jobs based on a configuration file or uniform file distribution.

Other options are also supported, e.g. [Knapsack](https://knapsackpro.com/) (both free and pro versions).

The following example splits the tests with Knapsack when [job parallelism](../using-semaphore/jobs#job-parallelism) is enabled:

```shell
CI_NODE_TOTAL=$SEMAPHORE_JOB_COUNT CI_NODE_INDEX=$((SEMAPHORE_JOB_INDEX-1)) bundle exec rake 'knapsack:rspec'
```

### Help! My job is stuck or stalled and won't end

The most common reason for stalled builds is a process that refuses to shut down properly. This is most likely a debug statement or a cleanup procedure in the catch procedure.

To debug the problem, first, attach a terminal to the stalled job with [sem attach](../reference/semaphore-cli#sem-attach)

Check the following possible causes:

- List the running processes with `ps aux` or `top`. Are there any suspicious processes running?
- Run a strace on the running process: `sudo strace -p` to see the last kernel instruction that it is waiting for. For example, `select(1, ...` can mean that the process is waiting for user input.
- Check the system metrics at `/tmp/system-metrics`. This tracks memory and disk usage. Lack of disk space or free memory can result in stalling.
- Check the Agent logs at `/tmp/agent_logs`. The logs could indicate that an agent is waiting for certain conditions.
- Check the Job logs at `/tmp/job_logs.json`. The logs could indicate that a job is waiting for certain conditions.
- Check the syslog as it can be also a valuable source of information: tail `/var/log/syslog`. It can indicate 'Out of memory' conditions.

:::tip

While an issue is ongoing, you might consider using a shorter [execution_time_limit](../using-semaphore/pipelines#time-limit) in your pipelines. This will prevent stale builds from running for a full hour.

:::

### Why is my job failing if all commands have passed?

This can happen because of code coverage tools, e.g. simplecov, which can be set to fail the test suite if a [minimum coverage level is not achieved](https://github.com/simplecov-ruby/simplecov#minimum-coverage).

### Why are tests passing locally but not on Semaphore?

The main reason for this behavior is differences in the stacks. As a first step, ensure that the same versions of languages, services, tools, and frameworks such as Selenium, browser drivers, Capybara, Cypress are used both locally and in the CI environment.

If you are using Docker containers when performing tests, it's possible that, while the command itself runs instantly, the process will not be completely started, leading to certain endpoints not being available. Using a minimum `sleep 10` can help in this scenario. Cypress has a [wait-on](https://docs.cypress.io/guides/continuous-integration/introduction.html#Boot-your-server) module that provides similar functionality.

### Why my job is not starting?

You might be hitting the quota limitation. To see your activity across the server

1. Open the server menu
2. Select Activity Monitor
3. Check your agent usage, jobs won't start until a suitable agent is free

You can also run [`sem get jobs`](../reference/semaphore-cli#sem-get-job) to display all running jobs to confirm how much of the quota is being used.

### Why does my job fail when I specify "exit 0" in commands?

Using the exit command closes the PTY and causes the job to fail. If this isn't the desired behavior, you can use the `return 130` command and manually set [`SEMAPHORE_JOB_RESULT`](../reference/env-vars#job-result) environmental variable.

To set the job as:

- **Stopped**: execute `return 130`
- **Stopped and successful**: `export SEMAPHORE_JOB_RESULT=passed; return 130`
- **Stopped and failed**: `export SEMAPHORE_JOB_RESULT=failed; return 130`

:::note

Some commands like `bash -e` or `set -x otrace` may override this behavior and make it not function correctly.

:::

## Project

### When I try to edit the workflow, I get a 500 error page (workflow editor button)?

This can happen if no [initialization machine](../using-semaphore/pipelines#init-job) is defined. To fix the error, follow these steps:

1. Open the server menu and press **Settings**
2. Select **Initialiation jobs** on the left menu
3. Unsure at least **Environment type** and **Machine type** are select
4. Press **Save changes** *even it the correct options were already selected*

:::note

Even if the correct options are selected, press **Save changes** to ensure they are applied.

:::

### Can I transfer ownership of a project?

Yes. The following conditions need to be met:

- The new project owner needs to have [Admin role](../using-semaphore/rbac) for the repository
- The new owner needs to ensure that the [GitHub connection](../using-semaphore/connect-github) or [BitBucket connection](../using-semaphore/connect-bitbucket) is working

To change the project ownership:

1. Open to the project
2. Go to **Settings**
3. In the **General** section, under **Project Owner** type the name of the new owner
4. Press **Change**

After project ownership has been transferred, you need to push a new commit. Old workflows cannot be re-run after transferring ownership.

### Can I rename a project?

Yes. To do that, follow these steps:

1. Open the project you want to rename
2. Go to **Settings**
3. Type the new name for the project
4. Press **Save Changes**

This can also be performed from the CLI by using the [sem edit](../reference/semaphore-cli#sem-edit) command.

### Can I delete a project?

Yes. To delete a project:

1. Open the project you want to rename
2. Go to **Settings**
3. At the bottom of the page, click on the link in the Delete Project section.
4. Fill in the delete reason details
5. Enter the project name for final confirmation.
6. Press the **Delete** project button.

If you prefer using CLI, you can delete a project by using the [sem delete](../reference/semaphore-cli#sem-delete) command.

:::danger

Deleting a project cannot be reversed.

:::

### Can I change the visibility of a project?

Yes. To make the project visible or private follow these steps:

1. Open the project you want to rename
2. Go to **Settings**
3. Click the link next to **Public** or **Private** to toggle the visibility
4. Press **Save Changes**

## Workflows

### How do I fix the error "Machine type and OS image for initialization job not available"

The problem is that the agent that runs the initialization job is not defined or is defined but doesn't exist. To solve the error:

1. Open your server **Settings** menu
2. Select **Initialization job**
3. Select a valid agent types
4. Press **Save**

### Can I approve blocked workflow triggers? {#sem-approve}

If you are using a [filter for contributors](../using-semaphore/workflows#project-triggers), you can still review and approve blocked pull requests by commenting with a `/sem-approve` message. Anyone who can run a forked pull request can also approve one.

Approving forked pull requests is limited to new comments only and is not possible for comment edits. Due to security concerns, `/sem-approve` will work only once. Subsequent pushes to the forked pull request must be approved again.

### How do I fix the error "Revision: COMMIT_SHA not found. Exiting"

This happens when the repository receives pushed while Semaphore is still processing the incoming webhook. For example, when someone modifies or removes with a `git rebase` or `git commit --amend` command followed by a `git push --force` shortly after.

You can prevent this error by enabling the [auto-cancel](../using-semaphore/pipelines#auto-cancel) option in the pipeline.

### Why are my workflows not running in parallel?

Git pushes to the same branch are [queued](../using-semaphore/pipelines#pipeline-queues) by default. Pushes to different branches do run in parallel. You can use [named queues in your pipelines](../using-semaphore/pipelines#named-queues) to better control how workflows are parallelized or activate [auto-cancel](../using-semaphore/pipelines#auto-cancel) to stop running pipelines when new pushes arrive to the queue.

### Why did my workflow stop without explanation?

The [auto-cancel](../using-semaphore/pipelines#auto-cancel) can stop running workflows when new pushes arrive. Check if this feature is enabled and what strategy are you using to ensure important workflows are not canceled.

### Why aren't workflows triggering on pull requests?

Check that [pull request triggers](../using-semaphore/workflows#project-triggers) are enabled for the project. If they are, check if the pull request can be merged. Since Semaphore uses the merge commit to run the workflows, merge conflicts can prevent workflows from starting.

### Why does my code contain tags that have already been deleted?

This may be due to using [`checkout --use-cache`](../reference/toolbox#checkout). When used in this fashion, code is cached and might contain stale tags.

You can solve the issue by not using the cache, i.e. using `checkout` without arguments, or by deducing the value of [`SEMAPHORE_GIT_CACHE_AGE`](../reference/env-vars#git-cache-age). For example:

```shell
# set cache age to 12 hours
export SEMAPHORE_GIT_CACHE_AGE=43200
```

### Why does my SSH debug job fail to start?

There are several possible error messages that appear when trying to initiate an SSH session. For example:

```shell
sem debug job 46490d81-2d0b-42ee-a2b0-371880dd5d9c
* Creating debug session for job '46490d81-2d0b-42ee-a2b0-371880dd5d9c'
* Setting duration to 60 minutes
error: http status 401 with message "Unauthorized" received from upstream
```

Or:

```shell
 sem debug job 46490d81-2d0b-42ee-a2b0-371880dd5d9c
* Creating debug session for job '46490d81-2d0b-42ee-a2b0-371880dd5d9c'
* Setting duration to 60 minutes
error: http status 404 with message "{"code":5, "message":"Job 46490d81-2d0b-42ee-a2b0-371880dd5d9c not found", "details":[]}" received from upstream
```

The are several causes for these messages:

- You might have a typo in the job id
- You may need to [connect the `sem` tool](../using-semaphore/jobs#debug-jobs) to your server
- You may need to use [`sem context`](../reference/semaphore-cli#sem-context) to switch to the server containing the project you want to debug

The message indicates that the SSH session cannot be initiated for the provided job id.

### Why does autocomplete does not work in my SSH session?

Enabling the `set -e` option in the Bash shell causes autocomplete to fail and end the debugging session. Check that you are not using this option in any of your scripts and try again.

### Why are my secrets empty?

We have discontinued exposing secret content via the CLI, API, and web interface to ensure enhanced security measures. Retrieval of secret values is now exclusively available through the job mechanism.
