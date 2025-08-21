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

The `promotions` property is used for *promoting* (manually or automatically triggering) one or more pipelines using one or more pipeline YAML files. A pipeline YAML file can have a single `promotions` block or no `promotions` block.

The items of a `promotions` block are called *targets* and are implemented using pairs of `name` and `pipeline_file` properties. A `promotions` block can have multiple targets.

You can promote a target from the UI at any point, even while the pipeline that owns that target is still running.

### name {#name-in-promotions}

The `name` property in a `promotions` block is a Unicode string and is compulsory. It defines the name of a target.

### pipeline_file {#pipeline-file-in-promotions}

The `pipeline_file` property of the `promotions` block is a path to another pipeline YAML file within the repository of the Semaphore project. This property is compulsory.

If `pipeline_file` is a relative path, Semaphore will search for the file inside the directory of the current pipeline. If `pipeline_file` is an absolute path (starts with the `/` character), Semaphore will seek the file starting from the root directory of the repository.

Each `pipeline_file` value must be a valid and syntactically correct pipeline YAML file as defined in this document. However, potential errors in a pipeline YAML file, given as a value to the `pipeline_file` property, will be revealed when the relevant target is promoted.

The same will happen if the file given as a `pipeline_file` value does not exist – an error will be revealed at the time of promotion.

```yaml title="Example"
version: v1.0
name: Using promotions
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004

blocks:
  - name: ls
    task:
      jobs:
      - name: List contents
        commands:
          - ls -al
          - echo $SEMAPHORE_PIPELINE_ID

# highlight-start
promotions:
  - name: Pipeline 1
  # highlight-next-line
    pipeline_file: p1.yml
  - name: Pipeline 2
  # highlight-next-line
    pipeline_file: p2.yml
# highlight-end
```

The `promotions` block in the aforementioned `.semaphore/semaphore.yml` file will allow you to promote two other YAML files named `p1.yml` and `p2.yml`.

The contents of the `.semaphore/p1.yml` are as follows:

```yaml title="Example"
version: v1.0
name: This is Pipeline 1
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004

blocks:
  - name: Environment variable
    task:
      jobs:
      - name: SEMAPHORE_PIPELINE_ID
        commands:
          - echo $SEMAPHORE_PIPELINE_ID
```

Last, the contents of the `.semaphore/p2.yml` are as follows:

```yaml title="Example"
version: v1.0
name: This is Pipeline 2
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004

blocks:
  - name: List VM Linux version
    task:
      jobs:
      - name: uname
        commands:
          - echo $SEMAPHORE_PIPELINE_ID
          - uname -a
```

### auto_promote {#auto-promote-in-promotions}

The `auto_promote` property is optional and it allows you to specify a set of conditions under which a pipeline will be promoted automatically.

It requires conditions to be defined in a `when` sub-property, following the [Conditions DSL](./conditions-dsl).

If these conditions are fulfilled for a given pipeline's execution, the appropriate promotion will be triggered automatically.

You can define conditions based on values for the following properties of the original pipeline:

