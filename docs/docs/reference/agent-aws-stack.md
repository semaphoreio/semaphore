---
description: AWS Autoscaler for self-hosted reference
---

# AWS Autoscaler Settings

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
import Available from '@site/src/components/Available';
import VideoTutorial from '@site/src/components/VideoTutorial';
import Steps from '@site/src/components/Steps';

<Available plans={['Startup (Hybrid)', 'Scaleup (Hybrid)']}/>

This page describes all the settings available to configure [AWS Autoscaler Stack](../using-semaphore/self-hosted-aws).

## Overview

The AWS Autoscaler Stack accepts configuration settings in two ways:

- **Configuration file**: a JSON configuration file passed when you [deploy the AWS stack](../using-semaphore/self-hosted-aws#deploy)

    For example, given this configuration file for Linux agents:

    ```json title="config.json"
    {
    "SEMAPHORE_AGENT_STACK_NAME": "<your-stack-name>",
    "SEMAPHORE_AGENT_TOKEN_PARAMETER_NAME": "<your-ssm-parameter-name>",
    "SEMAPHORE_AGENT_TOKEN_KMS_KEY": "<your-ssm-parameter-name>",
    "SEMAPHORE_ENDPOINT": "<organization-url>.semaphoreci.com"
    }
    ```

    You can deploy the stack on AWS with:

    ```shell
    SEMAPHORE_AGENT_STACK_CONFIG=config.json \
        npm run bootstrap -- aws://<YOUR_AWS_ACCOUNT_ID>/<YOUR_AWS_REGION>
    ```

- **Environment variables**: you can define the configuration using environment variables before running `npm run bootstrap`

    For example:

    ```shell
    export SEMAPHORE_AGENT_TOKEN_PARAMETER_NAME=<your-ssm-parameter-name>
    export SEMAPHORE_AGENT_TOKEN_KMS_KEY=<your-kms-key-id>
    export SEMAPHORE_AGENT_STACK_NAME=<your-stack-name>
    export SEMAPHORE_ENDPOINT=<organization-url>.semaphoreci.com 

    npm run bootstrap -- aws://<YOUR_AWS_ACCOUNT_ID>/<YOUR_AWS_REGION>
    ```

See [Autoscaling with AWS](../using-semaphore/self-hosted-aws) to learn more.

## Required parameters

### Endpoint {#endpoint}

- **Parameter name**: `SEMAPHORE_ENDPOINT`

The endpoint the agent uses for registration and sync with your Semaphore organization.

If this parameter is not set, you must configure [`SEMAPHORE_ORGANIZATION`](#organization).

### Organization {#organization}

- **Parameter name**: `SEMAPHORE_ORGANIZATION`

The name of your organization.

If [`SEMAPHORE_ENDPOINT`] is not set, this parameter is used to generate the endpoint URL. In this case, the agent assumes the endpoint is `<organization>.semaphoreci.com`.

### Agent stack name {#agent-stack-name}

- **Parameter name**: `SEMAPHORE_AGENT_STACK_NAME`

The name of the stack. This is the stack name used in Cloudformation and as a prefix to name all the stack resources. When deploying multiple stacks for multiple agent types, different stack names are required.

### Agent token {#agent-token}

- **Parameter name**: `SEMAPHORE_AGENT_TOKEN_PARAMETER_NAME`

The AWS SSM parameter name contains the Semaphore agent [registration token](../using-semaphore/self-hosted-install#register-agent).

## Optional parameters

Here's the converted markdown documentation based on the original table you provided:

### Agent stack config {#agent-stack-config}

- **Parameter name**: `SEMAPHORE_AGENT_STACK_CONFIG`

Path to a JSON file containing the parameters to use. This is an alternative to using environment variables for setting the stack's configuration parameters.

### Agent instance type {#agent-instance-type}

- **Parameter name**: `SEMAPHORE_AGENT_INSTANCE_TYPE`
- **default value**: `t2.micro`

AWS instance type used for the agents. See the available instance type on [AWS docs](https://aws.amazon.com/ec2/instance-types/).

### Auto-scaling group minimum size {#asg-min-size}

- **Parameter name**: `SEMAPHORE_AGENT_ASG_MIN_SIZE`
- **default value**: `0`

Minimum size for the auto-scaling group.

### Auto-scaling group maximum size {#asg-max-size}

- **Parameter name**: `SEMAPHORE_AGENT_ASG_MAX_SIZE`
- **default value**: `1`

Maximum size for the auto-scaling group.

### Auto-scaling group desired capacity {#asg-desired}

- **Parameter name**: `SEMAPHORE_AGENT_ASG_DESIRED`
- **default value**: `1`

Desired capacity for the auto-scaling group.

### Use dynamic scaling {#use-dynamic-scaling}

- **Parameter name**: `SEMAPHORE_AGENT_USE_DYNAMIC_SCALING`
- **default value**: `true`

If true, use a lambda to dynamically scale the number of agents in the auto-scaling group based on the job demand.

### Security group ID {#security-group-id}

- **Parameter name**: `SEMAPHORE_AGENT_SECURITY_GROUP_ID`

Security Group ID to use for agent instances. If not specified, a security group is to be created with the following:

- an egress rule allowing all outbound traffic
- an ingress rule for SSH if [`SEMAPHORE_AGENT_KEY_NAME`](#key-name) is specified

### Key name {#key-name}

- **Parameter name**: `SEMAPHORE_AGENT_KEY_NAME`

Key name to access agents through SSH. If not specified, no SSH inbound access is allowed.

### Disconnect after job {#disconnect-after-job}

- **Parameter name**: `SEMAPHORE_AGENT_DISCONNECT_AFTER_JOB`
- **default value**: `true`

If true, the agent disconnects after completing a job.

### Disconnect after idle timeout {#disconnect-after-idle-timeout}

- **Parameter name**: `SEMAPHORE_AGENT_DISCONNECT_AFTER_IDLE_TIMEOUT`
- **default value**: `300`

Number of seconds of idleness after which the agent is shut down.

Setting this to 0 disables the scaling down behavior for the stack since the agents do not shutdown due to idleness.

### Cache bucket name {#cache-bucket-name}

- **Parameter name**: `SEMAPHORE_AGENT_CACHE_BUCKET_NAME`

Existing S3 bucket name to use for caching. If this is not set, [caching](../using-semaphore/cache) does not work.

### Token KMS key {#token-kms-key}

- **Parameter name**: `SEMAPHORE_AGENT_TOKEN_KMS_KEY`

KMS key id used to encrypt and decrypt `SEMAPHORE_AGENT_TOKEN_PARAMETER_NAME`. If nothing is given, the default `alias/aws/ssm` key is assumed.

### VPC ID {#vpc-id}

- **Parameter name**: `SEMAPHORE_AGENT_VPC_ID`

The ID of an existing VPC to use when launching agent instances. By default, this is blank, and the default VPC on your AWS account is used.

### Subnets {#subnets}

- **Parameter name**: `SEMAPHORE_AGENT_SUBNETS`

Comma-separated list of existing VPC subnet IDs where EC2 instances are to run. This is required when using [`SEMAPHORE_AGENT_VPC_ID`](#vpc-id).

If `SEMAPHORE_AGENT_SUBNETS` is set and [`SEMAPHORE_AGENT_VPC_ID`](#vpc-id) is blank, the subnets are ignored, and the default VPC is used. This means that private and public subnets are possible, but isolated subnets cannot be used.

### AMI {#ami}

- **Parameter name**: `SEMAPHORE_AGENT_AMI`

The AMI is used for all instances. If empty, the stack uses the default AMIs, looking them up by name. If the default AMI isn't sufficient, you can use your own AMIs, but they need to be based on the stack's default AMI.

### OS type {#os-type}

- **Parameter name**: `SEMAPHORE_AGENT_OS`

The OS type for agents.

Possible values:

- `ubuntu-focal`
- `windows`

### Architecture type {#architecture-type}

- **Parameter name**: `SEMAPHORE_AGENT_ARCH`

The arch type for agents. Possible values:

- `x86_64`
- `arm64`

### Availability zones {#availability-zones}

- **Parameter name**: `SEMAPHORE_AGENT_AZS`

A comma-separated list of availability zones to use for the auto-scaling group.

### Managed policy names {#managed-policy-names}

- **Parameter name**: `SEMAPHORE_AGENT_MANAGED_POLICY_NAMES`

A comma-separated list of custom IAM policy names to attach to the instance profile role.

### ASG metrics {#asg-metrics}

- **Parameter name**: `SEMAPHORE_AGENT_ASG_METRICS`

A comma-separated list of ASG metrics to collect. Available metrics can be found on the [AWS CDK Documentation](https://docs.aws.amazon.com/cdk/api/v2/docs/aws-cdk-lib.aws_autoscaling.CfnAutoScalingGroup.MetricsCollectionProperty.html).

### Volume name {#volume-name}

- **Parameter name**: `SEMAPHORE_AGENT_VOLUME_NAME`

The EBS volume's device name to use for a custom volume. If this is not set, the EC2 instances are assigned the EBS volume based on the AMI.

### Volume type {#volume-type}

- **Parameter name**: `SEMAPHORE_AGENT_VOLUME_TYPE`
- **default value**: `gp2`

The EBS volume's type, when using [`SEMAPHORE_AGENT_VOLUME_NAME`](#volume-name).

### Volume size {#volume-size}

- **Parameter name**: `SEMAPHORE_AGENT_VOLUME_SIZE`
- **default value**: `64`

The EBS volume's size, in GB, when using [`SEMAPHORE_AGENT_VOLUME_NAME`](#volume-name).

### License configuration ARN {#license-configuration-arn}

- **Parameter name**: `SEMAPHORE_AGENT_LICENSE_CONFIGURATION_ARN`

The license configuration ARN is associated with the AMI used by the stack.

### Mac family {#mac-family}

- **Parameter name**: `SEMAPHORE_AGENT_MAC_FAMILY`

The EC2 Mac instance family to use. Possible values: `mac1` and `mac2`.

### Mac dedicated hosts {#mac-dedicated-hosts}

- **Parameter name**: `SEMAPHORE_AGENT_MAC_DEDICATED_HOSTS`

A comma-separated list of dedicated host IDs to include in the host resource group.

### Tags {#tags}

- **Parameter name**: `SEMAPHORE_AGENT_TAGS`

A comma-separated list of key-value pairs of tags to be added to all resources created for the stack.

For example: `Name:Something,Category:SomethingElse`.

### Use pre-signed URL {#use-pre-signed-url}

- **Parameter name**: `SEMAPHORE_AGENT_USE_PRE_SIGNED_URL`
- **default value**: `false`

If true, use a pre-signed AWS STS GetCallerIdentity URL for agent registration.

See [agent type configuration](../using-semaphore/self-hosted-install#name-sts) to learn how to configure this security feature.

## See also

- [How to use self-hosted agents](../using-semaphore/self-hosted)
- [How to install self-hosted agents](../using-semaphore/self-hosted-install)
- [How to configure self-hosted agents](../using-semaphore/self-hosted-configure)
- [How to run an autoscaling fleet of agents in AWS](../using-semaphore/self-hosted-aws)
- [Self-hosted agent parameter reference](./self-hosted-config)
