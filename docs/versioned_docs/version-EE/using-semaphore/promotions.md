---
description: Connect pipelines to create workflows
---

# Promotions

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
import Available from '@site/src/components/Available';
import VideoTutorial from '@site/src/components/VideoTutorial';
import Steps from '@site/src/components/Steps';

<VideoTutorial title="How to use promotions" src="https://www.youtube.com/embed/rbf2jb3Uh-E?si=UH-_74icf4KdGYCf" />

Promotions connect [pipelines](./pipelines) to implement continuous delivery and deployment, or other types of automation, such as [blue-green](https://semaphoreci.com/blog/blue-green-deployment) deployments and [canary](https://semaphoreci.com/blog/what-is-canary-deployment) deployments. 

This page explains promotions, how to use them to connect pipelines, and what settings are available.

## Connecting pipelines {#promotions}

If your [project](./projects) contains multiple pipelines, you can use promotions to chain them. 

Using promotions, we can create a tree-like structure where pipelines branch off from other pipelines. The root of the tree is the default pipeline located at `.semaphore/semaphore.yml`.

Promoted pipelines are typically used for continuous delivery and continuous deployment. The following example shows the default pipeline branching into two continuous delivery pipelines: production and development. In each of these, we define the sequence of [jobs](./jobs) needed to deploy the application in the respective environment.

![A workflow with 3 pipelines](./img/workflows1.jpg)

## Promotion triggers {#triggers}

Triggering a promotion means starting the next pipeline in the chain. There are three ways of triggering a promotion:

- **Manual promotions**: this is the default. Start the next pipeline manually
- **Auto promotions**: automatically start a promotion based on predefined conditions
- **Parameterized promotions**: allow you to pass values as environment variables into the next pipelines, enabling pipeline reuse for different tasks
 
## How to add promotions {#create-promotions}

Promotions are defined as pointers to the next pipelines in the chain. You can create multiple promotions and nest pipelines as needed.


<Tabs groupId="editor-yaml">
<TabItem value="editor" label="Editor">

<Steps>

1. Press **+Add Promotion**
2. Set a descriptive name for the promotion
3. Configure the new pipeline and add jobs as needed

  ![Adding a manual promotion](./img/promotion-add-manual.jpg)

</Steps>

Press **Delete Promotion** to completely delete the promotion along with *all its child pipelines*.

</TabItem>
<TabItem value="yaml" label="YAML">

1. Create a new pipeline file in the `.semaphore` folder, e.g., `deploy.yml`
2. Edit the pipeline from which the new one (from step 1) branches off, e.g., `semaphore.yml`
3. Add the `promotions` key at the root level of the YAML
4. Type the `name` of the promotion
5. Type the `pipeline_file` filename of the pipeline created in step 1

```yaml title=".semaphore/semaphore.yml"
version: v1.0
name: Initial Pipeline
agent:
  machine:
    type: f1-standard-2
    os_image: ubuntu2004
blocks:
  - name: Build
    dependencies: []
    task:
      jobs:
        - name: Build
          commands:
            - checkout
            - npm run build
# highlight-start
promotions:
  - name: Promotion 1
    pipeline_file: deploy.yml
# highlight-end
```

</TabItem>
</Tabs>

### Automatic promotions {#automatic-promotions}

Automatic promotions start a pipeline based on user-defined conditions.

After [adding a promotion](#promotions), you can set automatic conditions. Whenever Semaphore detects that these conditions are met, the child pipeline automatically starts.

<Tabs groupId="editor-yaml">
<TabItem value="editor" label="Editor">

<Steps>

1. Open the promotion you want to autostart
2. Enable the checkbox **Enable automatic promotion**
3. Type in the [start conditions](../reference/conditions-dsl)

  ![Setting autostart conditions on a promotion](./img/promotion-auto.jpg)

</Steps>

</TabItem>
<TabItem value="yaml" label="YAML">

1. Open the pipeline file containing the promotion you want to autostart
2. Add an `auto_promote` key
3. Add a child `when` key. Type in the [start conditions](../reference/conditions-dsl)

```yaml title=".semaphore/semaphore.yml"
version: v1.0
name: Initial Pipeline
agent:
  machine:
    type: f1-standard-2
    os_image: ubuntu2004
blocks:
  - name: 'Block #1'
    dependencies: []
    task:
      jobs:
        - name: 'Job #1'
          commands:
            - checkout
            - make build
# highlight-start
promotions:
  - name: Promotion 1
    pipeline_file: deploy.yml
    auto_promote:
      when: branch = 'master' AND result = 'passed'
# highlight-end
```

</TabItem>
</Tabs>

### Tagged promotions {#tagged}

Many teams use Git tags to manage their release cycles. To auto-trigger a promotion with tags, you can use Perl Compatible Regular Expressions.

For example:

- `tag =~ '.*'` matches all tags. The presence of any Git tag alone is enough to match the condition
- `tag =~ '^v1\.'` matches any tag starting with "v1"

You can mix tags and other conditions to trigger promotions with a high level of control.

<Tabs groupId="editor-yaml">
<TabItem value="editor" label="Editor">

The following example shows how to trigger a deployment promotion when all tests have passed and there is a Git tag starting with "v1".

![Using tags for promotions](./img/promote-on-tag.jpg)

</TabItem>
<TabItem value="yaml" label="YAML">

The following example shows how to trigger a deployment promotion when all tests have passed and there is a Git tag starting with "v1".

```yaml
version: v1.0
name: Continuous Integration Pipeline
agent:
  machine:
    type: f1-standard-2
    os_image: ubuntu2004
blocks:
  - name: Install
    dependencies: []
    task:
      jobs:
        - name: Job
          commands:
          - checkout
          - npm install
          - npm test

promotions:
  - name: Deploy on v1 tag
    pipeline_file: deploy.yml
    # highlight-start
    auto_promote:
      when: result = 'passed' AND tag =~ '^v1\.'
    # highlight-end
```

</TabItem>
</Tabs>


## Parameterized promotions {#parameters}

Parameterized promotions allow you to propagate environment variables across all jobs in the next pipeline.

Use parameters to reduce pipeline duplication. For example, if you create a parameterized pipeline that reads the target environment from a variable, you can reuse it to deploy an application to both production and testing environments. Parameters work with both [manual](#manual-promotions) and [automatic](#automatic-promotions) promotions.

:::note

Parameterized promotions cause Semaphore to run an [initialization job](./pipelines#init-job) before the pipeline starts.

:::

### How to add parameters {#parameters-add}


<Tabs groupId="editor-yaml">
<TabItem value="editor" label="Editor">

To add parameters to a promotion with the workflow editor, follow these steps:

<Steps>

1. Select the promotion to which you want to add parameters
2. Click **+Add Environment Variable**

    ![Add parameter to promotion](./img/parameter-1.jpg)

3. Set the variable name
4. Set an optional description
5. Set optional valid options. Leave blank to input value as freeform text
6. Enable the "This is a required parameter" checkbox if the parameter is mandatory
7. Set a default value (only when the parameter is mandatory)
8. Add more parameters as needed

    ![Setting up parameters](./img/parameter-2.jpg)

</Steps>

</TabItem>
<TabItem value="yaml" label="YAML">

To add parameters to a promotion using YAML, follow these steps

1. Edit the file where you want to add the parameters
2. Add a `parameters.env_vars` key
3. Every list item is a new parameter. Set the `name` of the environment variable
4. Type an optional `description`
5. Optionally set `required` to `true|false`
6. Optionally set `options`. Each item in the list is a valid option. Leave blank to input value as freeform text
7. If `required: true`, set the `default_value`. Optional parameters don't have a default value

```yaml title=".semaphore/semaphore.yml"
# ...
promotions:
  - name: Push to Prod
    pipeline_file: deploy.yml
    parameters:
      # highlight-start
      env_vars:
        - required: true
          options:
            - Stage
            - Production
          default_value: Stage
          description: Where to Deploy?
          name: ENVIRONMENT
      # highlight-end
```

In the example above, if auto-promotion is triggered, the value for `$ENVIRONMENT` is `Stage` by default.

</TabItem>
</Tabs>

:::info

When a pipeline is triggered with [automatic promotions](#automatic-promotions) the parameter values are automatically filled following these rules:

- Mandatory parameters use the default value
- Optional parameters are left blank

:::

### Promoting with the UI {#manual-promotions}

Once you have [added a parameter](#parameters-add), you can select its value from the Semaphore UI.

<Steps>

1. Press the promotion button
2. Select or type in the value. Optional parameters can be left blank
3. Press **Start promotion**

</Steps>

<Tabs>
<TabItem value="options" label="Select value from options">

![Selecting a parameter value from options](./img/promotion-options.jpg)

</TabItem>
<TabItem value="freeform" label="Freeform type value">

![Typing the parameter value in freeform](./img/promotion-freeform.jpg)

</TabItem>
</Tabs>

### Promoting with the API {#api-promotions}

You can pass parameter values to the promotion when it's triggered using [Semaphore API](../reference/api) the to trigger promotions. If a promotion is forbidden by the environment, you will receive an `HTTP 400 Bad Request` response with a reason in the body.

<!-- new api: [Semaphore API](../openapi-spec/semaphore-public-api)  -->

The following is an example of a curl call that includes parameters:

```shell
curl -H "Authorization: Token {api_token}" \
 -d "name={promotion_name}&pipeline_id={parent_pipeline_id}&{param_1_name}={param_1_value}&{param_2_name}={param_2_value}" \
 -X POST "https://{org_name}.semaphoreci.com/api/v1alpha/promotions"
```

### Accessing values in jobs {#access-parameters-jobs}

Parameters are exported as [environment variables](./jobs#environment-variables) in all the jobs contained in the promoted pipeline.

You can access the parameter value by directly using the environment variable in your commands.

<Tabs groupId="editor-yaml">
<TabItem value="editor" label="Editor">

![Using parameters a environment variables in jobs](./img/parameters-jobs.jpg)

</TabItem>
<TabItem value="yaml" label="YAML">

The parameters are accessible as regular environment variables in the `commands` section.

```yaml title="deploy.yml"
version: v1.0
name: Deployment pipeline
agent:
  machine:
    type: f1-standard-2
    os_image: ubuntu2004
blocks:
  - name: Deploy
    task:
      jobs:
        - name: Deploy
          commands:
            # highlight-next-line
            - echo "Deploy to $ENVIRONMENT"
```

</TabItem>
</Tabs>


### Accessing values in pipelines {#access-parameters-pipeline}

You can use parameters in the pipeline YAML to dynamically define pipelines at runtime. For example, you can use parameters to change the pipeline name, compile a [job matrix](./jobs#matrix), or dynamically assign [pipeline queue](./pipelines#queue-scopes), among many other things.

Parameters can be used in two ways:


- **String expansion** (starts with `$`): parameters using the `${{parameters.VAR_NAME}}` syntax are expanded at runtime. For example, if you defined a parameter called `ENVIRONMENT`, you can insert its value in the pipeline definition as `${{parameters.ENVIRONMENT}}` at runtime
- **String evaluation** (start with `%`): strings using the `%{{parameters.VAR_NAME}}` syntax produce JSON-serialized output, allowing you to dynamically transform values and inject them as YAML into pipeline during runtime. This feature supports string manipulation using pipes and [Sprout functions](../reference/pipeline-yaml#parameters-functions)
 
See the [pipeline YAML reference](../reference/pipeline-yaml#parameters) to view all the places where parameters and what functions are supported in the pipeline YAML definition.

<Tabs groupId="editor-yaml">
<TabItem value="editor" label="Editor">

You can access some parameters in the UI with the `${{parameters.VAR_NAME}}` syntax. The following example shows how to change the pipeline name based on a parameter called `ENVIRONMENT`.

![Parameter value is expanded in the pipeline name](./img/pipeline-parameter-expansion.jpg)

</TabItem>
<TabItem value="yaml" label="YAML">

The following example shows various ways in which parameters can be using in the pipeline YAML.

```yaml title="deploy.yml"
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

</TabItem>
</Tabs>

## Deployment targets {#deployment-targets}

<VideoTutorial title="How to Use Deployment Targets" src="https://www.youtube.com/embed/xId2H2wlKx4?si=0IXKyNNUVVjDDvHz" />

Deployment targets (also known as Environments) provide additional controls over [pipelines](./pipelines). You can limit who can trigger a pipeline and under which circumstances, or define fine-grained secrets and environment variables.

### Overview {#overview-environments}

Environments allow you to tightly control [promotions](#promotions), preventing unauthorized users from starting a critical pipeline. Additionally, deployment targets can restrict branches, and pull requests, and protect [secrets](./secrets).

Environments also provide a convenient way to [view the history of your deployments](#view-history).

Configuring a deployment target is a two-step process:

1. Create a deployment target
2. Associate the target with a promotion

### How to create an environment {#create-environment}

Environments can be defined once and used in multiple promotions in a project.

To create an environment, navigate to your Semaphore project and:

<Steps>

1. Go to the **Deployment Targets** tab
2. Press **Create your first Deployment Target**

    ![Creating a deployment target](./img/deployment-target-create.jpg)

3. Fill in the deployment details:
    - Name of the deployment
    - Optional description
    - Optional URL of the deployed application
    - Optional bookmarks
4. Press **Next**

    ![Example deployment target](./img/deployment-target-1.jpg)

</Steps>

The bookmarks are useful when using [parameterized promotions](#parameters). You can add up to three bookmarks matching the names of the parameters in the promotions. Think of the bookmarks as additional filters available in the deployment history view.

### Credentials and secrets {#credentials}

Credentials are a restricted type of [secrets](./secrets) that are only accessible to authorized members of your organization.

In the second part, you can define environment variables and upload files that will be accessible to the promoted pipelines. All information will be encrypted once saved.

Credentials are optional. Go to the next step if you don't need them.

<Steps>

1. Set the environment variable name and value
2. Add more variables as needed
3. Upload a file and set where to put it in the [agent](./pipelines#agents)
4. Add more files as needed
5. Press **Next**

    <details>
    <summary>Show me</summary>
    <div>
    ![Setting up credentials for the deployment target](./img/deployment-target-2.jpg)
    </div>
    </details>

</Steps>

### Granular permissions {#granular-permissions}

In the "Who can deploy?" section, you can define the users and roles that can manually start the promotion. Granular permissions are optional. You can go to the next section if you don't need to restrict access to the promotion.

By default, everyone can start the promotion linked to this environment. To restrict access:

<Steps>

1. Select **Allow only particular users to deploy**
2. Optionally, select the roles that can deploy from the list
3. Optionally, select the members of your organization that can deploy
4. Uncheck the **Allow automatic promotions from target** option to disallow [automatic promotions](#automatic-promotions)
5. Press **Next**

    <details>
    <summary>Show me</summary>
    <div>
    ![Configuring granular access permissions for the deployment target](./img/deployment-target-3.jpg)
    </div>
    </details>

</Steps>

### Git-based permissions {#git-permissions}

In the fourth part, you can restrict which Git branches and tags are allowed to start a promotion. Here, you can also block promotions coming from pull requests. This section is optional.

To restrict Git-based access:

<Steps>

1. Select which branches are enabled for promotions: all, none, or a list of allowed branches
2. Select which Git tags are enabled: all, none, or a list of allowed tags
3. Enable or disable pull requests from triggering promotions
4. Press **Next**
5. Press **Create**

    <details>
    <summary>Show me</summary>
    <div>
    ![Setting up Git-based permissions](./img/deployment-target-4.jpg)
    </div>
    </details>

</Steps>

Once done, you can see the created environment in the **Deployments** tab.

:::tip Exact match or regular expressions?

Branches and tags can be matched in two ways:
- **Exact match**: strings must match exactly
- **Regex match**: strings are matched using Perl-compatible regular expressions. See the [Erlang re module documentation](https://www.erlang.org/doc/man/re.html) to see more details on the syntax

:::

### How to view deployment history {#view-history}

The **Deployment** tab allows you to track your previous deployments. In this tab, you can see:

- Who started the last deployment
- Which commit was used
- Which [workflow](./workflows) the deployment belongs to

You can also stop a running pipeline or rerun a promotion if you have the rights to do so.

![Deployment history](./img/deployment-history-1.jpg)

Press **View full history** to see the latest deployments in reverse chronological order.

![Deployment history details](./img/deployment-history-2.jpg)

Use **Newer** and **Older** buttons to navigate to other pages. You can also jump to a specific date.

You can also filter deployments by:
- **Type**: View branches, tags, pull requests, or everything
- **Author**: Everyone or just you
- **Origin**: Branch, tag, or pull request
- **Promotion parameters**: These are the [bookmarks](#create-environment) added to the environment target

To filter using promotion parameters, type the value of the parameter and press Enter. This feature is useful when you have [parameterized promotions](#promotions).

![Deployment history filtered by parameters](./img/deployment-history-3.jpg)

### How to target promotions {#promotion-target}

Once you have created at least one environment, you can associate it with a [promotion](#promotions). This creates a targeted promotion.

![Deployment target created](./img/deployment-target-created.jpg)

<Tabs groupId="editor-yaml">
<TabItem value="editor" label="Editor">

Press **Edit workflow** to open the visual editor and:

<Steps>

1. Select or create a promotion
2. In **Deployment target**, select the target from the dropdown list

  Select **No target** to remove the association between the deployment target and the promotion.
  ![Associating a deployment target with a promotion](./img/promotion-target.jpg)

</Steps>

</TabItem>
<TabItem value="yaml" label="YAML">

1. Edit the pipeline file with the promotion you want to target
2. Add a `deployment_target` key to the promotion. The value is the name of the environment you want to associate with this promotion

Delete `deployment_target` to remove the association between the environment and the promotion.

```yaml title=".semaphore/semaphore.yml"
# ...
promotions:
  - name: Promotion 1
    pipeline_file: pipeline_4.yml
    # highlight-next-line
    deployment_target: Production
```

</TabItem>
</Tabs>

### Promoting environments {#targeted-promotions}

Promotions with attached environments show a lock icon next to the promotion button. The icon will be unlocked if you have permission to start the promotion or locked if you don't.

<Tabs groupId="targeted-promotions">
<TabItem value="unlocked" label="Unlocked promotion">

The promotion is unlocked. Press the promotion button to start the next pipeline.
![Promotion is unlocked](./img/promotion-unlocked.jpg)

</TabItem>
<TabItem value="locked" label="Locked promotion">

The promotion is locked. The button is grayed out, and you can't start the next pipeline.
![Promotion is locked](./img/promotion-locked.jpg)

</TabItem>
</Tabs>

:::warning

Anyone with write access to the repository can edit the pipeline file and remove the environment in the promotion.

:::

### Help! I can't start a promotion {#promotion-debug}

Once a [promotion](#promotions) is targeted, you may be locked out from starting it. The most common reasons that a promotion appears as blocked are:

- You don't have the correct permissions to deploy to the bound [environment](#overview-environments)
- You are on a Git branch, tag, or pull request that isn't allowed
- You are not logged in, or you are viewing a build of a public project
- The environment is deactivated or deleted

### Promoting environments via API {#promotion-api}

You can also use the [Semaphore API](../reference/api) to trigger promotions. If a promotion is forbidden by the environment, you will receive an `HTTP 400 Bad Request` response with a reason in the body.

<!-- new api: [Public API](../openapi-spec/semaphore-public-api) -->

## See also

- [Pipeline YAML reference](../reference/pipeline-yaml)
- [Promotion conditions reference](../reference/conditions-dsl)
- [Plan job and block execution with pipelines](./pipelines)