- `branch`: the name of the branch for which the pipeline is initiated (empty in the case of a tag or pull request)
- `tag`: the name of the tag for which the pipeline is initiated (empty in the case of branch or pull requests)
- `pull request`: the number of pull requests for which the pipeline is initiated (empty in the case of a branch or tag)
- `change_in`: at least one file has changed in a given path (used for [monorepo workflows](../using-semaphore/monorepo). See [Conditions DSL](./conditions-dsl) for more details
- `result`: the result of a pipeline's execution (see possible values below)
- `result_reason`: the reason for a specific pipeline execution result (see possible values for each result type below)

The valid values for `result` are:

- `passed`: all the blocks in the pipeline ended successfully
- `stopped`: the pipeline was stopped either by the user or by the system
- `canceled`: the pipeline was canceled either by the user or by the system (the difference between `canceled` and `stopped` is if the result is `canceled` it means that the pipeline was terminated before any block or job started to execute)
- `failed`: the pipeline failed either due to a pipeline YAML syntax error or because at least one of the blocks of the pipeline failed due to a command not being successfully executed.

The valid values for `result_reason` are:

- `test`: one or more user tests failed
- `malformed`: the pipeline YAML file is not correct
- `stuck`: the pipeline jammed for internal reasons and then aborted
- `internal`: the pipeline was terminated for internal reasons
- `user`: the pipeline was stopped on the user request
- `strategy`: the pipeline was terminated due to an auto-cancel strategy
- `timeout`: the pipeline exceeded the execution time limit

Not all [`result`](#result-in-promotions) and [`result_reason`](#result-reason-promotions) combinations can coexist. For example, you cannot have `passed` as the value of `result` and `malformed` as the value of `result_reason`. On the other hand, you can have `failed` as the value of `result` and `malformed` as the value of `result_reason`.

For example, with a `result` value of `failed`, the valid values of `result_reason` are `test`, `malformed`, and `stuck`. When the `result` value is `stopped` or `canceled`, the list of valid values for `result_reason` are:

- `internal`
- `user`
- `strategy`
- `timeout`

The following pipeline YAML file presents two examples using `auto_promote` and depends on three other pipeline YAML files named `p1.yml`, `p2.yml`, and `p3.yml`:

```yaml title="Example"
version: v1.0
name: Testing Auto Promoting
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004

promotions:
- name: Staging
  pipeline_file: p1.yml
  # highlight-start
  auto_promote:
    when: "result = 'passed' and (branch = 'master' or tag =~ '^v1\.')"
  # highlight-end
- name: Documentation
  pipeline_file: p2.yml
  # highlight-start
  auto_promote:
    when: "branch = 'master' and change_in('/docs/')"
  # highlight-end
- name: Production
  pipeline_file: p3.yml

blocks:
  - name: Block 1
    task:
      jobs:
        - name: Job 1 - Block 1
          commands:
            - echo $SEMAPHORE_GIT_BRANCH

  - name: Block 2
    task:
      jobs:
        - name: Job 1 - Block 2
          commands:
            - echo Job 1 - Block 2
            - echo $SEMAPHORE_GIT_BRANCH
        - name: Job 2 - Block 2
          commands:
            - echo Job 2 - Block 2
```

According to the specified rules, only the `Staging` and `Documentation` promotions can be auto-promoted – when the conditions specified in the `when` sub-property of the `auto_promote` property are fulfilled. However, the `Production` promotion has no `auto_promote` property, so it can't be auto-promoted.

Therefore, if the pipeline finishes with a `passed` result and was initiated from the `master` branch, then the `p1.yml` pipeline file will be auto-promoted.

The same will happen if the pipeline is initiated from the tag with a name that matches the expression given in PCRE (*Perl Compatible Regular Expression*) syntax, which is, in this case, any string that starts with `v1.`.

`Documentation` promotion will be auto-promoted when initiated from the `master` branch, while there is at least one changed file in the `docs` folder (relative to the root of the repository). Check the [change_in reference](./conditions-dsl#change-in) for additional usage details.

The content of `p1.yml` is as follows:

```yaml title="Example"
version: v1.0
name: Pipeline 1
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004

blocks:
  - name: Environment variable
    task:
      jobs:
      - name: SEMAPHORE_PIPELINE_ID
        commands:
          - echo $SEMAPHORE_PIPELINE_ID
```

The content of `p2.yml` is as follows:

```yaml title="Example"
version: v1.0
name: Pipeline 2
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004

blocks:
  - name: Update docs
    task:
      jobs:
      - name: make docs
        commands:
          - make docs
```

Finally, the contents of `p3.yml` is as follows:

```yaml title="Example"
version: v1.0
name: This is Pipeline 3
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004

blocks:
  - name: List VM Linux version
    task:
      jobs:
      - name: uname
        commands:
          - echo $SEMAPHORE_PIPELINE_ID
          - uname -a
```

All the displayed files are correct pipeline YAML files that could be used as `semaphore.yml` files.


### result {#result-in-promotions}

The value of the `result` property is a string that is used for matching the status of a pipeline.

The list of valid values for `result`: `passed`, `stopped`, `canceled`, and `failed` is shown below.

- `passed`: all the blocks in the pipeline ended successfully
- `stopped`: the pipeline was stopped either by the user or by the system
- `canceled`: the pipeline was canceled either by the user or by the system. (the difference between `canceled` and `stopped` is that a pipeline that is not running can be canceled but cannot be stopped)
- `failed`: the pipeline failed either due to a pipeline YAML syntax error or because at least one of the blocks of the pipeline failed due to a command not being successfully executed.

### branch {#branch-in-promotions}

The `branch` property is a list of items. Its items are regular expressions that Semaphore tries to match against the name of the branch that is used with the pipeline that is being executed. If any of them is a match, then the return value of the `branch` is `true`.

The `branch` property uses Perl Compatible Regular Expressions.

In order for a `branch` value to match the `master` branch only and not match names such as `this-is-not-master` or `a-master-alternative`, you should use `^master$` as the value of the `branch` property. The same rule applies to matching words or strings.

In order for a `branch` value to match branches that begin with `dev` you should use something like `^dev`.

### result_reason {#result-reason-promotions}

The value of the `result_reason` property is a string that defines the reason behind the value of the `result` property.

The list of valid values for `result_reason` are: `test`, `malformed`, `stuck`, `deleted`, `internal`, and `user`.

- `test`: one or more user tests failed
- `malformed`: the pipeline YAML file is not correct
- `stuck`: the pipeline jammed for internal reasons and then aborted
- `deleted`: the pipeline was terminated because the branch was deleted while the pipeline was running
- `internal`: the pipeline was terminated for internal reasons
- `user`: the pipeline was stopped on the user's request

Not all `result` and `result_reason` combinations can coexist. For example, you cannot have `passed` as the value of `result` and `malformed` as the value of `result_reason`. On the other hand, you can have `failed` as the value of `result` and `malformed` as the value of `result_reason`.

For example, with a `result` value of `failed`, the valid values of `result_reason` are `test`, `malformed`, and `stuck`. When the `result` value is `stopped` or `canceled`, the list of valid values for `result_reason` are:

- `deleted`
- `internal`
- `user`

## Parameters {#parameters}

Parameters can only be used in [parameterized promotions](../using-semaphore/promotions#parameters). When a pipeline is promoted with parameters enabled, you can use the special `${{parameters}}` and `%{{parameters}}` template syntax to define values and even change the pipeline YAML at runtime.

There are two ways to use the template syntax:

- **String expansion** (starts with `$`): parameters using the `${{parameters.VAR_NAME}}` syntax are expanded at runtime. For example, if you defined a parameter called `ENVIRONMENT`, you can insert its value in the pipeline config as `${{parameters.ENVIRONMENT}}` at runtime
- **String evaluation** (start with `%`): strings using the `%{{parameters.VAR_NAME}}` syntax produce JSON-serialized output, allowing you to dynamically transform values and inject them as YAML into pipeline during runtime. This feature supports string manipulation using pipes and [Sprout functions](#parameters-functions)

The examples below show all the ways these parameters can be used.

### Using Sprout functions {#parameters-functions}

Strings using the form `%{{parameters}}` (starting with the `%` sign) produce a JSON-serialized output and support string manipulation via pipes and functions. Internally, the templates are processed using the [Sprout library]

Internally, Semaphore uses [Sprout](https://docs.atom.codes/sprout) as the templating engine and supports a subset of the [Sprout functions](https://docs.atom.codes/sprout/registries/list-of-all-registries).

For example, given `VAR1='Hello World'` the string:

```text
"%{{parameters.VAR1 | nospace }}"
```

Removes the space, generating the following output:

```text
HelloWorld
```

Likewise, given `VAR2=us-central-1,us-east-1`

```text
"%{{parameters.VAR2 | splitList \",\"}}"
```

Generates the following list:

```yaml
- us-central-1
- us-east-1
```

See [parameters job matrices](#parameter-matrix) for a complete working example using lists.

<details>
<summary>Supported Sprout functions</summary>
<div>

The following functions are supported. Refer to the [Sprout documentation](https://docs.atom.codes/sprout/registries/list-of-all-registries) to learn more about using these functions.

- default  
- empty  
- coalesce  
- all  
- any  
- compact  
- ternary  
- fromJson  
- toJson  
- toPrettyJson  
- toRawJson  
- deepCopy  
- b64enc  
- b64dec  
- b32enc  
- b32dec  
- list  
- dict  
- get  
- set  
- unset  
- chunk  
- hasKey  
- pluck  
- keys  
- pick  
- omit  
- values  
- concat  
- dig  
- merge  
- mergeOverwrite  
- append  
- prepend  
- reverse  
- first  
- rest  
- last  
- initial  
- uniq  
- without  
- has  
- slice  
- regexMatch  
- regexFindAll  
- regexFind  
- regexReplaceAll  
- regexReplaceAllLiteral  
- regexSplit  
- regexQuoteMeta  
- ellipsis  
- ellipsisBoth  
- trunc  
- trim  
- upper  
- lower  
- title  
- untitle  
- substr  
- repeat  
- join  
- sortAlpha  
- trimAll  
- trimSuffix  
- trimPrefix  
- nospace  
- initials  
- randAlphaNum  
- randAlpha  
- randAscii  
- randNumeric  
- swapcase  
- shuffle  
- snakecase  
- camelcase  
- kebabcase  
- wrap  
- wrapWith  
- contains  
- hasPrefix  
- hasSuffix  
- quote  
- squote  
- cat  
- indent  
- nindent  
- replace  
- plural  
- sha1sum  
- sha256sum  
- adler32sum  
- toString  
- int64  
- int  
- float64  
- seq  
- toDecimal  
- until  
- untilStep  
- split  
- splitList  
- splitn  
- toStrings  
- add1  
- add  
- sub  
- div  
- mod  
- mul  
- randInt  
- add1f  
- addf  
- subf  
- divf  
- mulf  
- max  
- min  
- maxf  
- minf  
- ceil  
- floor  
- round  

</div>
</details>


### Pipeline name {#parameter-pipeline-name}

The following example customizes the pipeline name given the parameters `DEPLOY_ENV` and `SERVER`. 

```yaml title="deploy.yml"
version: v1.0
# highlight-next-line
name: "Deploy to ${{parameters.DEPLOY_ENV}} on ${{parameters.SERVER}}"
```

### Job and block names {#parameter-job-name}

The following example uses parameters to set the job and block names with parameters.

```yaml title="deploy.yml"
version: v1.0
name: Deploy pipeline
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004

blocks:
# highlight-next-line
  - name: Deploy image to ${{parameters.DEPLOY_ENV}}
    task:
      jobs:
      # highlight-start
        - name: Deploy to ${{parameters.DEPLOY_ENV}} on ${{parameters.SERVER}}
          commands: ./deploy.sh $DEPLOY_ENV $SERVER
      # highlight-end
```

### Agent {#parameter-agent}

You can use parameters to dynamically define the [agent type](../using-semaphore/pipelines#agents).

```yaml title="deploy.yml"
version: v1.0
name: Deployment pipeline

agent:
  machine:
  # highlight-start
    type: "${{parameters.MACHINE_TYPE}}"
    os_image: "${{parameters.OS_IMAGE}}"
  # highlight-end
```

### Commands in jobs {#parameter-commands}

All parameters are exported as environment variables in the CI environment. You can access the value as environment variables in you shell environment.

For example, if you have parameters named `ENVIRONMENT` and `RELEASE`, you can access them like this:

```yaml title="deploy.yml"
version: v1.0
name: Deployment pipeline
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004
blocks:
    task:
      jobs:
        - name: Using promotion as env. var
          commands:
            # highlight-start
            # Use parameter values inside a job
            - echo $ENVIRONMENT
            - echo $RELEASE
            # highlight-end
```

### Secrets {#parameter-secrets}

You can dynamically import [secrets](../using-semaphore/secrets) using parameters in your pipeline YAML.

```yaml title="deploy.yml"
version: v1.0
name: Deployment pipeline
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004

blocks:
    task:
      jobs:
        - name: Deploy application
          task:
            secrets:
      # highlight-start
              - name: ${{parameters.DEPLOY_ENV}}_deploy_key
              - name: ${{parameters.DEPLOY_ENV}}_aws_creds
      # highlight-end
            jobs:
              - name: Deploy
                commands: ./deploy.sh
```


### Global config {#parameter-global}

You can use parameters in the [global config](#global-job-config) for the pipeline.

```yaml title="deploy.yml"
version: v1.0
name: Deployment pipeline
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004


global_job_config:
  secrets:
  # highlight-next-line
    - name: "${{parameters.DEPLOY_ENV}}_deploy_key"
    - name: "github_key"
```

### Queue {#parameter-queue}

The following example shows how to dynamically assign pipelines to [names queues](../using-semaphore/pipelines#named-queues) with parameters.


```yaml title="deploy.yml"
version: v1.0
name: Deployment pipeline
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004

queue:
# highlight-start
  - name: "${{parameters.DEPLOY_ENV}}_deployment_queue"
# highlight-end
```

### Job parallelism {#parameter-parallelism}

You can dynamically calculate the [parallelism of the job](../using-semaphore/jobs#job-parallelism) using [Sprout functions](#parameters-functions).

The following example configures job parallelism to the value of the `PARALLELISM` parameter multiplied by two:

```yaml title="deploy.yml"
version: v1.0
name: Deployment pipeline
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004

blocks:
  - name: Run tests
    task:
      jobs:
        - name: Run tests
          commands:
            - echo "Running tests"
            # highlight-next-line
          parallelism: "%{{parameters.PARALLELISM | mul 2}}"
```

### Job matrix {#parameter-matrix}

You can define a [job matrix](../using-semaphore/jobs#matrix) with parameters. Given `AWS_REGIONS=us-central-1,us-east1`, the following example runs the `deploy.sh` script both regions by transforming the comma-separated regions in a YAML list.


```yaml title="deploy.yml"
version: v1.0
name: Deployment pipeline
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004

blocks:
  - name: Deploy application in all regions
    task:
      jobs:
        - name: Deploy to ${{parameters.AZ}}
          commands: ./deploy.sh $AZ
          # highlight-start
          matrix:
            - env_var: AZ
              values: "%{{parameters.AWS_REGIONS | splitList \",\"}}"
          # highlight-end
```

### Complete example {#parameter-example}

The following example shows all the places and ways parameters can be used in dynamically define the pipeline YAML on runtime.

```yaml
version: v1.0
# highlight-start
# Change the pipeline name
name: "Deploy to ${{parameters.DEPLOY_ENV}} on ${{parameters.SERVER}}"
# highlight-end

agent:
  machine:
  # highlight-start
    # set the agent type and os image
    type: "${{parameters.MACHINE_TYPE}}"
    os_image: "${{parameters.OS_IMAGE}}"
  # highlight-end

global_job_config:
  secrets:
  # highlight-start
    # import the correct secret into all jobs
    - name: "${{parameters.DEPLOY_ENV}}_deploy_key"
  # highlight-end
    - name: "github_key"

queue:
# highlight-start
  # assign the pipeline to the first named queue that matches
  - name: "${{parameters.DEPLOY_ENV}}_deployment_queue"
  - name: "${{parameters.MISSING}}_queue"
# highlight-end
  - name: "default_queue"

blocks:
  - name: Run tests
    task:
      agent:
        machine:
        # highlight-start
          # override the machine type for this job
          type: "${{parameters.MACHINE_TYPE}}"
        # highlight-end
        containers: 
        # highlight-start
          # set the Docker environment container image and name
          - name: "${{parameters.DEPLOY_ENV}}_test_container"
            image: "${{parameters.DEPLOY_ENV}}_test_image"
            secrets:
              # import the secret to pull the image from a private registry
              - name: ${{parameters.DEPLOY_ENV}}_api_key
        # highlight-end
      jobs:
        - name: Run tests
          commands:
            - echo "Running tests"
            # highlight-start
          # set job parallelism to PARALLELISM * 2
          parallelism: "%{{parameters.PARALLELISM | mul 2}}"
            # highlight-end

  - name: Build and push image
    task:
      secrets:
      # highlight-start
        # dynamically import the right secrets
        - name: ${{parameters.DEPLOY_ENV}}_dockerhub
        - name: ${{parameters.DEPLOY_ENV}}_ecr
      # highlight-end

  # highlight-start
  # change the job name using the parameter DEPLOY_ENV
  - name: Deploy image to ${{parameters.DEPLOY_ENV}}
  # highlight-end
    task:
      secrets:
# highlight-start
        # dynamically import the right secrets
        - name: ${{parameters.DEPLOY_ENV}}_deploy_key
        - name: ${{parameters.DEPLOY_ENV}}_aws_creds
# highlight-end
      jobs:
      # highlight-start
        # change the job name using the parameters DEPLOY_ENV and SERVER
        - name: Deploy to ${{parameters.DEPLOY_ENV}} on ${{parameters.SERVER}}
          # run deployment script in the region
          commands: ./deploy.sh $AWS_REGION
          # create a job matrix from a comma-separated string
          matrix:
            - env_var: AWS_REGION
              values: "%{{parameters.AWS_REGIONS | splitList \",\"}}"
      # highlight-end

# send notifications to Slack channels and ping the servers once all jobs have ended
after_pipeline:
  task:
    secrets:
      - name: ${{parameters.DEPLOY_ENV}}_slack_token
    jobs:
      - name: "Notify on Slack: %{{parameters.SLACK_CHANNELS | splitList \",\"}}"
        commands:
          - echo "Notifying Slack"
        matrix:
          - env_var: SLACK_CHANNEL
            values: "%{{parameters.SLACK_CHANNELS | splitList \",\" }}"
      - name: Ping ${{parameters.DEPLOY_ENV}} from %{{parameters.PARALLELISM}} jobs
        commands:
          - echo "Pinging environment"
        parallelism: "%{{parameters.PARALLELISM | int64 }}"
```

## Deprecated properties {#deprecated}

This section shows deprecated properties.

### auto_promote_on {#auto-promote-on-in-deprecated}

:::warning

The `auto_promote_on` property has been deprecated in favor of the [`auto_promote`](#auto-promote-in-promotions) property.

:::

The `auto_promote_on` property is used for automatically promoting one or more branches of `promotions` blocks according to user-specified rules.

The `auto_promote_on` property is a list of items that supports three properties: `result`, which is mandatory; `branch`, which is optional; and `result_reason`, which is also optional.

For an `auto_promote_on` branch to execute, the return values of all the used properties of that branch must be `true`.


<details>
<summary>`auto_promote_on` example</summary>
<div>

The following pipeline YAML file shows an example use of `auto_promote_on` and depends on two other pipeline YAML files named `p1.yml` and `p2.yml`:

```yaml title="Example"
version: v1.0
name: Testing Auto Promoting
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004

promotions:
- name: Staging
  pipeline_file: p1.yml
  # highlight-start
  auto_promote_on:
    - result: passed
      branch:
        - "master"
        - ^refs/tags/v1.*
    - result: failed
      branch:
        - "v2."
      result_reason: malformed
  # highlight-end

- name: prod
  pipeline_file: p2.yml

blocks:
  - name: Block 1
    task:
      jobs:
        - name: Job 1 - Block 1
          commands:
            - echo $SEMAPHORE_GIT_BRANCH
        - name: Job 2 - Block 1
          commands:
            - echo Job 2 - Block 1

  - name: Block 2
    task:
      jobs:
        - name: Job 1 - Block 2
          commands:
            - echo Job 1 - Block 2
            - echo $SEMAPHORE_GIT_BRANCH
        - name: Job 2 - Block 2
          commands:
            - echo Job 2 - Block 2
```

According to the specified rules, only the `Staging` promotion of the `promotions` list can be auto-promoted – this depends on the rules of the two items of the `auto_promote_on` list. However, the `prod` promotion of the `promotions` list has no `auto_promote_on` property so there is no way it can be auto-promoted.

So, if the pipeline finishes with a `passed` result and the branch name contains the word `master`, then the `p1.yml` pipeline file will be auto-promoted. The same will happen if the pipeline finishes with a `failed` result. The `result_reason` is `malformed` and the branch name contains the `v2` sequence of characters followed by at least one more character because a `.` character in a Perl Compatible Regular Expression means one or more characters.

The contents of `p1.yml` are as follows:

```yaml title="Example"
version: v1.0
name: Pipeline 1
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004

blocks:
  - name: Environment variable
    task:
      jobs:
      - name: SEMAPHORE_PIPELINE_ID
        commands:
          - echo $SEMAPHORE_PIPELINE_ID
```

The contents of `p2.yml` are as follows:

```yaml title="Example"
version: v1.0
name: This is Pipeline 2
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004

blocks:
  - name: List VM Linux version
    task:
      jobs:
      - name: uname
        commands:
          - echo $SEMAPHORE_PIPELINE_ID
          - uname -a
```

Both `p1.yml` and `p2.yml` are correct pipeline YAML files that could be used as `semaphore.yml` files.

</div>
</details>

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

