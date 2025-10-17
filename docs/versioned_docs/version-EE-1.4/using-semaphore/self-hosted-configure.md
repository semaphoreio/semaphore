---
description: Configure self-hosted agents
---

# Configure Agents







Self-hosted agents allow you to run Semaphore jobs. This page explains the configuration settings available and how to enable additional features.

## Overview

Self-hosted agents accept configuration settings in three ways. In order of precedence:

- **command line arguments**: used when starting the agent, e.g. `agent start --endpoint my-org.semaphoreci.com`
- **environment variables**: supplied when starting the agent. All configuration variable names are prefixed with `SEMAPHORE_AGENT`. So, for example the `--disconnect-after-job` argument is transformed into `SEMAPHORE_AGENT_DISCONNECT_AFTER_JOB`
- **configuration file**: using the `--config` option when starting the agent, e.g. `agent start --config config.yml`

See the [Self-hosted agents configuration reference](../reference/self-hosted-config) to view all available settings.

## Agent disconnection {#disconnect}

Once connected self-hosted agents periodically [send sync requests](./self-hosted#communication) to keep the connection alive. This means that the agent remains idle until a new job is available. 

There are, however, situations in which it is we may prefer to let agents disconnect, for example:

- when the agent is running [inside a Docker container](#isolation-docker) it is a advantageous delete the old container after a job and create a new one on demand
- when using [AWS agent stack](./self-hosted-aws) disconnecting idle EC2 instance lets autoscaler do its job properly

There are two configuration settings to control when an agent can disconnect:

- [`disconnect-after-job`](../reference/self-hosted-config#disconnect-after-job) (default=false): when true the agent disconnects after running a job
- [`disconnect-after-idle-timeout`](../reference/self-hosted-config#disconnect-after-idle-timeout) (default=0): the agent disconnects after being idle for the set amount of seconds. The value must be greater than 0

## Job isolation {#isolation}

Self-hosted agent jobs do not run in isolated environments. This means one job can interfere with the operation of another. To avoid this possibility, you can configure job isolation.

The details depend on how you run the jobs:

- **Containers**: configuring jobs to run in containers is the easiest and recommended way to achieve job isolation. The self-hosted agent spins up a new container for every job and destroys it once it is done.
- **Cloud instance**: this involves configuring the agent to spin up a new cloud machine for every job. This method takes longer to provision instances on demand and is thus not recommended generally.

### Isolation with Docker {#isolation-docker}

Docker is the fastest method for provisioning clean and isolated environments for every job. Creating, starting, stopping, and destroying Docker containers is a very fast operation, especially if you cache the Docker images in the machine running the agent.

There are two different ways that Docker containers can be used by an agent:

Depending on how Docker is configured, isolation can be achieved in two ways:

- **Agent inside container**: the self-hosted agent itself runs in a respawnable Docker container. The container must stop once the job is finished to give room for a new container. To do this, set the [`disconnect-after-job`](../reference/self-hosted-config#disconnect-after-job) setting to true.
- **Agent outside container**: in this scenario, the self-hosted agent runs outside a container. Isolation is achieved by configuring the pipeline to run the jobs in [Docker environments](./pipelines#docker-environments). This approach does not need any extra configuration settings.

### Isolation with cloud instances

In this scenario, a new cloud instance is spun up for every job and terminated when it's done. This is achieved by setting the [`shutdown-hook-path`](../reference/self-hosted-config#shutdown-path) and [`disconnect-after-job`](../reference/self-hosted-config#disconnect-after-job) settings in the agent.

See the [AWS self-hosted stack page](./self-hosted-aws) for how to automate this process in AWS.

:::tip

Keep in mind that using this method is slower than using Docker containers.

:::

## How to set up caching {#aws-cache}

Self-hosted agents do not provide cache storage for the [cache command](../reference/toolbox#cache) out of the box. If you want to use the cache, you need to provide an S3-compatible bucket. This section explains how to set up an external cache with AWS S3.

### Create AWS resources

First, create an S3 bucket in your region of choice. In the example, we'll call the bucket "semaphore-cache" and use the region "us-east-1". Update the values depending on your needs.

:::note

If you are using the [aws-agent-stack](./self-hosted-aws), only perform step 1. After that, the only thing remaining is to initialize `SEMAPHORE_AGENT_CACHE_BUCKET_NAME` with the name of the bucket and you're all set.

:::

To create the AWS resources, follow these steps:

<Steps>

1. Create the S3 bucket and block public access

    Execute these following commands to create the bucket.

    ```shell title="Creating an S3 bucket on AWS"
    aws s3api create-bucket \
    --region us-east-1 \
    --bucket semaphore-cache

    aws s3api put-public-access-block \
    --bucket semaphore-cache \
    --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
    ```


2. Create an IAM policy

    The self-hosted agent only needs the following permissions:

    - s3:PutObject
    - s3:GetObject
    - s3:ListBucket
    - s3:DeleteObject

    Run the following commands to set up an access policy with minimal permissions.

    ```shell title="Creating IAM access policy"
    cat > /tmp/semaphore-cache-policy.json <<EOF
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "statement1",
                "Effect": "Allow",
                "Action": [
                    "s3:PutObject",
                    "s3:GetObject",
                    "s3:ListBucket",
                    "s3:DeleteObject"
                ],
                "Resource": [
                    "arn:aws:s3:::semaphore-cache/*",
                    "arn:aws:s3:::semaphore-cache"
                ]
            }
        ]
    }
    EOF

    $ aws iam create-policy \
    --policy-name semaphore-cache-policy \
    --policy-document file:///tmp/semaphore-cache-policy.json \
    --description "Restricts access to some operations on the semaphore-cache S3 bucket"

    {
    "Policy": {
        "PolicyName": "semaphore-cache-policy",
        "CreateDate": "2015-06-01T19:31:18.620Z",
        "AttachmentCount": 0,
        "IsAttachable": true,
        "PolicyId": "ZXR6A36LTYANPAI7NJ5UV",
        "DefaultVersionId": "v1",
        "Path": "/",
        // highlight-start
        "Arn": "arn:aws:iam::0123456789012:policy/semaphore-cache-policy",
        // highlight-end
        "UpdateDate": "2015-06-01T19:31:18.620Z"
        }
    }
    ```

    Copy the value `"Arn"` value returned by `aws iam create-policy`. You will need this value in the following steps.

3. Create the AWS IAM user

    Execute the following commands to create an IAM user to access the bucket. The name of the user in this example is "semaphore"

    ```shell
    aws iam create-user --user-name semaphore
    $ aws iam create-access-key --user-name semaphore

    {
        "AccessKey": {
            "UserName": "semaphore",
            "Status": "Active",
            "CreateDate": "...",
            // highlight-start
            "SecretAccessKey": "...",
            "AccessKeyId": "..."
            // highlight-end
        }
    }
    ```

    Take note of the `"SecretAccessKey"` and `"AccessKeyId"` returned. You'll need these values later.

4. Attach the AWS IAM policy to the AWS IAM user

    Execute this command to attach the policy to the "semaphore" user. Replace `<ARN>` with the Arn value obtained in Step 1.

    ```shell
    aws iam attach-user-policy \
        --user-name semaphore \
        --policy-arn "<ARN>"
    ```

</Steps>

### Configure the agent

Now that we have the AWS resources and user ready, we can configure the agent to use the AWS credentials to access the bucket.

Follow these steps to finish the cache storage set up:


<Steps>

1. Log in to the self-hosted agent machine as the user running the agent
2. Initialize the aws folder

    Execute the following commands to initialize the `~/.aws` folder. Replace `<SecretAccessKey>` and `<AccessKeyId>` with the credentials obtained in Step 2 in the section above. Adjust the values as needed

    ```shell title="Initialize aws folder in agent"
    mkdir ~/.aws

    cat > ~/.aws/config <<EOF
    [default]
    region = us-east-1
    output = json
    EOF

    cat > ~/.aws/credentials <<EOF
    [default]
    aws_access_key_id = <SecretAccessKey>
    aws_secret_access_key = <AccessKeyId>
    EOF
    ```

3. Configure the agent

    Add the following [environment variables](../reference/self-hosted-config#env-vars) to the agent. You can achieve this by adding these lines to the agent's `config.yml`.

    ```yaml title="Adding environment variables to the agent"
    env-vars:
    - SEMAPHORE_CACHE_BACKEND=s3
    - SEMAPHORE_CACHE_S3_BUCKET=semaphore-cache
    ```

4. Restart the agent service

</Steps>

## See also

- [How to install self-hosted agents](./self-hosted-install)
- [How to run an autoscaling fleet of agents in AWS](./self-hosted-aws)
- [Self-hosted agents configuration reference](../reference/self-hosted-config)
