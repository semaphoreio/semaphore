---
description: Migrate from Travis CI
sidebar_position: 4
---

# Travis CI

<VideoTutorial title="Semaphore vs Travis CI" src="https://www.youtube.com/embed/QVGLTm1RhXM" />

This page explains the core concepts and feature mapping you need to migrate from Travis CI to Semaphore.

## Overview

Travis CI is a YAML-based syntax to define pipelines and actions. In Semaphore, you can use the [visual workflow editor](../../using-semaphore/workflows#workflow-editor) to more easily configure and preview pipelines.

Semaphore [cloud machines](../../reference/machine-types) also provide a 2x speed boost and much better reliability when compared with Travis CI.

## Travis CI vs Semaphore

This section describes how to implement common Travis CI functionalities in Semaphore.

### Checkout

Checkout clones the repository in the CI environment.

<Tabs groupId="migration">
<TabItem value="old" label="Travis CI">

Checkout is implicit in all Travis CI workflows by default.

</TabItem>
<TabItem value="new" label="Semaphore">

Semaphore does not clone the repository by default. This is because there are certain scenarios in which you don't need the code or you want to customize the cloning process.

To clone the repository in Semaphore we only need to execute [`checkout`](../../reference/toolbox#checkout).

```shell
# highlight-next-line
checkout
# now the code is the current working directory
cat README.md
```

</TabItem>
</Tabs>

### Artifacts

Both Travis CI and Semaphore support a method to persist data between jobs called Artifacts.

<Tabs groupId="editor-yaml">
<TabItem value="ga" label="Travis CI">

In Travis CI we use the artifacts addon.

The following example uploads and downloads `test.log`

```yaml
addons:
# highlight-start
  artifacts:
    paths:
    - $HOME/project/test.log
# highlight-end
```

</TabItem>
<TabItem value="semaphore" label="Semaphore">

In Semaphore, we use the [artifact](../../reference/toolbox#artifact) command to download and upload files to the artifact store.

The following command stores `test.log` from any job:

```shell
artifact push workflow test.log
```

To retrieve the file from any other job, we use:

```shell
artifact pull workflow test.log
```

See [artifacts](../../using-semaphore/artifacts) for more details.

</TabItem>
</Tabs>

### Caching

Both Travis CI and Semaphore support manually caching files. See the comparison below.

<Tabs groupId="editor-yaml">
<TabItem value="ga" label="Travis CI">

Travis CI has a cache keyword to cache files and dependencies.

The following example caches Gems in a Ruby project:

```yaml
language: ruby
cache: bundler
```

</TabItem>
<TabItem value="semaphore" label="Semaphore">

In Semaphore, we use the [cache](../../reference/toolbox#cache) command to cache dependencies and files.

The following commands, when added to a job downloads, cache, and installs Gems in a Ruby project:

```shell
checkout
cache restore
bundle install
cache store
```

See [caching](../../using-semaphore/cache) for more details.

</TabItem>
</Tabs>

### Language versions

Both Travis CI and Semaphore allow you to use specific language versions.

<Tabs groupId="editor-yaml">
<TabItem value="ga" label="Travis CI">

Travis CI uses a language-specific setup keyword.

The following example sets the Ruby version to `3.3.4`

```yaml
language: ruby
rvm:
  - 3.3.4
```

</TabItem>
<TabItem value="semaphore" label="Semaphore">

Semaphore provides the [Docker environments](../../using-semaphore/pipelines#docker-environments) to run your jobs in environments with all your build tools. You can connect multiple Docker images to provide database services for your end-to-end or smoke tests.

</TabItem>
</Tabs>

### Database and services

Both Travis CI and Semaphore support starting a databases and services. Semaphore uses Docker containers for this.

<Tabs groupId="editor-yaml">
<TabItem value="ga" label="Travis CI">

Travis CI uses services keyword. The following example starts Redis on default port.

```yaml
services:
  - redis-server
```

</TabItem>
<TabItem value="semaphore" label="Semaphore">

Semaphore provides the [Docker environments](../../using-semaphore/pipelines#docker-environments) to run your jobs in environments with all your build tools. You can connect multiple Docker images to provide database services for your end-to-end or smoke tests.

</TabItem>
</Tabs>

### Secrets

Secrets inject sensitive data and credentials into the workflow securely.

<Tabs groupId="migration">
<TabItem value="old" label="Travis CI">

In Travis CI we encrypt sensitive data using the Travis CLI. Travis uses asymmetric encryption to put the encrypted values in the YAML pipeline.

to access the values, we use the `secure` keyword, which tells Travis to decrypt the value on runtime.

```yaml
env:
  global:
 - secure: "... long encrypted string ..."
```

Using encrypted files uses a different system that's a bit more convoluted.

</TabItem>
<TabItem value="new" label="Semaphore">

In Semaphore, secrets are stored on the Semaphore server or project. Encryption and decryption is automatically handled for environment variables and files.

First, we create a [secret](../../using-semaphore/secrets) at the server or project level and activate it on a block.

The secret contents are automatically injected as environment variables in all jobs contained on that block.

![Using secrets on Semaphore](./img/secrets.jpg)
</TabItem>
</Tabs>

### Complete example

The following comparison shows how to build and test a Ruby project on Travis CI and in Semaphore.

<Tabs groupId="editor-yaml">
<TabItem value="ga" label="Travis CI">

On Travis CI, we need several actions to start services, manage Gems, and run the build and test commands.

```yaml
language: ruby

rvm:
  - $(cat .ruby-version)

cache: bundler

addons:
  apt:
    packages:
      - curl
      - libjemalloc2
      - libvips
      - sqlite3

branches:
  only:
    - main

jobs:
  include:
    - stage: security_scans
      name: "Scan Ruby"
      script:
        - bin/brakeman --no-pager

    - stage: security_scans
      name: "Scan JS"
      script:
        - bin/importmap audit

    - stage: lint
      script:
        - bin/rubocop -f github

    - stage: test
      before_script:
        - cp .sample.env .env
        - bundle exec rake db:setup
      script:
        - bundle exec rake
        - bin/rails db:test:prepare test test:system

env:
  global:
    - RAILS_ENV=test
```

</TabItem>
<TabItem value="semaphore" label="Semaphore">

We can achieve the same results in a single job on Semaphore by using these commands:

```shell
checkout
cache restore
nvm install --lts
bundle install --path vendor/bundle
yarn install
cache store
bundle exec rake db:create
bundle exec rake db:schema:load
bundle exec rake test
bundle exec rake test:system
```

</TabItem>
</Tabs>

## See also

- [Migration guide for Jenkins](./jenkins)
- [Migration guide for GitHub Actions](./github-actions)
- [Migration guide for BitBucket Pipelines](./bitbucket)
