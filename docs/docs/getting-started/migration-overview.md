---
description: Migrate to Semaphore
sidebar_position: 1
---

# Migration Overview

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
import Available from '@site/src/components/Available';
import VideoTutorial from '@site/src/components/VideoTutorial';
import Steps from '@site/src/components/Steps';

Migrating a Continuous Integration and Delivery (CI/CD) platform can be straightforward or challenging. Every project, every team is a world; for some, it is trivial while for others, it is a big effort. In any case, it is our dearest hope that the effort benefits you and your team.

These guides will help you migrate from other CI systems to Semaphore. In this page, we'll review the basis for the migration process, as several migration steps are common for all CI systems.

We recommend going through the [Guided Tour](../guided-tour) pages to familiarize yourself with Semaphore before starting the migration plan.

## Migration plan

Here is the recommended plan to migrate from any CI provider to Semaphore.

<Steps>

1. Set goals

    Write down your goals and reasons for migrating your CI to Semaphore. For example, you might wish to reduce costs or speed up your builds. Setting expectations from the get-go will make the whole migration process clearer and more straightforward.

    If at any point in the process, you have doubts, contact us at `support@semaphoreci.com`. We want this process to be as smooth and painless as possible.

2. Compare features

    We suggest breaking down the requirements for the new CI system into three categories:

    - Must have
    - Nice to have
    - Optional

    Compare the list against [Semaphore Features](https://semaphoreci.com/pricing). Some of the requirements can be implemented in several ways by combining several features.

3. Create a proof of concept in Semaphore

    Pick one of your projects to be a pilot in your migration effort.

        - [Connect your GitHub](../../using-semaphore/connect-github) or [connect your BitBucket](../../using-semaphore/connect-bitbucket) repository to Semaphore 
        - Configure a CI pipeline, the objective is to reach a green build. See the [Guided Tour](../guided-tour) to get an overview of Semaphore

    The following pages describe key features you might need for the migration:

        - [How to create jobs](../../using-semaphore/jobs)
        - [Persist data with Artifacts](../../using-semaphore/artifacts)
        - [How to use Docker Environments](../../using-semaphore/pipelines#docker-environments)
        - [How to use the Cache](../../using-semaphore/cache)
        - [Using promotions for Continuous Delivery](../../using-semaphore/promotions)
        - [How to specify language versions](../../reference/toolbox#sem-version)

4. Optimize performance

    Once your project is building on Semaphore, begin optimizing for performance.

        - Pick the best [machine type](../../reference/machine-types) for the CI pipeline
        - Learn and implement the optimization strategies like [caching](../../using-semaphore/cache), [fail-fast](../../using-semaphore/pipelines#fail-fast), and [auto-cancel](../../using-semaphore/pipelines#auto-cancel)

5. Optimize costs

    Once you have your project running, you can track your spending in the [Plans & Billing page](../../using-semaphore/billing).

    The figure to optimize is the cost-per-pipeline. In other words, you should balance the cost of running your CI pipeline against the expected performance.

    You want to focus on the CI pipeline because it accounts for the vast majority of your usage, so optimizing this value has the most impact on your costs.

    You can optimize your costs by trying different [machine types](../../reference/machine-types), using [skip conditions](../../using-semaphore/jobs#skip-run), testing different levels of [job parallelism](../../using-semaphore/jobs#job-parallelism) and exploring [pipeline queues](../../using-semaphore/pipelines#pipeline-queues)

6. Onboard your team

    Once satisfied with your CI workflow it's time to onboard the rest of your team:

        - Begin by [adding the core developer team](../../using-semaphore/projects#people) and letting them familiarize with Semaphore 
        - Then, [invite to your organization](../../using-semaphore/organizations#people) the rest of the team 
        - Assign [roles](../../using-semaphore/rbac) and [create groups](../../using-semaphore/organizations#add-groups) to ensure everyone has the permissions needed to fulfill their roles
        
7. Migrate deployments

    If you have Continuous Delivery or Continuous Deployment tasks in your project, now's the time to migrate them to Semaphore.

        - Begin by migrating your secrets. [Secrets](../../using-semaphore/secrets) are used to store sensitive data such as SSH keys, database passwords, deployment keys, and API keys. If your CI/CD workflows connect to external services, secrets can help you keep these confidential details secure

        - We recommend creating a new set of credentials for Semaphore access instead of just copying the credentials you were using in your previous CI system. Once the migration is complete, you can disable or delete the older credentials without disrupting your Semaphore workflows

        - Create your delivery pipelines using [promotions](../../using-semaphore/promotions)

        - Use [deployment targets](../../using-semaphore/promotions#deployment-targets) to define deployment policies and permissions

8. Repeat steps 3-7 for the rest of your projects
9. Shut down the old CI system

    If you don't have any projects running in your old CI system you can shut it down or cancel your plan once you are satisfied with Semaphore. Remember to deactivate or delete the old secrets connected to the decommissioned systems.

10. Track and optimize

    The migration might be done but the work never ends. Keep track of your [organization health](../../using-semaphore/org-health) and monitor spending. Get feedback from people working on the projects to find improvement opportunities.

</Steps>

## See also

- [Migration guide for Jenkins](./jenkins)
- [Migration guide for GitHub Actions](./github-actions)
- [Migration guide for Travis CI](./travis)
- [Migration guide for BitBucket Pipelines](./bitbucket)
