---
description: Speed up pipelines with the cache
sidebar_position: 1
---

# Cache

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
import Available from '@site/src/components/Available';
import VideoTutorial from '@site/src/components/VideoTutorial';
import Steps from '@site/src/components/Steps';

<VideoTutorial title="Build optimization with caching" src="https://www.youtube.com/embed/jo4RfgN9sBg?si=ajDtPml-joj1ghfn" />

The cache provides fast and convenient storage for your jobs. Use the cache to store project dependencies to speed up builds. This page explains in detail how the cache works and shows examples.

## Overview

Semaphore provides a [cache tool](../reference/toolbox#cache) in all jobs to reuse files your project depends on but are not part of the repository.

Typical uses of the cache are:

- to propagate a file from one block to the next
- to reuse dependencies that are normally downloaded from the internet, like NPM modules

Semaphore creates a separate cache for every [project](./projects). For jobs running on Semaphore Cloud, the total cache size is 9.6GB. Older files are automatically deleted after 30 days or when the cache fills up.

:::note

Users running Semaphore On-Premise or [self-hosted agents](./self-hosted) need to [configure a custom backend](#custom-backends) to use the cache.

:::

## Language support {#languages}

The cache tool can recognize the structure for various popular languages and frameworks and automatically figure out what files to store and retrieve.

The cache tools recognize the following languages and dependency managers. See [advanced usage](#advanced) if your dependency manager is not listed below.

| Language | Files to be cached | Observations |
|--|--|--|
| Ruby (bundler) | `vendor/bundle/` | Requires `Gemfile.lock` to be present |
| Node.js (npm, yarn) | `node_modules/` or `$HOME/.cache/yarn` | Requires `package-lock.json` or `yarn.lock`  to be present |
| Node (nvm) | `$HOME/.nvm` | Requires `.nvmrc` to be present |
| Python (pip) | `.pip-cache/` | Requires `requirements.txt` to be present |
| PHP (composer) | `vendor/` | Requires `composer.lock` to be present |
| Elixir (mix) | `deps/` or `_build/` | Requires `mix.lock` to be present |
| Java (maven) | `.m2` or `target` | Requires `pom.xml` to be present |
| Go (native) | `$HOME/go/pkg/mod` | Requires `go.sum` to be present |

### Store and restore dependencies

When using one of the supported dependency managers:

<Steps>

1. Run `cache restore` to restore the latest files from the cache
2. Execute the usual command to install dependencies, e.g. `npm install`
3. Run `cache store` to save any updates in the cache

</Steps>

This ensures you always have the latest updated while reducing the time to download cached files.

<Tabs>
<TabItem value="npm" label="Node.js (npm)">

```shell title="Store NPM dependencies"
checkout
cache restore
npm install
cache store
```

</TabItem>
<TabItem value="pip" label="Python (pip)">

```shell title="Store Pip dependencies"
checkout
cache restore
pip download --cache-dir .pip_cache -r requirements.txt
cache store
```

</TabItem>
<TabItem value="bundle" label="Ruby (bundle)">

```shell title="Store Ruby gems"
checkout
cache restore
bundle install --path vendor/bundle
cache store
```

</TabItem>
</Tabs>

:::warning

Avoid using `cache store` in the [prologue](./pipelines#prologue) as this can cause file corruption due to multiple jobs trying to write the same key simultaneously. Instead, use `cache store` in the individual job commands.

:::

## Advanced usage {#advanced}

If your use case is not covered in the [supported languages](#languages) you can still use the cache. In this scenario, you need to provide additional arguments.

The full syntax for the `cache store` command is:

```shell
cache store <keys> <path>
```

The keys are a comma-separated lists of text labels to identify the contents of the files or folders stored. Semaphore compresses the files using tar and assigns all the keys for future reference.

The syntax to retrieve the keys is:

```shell
cache restore <keys>
```

Where keys are again a comma-separated lists of keys. Semaphore searches for the keys in the order provided and restores the first match to the working directory.

### Using multiple keys

It's recommended to use multiple keys to increase the chances of matching a key. The following example uses two keys:

```shell
cache store gems,my-gems vendor/bundle
```

We can retrieve the `vendor/bundle` folder with either of these commands:

```shell
cache restore gems
# or
cache restore my-gems
# or
cache restore gems,my-gems
```

Since *keys are not overwritten*, it's recommended to add a unique identifier for the stored files. The following example uses three keys and the checksum of `Gemfile.lock` as a key:

```shell
# store
cache store gems-master,gems-$SEMAPHORE_GIT_BRANCH,gems-$(checksum Gemfile.lock) vendor/bundle
# retrieve
cache restore gems-master,gems-$SEMAPHORE_GIT_BRANCH,gems-$(checksum Gemfile.lock) 
```

### Managing cache space

You can add the `--cleanup-by` parameter to define the cleanup strategy when the cache is full. This parameter accepts two options:

- `SIZE`: delete smallest archives first
- `ACCESS_TIME`: deletes least recently accessed keys first

For example:

```shell
cache store my-gems vendor/bundle --cleanup-by SIZE
```

You can also list all available keys with:

```shell
cache list --sort-by SIZE
# or
cache list --sort-by ACCESS_TIME
```

To delete an existing key use:

```shell
cache delete <keys>
```

And to clear the whole cache:

```shell
cache clear
```

## Custom backends {#custom-backends}

The cache storage is available for all Semaphore Cloud users. If you're running a different version such as On-Premise or [self-hosted agents](./self-hosted), the cache might not be available.

For these cases, you need to provide storage. This section explains how to configure custom storage in other platforms.

### AWS S3 {#aws}

You can use an AWS S3 bucket as cache storage.

To provision the storage, follow these steps:

<Steps>

1. Create and configure an S3 bucket as explained in [How to set up caching on self-hosted agents](./self-hosted-configure#aws-cache)
2. Configure the following [environment variables](./jobs#environment-variables) in your job
    - `SEMAPHORE_CACHE_BACKEND` set its value to "s3"
    - `SEMAPHORE_CACHE_S3_BUCKET` set its value to the S3 bucket name
3. Create a [secret](./secrets) with the following credentials
    - `AWS_ACCESS_KEY_ID`: the key for an IAM account with access to the bucket
    - `AWS_SECRET_ACCESS_KEY`: the secret key for the account
    - `AWS_DEFAULT_REGION`: the region where the bucket is located

</Steps>

### Google Cloud {#gcp}

You can use Google Cloud to provide custom storage for the cache.

To provision storage, follow these steps

<Steps>

1. [Create a Google Cloud Bucket](https://cloud.google.com/storage/docs/creating-buckets)
2. Configure the following [environment variables](./jobs#environment-variables) in your job
    - `SEMAPHORE_CACHE_BACKEND` set it to "gcs"
    - `SEMAPHORE_CACHE_GCS_BUCKET` set it to your Google Cloud bucket name
3. Provide the Google Cloud Application Default Credentials. See [How Application Default Credentials work](https://cloud.google.com/docs/authentication/application-default-credentials) to learn more

</Steps>

### Secure FTP (SFTP) {#sftp}

You can provide an SFTP server to provide custom storage for the cache.

To use SFTP, define the following [environment variables](./jobs#environment-variables) in your job:

- `SEMAPHORE_CACHE_BACKEND`: set its value to "sftp"
- `SEMAPHORE_CACHE_URL`: the IP address and port number of the SFTP server, e.g. "1.2.3.4:29920"
- `SEMAPHORE_CACHE_USERNAME`: the username used to connect to the server
- `SEMAPHORE_CACHE_PRIVATE_KEY_PATH`: the path of the private SSH key used to connect to the SFTP server

In addition, you must create a [secret](./secrets) to store the private SSH key and expose it inside the job.

## See also

- [Using cache in jobs](./jobs#cache)
- [Cache toolbox reference](../reference/toolbox#cache)
