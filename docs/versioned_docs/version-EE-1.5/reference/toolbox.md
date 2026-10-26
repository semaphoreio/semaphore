---
description: Semaphore toolbox reference
---

# Semaphore Toolbox






The toolbox is an [open source](https://github.com/semaphoreci/toolbox) package of command line tools available in every Semaphore job. It provides utility functions to clone, cache data, run test services, or change language versions. This page explains all the available tools.

## Overview

The Semaphore toolbox is preinstalled in all Semaphore jobs. It is also installed in [self-hosted agents](../using-semaphore/self-hosted), so you can assume that all the tools described on this page are available for use.

## artifact {#artifact}

This is the command line tool to access the [Semaphore artifacts](../using-semaphore/artifacts).

The usage is:

```shell
artifact <command> <namespace> <file_or_directory> [flags]
```

The available commands are:

- `help`: print help on the terminal
- `pull`: pull a file or directory from the artifact store
- `push`: push a file or directory to the artifact store
- `yank`: pull and delete a file or directory from the artifact store

The available namespaces are:

- `job`: storage available only to current job
- `workflow`: storage available to jobs in all pipelines in the workflow
- `project`: global storage for the project

See [artifact namespaces](../using-semaphore/artifacts#namespaces) for more details.

The optional flags are:

- `--force` or `-f`: overwrite file or directory if already exists
- `--destination` of `-d`: pull or yank the file into a different path
- `--verbose` or `-v`: verbose logging

### Examples

```shell title="Artifact usage examples"
# force push a final deliverable to the project level
artifact push project app-v1.tar.gz --force

# push a screenshot to the job level
artifact push job screenshots/app.png

# push a binary to the workflow level 
artifact push workflow build/app

# pull a binary from the workflow level 
artifact pull workflow build/app

# delete a binary from the workflow level 
artifact yank workflow build/app
```

### Error status

The `artifact pull` and `artifact yank` commands **exit with non-zero status** (ending the job with error) when:

- the file or directory already exists locally (unless `-f` or `--force` is supplied)
- the file or directory is not found in the specified namespace

### Supported filenames

The uploaded files must meet the following requirements:

- Unicode characters are supported
- File name lengths must be between 1-1024 bytes when UTF-8 encoded
- File names cannot contain end-of-line characters (carriage return or line feed)
- File names cannot start with `.well-known/acme-challenge/`
- File names cannot contain non-URI-encodable characters like `{, }, |, \, ^, ~, [, ]`
- Files cannot be named `.` or `...`

You can workaround these limitations by compressing the file with tar before pushing it to the artifact store. For example:

```shell title="Creating a tarball before storing the artifact"
tar -czvf example.tar.gz ~/example
artifact push workflow example.tar.gz
```

To retrieve the files, use:

```shell title="Retrieving the tarball"
artifact pull workflow example.tar.gz
tar -xzf example.tar.gz
```

## cache {#cache}

The cache tool lets you interact with your project's [Semaphore cache](../using-semaphore/cache).

The syntax is:

```shell
cache <command> <keys> [path] [flags]
```

The available commands are:

- `clear`: remove all keys in the cache.
- `delete`: delete a key from the cache.
- `has_key`: check if a key is present in the cache. Exits with non-zero status if the key is not found.
- `is_not_empty`: check if the cache is not empty.
- `list`: list all keys in the cache.
- `restore`: restore keys from the cache.
- `store`: store keys in the cache.
- `usage`: get a summary of cache usage.

### Cache keys

The cache keys are a comma-separated list of strings to label or select cached items.

The following examples show different ways to store and identify Ruby Gems in the `vendor/bundle` directory:

```shell
cache store our-gems vendor/bundle
cache store gems-$SEMAPHORE_GIT_BRANCH vendor/bundle
cache store gems-$SEMAPHORE_GIT_BRANCH-revision-$(checksum Gemfile.lock) vendor/bundle
```

To restore counterparts for the example above are:

```shell
cache restore our-gems
cache restore gems-$SEMAPHORE_GIT_BRANCH
cache restore gems-$SEMAPHORE_GIT_BRANCH-revision-$(checksum Gemfile.lock),gems-master
```

`cache restore` always retrieves the first item that matches a key found in the cache. The rest are ignored. If no archives are restored the command exits with exit status 0.

:::note

As the cache store uses tar, which automatically removes any leading / from a given path value, any further changes of the path after the store command completes will not be automatically propagated to the cache.

:::

### Space management {#cache-storage}

The `cache store` command automatically deletes older files when the cache is full. You can change the deletion criteria using the `--cleanup-by` or `-c` argument. For example:

```shell
cache store our-gems vendor/bundle --cleanup-by SIZE
```

The supported options for `--cleanup-by` are:

- `SIZE`: delete biggest files first
- `STORE_TIME`: (default) delete oldest files first
- `ACCESS_TIME`: delete oldest accessed files first

### Environment variables {#cache-env-vars}

The cache tool depends on the following environment variables:

- [`SEMAPHORE_CACHE_URL`](./env-vars#cache-url)
- [`SEMAPHORE_CACHE_USERNAME`](./env-vars#cache-username)
- [`SEMAPHORE_CACHE_PRIVATE_KEY_PATH`](./env-vars#cache-private-key-path)

## checkout {#checkout}

This tool clones the repository using Git. For performance reasons, the default behavior is to perform a [shallow clone](https://git-scm.com/docs/shallow). Shallow clones only include the latest commit instead of the full repository history.

The `checkout` command takes no arguments. It also changes the directory into the cloned repository. So, for example, this would work on a Node.js project:

```shell title="No need to cd into the cloned repository"
checkout
npm install
```

### Full clone {#full-clone}

If you want to do a full clone of the repository you can run the following commands to "unshallow" a repository:

```shell
checkout
git fetch --unshallow
git config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
git fetch --all
```

### Clone with cache {#cache-full-clone}

:::info

This is marked as an experimental feature.

:::

If a full clone takes too long, you can use `checkout --use-cache` to save a copy of the repository in the Semaphore cache. This should speed up full clones significantly.

To perform a full repository clone with cache run:

```shell
checkout --use-cache
```

This option creates or refreshes one or more copies of the repository in the Semaphore cache. See the [environment variables](#cache-env) to learn how to control the behavior of the cached copies.

### Environment variables {#cache-env}

The checkout command uses the following environment variables.

- [`SEMAPHORE_GIT_URL`](./env-vars#git-url)
- [`SEMAPHORE_GIT_DIR`](./env-vars#git-dir)
- [`SEMAPHORE_GIT_SHA`](./env-vars#commit-sha)
- [`SEMAPHORE_GIT_DEPTH`](./env-vars#git-depth)
- [`SEMAPHORE_GIT_CACHE_AGE`](./env-vars#git-cache-age) (only available after using `--use-cache`)
- [`SEMAPHORE_GIT_CACHE_KEEP`](./env-vars#git-cache-keep) (only available after using `--use-cache`)

## checksum {#checksum}

This tool takes a single argument which is the file to checksum. It outputs the MD5 checksum of the file's contents. This tool is useful for tagging [artifacts](../using-semaphore/artifacts) or generating [cache keys](../using-semaphore/cache).

The syntax is:

```shell title="checksum syntax"
checksum <file>
```

Example:

```shell title="Checksumming package-lock.json"
$ checksum package-lock.json
3dc6f33834092c93d26b71f9a35e4bb3
```

## install-package {#install-package}

The `install-package` tool is used to manage Ubuntu packages you may need for your jobs. It downloads and caches packages in a way that can be quickly reinstalled over and over again in different jobs. This is a convenient tool, you can still use `sudo` to install packages using the system's package manager.

The syntax is:

```shell title="install-package syntax"
install-package <command> <pkg-name>
```

Where `<pkg-name>` is the Ubuntu package name without the `.deb` extension. In other words, you want `libc6` instead of `libc6.deb`.

Where command is one of the following:

- `update`: Retrieve new lists of packages
- `upgrade`: Perform an upgrade
- `install`: Install new packages
- `reinstall`: Reinstall packages
- `remove`: Remove packages
- `purge`: Remove packages and config files
- `autoremove`: Remove automatically all unused packages
- `dist-upgrade`: Distribution upgrade, see apt-get(8)
- `dselect-upgrade`: Follow dselect selections
- `build-dep`: Configure build-dependencies for source packages
- `satisfy`: Satisfy dependency strings
- `clean`: Erase downloaded archive files
- `autoclean`: Erase old downloaded archive files
- `check`: Verify that there are no broken dependencies
- `source`: Download source archives
- `download`: Download the binary package into the current directory
- `changelog`: Download and display the changelog for the given package

You can supply multiple packages with their versions in the same invocation:

```shell
 install-package install mongodb-clients=3.6.8 mysql-client=8.0.36-0ubuntu0.20.04.1
```

The tool integrates with the [Semaphore cache](../using-semaphore/cache) to save, retrieve, and update the Deb packages as needed.

You can reinstall the packages in a different job within the same project with:

```shell title="Installing packages from the cache in other jobs"
install-package install
```

## retry {#retry}

The retry tool can be used to retry a command on an interval. This is useful when waiting for resources to become available or to mitigate connectivity issues.

The syntax is:

```shell title="retry syntax"
retry [flags] <command>
```

Where flags are optional arguments:

- `--times` or `-t`: number of times to retry before giving up. Default is 3
- `--sleep` or `-s`: wait interval between retries in seconds. Default is 0

For example, to retry 5 times `bundle install` with a 10-second sleep use:

```shell
retry --times 5 --sleep 10 bundle install
```

## sem-context {#sem-context}

This tool can be used to share key-value data between Semaphore jobs. It enables communication between jobs and pipelines within the same workflow.

:::note

sem-context depends on [artifacts](../using-semaphore/artifacts) to store data.

:::

The syntax is:

```shell title="sem-context syntax"
sem-context <action> <key>[=value] [flags]
```

The possible actions are:

- `put`: store a key-value pair
- `get`: retrieve a value for a key
- `delete`: delete a key

The following limitations apply to keys and values:

- keys are a alphanumerical string (`-` and `_` are allowed) of length 3 to 256 characters
- value is a string up to 20KB in size

Possible flags are:

- `--ignore-failure` forces the tool to exit with exit status 0 on failure
- `--force` overwrites existing keys
- `--fallback <value>` provides a default value for the get action if the key is not present

### put key {#sem-context-put}

The following example stores the version number with the key `ReleaseVersion`.

```shell
sem-context put ReleaseVersion=1.2.3
```

Exit status codes:

- 0: key-value saved successfully
- 1: key already exists
- 2: connection to the artifacts server failed
- 3: invalid format for key or value

### get key {#sem-context-get}

The following example retrieves the version number using the key `ReleaseVersion`.

```shell
$ sem-context get ReleaseVersion
1.2.3
```

Exit status codes:

- 0: key retrieved successfully
- 1: key not found
- 2: connection to the artifacts server failed
- 3: invalid key format

### delete key {#sem-context-delete}

The following example deletes the version value using the key `ReleaseVersion`.

```shell
sem-context delete ReleaseVersion
```

Exit status codes:

- 0: key deleted successfully
- 1: key not found
- 2: connection to the artifacts server failed
- 3: invalid key format

## spc {#spc}

The [Semaphore Pipeline Compiler](https://github.com/semaphoreci/spc) (SPC) is used during [initialization jobs](../using-semaphore/pipelines#init-job) to process runtime values in input pipelines. It generates an output pipeline that is used for the workflow execution.

:::note

spc is called automatically by Semaphore during initialization.

:::

The syntax is:

```shell title="spc syntax"
spc compile --input <input-pipeline-file> --output <output-pipeline-file> --logs <logs-file>
```

The tool evaluates [`change_in`](./conditions-dsl#change-in) arguments and outputs the result of each match condition.

## test-results {#test-results}

This tool processes test results in the JUnit format. It is used to process and generate [test reports](../using-semaphore/tests/test-reports) and the [flaky tests dashboard](../using-semaphore/tests/flaky-tests).

The syntax is:

```shell
test-results <command> [flags]
```

The available commands are:

- `combine`: combines multiples JSON report files into one file summary
- `compile`: parses JUnit XML files to a well-defined JSON report file
- `gen-pipeline-report`: fetches and combines workflow-level JUnit report and combines them
- `publish`: parses XML JUnit file to a well-defined JSON schema and publishes results to artifacts storage

The available flags are:

- `--config <path>`: path to the config file. Default is `$HOME/.test-results.yaml`
- `--name <name>` or `-N <name>`: override the name of the test suite
- `--parser <name>` or `-p <name>`: override the parser used. Defaults to "auto"
- `--suite-prefix <name>` or `-S <name>`: add a prefix for the test suite name
- `--trace`: provide trace logging

The test-results CLI is open-sourced and available on [semaphoreci/test-results](https://github.com/semaphoreci/test-results). You can access the source code, contribute, and report issues there.

### Merging test results {#test-result-merge}

To use the test result feature you must add the following command at the end of every test job.

The syntax is:

```shell
test-results publish <path>
```

Where `<path>` is a file or a directory containing JUnit XML files. This processes the files and uploads the results to the artifact store.

If working with Docker containers, you need to expose the JUnit files using bind mounts. For example:

```shell
docker run -v $(pwd):/app test-runner run-specs
test-results publish junit.xml
```

## sem-semantic-release {#sem-semantic-release}

`sem-semantic-release` wraps the [semantic release CLI] and exports the release information to the rest of your delivery process using [sem-context put](#sem-context-put). This information can later be retrieved with [sem-context get](#sem-context-get).

It is handy when you want to continue the delivery process once the release has been created. A common example would be to build a Docker image tagged with the release version, or add an annotation to a Kubernetes deployment manifest.

General usage in CI:

```shell
checkout
sem-semantic-release
```

Usage options:

```shell
Usage: sem-semantic-release [OPTION]...

Options:
  --dry-run   runs semantic-release without publishing version
  --plugins   npm plugins and extensions to be installed
  --branches  branches to run semantic release for
  --version   semantic-release version
```

The `sem-semantic-release` exports the following values to `sem-context`

| Key                 | Description                                             |
|--|--|
| `ReleasePublished`    | Whether a new release was published (`"true"` or `"false"`) |
| `ReleaseVersion`      | Version of the new release. (e.g. `"1.3.0"`)                |
| `ReleaseMajorVersion` | Major version of the new release. (e.g. `"1"`)              |
| `ReleaseMinorVersion` | Minor version of the new release. (e.g. `"3"`)              |
| `ReleasePatchVersion` | Patch version of the new release. (e.g. `"0"`)              |

You can use these values in your pipeline to automatically figure version numbers. For example:

```shell
docker build . -t my-app:$(sem-context get ReleaseVersion)
docker push
sed -i "s/IMAGE/$(sem-context get ReleaseVersion)" deployment.yml
kubectl apply -f deployment.yml
```

## See also

- [Semaphore command line tool reference](./semaphore-cli)
- [Working with Docker](../using-semaphore/containers/docker)
- [Environment variable reference](./env-vars)
