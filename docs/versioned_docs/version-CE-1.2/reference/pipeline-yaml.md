---
description: Pipeline YAML reference
---

# Pipeline YAML 

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
import Available from '@site/src/components/Available';
import VideoTutorial from '@site/src/components/VideoTutorial';
import Steps from '@site/src/components/Steps';
import FeatureNotAvailable from '@site/src/components/FeatureNotAvailable';

This page describes the formal pipeline YAML specification for Semaphore.

## Overview

Semaphore uses YAML for the definition of [pipeline](../using-semaphore/pipelines). Every Semaphore project requires at least one pipeline to work. If you don't want to write pipelines by hand, you can use the [visual workflow editor](../using-semaphore/workflows#workflow-editor).

### Execution order {#order}

You cannot assume that [`jobs`](#jobs) in the same [`task`](#task) run in any particular order. They run in parallel on a resource availability basis.

To force execution order, you must use [`block dependencies`](#dependencies-in-blocks). Semaphore only starts a `block` when all their dependencies are completed.

### Comments {#comments}

Lines beginning with `#` are considered comments and are ignored by the YAML parser.

## version {#version}

The version of the pipeline YAML specification to be used. The only value supported is `v1.0`

```yaml title="Example"
version: v1.0
```

## name {#name}

A Unicode string for the pipeline name. It is strongly recommended that you give descriptive names to your Semaphore pipelines.

```yaml title="Example"
name: The name of the Semaphore pipeline
```

## agent {#agent}

Defines the global agent's [`machine` type](#machine) and [`os_image`](#os-image) to run [`jobs`](#jobs). See [agents](../using-semaphore/pipelines#agents) to learn more.

The `agent` can contain the following properties:

- [`machine`]: VM machine type to run the jobs
- [`containers`]: optional Docker containers to run the jobs

```yaml title="Example"
# highlight-next-line
agent:
  machine:
    type: s1-kubernetes
    os_image: ''
  containers:
    - name: main
      image: 'registry.semaphoreci.com/ubuntu:22.04'
```

:::note

The default `agent` can be overridden [inside `tasks`](#agent-in-task).

:::

### machine {#machine}

Part of the [`agent`](#agent) definition. It defines the global VM machine type to run the jobs. 

It requires two properties:

- [`type`](#type)
- [`os_image`](#os-image)

```yaml title="Example"
agent:
# highlight-next-line
  machine:
    type: s1-kubernetes
    os_image: ''
  containers:
    - name: main
      image: 'registry.semaphoreci.com/ubuntu:22.04'
```


### type {#type}

Part of the [`agent`](#agent) definition. It selects the hardware or [self-hosted agent](../using-semaphore/self-hosted) type that runs the jobs.

By default, Semaphore uses the built-in `s1-kubernetes` agent which runs your jobs in a pod on the same cluster where the Semaphore server is running.

```yaml title="Example"
agent:
  machine:
# highlight-next-line
    type: s1-kubernetes
    os_image: ''
  containers:
    - name: main
      image: 'registry.semaphoreci.com/ubuntu:22.04'
```

### os_image {#os-image}

Part of the [`agent`](#agent) definition. This is an optional property to specify the Operating System image to mount on the [`machine`](#machine). The value is not used when running [Docker based environments](../using-semaphore/pipelines#docker-environments) or [Kubernetes self-hosted agents](../using-semaphore/self-hosted).

## containers {#containers}

An optional part of [`agent`](#agent). Defines an array of Docker image names to run jobs. The `container` property is required when using [Docker based environments](../using-semaphore/pipelines#docker-environments) or [Kubernetes self-hosted agents](../using-semaphore/self-hosted).

The first container in the list runs the jobs. You may optionally add more items that run as separate containers. All containers can reference each other via their names, which are mapped to hostnames using DNS records.

Each `container` entry can have:

- [`name`](#name-in-containers): the name of the container
- [`image`](#image-in-containers): the image for the container
- [`env_vars](#env-vars-in-containers): optional list of key-value pairs to define environment variables

```yaml title="Example"
agent:
  machine:
    type: s1-kubernetes
    os_image: ''
# highlight-next-line
  containers:
    - name: main
      image: 'registry.semaphoreci.com/ubuntu:22.04'
    - name: db
      image: 'registry.semaphoreci.com/postgres:9.6'
  # highlight-end
```

### name {#name-in-containers}

Defines the unique `name` of the container. The name is mapped to the container hostname and can be used to communicate with other containers.

```yaml title="Example"
agent:
  machine:
    type: e1-standard-2
  containers:
  # highlight-next-line
    - name: main
      image: 'registry.semaphoreci.com/ruby:2.6'
```

### image {#image-in-containers}

Defines the Docker image to run inside the container.

```yaml title="Example"
agent:
  machine:
    type: e1-standard-2
  containers:
    - name: main
  # highlight-next-line
      image: 'registry.semaphoreci.com/ruby:2.6'
```

### env_vars {#env-vars-in-containers}

An optional array of key-value pairs. The keys are exported as environment variables when the container starts.

You can define special variables to modify the container initialization:

- `user`: the active user inside the container
- `command`: overrides the Docker image's [CMD command](https://docs.docker.com/reference/dockerfile/#cmd)
- `entrypoint`: overrides the Docker image' [ENTRYPOINT entry](https://docs.docker.com/reference/dockerfile/#entrypoint)

You may also supply environment variables with `env_vars` and `secrets`.

```yaml title="Example"
agent:
  machine:
    type: e1-standard-2
  # highlight-start
  containers:
    - name: main
      image: 'registry.semaphoreci.com/ruby:2.6'
    - name: db
      image: 'registry.semaphoreci.com/postgres:9.6'
      user: postgres
      secrets:
        - name: mysecret
      env_vars:
        - name: POSTGRES_PASSWORD
          value: keyboard-cat
  # highlight-end
```

:::note

For `secrets`, only environment variables defined in the secret are imported. Any files in the secret are ignored.

:::

## execution_time_limit {#execution_time_limit}

Defines an optional time limit for executing the pipeline. Jobs are forcibly terminated once the time limit is reached. The default value is 1 hour.

The `execution_time_limit` property accepts one of two options:
- `hours`: time limit expressed in hours. Maximum value is 24
- `minutes`: The time limit is expressed in minutes. The maximum value is 1440

You can only either `hours` or `minutes`. Not both.

This property is also available on [`blocks`](#blocks) and [`jobs`](#jobs).

```yaml title="Example"
version: v1.0
name: Using execution_time_limit
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004

# highlight-start
execution_time_limit:
  hours: 3
# highlight-end
```

## fail_fast {#fail-fast}

This optional property defines what happens when a job fails. It accepts the following properties:

- [`stop`](#stop-in-fail)
- ['cancel'](#cancel-in-fail)

If both are set, `stop` is evaluated first. If `fail_fast` is not defined, jobs continue running following declared [`dependencies`](#dependencies-in-blocks) when a job fails.

### stop {#stop-in-fail}

The `stop` property causes all running jobs to stop as soon as one job fails. It requires a `when` property that defines a condition according to [Conditions DSL](./conditions-dsl).

In the following configuration, blocks A and B run in parallel. Block C runs after block B is finished. If Block A fails and the workflow is initiated from a non-master branch all running jobs stop immediately.

```yaml title="Example"
version: v1.0
name: Setting fail fast stop policy
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004

# highlight-start
fail_fast:
  stop:
    when: "branch != 'master'"
# highlight-end

blocks:
  - name: Block A
    dependencies: []
    task:
      jobs:
      - name: Job A
        commands:
          - sleep 10
          - failing command
  - name: Block B
    dependencies: []
    task:
      jobs:
      - name: Job B
        commands:
          - sleep 60
  - name: Block C
    dependencies: ["Block B"]
    task:
      jobs:
      - name: Job C
        commands:
          - sleep 60
```

### cancel {#cancel-in-fail}

The `cancel` property causes all non-started jobs to be canceled as soon as one job fails. Already running jobs are allowed to finish. This property requires a `when` property that defines a condition according to [Conditions DSL](./conditions-dsl).

In the following configuration, blocks A and B run in parallel. Block C runs after block B is finished.  If Block A fails in a workflow that was initiated from a non-master branch:

- Block B is allowed to finish
- Block C is canceled, i.e. it never starts

```yaml title="Example"
version: v1.0
name: Setting fail fast cancel policy
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004

# highlight-start
fail_fast:
  cancel:
    when: "branch != 'master'"
# highlight-end

blocks:
  - name: Block A
    dependencies: []
    task:
      jobs:
      - name: Job A
        commands:
          - sleep 10
          - failing command
  - name: Block B
    dependencies: []
    task:
      jobs:
      - name: Job B
        commands:
          - sleep 60
  - name: Block C
    dependencies: ["Block B"]
    task:
      jobs:
      - name: Job C
        commands:
          - sleep 60
```

## queue {#queue}

The optional `queue` property enables you to assign pipelines to custom execution queues or to configure the way the pipelines are processed when queuing happens.

There are two queueing strategies:

- **Direct assignment**: assigns all pipelines from the current pipeline file to a shared queue
- **Conditional assignment**: defines assignment rules based on conditions

See [Pipeline Queues](../using-semaphore/pipelines#pipeline-queues) for more information.

### Direct assignment {#direct-in-queue}

This option allows you to can use the `name`, `scope`, and `processing` properties as direct sub-properties of the `queue` property.  

The following rules apply:

- `name` or `processing` properties are required
- `scope` can only be set if `name` is defined
- `name` should hold the string that uniquely identifies the desired queue within the configured scope
- if you omit `name` if you only wish the `processing` property. The `name` is autogenerated from the Git commit details.
- `scope` can have one of two values: `project` or `organizations`. The default is `project`

When `scope: project` the queues with the same values for the `name` property in different projects are not queued together.

When `scope: organization` the pipelines from the queue will be queued together with pipelines from other projects within the server that have a queue configuration with the same `name` and `scope` values. 

The `processing` property can have two values:

- `serialized`: the pipelines in the queue will be queued and executed one by one in ascending order, according to creation time. This is the default
- `parallel`: all pipelines in the queue will be executed as soon as they are created and there will be no queuing.

### Conditional assignment {#conditional-in-queue}

In this option, you define an array of items with queue configurations as a sub-property of the `queue` property. Each array item can have the same properties, i.e. `name`, `scope`, and `processing`, as in [direct assignment](#direct-in-queue).

In addition, you need to supply a `when` property using the [Conditions DSL](./conditions-dsl). When the `queue` configuration is evaluated in this approach, the `when` conditions from the items in the array are evaluated one by one starting with the first item in the array.

The evaluation is stopped as soon as one of the `when` conditions is evaluated as `true`, and the rest of the properties from the same array item are used to configure the queue for the given pipeline.

This means that the order of the items in the array is important and that items should be ordered so that those with the most specific conditions are defined first, followed by those with more generalized conditions (e.g. items with conditions such as `branch = 'develop'` should be ordered before those with `branch != 'master'`).

b

## auto_cancel {#auto-cancel}

Sets a strategy for auto-canceling pipelines in a queue when a new pipeline appears. Two values are supported:

- [`running`](#running-in-auto-cancel)
- [`queued`](#queued-in-auto-cancel)

At least one of them is required. If both are set, `running` will be evaluated first.


### running {#running-in-auto-cancel}

When this property is set, queued and running pipelines are canceled as soon as a new workflow is triggered. This property requires a `when` property that defines a condition according to [Conditions DSL](./conditions-dsl).

In the following configuration, all pipelines initiated from a non-master branch will run immediately after auto-stopping everything else in front of them in the queue.

```yaml title="Example"
version: v1.0
name: Setting auto-cancel running strategy
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004

# highlight-start
auto_cancel:
  running:
    when: "branch != 'master'"
# highlight-end

blocks:
  - name: Unit tests
    task:
      jobs:
      - name: Unit tests job
        commands:
          - echo Running unit test
```

### queued {#queued-in-auto-cancel}

When this property is set, only queued are canceled as soon as a new workflow is triggered. Already-running pipelines are allowed to finish. This property requires a `when` property that defines a condition according to [Conditions DSL](./conditions-dsl).

In the following configuration, all pipelines initiated from a non-master branch will cancel any queued pipelines and wait for the one that is running to finish before starting.

```yaml title="Example"
version: v1.0
name: Setting auto-cancel queued strategy
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004
# highlight-start
auto_cancel:
  queued:
    when: "branch != 'master'"
# highlight-end
blocks:
  - name: Unit tests
    task:
      jobs:
      - name: Unit tests job
        commands:
          - echo Running unit test
```

## global_job_config {#global-job-config}

Set global properties to be applied to all jobs and blocks in the pipeline. It can contain any of these properties:

- `prologue`
- `epilogue`
- `secrets`
- `env_vars`
- `priority`

The defined configuration values have the same syntax as the ones defined on the [`task`](#task) or a [`jobs`](#jobs) level and are applied to all the tasks and jobs in a pipeline.

In the case of `prologue` and `env_vars` the global values, i.e. values from `global_job_config`, are exported first, and those defined on a task level thereafter. This allows for the overriding of global values for the specific task if the need arises.

In the case of `epilogue`, the order of exporting is reversed, so, for example, one can first perform specific cleanup commands before global ones.

`secrets` are simply merged since order plays no role here.

In the case of the `priority`, the global values are added at the end of the list of priorities, and their conditions are defined at the job level. This allows for job-specific priorities to be evaluated first, and only if none of them match will the global values be evaluated and used.

```yaml title="Example"
version: "v1.0"
name: An example of using global_job_config
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004
# highlight-start
global_job_config:
  prologue:
    commands:
      - checkout
  env_vars:
    - name: TEST_ENV_VAR
      value: test_value
# highlight-end
blocks:
  - name: Linter
    task:
      jobs:
        - name: Linter
          commands:
            - echo $TEST_ENV_VAR
  - name: Unit tests
    task:
      jobs:
        - name: Unit testing
          commands:
            - echo $TEST_ENV_VAR
  - name: Integration Tests
    task:
      jobs:
        - name: Integration testing
          commands:
            - echo $TEST_ENV_VAR
```

## blocks {#blocks}

Defines an array of items that hold the elements of a pipeline. Each element of that array is called a *block* and can have these properties:

- [`name`](#name-in-blocks)
- [`dependencies`](#dependencies-in-blocks)
- [`task`](#task) (mandatory)
- [`skip`](#skip-in-blocks)
- [`run`](#run-in-blocks)

### name {#name-in-blocks}

An optional name for the block.

### dependencies {#dependencies-in-blocks}

Defines the flow of execution between blocks. When no dependencies are set, blocks run in parallel.

The following example runs `Block A` and `Block B` in parallel at the beginning of a pipeline. `Block C` runs only after `Block A` and `Block B` have finished.

```yaml title="Example"
version: "v1.0"
name: Pipeline with dependencies
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004

blocks:
  - name: "Block A"
  # highlight-next-line
    dependencies: []
    task:
      jobs:
      - name: "Job A"
        commands:
          - echo "output"
  - name: "Block B"
  # highlight-next-line
    dependencies: []
    task:
      jobs:
      - name: "Job B"
        commands:
          - echo "output"
  - name: "Block C"
  # highlight-next-line
    dependencies: ["Block A", "Block B"]
    task:
      jobs:
      - name: "Job C"
        commands:
          - echo "output"
```

If you use the `dependencies` property in one block, you have to specify dependencies for all other blocks as well. The following pipeline **is invalid** because dependencies are missing for `Block A` and `Block B`.

```yaml title="This example is INVALID"
version: "v1.0"
name: Invalid pipeline
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004

blocks:
  - name: "Block A"
    task:
      jobs:
      - name: "Job A"
        commands:
          - echo "output"
  - name: "Block B"
    task:
      jobs:
      - name: "Job B"
        commands:
          - echo "output"
  - name: "Block C"
  # highlight-next-line
    dependencies: ["Block A", "Block B"]
    task:
      jobs:
      - name: "Job C"
        commands:
          - echo "output"
```

### skip {#skip-in-blocks}

The `skip` property is optional and it allows you to define conditions, written in [Conditions DSL](./conditions-dsl) which are based on the branch name or tag name of the current push that initiated the entire pipeline.  If a condition defined in this way is evaluated to be true, the block will be skipped.

When a block is skipped, it means that it will immediately finish with a `passed` result without actually running any of its jobs.

Its result_reason will be set to `skipped` and other blocks which depend on its passing will be started and executed as if this block executed regularly and all of its jobs passed.

Example of a block that has been skipped on all branches except master:

```yaml title="Example"
version: v1.0
name: The name of the Semaphore project
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004
blocks:
 - name: Inspect Linux environment
 # highlight-start
   skip:
     when: "branch != 'master'"
 # highlight-end
   task:
      jobs:
        - name: Print Environment variables
          commands:
            - echo $SEMAPHORE_PIPELINE_ID
            - echo $HOME
```

:::note

It is not possible to have both `skip` and [`run`](#run-in-blocks) properties defined for the same block.

:::

### run {#run-in-blocks}

The `run` property is optional and it allows you to define a condition, written in [Conditions DSL](./conditions-dsl) that is based on properties of the push which initiated the entire workflow.

If the run condition is evaluated as true, the block and all of its jobs will run, otherwise, the block will be skipped.

When a block is skipped, it means that it will immediately finish with a `passed` result and a `skipped` result_reason, without actually running any of its jobs.

Example of a block that is run only on the master branch:

```yaml title="Example"
version: v1.0
name: The name of the Semaphore project
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004
blocks:
 - name: Inspect Linux environment
 # highlight-start
   run:
     when: "branch = 'master'"
 # highlight-end
   task:
      jobs:
        - name: Print Environment variables
          commands:
            - echo $SEMAPHORE_PIPELINE_ID
            - echo $HOME
```

:::note

It is not possible to have both `skip` and [`run`](#run-in-blocks) properties defined for the same block.

:::

## task {#task}

The `task` property defines the [`jobs`](#jobs) in the blocks along with all its optional properties:

- [`agent`](#agent-in-task)
- [`prologue`](#prologue-in-task)
- [`epilogue`](#epilogue-in-task)
- [`env_vars`](#env-vars-in-task)
- [`secrets`](#secrets-in-task)

```yaml title="Example"
version: v1.0
name: The name of the Semaphore project
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004
blocks:
 - name: Inspect Linux environment
 # highlight-next-line
   task:
      jobs:
        - name: Print Environment variables
          commands:
            - echo $SEMAPHORE_PIPELINE_ID
            - echo $HOME
```

### agent {#agent-in-task}

The `agent` section under a `task` section is optional and can coexist with the global `agent` definition at the beginning of a Pipeline YAML file. The properties and the possible values of the `agent` section can be found in the [`agent` reference](#agent).

An `agent` block under a `task` block overrides the global `agent` definition.

```yaml title="Example"
version: v1.0
name: YAML file example with task and agent.
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004
blocks:
 - name: Run in Linux environment
   task:
      jobs:
        - name: Learn about SEMAPHORE_GIT_DIR
          commands:
            - echo $SEMAPHORE_GIT_DIR

 - name: Run in macOS environment
   task:
   # highlight-start
      agent:
          machine:
            type: a1-standard-4
            os_image: macos-xcode15
   # highlight-end
      jobs:
        - name: Using agent job
          commands:
            - echo $PATH
```

### env_vars {#env-vars-in-task}

The elements of an `env_vars` array are name and value pairs that hold the name of the environment variable and the value of the environment variable.

```yaml title="Example"
version: v1.0
name: A Semaphore project
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004
blocks:
   task:
      jobs:
        - name: Check environment variables
          commands:
            - echo $HOME
            - echo $PI
            - echo $VAR1
            # highlight-start
      env_vars:
           - name: PI
             value: "3.14159"
           - name: VAR1
             value: This is Var 1
            # highlight-end
```

:::note

The indentation level of the `prologue`, `epilogue`, `env_vars`, and `jobs` properties should be the same.

:::


### prologue {#prologue-in-task}

A `prologue` block in a `task` block is used when you want to execute certain commands prior to the commands of each job of a given `task`. This is usually the case with initialization commands that install software, start or stop services, etc.

```yaml title="Example"
version: v1.0
name: YAML file illustrating the prologue property
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004
blocks:
 - name: Display a file
   task:
      jobs:
        - name: Display hw.go
          commands:
            - ls -al
            - cat hw.go
            # highlight-start
      prologue:
          commands:
            - checkout
            # highlight-end
```

### epilogue {#epilogue-in-task}

An `epilogue` block should be used when you want to execute commands after a job has finished, either successfully or unsuccessfully.

Please notice that a pipeline *will not fail* if one or more commands in the `epilogue` fail to execute for some reason. Also, epilogue commands will not run if the job was stopped, canceled, or timed-out.

There are three types of epilogue commands:

- **Always executed**: defined with `always` in the epilogue section.
- **Executed when the job passes**: defined with `on_pass` in the epilogue section.
- **Executed when the job fails**: defined with `on_fail` in the epilogue sections.

The order of command execution is as follows:

- First, the `always` commands are executed.
- Then, the `on_pass` or `on_fail` commands are executed.

```yaml title="Example"
version: v1.0
name: YAML file illustrating the epilogue property
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004
blocks:
 - name: Linux version
   task:
      jobs:
        - name: Execute uname
          commands:
            - uname -a
            # highlight-start
      epilogue:
        always:
          commands:
            - echo "this command is executed for both passed and failed jobs"
        on_pass:
          commands:
            - echo "This command runs if job has passed"
        on_fail:
          commands:
            - echo "This command runs if job has failed"
            # highlight-end
```

Commands can be defined as a list directly in the YAML file, as in the above example, or via the `commands_file` property:

```yaml title="Example"
version: v1.0
name: YAML file illustrating the epilogue property
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004
blocks:
 - name: Linux version
   task:
      jobs:
        - name: Execute uname
          commands:
            - uname -a
            # highlight-start
      epilogue:
        always:
          commands_file: file_with_epilogue_always_commands.sh
        on_pass:
          commands_file: file_with_epilogue_on_pass_commands.sh
        on_fail:
          commands_file: file_with_epilogue_on_fail_commands.sh
            # highlight-end
```

Where the content of the files is a list of commands, as in the following example:

```bash
echo "hello from command file"
echo "hello from $SEMAPHORE_GIT_BRANCH/$SEMAPHORE_GIT_SHA"
```

The location of the file is relative to the pipeline file. For example, if your pipeline file is located in `.semaphore/semaphore.yml`, the `file_with_epilogue_always_commands.sh` in the above example is assumed to live in `.semaphore/file_with_epilogue_always_commands.sh`.

### secrets {#secrets-in-task}

A [secret](../using-semaphore/secrets) is a place for keeping sensitive information in the form of environment variables and small files. Sharing sensitive data in secret is both safer and more flexible than storing it using plain text files or environment variables that anyone can access. 

The `secrets` property is used for importing all the environment variables and files from an existing secret into a Semaphore server.

If one or more names of the environment variables from two or more imported secrets are the same, then the shared environment variables will have the value that was found in the secret that was imported last. The same rule applies to the files in secrets.

Additionally, if you try to use a `name` value that does not exist, the pipeline fails to execute.

#### name {#name-in-secrets}

The `name` property is compulsory in a `secrets` block because it specifies the secret that you want to import. The secret or secrets must be found within the active server.

All files in secrets are restored in the home directory of the user of the agent, usually mapped to `/home/semaphore`.

```yaml title="Example"
version: v1.0
name: Pipeline configuration with secrets
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004
blocks:
  - task:
      jobs:
        - name: Using secrets
          commands:
            - echo $USERNAME
            - echo $PASSWORD
            # highlight-start
      secrets:
        - name: mysql-secrets
            # highlight-end
```

Environment variables imported from a `secrets` property are used like regular environment variables defined in an `env_vars` block.

## jobs {#jobs}

The `jobs` items are essential for each pipeline because they allow you to define the actual commands that you want to execute.

Under `jobs` you may define the following properties:

- [`name`](#name-in-jobs)
- [`commands`](#commands-in-jobs)
- [`commands_file`](#commands-file-in-jobs)
- [`env_vars`](#env-vars-in-jobs)
- [`priority`](#priority-in-jobs)
- [`matrix`](#matrix-in-jobs)
- [`parallelism`](#parallelism-in-jobs)

### name {#name-in-jobs}

The value of the optional `name` property is a Unicode string that provides a name for a job. Semaphore assigns its own names to nameless `jobs` items, which are displayed on the Semaphore website.

It is strongly recommended that you give descriptive names to all `jobs` and `blocks` items in a Semaphore pipeline.

### commands {#commands-in-jobs}

The `commands` property is an array of strings that holds the commands that will be executed for a job.

The general structure of a job when using the `commands` property is as follows:

```yaml title="Example"
version: v1.0
name: The name of the Semaphore project
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004
blocks:
   task:
      jobs:
        - name: Check environment variables
        # highlight-start
          commands:
            - echo $SEMAPHORE_PIPELINE_ID
            - pwd
        # highlight-end
```

### commands_file {#commands-file-in-jobs}

The `commands_file` property allows you to define the path of a plain text file containing the commands of a job that is an item in a `jobs` list, `prologue` block, or `epilogue` block, instead of using a `commands` list.

You cannot use both `commands_file` and `commands` when defining a job, `prologue`, or `epilogue` item. Moreover, you cannot have a job, `prologue`, or `epilogue` properly defined if both the `commands` and `commands_file` properties are missing, i.e. you must use one (and only one).

```yaml title="Example"
version: v1.0
name: Using commands_file
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004
blocks:
 - name: Calling text file
   task:
      jobs:
        - name: Using command_file
        # highlight-next-line
          commands_file: file_with_commands.txt
      prologue:
          commands:
            - checkout
```

The contents of `file_with_commands.txt` should be valid shell commands, for instance:

```bash
echo "Command File"
echo "Exit command_file"
```

:::note

Semaphore reads the plain text file and creates an equivalent job using a `commands` block, which is what is finally executed. This means that the `commands_file` property is replaced before the job is started and the machine begins its execution.

The location of the `commands_file` file is relative to the pipeline file. For example, if your pipeline file is located in .semaphore/semaphore.yml, the file_with_commands in the above example is assumed to live in `semaphore/file_with_commands`

:::

### env_vars {#env-vars-in-jobs}

The `env_vars` property can also be defined within a [`jobs`](#jobs) block on a local scope in addition to an `env_vars` block that is defined on the `task` level, where its scope is the entire `task` block. In that case, the environment variables of the local `env_vars` block will be only visible to the `jobs` block it belongs to.

If one or more environment variables are defined on both a `jobs` level and a `task` level, the values of the environment variables that are defined on the `jobs` level take precedence over the values of the environment variables defined on the `task` level.

```yaml title="Example"
version: v1.0
name: Using env_vars per jobs
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004

blocks:
  - name: Using Local Environment variables only
    task:
      jobs:
      - name: Job that uses local env_vars
        commands:
          - echo $APP_ENV
          # highlight-start
        env_vars:
          - name: APP_ENV
            value: This is APP_ENV
          - name: VAR_2
            value: This is VAR_2 from First Job
          # highlight-end

  - name: Both local and global env_vars
    task:
      env_vars:
        - name: APP_ENV
          value: prod
        - name: VAR_1
          value: VAR_1 from outer env_vars
      jobs:
      - name: Using both global and local env_vars
        commands:
          - echo $VAR_1
          - echo $VAR_2
          - echo $APP_ENV
          # highlight-start
        env_vars:
          - name: VAR_1
            value: This is VAR_1
          - name: VAR_2
            value: This is VAR_2
          # highlight-end
      - name: Second job - no local env_vars
        commands:
          - echo $VAR_1
          - echo $APP_ENV
```

### priority {#priority-in-jobs}

The `priority` property allows you to configure a job priority that affects the order in which jobs are started when the parallel jobs quota for the server is reached.

This property holds a list of items, where each item has a `value` property that represents the numerical value for its job priority in a range from 0 to 100, and a `when` condition property written in [Conditions DSL](./conditions-dsl).

The items are evaluated from the top of the list and the value of the first item for which the `when` condition is evaluated as true will be set as a top priority for the given job.

If none of the conditions are evaluated as true, the [default job priority](../using-semaphore/jobs#priority).

```yaml title="Example"
version: v1.0
name: Job priorities
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004

blocks:
  - name: Tests
    task:
      jobs:
      - name: Unit tests
      # highlight-start
        priority:
        - value: 70
          when: "branch = 'master'"
        - value: 45
          when: true
      # highlight-end
        commands:
          - make unit-test
      - name: Integration tests
      # highlight-start
        priority:
        - value: 58
          when: "branch = 'master'"
        - value: 42
          when: true
      # highlight-end
        commands:
          - make integration-test
```

### matrix {#matrix-in-jobs}

The `matrix` property allows you to define one or more environment variable sets with multiple values. In such a setup, `n` parallel jobs are created, where `n` equals the cardinality of the Cartesian product of all environment variable sets.

So, the final outcome of the `matrix` property is the creation of multiple parallel jobs with exactly the same commands that are defined in the respective `commands` property. Each generated job is assigned with the environment variables from the corresponding element of the Cartesian product.

```yaml title="Example"
version: v1.0
name: Using the matrix property
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004

blocks:
  - name: Elixir + Erlang
    task:
        jobs:
        - name: Elixir + Erlang matrix
          commands:
            - echo $ELIXIR
            - echo $ERLANG
            # highlight-start
          matrix:
            - env_var: ELIXIR
              values: ["1.3", "1.4"]
            - env_var: ERLANG
              values: ["19", "20", "21"]
            # highlight-end
```

In this example, the job specification named `Elixir + Erlang matrix` expands to 6 parallel jobs as there are 2 x 3 = 6 combinations of the provided environment variables:

- `Elixir + Erlang matrix - ELIXIR=1.4, ERLANG=21`
- `Elixir + Erlang matrix - ELIXIR=1.4, ERLANG=20`
- `Elixir + Erlang matrix - ELIXIR=1.4, ERLANG=19`
- `Elixir + Erlang matrix - ELIXIR=1.3, ERLANG=21`
- `Elixir + Erlang matrix - ELIXIR=1.3, ERLANG=20`
- `Elixir + Erlang matrix - ELIXIR=1.3, ERLANG=19`

### parallelism {#parallelism-in-jobs}

The `parallelism` property can be used to easily generate a set of jobs with the same commands that can be parameterized. Each of those jobs will have environment variables with the total number of jobs and the index of a particular job that can be used as parameters.

The `parallelism` property expects integer values larger than `1`.

The following environment variables are added to each generated job:

- `SEMAPHORE_JOB_COUNT`: total number of jobs generated via the `parallelism` property
- `SEMAPHORE_JOB_INDEX`: value in the range from `1` to `SEMAPHORE_JOB_COUNT`, which represents the index of a particular job in the list of generated jobs.


```yaml title="Example"
version: v1.0
name: Using the parallelism property
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004

blocks:
  - name: Example for parallelism
    task:
        jobs:
        - name: Parallel job
        # highlight-next-line
          parallelism: 4
          commands:
            - echo Job $SEMAPHORE_JOB_INDEX out of $SEMAPHORE_JOB_COUNT
            - make test PARTITION=$SEMAPHORE_JOB_INDEX
```
It will automatically create 4 jobs with the following names:

- `Parallel job - 1/4`
- `Parallel job - 2/4`
- `Parallel job - 3/4`
- `Parallel job - 4/4`


:::note

It is not possible to have both `parallelism` and [`matrix`](#matrix-in-jobs) properties defined for the same job, as `parallelism` functionality is a subset of `matrix` functionality.

:::

## after_pipeline {#after_pipeline}

Defines a set of jobs to execute when the pipeline is finished. The `after_pipeline` property is most commonly used for sending notifications, collecting test results, and submitting metrics.

For example, to submit pipeline duration metrics and to publish test results, you would define the `after_pipeline` with the following YAML snippet:

```yaml title="Example"
after_pipeline:
  task:
    jobs:
      - name: Submit Metrics
        commands:
          - "export DURATION_IN_MS=$((SEMAPHORE_PIPELINE_TOTAL_DURATION * 1000))"
          - echo "ci.duration:${DURATION_IN_MS}|ms" | nc -w 3 -u statsd.example.com

      - name: Publish Tests
        commands:
          - test-results gen-pipeline-report
```

Jobs in the `after_pipeline` task are always executed regardless of the result of the pipeline. Meaning that the `after_pipeline` jobs are executed on passed, failed, stopped, and canceled pipelines.

All `SEMAPHORE_*` environment variables that are injected into regular pipeline jobs are also injected into `after_pipeline` jobs.

Additionally, Semaphore [injects environment variables](./env-vars#after-pipeline-variables) describes the state, result, and duration of the executed pipeline into `after_pipeline` jobs.

:::note

Global job config is not applied to `after_pipeline` jobs. This includes secrets, prologue, and epilogue commands that are defined in the global job configuration stanza.

:::

## Promotions {#promotions}

<FeatureNotAvailable/>

## Complete examples {#complete-examples}

This section shows complete pipelines showcasing YAML features.

<details>
<summary>Go pipeline</summary>
<div>

```yaml
version: v1.0
name: YAML file example for Go project
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004

blocks:
 - name: Inspect Linux environment
   task:
      jobs:
        - name: Execute hw.go
          commands:
            - echo $SEMAPHORE_PIPELINE_ID
            - echo $HOME
            - echo $SEMAPHORE_GIT_DIR
            - echo $PI
      prologue:
          commands:
            - checkout
      env_vars:
           - name: PI
             value: "3.14159"

 - name: Build Go project
   task:
      jobs:
        - name: Build hw.go
          commands:
            - checkout
            - change-go-version 1.10
            - go build hw.go
            - ./hw
        - name: PATH variable
          commands:
            - echo $PATH
      epilogue:
        always:
          commands:
            - echo "The job finished with $SEMAPHORE_JOB_RESULT"
        on_pass:
          commands:
            - echo "Executed when the SEMAPHORE_JOB_RESULT is passed"
        on_fail:
          commands:
            - echo "Executed when the SEMAPHORE_JOB_RESULT is failed"
```

</div>
</details>

<details>
<summary>Pipeline using secrets</summary>
<div>


``` yaml
version: v1.0
name: Pipeline configuration with secrets
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004
blocks:
  - task:
      jobs:
        - name: Using secrets
          commands:
            - checkout
            - ls -l .semaphore
            - echo $SEMAPHORE_PIPELINE_ID
            - echo $SECRET_ONE
            - echo $SECRET_TWO
        - name: Using SECRET_TWO
          commands:
            - checkout
            - echo $SECRET_TWO
            - ls -l .semaphore

      secrets:
        - name: mySecrets
        - name: more-mihalis-secrets
```

</div>
</details>

<details>
<summary>Pipeline without job/block names</summary>
<div>

``` yaml
version: v1.0
name: Basic YAML configuration file example.
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004
blocks:
  - task:
      jobs:
          - commands:
             - echo $SEMAPHORE_PIPELINE_ID
             - echo "Hello World!"
```

</div>
</details>


## See also

- [Jobs YAML reference](./jobs-yaml)
- [Projects YAML reference](./project-yaml)
- [Secret YAML reference](./secret-yaml)
- [Agents YAML reference](./agent-yaml)
- [Notifications YAML reference](./notifications-yaml)
- [Semaphore Command Line reference](./semaphore-cli)

