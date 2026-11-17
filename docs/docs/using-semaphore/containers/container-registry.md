---
description: Download popular Docker images faster
sidebar_position: 6
---

# Semaphore Container Registry






Semaphore Cloud provides an integrated Docker Container Registry to pull popular images faster into your jobs.

## Overview

The Docker Container Registry integrated into Semaphore Cloud can be used in two ways:

- **Convenience images**: you can pull images to use in your [jobs](../jobs) without any restrictions or limits
- **Service images**: these are images used by the [sem-service command line tool](../../reference/toolbox#sem-service)

:::note

Due to the introduction of the [rate limits on Docker Hub](https://docs.docker.com/docker-hub/download-rate-limit/), any images pulled from [Semaphore Docker Hub organization](https://hub.docker.com/u/semaphoreci) will be automatically redirected to the Semaphore Container Registry.

:::


## How to use the Semaphore Registry

To use any of the images, run `docker pull` or `docker run` using the link provided in the table.

For example, to use a Node image in your jobs add the following command:

```shell title="Job commands"
docker pull registry.semaphoreci.com/node:20
```

To use the Container Registry in your Dockerfiles, replace:

```docker title="Dockerfile"
FROM node:20
```

With:

```docker title="Dockerfile"
FROM registry.semaphoreci.com/node:20
```

Service images can be used with [sem-service](../../reference/toolbox#sem-service). For example, the following command starts a PostgreSQL v18 container in your job:

```shell title="Job commands"
$ sem-service start postgres 18
Starting postgres...done.
PostgreSQL 18 is running at 0.0.0.0:5432
To access it use username 'postgres' and blank password.
```

## Convenience and language images

This section lists available images for several popular languages and operating systems.

The tables include numeric version tags and their available Node.js, browser, and Flutter variants.
Distribution-specific tags and prereleases are omitted.

### Ubuntu

<details>
<summary>Show me</summary>
<div>

| Image | Link |
|--------|--------|
| ubuntu:18.04 | `registry.semaphoreci.com/ubuntu:18.04` |  
| ubuntu:20.04 | `registry.semaphoreci.com/ubuntu:20.04` |  
| ubuntu:22.04 | `registry.semaphoreci.com/ubuntu:22.04` |  

</div>
</details>

### Alpine

<details>
<summary>Alpine images</summary>
<div>

| Image | Link |
|--------|--------|
| alpine:3.9 | `registry.semaphoreci.com/alpine:3.9` |

</div>
</details>

### Android

Android images come in three variants:

- **base**: base images matching the Android official images
- **node**: base image extended with Node.js
- **flutter**: base image extended with Flutter


<details>
<summary>Android images</summary>
<div>

| Image | Link |
|--------|--------|
| android:26 | `registry.semaphoreci.com/android:26` |
| android:26-flutter | `registry.semaphoreci.com/android:26-flutter` |
| android:26-node | `registry.semaphoreci.com/android:26-node` |
| android:27 | `registry.semaphoreci.com/android:27` |
| android:27-flutter | `registry.semaphoreci.com/android:27-flutter` |
| android:27-node | `registry.semaphoreci.com/android:27-node` |
| android:28 | `registry.semaphoreci.com/android:28` |
| android:28-flutter | `registry.semaphoreci.com/android:28-flutter` |
| android:28-node | `registry.semaphoreci.com/android:28-node` |
| android:29 | `registry.semaphoreci.com/android:29` |
| android:29-flutter | `registry.semaphoreci.com/android:29-flutter` |
| android:29-node | `registry.semaphoreci.com/android:29-node` |
| android:30 | `registry.semaphoreci.com/android:30` |
| android:30-flutter | `registry.semaphoreci.com/android:30-flutter` |
| android:30-node | `registry.semaphoreci.com/android:30-node` |
| android:31 | `registry.semaphoreci.com/android:31` |
| android:31-flutter | `registry.semaphoreci.com/android:31-flutter` |
| android:31-node | `registry.semaphoreci.com/android:31-node` |
| android:33 | `registry.semaphoreci.com/android:33` |
| android:33-flutter | `registry.semaphoreci.com/android:33-flutter` |
| android:33-node | `registry.semaphoreci.com/android:33-node` |
| android:34 | `registry.semaphoreci.com/android:34` |
| android:34-flutter | `registry.semaphoreci.com/android:34-flutter` |
| android:34-node | `registry.semaphoreci.com/android:34-node` |
| android:35 | `registry.semaphoreci.com/android:35` |
| android:35-flutter | `registry.semaphoreci.com/android:35-flutter` |
| android:35-node | `registry.semaphoreci.com/android:35-node` |
| android:36 | `registry.semaphoreci.com/android:36` |
| android:36-flutter | `registry.semaphoreci.com/android:36-flutter` |
| android:36-node | `registry.semaphoreci.com/android:36-node` |

</div>
</details>

### Node

Node images come in two variants:

- **base**: base images matching the Node.js official images
- **browsers**: base image extended with Firefox, Google Chrome, and chromedriver. Useful for running browser-based pipelines

<details>
<summary>Node images</summary>
<div>

| Image | Link |
|--------|--------|
| node:10 | `registry.semaphoreci.com/node:10` |  
| node:10-browsers | `registry.semaphoreci.com/node:10-browsers` |   
| node:10.23 | `registry.semaphoreci.com/node:10.23` |
| node:10.23-browsers | `registry.semaphoreci.com/node:10.23-browsers` |
| node:10.23.1 | `registry.semaphoreci.com/node:10.23.1` |
| node:10.23.1-browsers | `registry.semaphoreci.com/node:10.23.1-browsers` |
| node:10.23.2 | `registry.semaphoreci.com/node:10.23.2` |
| node:10.23.2-browsers | `registry.semaphoreci.com/node:10.23.2-browsers` |
| node:10.24 | `registry.semaphoreci.com/node:10.24` |
| node:10.24-browsers | `registry.semaphoreci.com/node:10.24-browsers` |
| node:10.24.0 | `registry.semaphoreci.com/node:10.24.0` |
| node:10.24.0-browsers | `registry.semaphoreci.com/node:10.24.0-browsers` |
| node:10.24.1 | `registry.semaphoreci.com/node:10.24.1` |
| node:10.24.1-browsers | `registry.semaphoreci.com/node:10.24.1-browsers` |
| node:12 | `registry.semaphoreci.com/node:12` |  
| node:12-browsers | `registry.semaphoreci.com/node:12-browsers` |  
| node:12.4.0 | `registry.semaphoreci.com/node:12.4.0` |
| node:12.20 | `registry.semaphoreci.com/node:12.20` |
| node:12.20-browsers | `registry.semaphoreci.com/node:12.20-browsers` |
| node:12.20.1 | `registry.semaphoreci.com/node:12.20.1` |
| node:12.20.1-browsers | `registry.semaphoreci.com/node:12.20.1-browsers` |
| node:12.21 | `registry.semaphoreci.com/node:12.21` |
| node:12.21-browsers | `registry.semaphoreci.com/node:12.21-browsers` |
| node:12.21.0 | `registry.semaphoreci.com/node:12.21.0` |
| node:12.21.0-browsers | `registry.semaphoreci.com/node:12.21.0-browsers` |
| node:12.22 | `registry.semaphoreci.com/node:12.22` |
| node:12.22-browsers | `registry.semaphoreci.com/node:12.22-browsers` |
| node:12.22.0 | `registry.semaphoreci.com/node:12.22.0` |
| node:12.22.0-browsers | `registry.semaphoreci.com/node:12.22.0-browsers` |
| node:12.22.1 | `registry.semaphoreci.com/node:12.22.1` |
| node:12.22.1-browsers | `registry.semaphoreci.com/node:12.22.1-browsers` |
| node:12.22.4 | `registry.semaphoreci.com/node:12.22.4` |
| node:12.22.4-browsers | `registry.semaphoreci.com/node:12.22.4-browsers` |
| node:12.22.6 | `registry.semaphoreci.com/node:12.22.6` |
| node:12.22.6-browsers | `registry.semaphoreci.com/node:12.22.6-browsers` |
| node:12.22.7 | `registry.semaphoreci.com/node:12.22.7` |
| node:12.22.7-browsers | `registry.semaphoreci.com/node:12.22.7-browsers` |
| node:12.22.8 | `registry.semaphoreci.com/node:12.22.8` |
| node:12.22.8-browsers | `registry.semaphoreci.com/node:12.22.8-browsers` |
| node:12.22.9 | `registry.semaphoreci.com/node:12.22.9` |
| node:12.22.9-browsers | `registry.semaphoreci.com/node:12.22.9-browsers` |
| node:12.22.10 | `registry.semaphoreci.com/node:12.22.10` |
| node:12.22.10-browsers | `registry.semaphoreci.com/node:12.22.10-browsers` |
| node:12.22.11 | `registry.semaphoreci.com/node:12.22.11` |
| node:12.22.11-browsers | `registry.semaphoreci.com/node:12.22.11-browsers` |
| node:12.22.12 | `registry.semaphoreci.com/node:12.22.12` |
| node:12.22.12-browsers | `registry.semaphoreci.com/node:12.22.12-browsers` |
| node:14 | `registry.semaphoreci.com/node:14` |  
| node:14-browsers | `registry.semaphoreci.com/node:14-browsers` |  
| node:14.15 | `registry.semaphoreci.com/node:14.15` |
| node:14.15-browsers | `registry.semaphoreci.com/node:14.15-browsers` |
| node:14.15.4 | `registry.semaphoreci.com/node:14.15.4` |
| node:14.15.4-browsers | `registry.semaphoreci.com/node:14.15.4-browsers` |
| node:14.16 | `registry.semaphoreci.com/node:14.16` |
| node:14.16-browsers | `registry.semaphoreci.com/node:14.16-browsers` |
| node:14.16.0 | `registry.semaphoreci.com/node:14.16.0` |
| node:14.16.0-browsers | `registry.semaphoreci.com/node:14.16.0-browsers` |
| node:14.16.1 | `registry.semaphoreci.com/node:14.16.1` |
| node:14.16.1-browsers | `registry.semaphoreci.com/node:14.16.1-browsers` |
| node:14.17 | `registry.semaphoreci.com/node:14.17` |
| node:14.17-browsers | `registry.semaphoreci.com/node:14.17-browsers` |
| node:14.17.0 | `registry.semaphoreci.com/node:14.17.0` |
| node:14.17.0-browsers | `registry.semaphoreci.com/node:14.17.0-browsers` |
| node:14.17.1 | `registry.semaphoreci.com/node:14.17.1` |
| node:14.17.1-browsers | `registry.semaphoreci.com/node:14.17.1-browsers` |
| node:14.17.4 | `registry.semaphoreci.com/node:14.17.4` |
| node:14.17.4-browsers | `registry.semaphoreci.com/node:14.17.4-browsers` |
| node:14.17.6 | `registry.semaphoreci.com/node:14.17.6` |
| node:14.17.6-browsers | `registry.semaphoreci.com/node:14.17.6-browsers` |
| node:14.18 | `registry.semaphoreci.com/node:14.18` |
| node:14.18-browsers | `registry.semaphoreci.com/node:14.18-browsers` |
| node:14.18.0 | `registry.semaphoreci.com/node:14.18.0` |
| node:14.18.0-browsers | `registry.semaphoreci.com/node:14.18.0-browsers` |
| node:14.18.1 | `registry.semaphoreci.com/node:14.18.1` |
| node:14.18.1-browsers | `registry.semaphoreci.com/node:14.18.1-browsers` |
| node:14.18.2 | `registry.semaphoreci.com/node:14.18.2` |
| node:14.18.2-browsers | `registry.semaphoreci.com/node:14.18.2-browsers` |
| node:14.18.3 | `registry.semaphoreci.com/node:14.18.3` |
| node:14.18.3-browsers | `registry.semaphoreci.com/node:14.18.3-browsers` |
| node:14.19 | `registry.semaphoreci.com/node:14.19` |
| node:14.19-browsers | `registry.semaphoreci.com/node:14.19-browsers` |
| node:14.19.0 | `registry.semaphoreci.com/node:14.19.0` |
| node:14.19.0-browsers | `registry.semaphoreci.com/node:14.19.0-browsers` |
| node:14.19.1 | `registry.semaphoreci.com/node:14.19.1` |
| node:14.19.1-browsers | `registry.semaphoreci.com/node:14.19.1-browsers` |
| node:14.19.3 | `registry.semaphoreci.com/node:14.19.3` |
| node:14.19.3-browsers | `registry.semaphoreci.com/node:14.19.3-browsers` |
| node:14.20 | `registry.semaphoreci.com/node:14.20` |
| node:14.20-browsers | `registry.semaphoreci.com/node:14.20-browsers` |
| node:14.20.0 | `registry.semaphoreci.com/node:14.20.0` |
| node:14.20.0-browsers | `registry.semaphoreci.com/node:14.20.0-browsers` |
| node:14.20.1 | `registry.semaphoreci.com/node:14.20.1` |
| node:14.20.1-browsers | `registry.semaphoreci.com/node:14.20.1-browsers` |
| node:14.21 | `registry.semaphoreci.com/node:14.21` |
| node:14.21-browsers | `registry.semaphoreci.com/node:14.21-browsers` |
| node:14.21.1 | `registry.semaphoreci.com/node:14.21.1` |
| node:14.21.1-browsers | `registry.semaphoreci.com/node:14.21.1-browsers` |
| node:14.21.2 | `registry.semaphoreci.com/node:14.21.2` |
| node:14.21.2-browsers | `registry.semaphoreci.com/node:14.21.2-browsers` |
| node:14.21.3 | `registry.semaphoreci.com/node:14.21.3` |
| node:15 | `registry.semaphoreci.com/node:15` |  
| node:15-browsers | `registry.semaphoreci.com/node:15-browsers` |  
| node:15.5 | `registry.semaphoreci.com/node:15.5` |
| node:15.5-browsers | `registry.semaphoreci.com/node:15.5-browsers` |
| node:15.5.0 | `registry.semaphoreci.com/node:15.5.0` |
| node:15.5.1 | `registry.semaphoreci.com/node:15.5.1` |
| node:15.5.1-browsers | `registry.semaphoreci.com/node:15.5.1-browsers` |
| node:15.7 | `registry.semaphoreci.com/node:15.7` |
| node:15.7-browsers | `registry.semaphoreci.com/node:15.7-browsers` |
| node:15.7.0 | `registry.semaphoreci.com/node:15.7.0` |
| node:15.7.0-browsers | `registry.semaphoreci.com/node:15.7.0-browsers` |
| node:15.10 | `registry.semaphoreci.com/node:15.10` |
| node:15.10-browsers | `registry.semaphoreci.com/node:15.10-browsers` |
| node:15.10.0 | `registry.semaphoreci.com/node:15.10.0` |
| node:15.10.0-browsers | `registry.semaphoreci.com/node:15.10.0-browsers` |
| node:15.13 | `registry.semaphoreci.com/node:15.13` |
| node:15.13-browsers | `registry.semaphoreci.com/node:15.13-browsers` |
| node:15.13.0 | `registry.semaphoreci.com/node:15.13.0` |
| node:15.13.0-browsers | `registry.semaphoreci.com/node:15.13.0-browsers` |
| node:15.14 | `registry.semaphoreci.com/node:15.14` |
| node:15.14-browsers | `registry.semaphoreci.com/node:15.14-browsers` |
| node:15.14.0 | `registry.semaphoreci.com/node:15.14.0` |
| node:15.14.0-browsers | `registry.semaphoreci.com/node:15.14.0-browsers` |
| node:16 | `registry.semaphoreci.com/node:16` |  
| node:16-browsers | `registry.semaphoreci.com/node:16-browsers` |  
| node:16.0 | `registry.semaphoreci.com/node:16.0` |
| node:16.0-browsers | `registry.semaphoreci.com/node:16.0-browsers` |
| node:16.0.0 | `registry.semaphoreci.com/node:16.0.0` |
| node:16.0.0-browsers | `registry.semaphoreci.com/node:16.0.0-browsers` |
| node:16.2 | `registry.semaphoreci.com/node:16.2` |
| node:16.2-browsers | `registry.semaphoreci.com/node:16.2-browsers` |
| node:16.2.0 | `registry.semaphoreci.com/node:16.2.0` |
| node:16.2.0-browsers | `registry.semaphoreci.com/node:16.2.0-browsers` |
| node:16.3 | `registry.semaphoreci.com/node:16.3` |
| node:16.3-browsers | `registry.semaphoreci.com/node:16.3-browsers` |
| node:16.3.0 | `registry.semaphoreci.com/node:16.3.0` |
| node:16.3.0-browsers | `registry.semaphoreci.com/node:16.3.0-browsers` |
| node:16.6 | `registry.semaphoreci.com/node:16.6` |
| node:16.6-browsers | `registry.semaphoreci.com/node:16.6-browsers` |
| node:16.6.0 | `registry.semaphoreci.com/node:16.6.0` |
| node:16.6.0-browsers | `registry.semaphoreci.com/node:16.6.0-browsers` |
| node:16.8 | `registry.semaphoreci.com/node:16.8` |
| node:16.8-browsers | `registry.semaphoreci.com/node:16.8-browsers` |
| node:16.8.0 | `registry.semaphoreci.com/node:16.8.0` |
| node:16.8.0-browsers | `registry.semaphoreci.com/node:16.8.0-browsers` |
| node:16.10 | `registry.semaphoreci.com/node:16.10` |
| node:16.10-browsers | `registry.semaphoreci.com/node:16.10-browsers` |
| node:16.10.0 | `registry.semaphoreci.com/node:16.10.0` |
| node:16.10.0-browsers | `registry.semaphoreci.com/node:16.10.0-browsers` |
| node:16.13 | `registry.semaphoreci.com/node:16.13` |
| node:16.13-browsers | `registry.semaphoreci.com/node:16.13-browsers` |
| node:16.13.0 | `registry.semaphoreci.com/node:16.13.0` |
| node:16.13.0-browsers | `registry.semaphoreci.com/node:16.13.0-browsers` |
| node:16.13.1 | `registry.semaphoreci.com/node:16.13.1` |
| node:16.13.1-browsers | `registry.semaphoreci.com/node:16.13.1-browsers` |
| node:16.13.2 | `registry.semaphoreci.com/node:16.13.2` |
| node:16.13.2-browsers | `registry.semaphoreci.com/node:16.13.2-browsers` |
| node:16.14 | `registry.semaphoreci.com/node:16.14` |
| node:16.14-browsers | `registry.semaphoreci.com/node:16.14-browsers` |
| node:16.14.0 | `registry.semaphoreci.com/node:16.14.0` |
| node:16.14.0-browsers | `registry.semaphoreci.com/node:16.14.0-browsers` |
| node:16.14.2 | `registry.semaphoreci.com/node:16.14.2` |
| node:16.14.2-browsers | `registry.semaphoreci.com/node:16.14.2-browsers` |
| node:16.15 | `registry.semaphoreci.com/node:16.15` |
| node:16.15-browsers | `registry.semaphoreci.com/node:16.15-browsers` |
| node:16.15.0 | `registry.semaphoreci.com/node:16.15.0` |
| node:16.15.0-browsers | `registry.semaphoreci.com/node:16.15.0-browsers` |
| node:16.15.1 | `registry.semaphoreci.com/node:16.15.1` |
| node:16.15.1-browsers | `registry.semaphoreci.com/node:16.15.1-browsers` |
| node:16.16 | `registry.semaphoreci.com/node:16.16` |
| node:16.16-browsers | `registry.semaphoreci.com/node:16.16-browsers` |
| node:16.16.0 | `registry.semaphoreci.com/node:16.16.0` |
| node:16.16.0-browsers | `registry.semaphoreci.com/node:16.16.0-browsers` |
| node:16.17 | `registry.semaphoreci.com/node:16.17` |
| node:16.17-browsers | `registry.semaphoreci.com/node:16.17-browsers` |
| node:16.17.0 | `registry.semaphoreci.com/node:16.17.0` |
| node:16.17.0-browsers | `registry.semaphoreci.com/node:16.17.0-browsers` |
| node:16.17.1 | `registry.semaphoreci.com/node:16.17.1` |
| node:16.17.1-browsers | `registry.semaphoreci.com/node:16.17.1-browsers` |
| node:16.18 | `registry.semaphoreci.com/node:16.18` |
| node:16.18-browsers | `registry.semaphoreci.com/node:16.18-browsers` |
| node:16.18.0 | `registry.semaphoreci.com/node:16.18.0` |
| node:16.18.0-browsers | `registry.semaphoreci.com/node:16.18.0-browsers` |
| node:16.18.1 | `registry.semaphoreci.com/node:16.18.1` |
| node:16.18.1-browsers | `registry.semaphoreci.com/node:16.18.1-browsers` |
| node:16.19 | `registry.semaphoreci.com/node:16.19` |
| node:16.19-browsers | `registry.semaphoreci.com/node:16.19-browsers` |
| node:16.19.0 | `registry.semaphoreci.com/node:16.19.0` |
| node:16.19.0-browsers | `registry.semaphoreci.com/node:16.19.0-browsers` |
| node:16.20 | `registry.semaphoreci.com/node:16.20` |
| node:16.20-browsers | `registry.semaphoreci.com/node:16.20-browsers` |
| node:16.20.0 | `registry.semaphoreci.com/node:16.20.0` |
| node:16.20.1 | `registry.semaphoreci.com/node:16.20.1` |
| node:16.20.1-browsers | `registry.semaphoreci.com/node:16.20.1-browsers` |
| node:16.20.2 | `registry.semaphoreci.com/node:16.20.2` |
| node:16.20.2-browsers | `registry.semaphoreci.com/node:16.20.2-browsers` |
| node:17 | `registry.semaphoreci.com/node:17` |  
| node:17-browsers | `registry.semaphoreci.com/node:17-browsers` |  
| node:17.0 | `registry.semaphoreci.com/node:17.0` |
| node:17.0-browsers | `registry.semaphoreci.com/node:17.0-browsers` |
| node:17.0.1 | `registry.semaphoreci.com/node:17.0.1` |
| node:17.0.1-browsers | `registry.semaphoreci.com/node:17.0.1-browsers` |
| node:17.1 | `registry.semaphoreci.com/node:17.1` |
| node:17.1.0 | `registry.semaphoreci.com/node:17.1.0` |
| node:17.2 | `registry.semaphoreci.com/node:17.2` |
| node:17.2-browsers | `registry.semaphoreci.com/node:17.2-browsers` |
| node:17.2.0 | `registry.semaphoreci.com/node:17.2.0` |
| node:17.2.0-browsers | `registry.semaphoreci.com/node:17.2.0-browsers` |
| node:17.3 | `registry.semaphoreci.com/node:17.3` |
| node:17.3-browsers | `registry.semaphoreci.com/node:17.3-browsers` |
| node:17.3.0 | `registry.semaphoreci.com/node:17.3.0` |
| node:17.3.0-browsers | `registry.semaphoreci.com/node:17.3.0-browsers` |
| node:17.4 | `registry.semaphoreci.com/node:17.4` |
| node:17.4-browsers | `registry.semaphoreci.com/node:17.4-browsers` |
| node:17.4.0 | `registry.semaphoreci.com/node:17.4.0` |
| node:17.4.0-browsers | `registry.semaphoreci.com/node:17.4.0-browsers` |
| node:17.6 | `registry.semaphoreci.com/node:17.6` |
| node:17.6-browsers | `registry.semaphoreci.com/node:17.6-browsers` |
| node:17.6.0 | `registry.semaphoreci.com/node:17.6.0` |
| node:17.6.0-browsers | `registry.semaphoreci.com/node:17.6.0-browsers` |
| node:17.8 | `registry.semaphoreci.com/node:17.8` |
| node:17.8-browsers | `registry.semaphoreci.com/node:17.8-browsers` |
| node:17.8.0 | `registry.semaphoreci.com/node:17.8.0` |
| node:17.8.0-browsers | `registry.semaphoreci.com/node:17.8.0-browsers` |
| node:17.9 | `registry.semaphoreci.com/node:17.9` |
| node:17.9-browsers | `registry.semaphoreci.com/node:17.9-browsers` |
| node:17.9.0 | `registry.semaphoreci.com/node:17.9.0` |
| node:17.9.0-browsers | `registry.semaphoreci.com/node:17.9.0-browsers` |
| node:18 | `registry.semaphoreci.com/node:18` |  
| node:18-browsers | `registry.semaphoreci.com/node:18-browsers` |  
| node:18.0 | `registry.semaphoreci.com/node:18.0` |
| node:18.0-browsers | `registry.semaphoreci.com/node:18.0-browsers` |
| node:18.0.0 | `registry.semaphoreci.com/node:18.0.0` |
| node:18.0.0-browsers | `registry.semaphoreci.com/node:18.0.0-browsers` |
| node:18.2 | `registry.semaphoreci.com/node:18.2` |
| node:18.2-browsers | `registry.semaphoreci.com/node:18.2-browsers` |
| node:18.2.0 | `registry.semaphoreci.com/node:18.2.0` |
| node:18.2.0-browsers | `registry.semaphoreci.com/node:18.2.0-browsers` |
| node:18.4 | `registry.semaphoreci.com/node:18.4` |
| node:18.4-browsers | `registry.semaphoreci.com/node:18.4-browsers` |
| node:18.4.0 | `registry.semaphoreci.com/node:18.4.0` |
| node:18.4.0-browsers | `registry.semaphoreci.com/node:18.4.0-browsers` |
| node:18.7 | `registry.semaphoreci.com/node:18.7` |
| node:18.7-browsers | `registry.semaphoreci.com/node:18.7-browsers` |
| node:18.7.0 | `registry.semaphoreci.com/node:18.7.0` |
| node:18.7.0-browsers | `registry.semaphoreci.com/node:18.7.0-browsers` |
| node:18.8 | `registry.semaphoreci.com/node:18.8` |
| node:18.8-browsers | `registry.semaphoreci.com/node:18.8-browsers` |
| node:18.8.0 | `registry.semaphoreci.com/node:18.8.0` |
| node:18.8.0-browsers | `registry.semaphoreci.com/node:18.8.0-browsers` |
| node:18.10 | `registry.semaphoreci.com/node:18.10` |
| node:18.10-browsers | `registry.semaphoreci.com/node:18.10-browsers` |
| node:18.10.0 | `registry.semaphoreci.com/node:18.10.0` |
| node:18.10.0-browsers | `registry.semaphoreci.com/node:18.10.0-browsers` |
| node:18.12 | `registry.semaphoreci.com/node:18.12` |
| node:18.12-browsers | `registry.semaphoreci.com/node:18.12-browsers` |
| node:18.12.0 | `registry.semaphoreci.com/node:18.12.0` |
| node:18.12.0-browsers | `registry.semaphoreci.com/node:18.12.0-browsers` |
| node:18.12.1 | `registry.semaphoreci.com/node:18.12.1` |
| node:18.12.1-browsers | `registry.semaphoreci.com/node:18.12.1-browsers` |
| node:18.13 | `registry.semaphoreci.com/node:18.13` |
| node:18.13.0 | `registry.semaphoreci.com/node:18.13.0` |
| node:18.15 | `registry.semaphoreci.com/node:18.15` |
| node:18.15.0 | `registry.semaphoreci.com/node:18.15.0` |
| node:18.16 | `registry.semaphoreci.com/node:18.16` |
| node:18.16-browsers | `registry.semaphoreci.com/node:18.16-browsers` |
| node:18.16.0 | `registry.semaphoreci.com/node:18.16.0` |
| node:18.16.1 | `registry.semaphoreci.com/node:18.16.1` |
| node:18.16.1-browsers | `registry.semaphoreci.com/node:18.16.1-browsers` |
| node:18.17 | `registry.semaphoreci.com/node:18.17` |
| node:18.17-browsers | `registry.semaphoreci.com/node:18.17-browsers` |
| node:18.17.0 | `registry.semaphoreci.com/node:18.17.0` |
| node:18.17.1 | `registry.semaphoreci.com/node:18.17.1` |
| node:18.17.1-browsers | `registry.semaphoreci.com/node:18.17.1-browsers` |
| node:18.18 | `registry.semaphoreci.com/node:18.18` |
| node:18.18-browsers | `registry.semaphoreci.com/node:18.18-browsers` |
| node:18.18.0 | `registry.semaphoreci.com/node:18.18.0` |
| node:18.18.0-browsers | `registry.semaphoreci.com/node:18.18.0-browsers` |
| node:18.18.2 | `registry.semaphoreci.com/node:18.18.2` |
| node:18.18.2-browsers | `registry.semaphoreci.com/node:18.18.2-browsers` |
| node:18.19 | `registry.semaphoreci.com/node:18.19` |
| node:18.19-browsers | `registry.semaphoreci.com/node:18.19-browsers` |
| node:18.19.0 | `registry.semaphoreci.com/node:18.19.0` |
| node:18.19.0-browsers | `registry.semaphoreci.com/node:18.19.0-browsers` |
| node:18.19.1 | `registry.semaphoreci.com/node:18.19.1` |
| node:18.20 | `registry.semaphoreci.com/node:18.20` |
| node:18.20-browsers | `registry.semaphoreci.com/node:18.20-browsers` |
| node:18.20.2 | `registry.semaphoreci.com/node:18.20.2` |
| node:18.20.4 | `registry.semaphoreci.com/node:18.20.4` |
| node:18.20.4-browsers | `registry.semaphoreci.com/node:18.20.4-browsers` |
| node:18.20.5 | `registry.semaphoreci.com/node:18.20.5` |
| node:18.20.5-browsers | `registry.semaphoreci.com/node:18.20.5-browsers` |
| node:18.20.6 | `registry.semaphoreci.com/node:18.20.6` |
| node:18.20.6-browsers | `registry.semaphoreci.com/node:18.20.6-browsers` |
| node:18.20.7 | `registry.semaphoreci.com/node:18.20.7` |
| node:18.20.8 | `registry.semaphoreci.com/node:18.20.8` |
| node:18.20.8-browsers | `registry.semaphoreci.com/node:18.20.8-browsers` |
| node:19 | `registry.semaphoreci.com/node:19` |  
| node:19-browsers | `registry.semaphoreci.com/node:19-browsers` |  
| node:19.0 | `registry.semaphoreci.com/node:19.0` |
| node:19.0-browsers | `registry.semaphoreci.com/node:19.0-browsers` |
| node:19.0.0 | `registry.semaphoreci.com/node:19.0.0` |
| node:19.0.0-browsers | `registry.semaphoreci.com/node:19.0.0-browsers` |
| node:19.2 | `registry.semaphoreci.com/node:19.2` |
| node:19.2-browsers | `registry.semaphoreci.com/node:19.2-browsers` |
| node:19.2.0 | `registry.semaphoreci.com/node:19.2.0` |
| node:19.2.0-browsers | `registry.semaphoreci.com/node:19.2.0-browsers` |
| node:19.3 | `registry.semaphoreci.com/node:19.3` |
| node:19.3-browsers | `registry.semaphoreci.com/node:19.3-browsers` |
| node:19.3.0 | `registry.semaphoreci.com/node:19.3.0` |
| node:19.3.0-browsers | `registry.semaphoreci.com/node:19.3.0-browsers` |
| node:19.5 | `registry.semaphoreci.com/node:19.5` |
| node:19.5.0 | `registry.semaphoreci.com/node:19.5.0` |
| node:19.8 | `registry.semaphoreci.com/node:19.8` |
| node:19.8.1 | `registry.semaphoreci.com/node:19.8.1` |
| node:19.9 | `registry.semaphoreci.com/node:19.9` |
| node:19.9.0 | `registry.semaphoreci.com/node:19.9.0` |
| node:20 | `registry.semaphoreci.com/node:20` |  
| node:20-browsers | `registry.semaphoreci.com/node:20-browsers` |  
| node:20.0 | `registry.semaphoreci.com/node:20.0` |
| node:20.0.0 | `registry.semaphoreci.com/node:20.0.0` |
| node:20.2 | `registry.semaphoreci.com/node:20.2` |
| node:20.2.0 | `registry.semaphoreci.com/node:20.2.0` |
| node:20.3 | `registry.semaphoreci.com/node:20.3` |
| node:20.3-browsers | `registry.semaphoreci.com/node:20.3-browsers` |
| node:20.3.1 | `registry.semaphoreci.com/node:20.3.1` |
| node:20.3.1-browsers | `registry.semaphoreci.com/node:20.3.1-browsers` |
| node:20.4 | `registry.semaphoreci.com/node:20.4` |
| node:20.4-browsers | `registry.semaphoreci.com/node:20.4-browsers` |
| node:20.4.0 | `registry.semaphoreci.com/node:20.4.0` |
| node:20.4.0-browsers | `registry.semaphoreci.com/node:20.4.0-browsers` |
| node:20.5 | `registry.semaphoreci.com/node:20.5` |
| node:20.5.0 | `registry.semaphoreci.com/node:20.5.0` |
| node:20.5.1 | `registry.semaphoreci.com/node:20.5.1` |
| node:20.6 | `registry.semaphoreci.com/node:20.6` |
| node:20.6-browsers | `registry.semaphoreci.com/node:20.6-browsers` |
| node:20.6.0 | `registry.semaphoreci.com/node:20.6.0` |
| node:20.6.0-browsers | `registry.semaphoreci.com/node:20.6.0-browsers` |
| node:20.8 | `registry.semaphoreci.com/node:20.8` |
| node:20.8-browsers | `registry.semaphoreci.com/node:20.8-browsers` |
| node:20.8.0 | `registry.semaphoreci.com/node:20.8.0` |
| node:20.8.0-browsers | `registry.semaphoreci.com/node:20.8.0-browsers` |
| node:20.9 | `registry.semaphoreci.com/node:20.9` |
| node:20.9-browsers | `registry.semaphoreci.com/node:20.9-browsers` |
| node:20.9.0 | `registry.semaphoreci.com/node:20.9.0` |
| node:20.9.0-browsers | `registry.semaphoreci.com/node:20.9.0-browsers` |
| node:20.10 | `registry.semaphoreci.com/node:20.10` |
| node:20.10-browsers | `registry.semaphoreci.com/node:20.10-browsers` |
| node:20.10.0 | `registry.semaphoreci.com/node:20.10.0` |
| node:20.10.0-browsers | `registry.semaphoreci.com/node:20.10.0-browsers` |
| node:20.11 | `registry.semaphoreci.com/node:20.11` |
| node:20.11-browsers | `registry.semaphoreci.com/node:20.11-browsers` |
| node:20.11.0 | `registry.semaphoreci.com/node:20.11.0` |
| node:20.11.0-browsers | `registry.semaphoreci.com/node:20.11.0-browsers` |
| node:20.11.1 | `registry.semaphoreci.com/node:20.11.1` |
| node:20.12 | `registry.semaphoreci.com/node:20.12` |
| node:20.12.2 | `registry.semaphoreci.com/node:20.12.2` |
| node:20.18 | `registry.semaphoreci.com/node:20.18` |
| node:20.18-browsers | `registry.semaphoreci.com/node:20.18-browsers` |
| node:20.18.0 | `registry.semaphoreci.com/node:20.18.0` |
| node:20.18.0-browsers | `registry.semaphoreci.com/node:20.18.0-browsers` |
| node:20.18.1 | `registry.semaphoreci.com/node:20.18.1` |
| node:20.18.1-browsers | `registry.semaphoreci.com/node:20.18.1-browsers` |
| node:20.18.2 | `registry.semaphoreci.com/node:20.18.2` |
| node:20.18.2-browsers | `registry.semaphoreci.com/node:20.18.2-browsers` |
| node:20.19 | `registry.semaphoreci.com/node:20.19` |
| node:20.19-browsers | `registry.semaphoreci.com/node:20.19-browsers` |
| node:20.19.1 | `registry.semaphoreci.com/node:20.19.1` |
| node:20.19.1-browsers | `registry.semaphoreci.com/node:20.19.1-browsers` |
| node:20.19.2 | `registry.semaphoreci.com/node:20.19.2` |
| node:20.19.2-browsers | `registry.semaphoreci.com/node:20.19.2-browsers` |
| node:20.19.3 | `registry.semaphoreci.com/node:20.19.3` |
| node:20.19.3-browsers | `registry.semaphoreci.com/node:20.19.3-browsers` |
| node:20.19.4 | `registry.semaphoreci.com/node:20.19.4` |
| node:20.19.4-browsers | `registry.semaphoreci.com/node:20.19.4-browsers` |
| node:20.19.5 | `registry.semaphoreci.com/node:20.19.5` |
| node:20.19.6 | `registry.semaphoreci.com/node:20.19.6` |
| node:20.20 | `registry.semaphoreci.com/node:20.20` |
| node:20.20-browsers | `registry.semaphoreci.com/node:20.20-browsers` |
| node:20.20.0 | `registry.semaphoreci.com/node:20.20.0` |
| node:20.20.2 | `registry.semaphoreci.com/node:20.20.2` |
| node:20.20.2-browsers | `registry.semaphoreci.com/node:20.20.2-browsers` |
| node:21 | `registry.semaphoreci.com/node:21` |  
| node:21-browsers | `registry.semaphoreci.com/node:21-browsers` |  
| node:21.1 | `registry.semaphoreci.com/node:21.1` |
| node:21.1-browsers | `registry.semaphoreci.com/node:21.1-browsers` |
| node:21.1.0 | `registry.semaphoreci.com/node:21.1.0` |
| node:21.1.0-browsers | `registry.semaphoreci.com/node:21.1.0-browsers` |
| node:21.2 | `registry.semaphoreci.com/node:21.2` |
| node:21.2-browsers | `registry.semaphoreci.com/node:21.2-browsers` |
| node:21.2.0 | `registry.semaphoreci.com/node:21.2.0` |
| node:21.2.0-browsers | `registry.semaphoreci.com/node:21.2.0-browsers` |
| node:21.6 | `registry.semaphoreci.com/node:21.6` |
| node:21.6-browsers | `registry.semaphoreci.com/node:21.6-browsers` |
| node:21.6.1 | `registry.semaphoreci.com/node:21.6.1` |
| node:21.6.1-browsers | `registry.semaphoreci.com/node:21.6.1-browsers` |
| node:21.6.2 | `registry.semaphoreci.com/node:21.6.2` |
| node:21.7 | `registry.semaphoreci.com/node:21.7` |
| node:21.7.3 | `registry.semaphoreci.com/node:21.7.3` |
| node:22 | `registry.semaphoreci.com/node:22` |  
| node:22-browsers | `registry.semaphoreci.com/node:22-browsers` |  
| node:22.0 | `registry.semaphoreci.com/node:22.0` |
| node:22.0.0 | `registry.semaphoreci.com/node:22.0.0` |
| node:22.10 | `registry.semaphoreci.com/node:22.10` |
| node:22.10-browsers | `registry.semaphoreci.com/node:22.10-browsers` |
| node:22.10.0 | `registry.semaphoreci.com/node:22.10.0` |
| node:22.10.0-browsers | `registry.semaphoreci.com/node:22.10.0-browsers` |
| node:22.11 | `registry.semaphoreci.com/node:22.11` |
| node:22.11-browsers | `registry.semaphoreci.com/node:22.11-browsers` |
| node:22.11.0 | `registry.semaphoreci.com/node:22.11.0` |
| node:22.11.0-browsers | `registry.semaphoreci.com/node:22.11.0-browsers` |
| node:22.12 | `registry.semaphoreci.com/node:22.12` |
| node:22.12-browsers | `registry.semaphoreci.com/node:22.12-browsers` |
| node:22.12.0 | `registry.semaphoreci.com/node:22.12.0` |
| node:22.12.0-browsers | `registry.semaphoreci.com/node:22.12.0-browsers` |
| node:22.13 | `registry.semaphoreci.com/node:22.13` |
| node:22.13-browsers | `registry.semaphoreci.com/node:22.13-browsers` |
| node:22.13.1 | `registry.semaphoreci.com/node:22.13.1` |
| node:22.13.1-browsers | `registry.semaphoreci.com/node:22.13.1-browsers` |
| node:22.14 | `registry.semaphoreci.com/node:22.14` |
| node:22.14.0 | `registry.semaphoreci.com/node:22.14.0` |
| node:22.15 | `registry.semaphoreci.com/node:22.15` |
| node:22.15-browsers | `registry.semaphoreci.com/node:22.15-browsers` |
| node:22.15.0 | `registry.semaphoreci.com/node:22.15.0` |
| node:22.15.0-browsers | `registry.semaphoreci.com/node:22.15.0-browsers` |
| node:22.16 | `registry.semaphoreci.com/node:22.16` |
| node:22.16-browsers | `registry.semaphoreci.com/node:22.16-browsers` |
| node:22.16.0 | `registry.semaphoreci.com/node:22.16.0` |
| node:22.16.0-browsers | `registry.semaphoreci.com/node:22.16.0-browsers` |
| node:22.17 | `registry.semaphoreci.com/node:22.17` |
| node:22.17-browsers | `registry.semaphoreci.com/node:22.17-browsers` |
| node:22.17.0 | `registry.semaphoreci.com/node:22.17.0` |
| node:22.17.0-browsers | `registry.semaphoreci.com/node:22.17.0-browsers` |
| node:22.17.1 | `registry.semaphoreci.com/node:22.17.1` |
| node:22.17.1-browsers | `registry.semaphoreci.com/node:22.17.1-browsers` |
| node:22.19 | `registry.semaphoreci.com/node:22.19` |
| node:22.19.0 | `registry.semaphoreci.com/node:22.19.0` |
| node:22.21 | `registry.semaphoreci.com/node:22.21` |
| node:22.21.1 | `registry.semaphoreci.com/node:22.21.1` |
| node:22.22 | `registry.semaphoreci.com/node:22.22` |
| node:22.22-browsers | `registry.semaphoreci.com/node:22.22-browsers` |
| node:22.22.0 | `registry.semaphoreci.com/node:22.22.0` |
| node:22.22.2 | `registry.semaphoreci.com/node:22.22.2` |
| node:22.22.2-browsers | `registry.semaphoreci.com/node:22.22.2-browsers` |
| node:22.22.3 | `registry.semaphoreci.com/node:22.22.3` |
| node:22.22.3-browsers | `registry.semaphoreci.com/node:22.22.3-browsers` |
| node:22.23 | `registry.semaphoreci.com/node:22.23` |
| node:22.23-browsers | `registry.semaphoreci.com/node:22.23-browsers` |
| node:22.23.1 | `registry.semaphoreci.com/node:22.23.1` |
| node:22.23.1-browsers | `registry.semaphoreci.com/node:22.23.1-browsers` |
| node:22.23.2 | `registry.semaphoreci.com/node:22.23.2` |
| node:22.23.2-browsers | `registry.semaphoreci.com/node:22.23.2-browsers` |
| node:22.23.3 | `registry.semaphoreci.com/node:22.23.3` |
| node:22.23.3-browsers | `registry.semaphoreci.com/node:22.23.3-browsers` |
| node:23 | `registry.semaphoreci.com/node:23` |  
| node:23-browsers | `registry.semaphoreci.com/node:23-browsers` |  
| node:23.0 | `registry.semaphoreci.com/node:23.0` |
| node:23.0-browsers | `registry.semaphoreci.com/node:23.0-browsers` |
| node:23.0.0 | `registry.semaphoreci.com/node:23.0.0` |
| node:23.0.0-browsers | `registry.semaphoreci.com/node:23.0.0-browsers` |
| node:23.1 | `registry.semaphoreci.com/node:23.1` |
| node:23.1-browsers | `registry.semaphoreci.com/node:23.1-browsers` |
| node:23.1.0 | `registry.semaphoreci.com/node:23.1.0` |
| node:23.1.0-browsers | `registry.semaphoreci.com/node:23.1.0-browsers` |
| node:23.3 | `registry.semaphoreci.com/node:23.3` |
| node:23.3-browsers | `registry.semaphoreci.com/node:23.3-browsers` |
| node:23.3.0 | `registry.semaphoreci.com/node:23.3.0` |
| node:23.3.0-browsers | `registry.semaphoreci.com/node:23.3.0-browsers` |
| node:23.5 | `registry.semaphoreci.com/node:23.5` |
| node:23.5-browsers | `registry.semaphoreci.com/node:23.5-browsers` |
| node:23.5.0 | `registry.semaphoreci.com/node:23.5.0` |
| node:23.5.0-browsers | `registry.semaphoreci.com/node:23.5.0-browsers` |
| node:23.7 | `registry.semaphoreci.com/node:23.7` |
| node:23.7-browsers | `registry.semaphoreci.com/node:23.7-browsers` |
| node:23.7.0 | `registry.semaphoreci.com/node:23.7.0` |
| node:23.7.0-browsers | `registry.semaphoreci.com/node:23.7.0-browsers` |
| node:23.9 | `registry.semaphoreci.com/node:23.9` |
| node:23.9.0 | `registry.semaphoreci.com/node:23.9.0` |
| node:23.10 | `registry.semaphoreci.com/node:23.10` |
| node:23.10.0 | `registry.semaphoreci.com/node:23.10.0` |
| node:23.11 | `registry.semaphoreci.com/node:23.11` |
| node:23.11-browsers | `registry.semaphoreci.com/node:23.11-browsers` |
| node:23.11.0 | `registry.semaphoreci.com/node:23.11.0` |
| node:23.11.0-browsers | `registry.semaphoreci.com/node:23.11.0-browsers` |
| node:23.11.1 | `registry.semaphoreci.com/node:23.11.1` |
| node:23.11.1-browsers | `registry.semaphoreci.com/node:23.11.1-browsers` |
| node:24 | `registry.semaphoreci.com/node:24` |  
| node:24-browsers | `registry.semaphoreci.com/node:24-browsers` |  
| node:24.0 | `registry.semaphoreci.com/node:24.0` |
| node:24.0-browsers | `registry.semaphoreci.com/node:24.0-browsers` |
| node:24.0.0 | `registry.semaphoreci.com/node:24.0.0` |
| node:24.0.0-browsers | `registry.semaphoreci.com/node:24.0.0-browsers` |
| node:24.1 | `registry.semaphoreci.com/node:24.1` |
| node:24.1-browsers | `registry.semaphoreci.com/node:24.1-browsers` |
| node:24.1.0 | `registry.semaphoreci.com/node:24.1.0` |
| node:24.1.0-browsers | `registry.semaphoreci.com/node:24.1.0-browsers` |
| node:24.3 | `registry.semaphoreci.com/node:24.3` |
| node:24.3-browsers | `registry.semaphoreci.com/node:24.3-browsers` |
| node:24.3.0 | `registry.semaphoreci.com/node:24.3.0` |
| node:24.3.0-browsers | `registry.semaphoreci.com/node:24.3.0-browsers` |
| node:24.4 | `registry.semaphoreci.com/node:24.4` |
| node:24.4.1 | `registry.semaphoreci.com/node:24.4.1` |
| node:24.7 | `registry.semaphoreci.com/node:24.7` |
| node:24.7.0 | `registry.semaphoreci.com/node:24.7.0` |
| node:24.11 | `registry.semaphoreci.com/node:24.11` |
| node:24.11.0 | `registry.semaphoreci.com/node:24.11.0` |
| node:24.11.1 | `registry.semaphoreci.com/node:24.11.1` |
| node:24.12 | `registry.semaphoreci.com/node:24.12` |
| node:24.12.0 | `registry.semaphoreci.com/node:24.12.0` |
| node:24.13 | `registry.semaphoreci.com/node:24.13` |
| node:24.13.0 | `registry.semaphoreci.com/node:24.13.0` |
| node:24.14 | `registry.semaphoreci.com/node:24.14` |
| node:24.14-browsers | `registry.semaphoreci.com/node:24.14-browsers` |
| node:24.14.0 | `registry.semaphoreci.com/node:24.14.0` |
| node:24.14.1 | `registry.semaphoreci.com/node:24.14.1` |
| node:24.14.1-browsers | `registry.semaphoreci.com/node:24.14.1-browsers` |
| node:24.15 | `registry.semaphoreci.com/node:24.15` |
| node:24.15-browsers | `registry.semaphoreci.com/node:24.15-browsers` |
| node:24.15.0 | `registry.semaphoreci.com/node:24.15.0` |
| node:24.15.0-browsers | `registry.semaphoreci.com/node:24.15.0-browsers` |
| node:24.16 | `registry.semaphoreci.com/node:24.16` |
| node:24.16-browsers | `registry.semaphoreci.com/node:24.16-browsers` |
| node:24.16.0 | `registry.semaphoreci.com/node:24.16.0` |
| node:24.16.0-browsers | `registry.semaphoreci.com/node:24.16.0-browsers` |
| node:24.18 | `registry.semaphoreci.com/node:24.18` |
| node:24.18-browsers | `registry.semaphoreci.com/node:24.18-browsers` |
| node:24.18.0 | `registry.semaphoreci.com/node:24.18.0` |
| node:24.18.0-browsers | `registry.semaphoreci.com/node:24.18.0-browsers` |
| node:24.18.1 | `registry.semaphoreci.com/node:24.18.1` |
| node:24.18.1-browsers | `registry.semaphoreci.com/node:24.18.1-browsers` |
| node:24.20 | `registry.semaphoreci.com/node:24.20` |
| node:24.20-browsers | `registry.semaphoreci.com/node:24.20-browsers` |
| node:24.20.0 | `registry.semaphoreci.com/node:24.20.0` |
| node:24.20.0-browsers | `registry.semaphoreci.com/node:24.20.0-browsers` |
| node:24.21 | `registry.semaphoreci.com/node:24.21` |
| node:24.21-browsers | `registry.semaphoreci.com/node:24.21-browsers` |
| node:24.21.0 | `registry.semaphoreci.com/node:24.21.0` |
| node:24.21.0-browsers | `registry.semaphoreci.com/node:24.21.0-browsers` |
| node:25 | `registry.semaphoreci.com/node:25` |  
| node:25-browsers | `registry.semaphoreci.com/node:25-browsers` |  
| node:25.1 | `registry.semaphoreci.com/node:25.1` |
| node:25.1.0 | `registry.semaphoreci.com/node:25.1.0` |
| node:25.2 | `registry.semaphoreci.com/node:25.2` |
| node:25.2.1 | `registry.semaphoreci.com/node:25.2.1` |
| node:25.5 | `registry.semaphoreci.com/node:25.5` |
| node:25.5.0 | `registry.semaphoreci.com/node:25.5.0` |
| node:25.7 | `registry.semaphoreci.com/node:25.7` |
| node:25.7.0 | `registry.semaphoreci.com/node:25.7.0` |
| node:25.8 | `registry.semaphoreci.com/node:25.8` |
| node:25.8.2 | `registry.semaphoreci.com/node:25.8.2` |
| node:25.9 | `registry.semaphoreci.com/node:25.9` |
| node:25.9-browsers | `registry.semaphoreci.com/node:25.9-browsers` |
| node:25.9.0 | `registry.semaphoreci.com/node:25.9.0` |
| node:25.9.0-browsers | `registry.semaphoreci.com/node:25.9.0-browsers` |
| node:26 | `registry.semaphoreci.com/node:26` |  
| node:26-browsers | `registry.semaphoreci.com/node:26-browsers` |  
| node:26.2 | `registry.semaphoreci.com/node:26.2` |
| node:26.2-browsers | `registry.semaphoreci.com/node:26.2-browsers` |
| node:26.2.0 | `registry.semaphoreci.com/node:26.2.0` |
| node:26.2.0-browsers | `registry.semaphoreci.com/node:26.2.0-browsers` |
| node:26.4 | `registry.semaphoreci.com/node:26.4` |
| node:26.4-browsers | `registry.semaphoreci.com/node:26.4-browsers` |
| node:26.4.0 | `registry.semaphoreci.com/node:26.4.0` |
| node:26.4.0-browsers | `registry.semaphoreci.com/node:26.4.0-browsers` |
| node:26.5 | `registry.semaphoreci.com/node:26.5` |
| node:26.5-browsers | `registry.semaphoreci.com/node:26.5-browsers` |
| node:26.5.1 | `registry.semaphoreci.com/node:26.5.1` |
| node:26.5.1-browsers | `registry.semaphoreci.com/node:26.5.1-browsers` |
| node:26.8 | `registry.semaphoreci.com/node:26.8` |
| node:26.8-browsers | `registry.semaphoreci.com/node:26.8-browsers` |
| node:26.8.1 | `registry.semaphoreci.com/node:26.8.1` |
| node:26.8.1-browsers | `registry.semaphoreci.com/node:26.8.1-browsers` |
| node:26.10 | `registry.semaphoreci.com/node:26.10` |
| node:26.10-browsers | `registry.semaphoreci.com/node:26.10-browsers` |
| node:26.10.0 | `registry.semaphoreci.com/node:26.10.0` |
| node:26.10.0-browsers | `registry.semaphoreci.com/node:26.10.0-browsers` |

</div>
</details>

### Python

Python images come in four variants:

- **base**: base images matching the Python official images
- **node**: base image extended with Node.js
- **browsers**: base image extended with Firefox, Google Chrome, and chromedriver
- **node-browsers**: base image extended with Node.js, Firefox, Google Chrome, and chromedriver. Useful for running browser-based pipelines

<details>
<summary>Python images</summary>
<div>

| Image | Link |
|--------|--------|
| python:3 | `registry.semaphoreci.com/python:3` |
| python:3-browsers | `registry.semaphoreci.com/python:3-browsers` |
| python:3-node | `registry.semaphoreci.com/python:3-node` |
| python:3-node-browsers | `registry.semaphoreci.com/python:3-node-browsers` |
| python:3.6 | `registry.semaphoreci.com/python:3.6` |  
| python:3.6-browsers | `registry.semaphoreci.com/python:3.6-browsers` |
| python:3.6-node | `registry.semaphoreci.com/python:3.6-node` |
| python:3.6-node-browsers | `registry.semaphoreci.com/python:3.6-node-browsers` |  
| python:3.6.12 | `registry.semaphoreci.com/python:3.6.12` |
| python:3.6.12-browsers | `registry.semaphoreci.com/python:3.6.12-browsers` |
| python:3.6.12-node | `registry.semaphoreci.com/python:3.6.12-node` |
| python:3.6.12-node-browsers | `registry.semaphoreci.com/python:3.6.12-node-browsers` |
| python:3.6.13 | `registry.semaphoreci.com/python:3.6.13` |
| python:3.6.13-browsers | `registry.semaphoreci.com/python:3.6.13-browsers` |
| python:3.6.13-node | `registry.semaphoreci.com/python:3.6.13-node` |
| python:3.6.13-node-browsers | `registry.semaphoreci.com/python:3.6.13-node-browsers` |
| python:3.6.14 | `registry.semaphoreci.com/python:3.6.14` |
| python:3.6.14-browsers | `registry.semaphoreci.com/python:3.6.14-browsers` |
| python:3.6.14-node | `registry.semaphoreci.com/python:3.6.14-node` |
| python:3.6.14-node-browsers | `registry.semaphoreci.com/python:3.6.14-node-browsers` |
| python:3.6.15 | `registry.semaphoreci.com/python:3.6.15` |
| python:3.6.15-browsers | `registry.semaphoreci.com/python:3.6.15-browsers` |
| python:3.6.15-node | `registry.semaphoreci.com/python:3.6.15-node` |
| python:3.6.15-node-browsers | `registry.semaphoreci.com/python:3.6.15-node-browsers` |
| python:3.7 | `registry.semaphoreci.com/python:3.7` |  
| python:3.7-browsers | `registry.semaphoreci.com/python:3.7-browsers` |
| python:3.7-node | `registry.semaphoreci.com/python:3.7-node` |
| python:3.7-node-browsers | `registry.semaphoreci.com/python:3.7-node-browsers` |  
| python:3.7.9 | `registry.semaphoreci.com/python:3.7.9` |
| python:3.7.9-browsers | `registry.semaphoreci.com/python:3.7.9-browsers` |
| python:3.7.9-node | `registry.semaphoreci.com/python:3.7.9-node` |
| python:3.7.9-node-browsers | `registry.semaphoreci.com/python:3.7.9-node-browsers` |
| python:3.7.10 | `registry.semaphoreci.com/python:3.7.10` |
| python:3.7.10-browsers | `registry.semaphoreci.com/python:3.7.10-browsers` |
| python:3.7.10-node | `registry.semaphoreci.com/python:3.7.10-node` |
| python:3.7.10-node-browsers | `registry.semaphoreci.com/python:3.7.10-node-browsers` |
| python:3.7.11 | `registry.semaphoreci.com/python:3.7.11` |
| python:3.7.11-browsers | `registry.semaphoreci.com/python:3.7.11-browsers` |
| python:3.7.11-node | `registry.semaphoreci.com/python:3.7.11-node` |
| python:3.7.11-node-browsers | `registry.semaphoreci.com/python:3.7.11-node-browsers` |
| python:3.7.12 | `registry.semaphoreci.com/python:3.7.12` |
| python:3.7.12-browsers | `registry.semaphoreci.com/python:3.7.12-browsers` |
| python:3.7.12-node | `registry.semaphoreci.com/python:3.7.12-node` |
| python:3.7.12-node-browsers | `registry.semaphoreci.com/python:3.7.12-node-browsers` |
| python:3.7.13 | `registry.semaphoreci.com/python:3.7.13` |
| python:3.7.13-browsers | `registry.semaphoreci.com/python:3.7.13-browsers` |
| python:3.7.13-node | `registry.semaphoreci.com/python:3.7.13-node` |
| python:3.7.13-node-browsers | `registry.semaphoreci.com/python:3.7.13-node-browsers` |
| python:3.7.14 | `registry.semaphoreci.com/python:3.7.14` |
| python:3.7.14-browsers | `registry.semaphoreci.com/python:3.7.14-browsers` |
| python:3.7.14-node | `registry.semaphoreci.com/python:3.7.14-node` |
| python:3.7.14-node-browsers | `registry.semaphoreci.com/python:3.7.14-node-browsers` |
| python:3.7.15 | `registry.semaphoreci.com/python:3.7.15` |
| python:3.7.15-browsers | `registry.semaphoreci.com/python:3.7.15-browsers` |
| python:3.7.15-node | `registry.semaphoreci.com/python:3.7.15-node` |
| python:3.7.15-node-browsers | `registry.semaphoreci.com/python:3.7.15-node-browsers` |
| python:3.7.16 | `registry.semaphoreci.com/python:3.7.16` |
| python:3.7.16-browsers | `registry.semaphoreci.com/python:3.7.16-browsers` |
| python:3.7.16-node | `registry.semaphoreci.com/python:3.7.16-node` |
| python:3.7.16-node-browsers | `registry.semaphoreci.com/python:3.7.16-node-browsers` |
| python:3.7.17 | `registry.semaphoreci.com/python:3.7.17` |
| python:3.7.17-browsers | `registry.semaphoreci.com/python:3.7.17-browsers` |
| python:3.7.17-node | `registry.semaphoreci.com/python:3.7.17-node` |
| python:3.7.17-node-browsers | `registry.semaphoreci.com/python:3.7.17-node-browsers` |
| python:3.8 | `registry.semaphoreci.com/python:3.8` |  
| python:3.8-browsers | `registry.semaphoreci.com/python:3.8-browsers` |
| python:3.8-node | `registry.semaphoreci.com/python:3.8-node` |
| python:3.8-node-browsers | `registry.semaphoreci.com/python:3.8-node-browsers` |  
| python:3.8.7 | `registry.semaphoreci.com/python:3.8.7` |
| python:3.8.7-browsers | `registry.semaphoreci.com/python:3.8.7-browsers` |
| python:3.8.7-node | `registry.semaphoreci.com/python:3.8.7-node` |
| python:3.8.7-node-browsers | `registry.semaphoreci.com/python:3.8.7-node-browsers` |
| python:3.8.8 | `registry.semaphoreci.com/python:3.8.8` |
| python:3.8.8-browsers | `registry.semaphoreci.com/python:3.8.8-browsers` |
| python:3.8.8-node | `registry.semaphoreci.com/python:3.8.8-node` |
| python:3.8.8-node-browsers | `registry.semaphoreci.com/python:3.8.8-node-browsers` |
| python:3.8.9 | `registry.semaphoreci.com/python:3.8.9` |
| python:3.8.9-browsers | `registry.semaphoreci.com/python:3.8.9-browsers` |
| python:3.8.9-node | `registry.semaphoreci.com/python:3.8.9-node` |
| python:3.8.9-node-browsers | `registry.semaphoreci.com/python:3.8.9-node-browsers` |
| python:3.8.10 | `registry.semaphoreci.com/python:3.8.10` |
| python:3.8.10-browsers | `registry.semaphoreci.com/python:3.8.10-browsers` |
| python:3.8.10-node | `registry.semaphoreci.com/python:3.8.10-node` |
| python:3.8.10-node-browsers | `registry.semaphoreci.com/python:3.8.10-node-browsers` |
| python:3.8.11 | `registry.semaphoreci.com/python:3.8.11` |
| python:3.8.11-browsers | `registry.semaphoreci.com/python:3.8.11-browsers` |
| python:3.8.11-node | `registry.semaphoreci.com/python:3.8.11-node` |
| python:3.8.11-node-browsers | `registry.semaphoreci.com/python:3.8.11-node-browsers` |
| python:3.8.12 | `registry.semaphoreci.com/python:3.8.12` |
| python:3.8.12-browsers | `registry.semaphoreci.com/python:3.8.12-browsers` |
| python:3.8.12-node | `registry.semaphoreci.com/python:3.8.12-node` |
| python:3.8.12-node-browsers | `registry.semaphoreci.com/python:3.8.12-node-browsers` |
| python:3.8.13 | `registry.semaphoreci.com/python:3.8.13` |
| python:3.8.13-browsers | `registry.semaphoreci.com/python:3.8.13-browsers` |
| python:3.8.13-node | `registry.semaphoreci.com/python:3.8.13-node` |
| python:3.8.13-node-browsers | `registry.semaphoreci.com/python:3.8.13-node-browsers` |
| python:3.8.14 | `registry.semaphoreci.com/python:3.8.14` |
| python:3.8.14-browsers | `registry.semaphoreci.com/python:3.8.14-browsers` |
| python:3.8.14-node | `registry.semaphoreci.com/python:3.8.14-node` |
| python:3.8.14-node-browsers | `registry.semaphoreci.com/python:3.8.14-node-browsers` |
| python:3.8.15 | `registry.semaphoreci.com/python:3.8.15` |
| python:3.8.15-browsers | `registry.semaphoreci.com/python:3.8.15-browsers` |
| python:3.8.15-node | `registry.semaphoreci.com/python:3.8.15-node` |
| python:3.8.15-node-browsers | `registry.semaphoreci.com/python:3.8.15-node-browsers` |
| python:3.8.16 | `registry.semaphoreci.com/python:3.8.16` |
| python:3.8.16-browsers | `registry.semaphoreci.com/python:3.8.16-browsers` |
| python:3.8.16-node | `registry.semaphoreci.com/python:3.8.16-node` |
| python:3.8.16-node-browsers | `registry.semaphoreci.com/python:3.8.16-node-browsers` |
| python:3.8.17 | `registry.semaphoreci.com/python:3.8.17` |
| python:3.8.17-browsers | `registry.semaphoreci.com/python:3.8.17-browsers` |
| python:3.8.17-node | `registry.semaphoreci.com/python:3.8.17-node` |
| python:3.8.17-node-browsers | `registry.semaphoreci.com/python:3.8.17-node-browsers` |
| python:3.8.18 | `registry.semaphoreci.com/python:3.8.18` |
| python:3.8.18-browsers | `registry.semaphoreci.com/python:3.8.18-browsers` |
| python:3.8.18-node | `registry.semaphoreci.com/python:3.8.18-node` |
| python:3.8.18-node-browsers | `registry.semaphoreci.com/python:3.8.18-node-browsers` |
| python:3.8.19 | `registry.semaphoreci.com/python:3.8.19` |
| python:3.8.19-node | `registry.semaphoreci.com/python:3.8.19-node` |
| python:3.9 | `registry.semaphoreci.com/python:3.9` |  
| python:3.9-browsers | `registry.semaphoreci.com/python:3.9-browsers` |
| python:3.9-node | `registry.semaphoreci.com/python:3.9-node` |
| python:3.9-node-browsers | `registry.semaphoreci.com/python:3.9-node-browsers` |  
| python:3.9.1 | `registry.semaphoreci.com/python:3.9.1` |
| python:3.9.1-browsers | `registry.semaphoreci.com/python:3.9.1-browsers` |
| python:3.9.1-node | `registry.semaphoreci.com/python:3.9.1-node` |
| python:3.9.1-node-browsers | `registry.semaphoreci.com/python:3.9.1-node-browsers` |
| python:3.9.2 | `registry.semaphoreci.com/python:3.9.2` |
| python:3.9.2-browsers | `registry.semaphoreci.com/python:3.9.2-browsers` |
| python:3.9.2-node | `registry.semaphoreci.com/python:3.9.2-node` |
| python:3.9.2-node-browsers | `registry.semaphoreci.com/python:3.9.2-node-browsers` |
| python:3.9.4 | `registry.semaphoreci.com/python:3.9.4` |
| python:3.9.4-browsers | `registry.semaphoreci.com/python:3.9.4-browsers` |
| python:3.9.4-node | `registry.semaphoreci.com/python:3.9.4-node` |
| python:3.9.4-node-browsers | `registry.semaphoreci.com/python:3.9.4-node-browsers` |
| python:3.9.5 | `registry.semaphoreci.com/python:3.9.5` |
| python:3.9.5-browsers | `registry.semaphoreci.com/python:3.9.5-browsers` |
| python:3.9.5-node | `registry.semaphoreci.com/python:3.9.5-node` |
| python:3.9.5-node-browsers | `registry.semaphoreci.com/python:3.9.5-node-browsers` |
| python:3.9.6 | `registry.semaphoreci.com/python:3.9.6` |
| python:3.9.6-browsers | `registry.semaphoreci.com/python:3.9.6-browsers` |
| python:3.9.6-node | `registry.semaphoreci.com/python:3.9.6-node` |
| python:3.9.6-node-browsers | `registry.semaphoreci.com/python:3.9.6-node-browsers` |
| python:3.9.7 | `registry.semaphoreci.com/python:3.9.7` |
| python:3.9.7-browsers | `registry.semaphoreci.com/python:3.9.7-browsers` |
| python:3.9.7-node | `registry.semaphoreci.com/python:3.9.7-node` |
| python:3.9.7-node-browsers | `registry.semaphoreci.com/python:3.9.7-node-browsers` |
| python:3.9.9 | `registry.semaphoreci.com/python:3.9.9` |
| python:3.9.9-browsers | `registry.semaphoreci.com/python:3.9.9-browsers` |
| python:3.9.9-node | `registry.semaphoreci.com/python:3.9.9-node` |
| python:3.9.9-node-browsers | `registry.semaphoreci.com/python:3.9.9-node-browsers` |
| python:3.9.10 | `registry.semaphoreci.com/python:3.9.10` |
| python:3.9.10-browsers | `registry.semaphoreci.com/python:3.9.10-browsers` |
| python:3.9.10-node | `registry.semaphoreci.com/python:3.9.10-node` |
| python:3.9.10-node-browsers | `registry.semaphoreci.com/python:3.9.10-node-browsers` |
| python:3.9.12 | `registry.semaphoreci.com/python:3.9.12` |
| python:3.9.12-browsers | `registry.semaphoreci.com/python:3.9.12-browsers` |
| python:3.9.12-node | `registry.semaphoreci.com/python:3.9.12-node` |
| python:3.9.12-node-browsers | `registry.semaphoreci.com/python:3.9.12-node-browsers` |
| python:3.9.13 | `registry.semaphoreci.com/python:3.9.13` |
| python:3.9.13-browsers | `registry.semaphoreci.com/python:3.9.13-browsers` |
| python:3.9.13-node | `registry.semaphoreci.com/python:3.9.13-node` |
| python:3.9.13-node-browsers | `registry.semaphoreci.com/python:3.9.13-node-browsers` |
| python:3.9.14 | `registry.semaphoreci.com/python:3.9.14` |
| python:3.9.14-browsers | `registry.semaphoreci.com/python:3.9.14-browsers` |
| python:3.9.14-node | `registry.semaphoreci.com/python:3.9.14-node` |
| python:3.9.14-node-browsers | `registry.semaphoreci.com/python:3.9.14-node-browsers` |
| python:3.9.15 | `registry.semaphoreci.com/python:3.9.15` |
| python:3.9.15-browsers | `registry.semaphoreci.com/python:3.9.15-browsers` |
| python:3.9.15-node | `registry.semaphoreci.com/python:3.9.15-node` |
| python:3.9.15-node-browsers | `registry.semaphoreci.com/python:3.9.15-node-browsers` |
| python:3.9.16 | `registry.semaphoreci.com/python:3.9.16` |
| python:3.9.16-browsers | `registry.semaphoreci.com/python:3.9.16-browsers` |
| python:3.9.16-node | `registry.semaphoreci.com/python:3.9.16-node` |
| python:3.9.16-node-browsers | `registry.semaphoreci.com/python:3.9.16-node-browsers` |
| python:3.9.17 | `registry.semaphoreci.com/python:3.9.17` |
| python:3.9.17-browsers | `registry.semaphoreci.com/python:3.9.17-browsers` |
| python:3.9.17-node | `registry.semaphoreci.com/python:3.9.17-node` |
| python:3.9.17-node-browsers | `registry.semaphoreci.com/python:3.9.17-node-browsers` |
| python:3.9.18 | `registry.semaphoreci.com/python:3.9.18` |
| python:3.9.18-browsers | `registry.semaphoreci.com/python:3.9.18-browsers` |
| python:3.9.18-node | `registry.semaphoreci.com/python:3.9.18-node` |
| python:3.9.18-node-browsers | `registry.semaphoreci.com/python:3.9.18-node-browsers` |
| python:3.9.19 | `registry.semaphoreci.com/python:3.9.19` |
| python:3.9.19-node | `registry.semaphoreci.com/python:3.9.19-node` |
| python:3.9.20 | `registry.semaphoreci.com/python:3.9.20` |
| python:3.9.20-browsers | `registry.semaphoreci.com/python:3.9.20-browsers` |
| python:3.9.20-node | `registry.semaphoreci.com/python:3.9.20-node` |
| python:3.9.20-node-browsers | `registry.semaphoreci.com/python:3.9.20-node-browsers` |
| python:3.9.21 | `registry.semaphoreci.com/python:3.9.21` |
| python:3.9.21-browsers | `registry.semaphoreci.com/python:3.9.21-browsers` |
| python:3.9.21-node | `registry.semaphoreci.com/python:3.9.21-node` |
| python:3.9.21-node-browsers | `registry.semaphoreci.com/python:3.9.21-node-browsers` |
| python:3.9.22 | `registry.semaphoreci.com/python:3.9.22` |
| python:3.9.22-browsers | `registry.semaphoreci.com/python:3.9.22-browsers` |
| python:3.9.22-node | `registry.semaphoreci.com/python:3.9.22-node` |
| python:3.9.22-node-browsers | `registry.semaphoreci.com/python:3.9.22-node-browsers` |
| python:3.9.23 | `registry.semaphoreci.com/python:3.9.23` |
| python:3.9.23-browsers | `registry.semaphoreci.com/python:3.9.23-browsers` |
| python:3.9.23-node | `registry.semaphoreci.com/python:3.9.23-node` |
| python:3.9.23-node-browsers | `registry.semaphoreci.com/python:3.9.23-node-browsers` |
| python:3.9.25 | `registry.semaphoreci.com/python:3.9.25` |
| python:3.10 | `registry.semaphoreci.com/python:3.10` |  
| python:3.10-browsers | `registry.semaphoreci.com/python:3.10-browsers` |
| python:3.10-node | `registry.semaphoreci.com/python:3.10-node` |
| python:3.10-node-browsers | `registry.semaphoreci.com/python:3.10-node-browsers` |  
| python:3.10.0 | `registry.semaphoreci.com/python:3.10.0` |
| python:3.10.0-browsers | `registry.semaphoreci.com/python:3.10.0-browsers` |
| python:3.10.0-node | `registry.semaphoreci.com/python:3.10.0-node` |
| python:3.10.0-node-browsers | `registry.semaphoreci.com/python:3.10.0-node-browsers` |
| python:3.10.1 | `registry.semaphoreci.com/python:3.10.1` |
| python:3.10.1-browsers | `registry.semaphoreci.com/python:3.10.1-browsers` |
| python:3.10.1-node | `registry.semaphoreci.com/python:3.10.1-node` |
| python:3.10.1-node-browsers | `registry.semaphoreci.com/python:3.10.1-node-browsers` |
| python:3.10.2 | `registry.semaphoreci.com/python:3.10.2` |
| python:3.10.2-browsers | `registry.semaphoreci.com/python:3.10.2-browsers` |
| python:3.10.2-node | `registry.semaphoreci.com/python:3.10.2-node` |
| python:3.10.2-node-browsers | `registry.semaphoreci.com/python:3.10.2-node-browsers` |
| python:3.10.4 | `registry.semaphoreci.com/python:3.10.4` |
| python:3.10.4-browsers | `registry.semaphoreci.com/python:3.10.4-browsers` |
| python:3.10.4-node | `registry.semaphoreci.com/python:3.10.4-node` |
| python:3.10.4-node-browsers | `registry.semaphoreci.com/python:3.10.4-node-browsers` |
| python:3.10.5 | `registry.semaphoreci.com/python:3.10.5` |
| python:3.10.5-browsers | `registry.semaphoreci.com/python:3.10.5-browsers` |
| python:3.10.5-node | `registry.semaphoreci.com/python:3.10.5-node` |
| python:3.10.5-node-browsers | `registry.semaphoreci.com/python:3.10.5-node-browsers` |
| python:3.10.6 | `registry.semaphoreci.com/python:3.10.6` |
| python:3.10.6-browsers | `registry.semaphoreci.com/python:3.10.6-browsers` |
| python:3.10.6-node | `registry.semaphoreci.com/python:3.10.6-node` |
| python:3.10.6-node-browsers | `registry.semaphoreci.com/python:3.10.6-node-browsers` |
| python:3.10.7 | `registry.semaphoreci.com/python:3.10.7` |
| python:3.10.7-browsers | `registry.semaphoreci.com/python:3.10.7-browsers` |
| python:3.10.7-node | `registry.semaphoreci.com/python:3.10.7-node` |
| python:3.10.7-node-browsers | `registry.semaphoreci.com/python:3.10.7-node-browsers` |
| python:3.10.8 | `registry.semaphoreci.com/python:3.10.8` |
| python:3.10.8-browsers | `registry.semaphoreci.com/python:3.10.8-browsers` |
| python:3.10.8-node | `registry.semaphoreci.com/python:3.10.8-node` |
| python:3.10.8-node-browsers | `registry.semaphoreci.com/python:3.10.8-node-browsers` |
| python:3.10.9 | `registry.semaphoreci.com/python:3.10.9` |
| python:3.10.9-browsers | `registry.semaphoreci.com/python:3.10.9-browsers` |
| python:3.10.9-node | `registry.semaphoreci.com/python:3.10.9-node` |
| python:3.10.9-node-browsers | `registry.semaphoreci.com/python:3.10.9-node-browsers` |
| python:3.10.10 | `registry.semaphoreci.com/python:3.10.10` |
| python:3.10.10-node | `registry.semaphoreci.com/python:3.10.10-node` |
| python:3.10.11 | `registry.semaphoreci.com/python:3.10.11` |
| python:3.10.11-node | `registry.semaphoreci.com/python:3.10.11-node` |
| python:3.10.12 | `registry.semaphoreci.com/python:3.10.12` |
| python:3.10.12-browsers | `registry.semaphoreci.com/python:3.10.12-browsers` |
| python:3.10.12-node | `registry.semaphoreci.com/python:3.10.12-node` |
| python:3.10.12-node-browsers | `registry.semaphoreci.com/python:3.10.12-node-browsers` |
| python:3.10.13 | `registry.semaphoreci.com/python:3.10.13` |
| python:3.10.13-browsers | `registry.semaphoreci.com/python:3.10.13-browsers` |
| python:3.10.13-node | `registry.semaphoreci.com/python:3.10.13-node` |
| python:3.10.13-node-browsers | `registry.semaphoreci.com/python:3.10.13-node-browsers` |
| python:3.10.14 | `registry.semaphoreci.com/python:3.10.14` |
| python:3.10.14-node | `registry.semaphoreci.com/python:3.10.14-node` |
| python:3.10.15 | `registry.semaphoreci.com/python:3.10.15` |
| python:3.10.15-browsers | `registry.semaphoreci.com/python:3.10.15-browsers` |
| python:3.10.15-node | `registry.semaphoreci.com/python:3.10.15-node` |
| python:3.10.15-node-browsers | `registry.semaphoreci.com/python:3.10.15-node-browsers` |
| python:3.10.16 | `registry.semaphoreci.com/python:3.10.16` |
| python:3.10.16-browsers | `registry.semaphoreci.com/python:3.10.16-browsers` |
| python:3.10.16-node | `registry.semaphoreci.com/python:3.10.16-node` |
| python:3.10.16-node-browsers | `registry.semaphoreci.com/python:3.10.16-node-browsers` |
| python:3.10.17 | `registry.semaphoreci.com/python:3.10.17` |
| python:3.10.17-browsers | `registry.semaphoreci.com/python:3.10.17-browsers` |
| python:3.10.17-node | `registry.semaphoreci.com/python:3.10.17-node` |
| python:3.10.17-node-browsers | `registry.semaphoreci.com/python:3.10.17-node-browsers` |
| python:3.10.18 | `registry.semaphoreci.com/python:3.10.18` |
| python:3.10.18-browsers | `registry.semaphoreci.com/python:3.10.18-browsers` |
| python:3.10.18-node | `registry.semaphoreci.com/python:3.10.18-node` |
| python:3.10.18-node-browsers | `registry.semaphoreci.com/python:3.10.18-node-browsers` |
| python:3.10.19 | `registry.semaphoreci.com/python:3.10.19` |
| python:3.10.19-node | `registry.semaphoreci.com/python:3.10.19-node` |
| python:3.10.20 | `registry.semaphoreci.com/python:3.10.20` |
| python:3.10.20-browsers | `registry.semaphoreci.com/python:3.10.20-browsers` |
| python:3.10.20-node | `registry.semaphoreci.com/python:3.10.20-node` |
| python:3.10.20-node-browsers | `registry.semaphoreci.com/python:3.10.20-node-browsers` |
| python:3.10.21 | `registry.semaphoreci.com/python:3.10.21` |
| python:3.10.21-browsers | `registry.semaphoreci.com/python:3.10.21-browsers` |
| python:3.10.21-node | `registry.semaphoreci.com/python:3.10.21-node` |
| python:3.10.21-node-browsers | `registry.semaphoreci.com/python:3.10.21-node-browsers` |
| python:3.11 | `registry.semaphoreci.com/python:3.11` |  
| python:3.11-browsers | `registry.semaphoreci.com/python:3.11-browsers` |
| python:3.11-node | `registry.semaphoreci.com/python:3.11-node` |
| python:3.11-node-browsers | `registry.semaphoreci.com/python:3.11-node-browsers` |  
| python:3.11.0 | `registry.semaphoreci.com/python:3.11.0` |
| python:3.11.0-browsers | `registry.semaphoreci.com/python:3.11.0-browsers` |
| python:3.11.0-node | `registry.semaphoreci.com/python:3.11.0-node` |
| python:3.11.0-node-browsers | `registry.semaphoreci.com/python:3.11.0-node-browsers` |
| python:3.11.1 | `registry.semaphoreci.com/python:3.11.1` |
| python:3.11.1-browsers | `registry.semaphoreci.com/python:3.11.1-browsers` |
| python:3.11.1-node | `registry.semaphoreci.com/python:3.11.1-node` |
| python:3.11.1-node-browsers | `registry.semaphoreci.com/python:3.11.1-node-browsers` |
| python:3.11.2 | `registry.semaphoreci.com/python:3.11.2` |
| python:3.11.2-node | `registry.semaphoreci.com/python:3.11.2-node` |
| python:3.11.3 | `registry.semaphoreci.com/python:3.11.3` |
| python:3.11.3-node | `registry.semaphoreci.com/python:3.11.3-node` |
| python:3.11.4 | `registry.semaphoreci.com/python:3.11.4` |
| python:3.11.4-browsers | `registry.semaphoreci.com/python:3.11.4-browsers` |
| python:3.11.4-node | `registry.semaphoreci.com/python:3.11.4-node` |
| python:3.11.4-node-browsers | `registry.semaphoreci.com/python:3.11.4-node-browsers` |
| python:3.11.5 | `registry.semaphoreci.com/python:3.11.5` |
| python:3.11.5-browsers | `registry.semaphoreci.com/python:3.11.5-browsers` |
| python:3.11.5-node | `registry.semaphoreci.com/python:3.11.5-node` |
| python:3.11.5-node-browsers | `registry.semaphoreci.com/python:3.11.5-node-browsers` |
| python:3.11.6 | `registry.semaphoreci.com/python:3.11.6` |
| python:3.11.6-browsers | `registry.semaphoreci.com/python:3.11.6-browsers` |
| python:3.11.6-node | `registry.semaphoreci.com/python:3.11.6-node` |
| python:3.11.6-node-browsers | `registry.semaphoreci.com/python:3.11.6-node-browsers` |
| python:3.11.7 | `registry.semaphoreci.com/python:3.11.7` |
| python:3.11.7-browsers | `registry.semaphoreci.com/python:3.11.7-browsers` |
| python:3.11.7-node | `registry.semaphoreci.com/python:3.11.7-node` |
| python:3.11.7-node-browsers | `registry.semaphoreci.com/python:3.11.7-node-browsers` |
| python:3.11.8 | `registry.semaphoreci.com/python:3.11.8` |
| python:3.11.8-node | `registry.semaphoreci.com/python:3.11.8-node` |
| python:3.11.9 | `registry.semaphoreci.com/python:3.11.9` |
| python:3.11.9-node | `registry.semaphoreci.com/python:3.11.9-node` |
| python:3.11.10 | `registry.semaphoreci.com/python:3.11.10` |
| python:3.11.10-browsers | `registry.semaphoreci.com/python:3.11.10-browsers` |
| python:3.11.10-node | `registry.semaphoreci.com/python:3.11.10-node` |
| python:3.11.10-node-browsers | `registry.semaphoreci.com/python:3.11.10-node-browsers` |
| python:3.11.11 | `registry.semaphoreci.com/python:3.11.11` |
| python:3.11.11-browsers | `registry.semaphoreci.com/python:3.11.11-browsers` |
| python:3.11.11-node | `registry.semaphoreci.com/python:3.11.11-node` |
| python:3.11.11-node-browsers | `registry.semaphoreci.com/python:3.11.11-node-browsers` |
| python:3.11.12 | `registry.semaphoreci.com/python:3.11.12` |
| python:3.11.12-browsers | `registry.semaphoreci.com/python:3.11.12-browsers` |
| python:3.11.12-node | `registry.semaphoreci.com/python:3.11.12-node` |
| python:3.11.12-node-browsers | `registry.semaphoreci.com/python:3.11.12-node-browsers` |
| python:3.11.13 | `registry.semaphoreci.com/python:3.11.13` |
| python:3.11.13-browsers | `registry.semaphoreci.com/python:3.11.13-browsers` |
| python:3.11.13-node | `registry.semaphoreci.com/python:3.11.13-node` |
| python:3.11.13-node-browsers | `registry.semaphoreci.com/python:3.11.13-node-browsers` |
| python:3.11.14 | `registry.semaphoreci.com/python:3.11.14` |
| python:3.11.14-node | `registry.semaphoreci.com/python:3.11.14-node` |
| python:3.11.15 | `registry.semaphoreci.com/python:3.11.15` |
| python:3.11.15-browsers | `registry.semaphoreci.com/python:3.11.15-browsers` |
| python:3.11.15-node | `registry.semaphoreci.com/python:3.11.15-node` |
| python:3.11.15-node-browsers | `registry.semaphoreci.com/python:3.11.15-node-browsers` |
| python:3.11.16 | `registry.semaphoreci.com/python:3.11.16` |
| python:3.11.16-browsers | `registry.semaphoreci.com/python:3.11.16-browsers` |
| python:3.11.16-node | `registry.semaphoreci.com/python:3.11.16-node` |
| python:3.11.16-node-browsers | `registry.semaphoreci.com/python:3.11.16-node-browsers` |
| python:3.12 | `registry.semaphoreci.com/python:3.12` |  
| python:3.12-browsers | `registry.semaphoreci.com/python:3.12-browsers` |
| python:3.12-node | `registry.semaphoreci.com/python:3.12-node` |
| python:3.12-node-browsers | `registry.semaphoreci.com/python:3.12-node-browsers` |  
| python:3.12.0 | `registry.semaphoreci.com/python:3.12.0` |
| python:3.12.0-browsers | `registry.semaphoreci.com/python:3.12.0-browsers` |
| python:3.12.0-node | `registry.semaphoreci.com/python:3.12.0-node` |
| python:3.12.0-node-browsers | `registry.semaphoreci.com/python:3.12.0-node-browsers` |
| python:3.12.1 | `registry.semaphoreci.com/python:3.12.1` |
| python:3.12.1-browsers | `registry.semaphoreci.com/python:3.12.1-browsers` |
| python:3.12.1-node | `registry.semaphoreci.com/python:3.12.1-node` |
| python:3.12.1-node-browsers | `registry.semaphoreci.com/python:3.12.1-node-browsers` |
| python:3.12.2 | `registry.semaphoreci.com/python:3.12.2` |
| python:3.12.2-node | `registry.semaphoreci.com/python:3.12.2-node` |
| python:3.12.3 | `registry.semaphoreci.com/python:3.12.3` |
| python:3.12.3-node | `registry.semaphoreci.com/python:3.12.3-node` |
| python:3.12.7 | `registry.semaphoreci.com/python:3.12.7` |
| python:3.12.7-browsers | `registry.semaphoreci.com/python:3.12.7-browsers` |
| python:3.12.7-node | `registry.semaphoreci.com/python:3.12.7-node` |
| python:3.12.7-node-browsers | `registry.semaphoreci.com/python:3.12.7-node-browsers` |
| python:3.12.8 | `registry.semaphoreci.com/python:3.12.8` |
| python:3.12.8-browsers | `registry.semaphoreci.com/python:3.12.8-browsers` |
| python:3.12.8-node | `registry.semaphoreci.com/python:3.12.8-node` |
| python:3.12.8-node-browsers | `registry.semaphoreci.com/python:3.12.8-node-browsers` |
| python:3.12.9 | `registry.semaphoreci.com/python:3.12.9` |
| python:3.12.9-node | `registry.semaphoreci.com/python:3.12.9-node` |
| python:3.12.10 | `registry.semaphoreci.com/python:3.12.10` |
| python:3.12.10-browsers | `registry.semaphoreci.com/python:3.12.10-browsers` |
| python:3.12.10-node | `registry.semaphoreci.com/python:3.12.10-node` |
| python:3.12.10-node-browsers | `registry.semaphoreci.com/python:3.12.10-node-browsers` |
| python:3.12.11 | `registry.semaphoreci.com/python:3.12.11` |
| python:3.12.11-browsers | `registry.semaphoreci.com/python:3.12.11-browsers` |
| python:3.12.11-node | `registry.semaphoreci.com/python:3.12.11-node` |
| python:3.12.11-node-browsers | `registry.semaphoreci.com/python:3.12.11-node-browsers` |
| python:3.12.12 | `registry.semaphoreci.com/python:3.12.12` |
| python:3.12.12-node | `registry.semaphoreci.com/python:3.12.12-node` |
| python:3.12.13 | `registry.semaphoreci.com/python:3.12.13` |
| python:3.12.13-browsers | `registry.semaphoreci.com/python:3.12.13-browsers` |
| python:3.12.13-node | `registry.semaphoreci.com/python:3.12.13-node` |
| python:3.12.13-node-browsers | `registry.semaphoreci.com/python:3.12.13-node-browsers` |
| python:3.12.14 | `registry.semaphoreci.com/python:3.12.14` |
| python:3.12.14-browsers | `registry.semaphoreci.com/python:3.12.14-browsers` |
| python:3.12.14-node | `registry.semaphoreci.com/python:3.12.14-node` |
| python:3.12.14-node-browsers | `registry.semaphoreci.com/python:3.12.14-node-browsers` |
| python:3.13 | `registry.semaphoreci.com/python:3.13` |  
| python:3.13-browsers | `registry.semaphoreci.com/python:3.13-browsers` |
| python:3.13-node | `registry.semaphoreci.com/python:3.13-node` |
| python:3.13-node-browsers | `registry.semaphoreci.com/python:3.13-node-browsers` |  
| python:3.13.0 | `registry.semaphoreci.com/python:3.13.0` |
| python:3.13.0-browsers | `registry.semaphoreci.com/python:3.13.0-browsers` |
| python:3.13.0-node | `registry.semaphoreci.com/python:3.13.0-node` |
| python:3.13.0-node-browsers | `registry.semaphoreci.com/python:3.13.0-node-browsers` |
| python:3.13.1 | `registry.semaphoreci.com/python:3.13.1` |
| python:3.13.1-browsers | `registry.semaphoreci.com/python:3.13.1-browsers` |
| python:3.13.1-node | `registry.semaphoreci.com/python:3.13.1-node` |
| python:3.13.1-node-browsers | `registry.semaphoreci.com/python:3.13.1-node-browsers` |
| python:3.13.2 | `registry.semaphoreci.com/python:3.13.2` |
| python:3.13.2-node | `registry.semaphoreci.com/python:3.13.2-node` |
| python:3.13.3 | `registry.semaphoreci.com/python:3.13.3` |
| python:3.13.3-browsers | `registry.semaphoreci.com/python:3.13.3-browsers` |
| python:3.13.3-node | `registry.semaphoreci.com/python:3.13.3-node` |
| python:3.13.3-node-browsers | `registry.semaphoreci.com/python:3.13.3-node-browsers` |
| python:3.13.5 | `registry.semaphoreci.com/python:3.13.5` |
| python:3.13.5-browsers | `registry.semaphoreci.com/python:3.13.5-browsers` |
| python:3.13.5-node | `registry.semaphoreci.com/python:3.13.5-node` |
| python:3.13.5-node-browsers | `registry.semaphoreci.com/python:3.13.5-node-browsers` |
| python:3.13.7 | `registry.semaphoreci.com/python:3.13.7` |
| python:3.13.9 | `registry.semaphoreci.com/python:3.13.9` |
| python:3.13.9-node | `registry.semaphoreci.com/python:3.13.9-node` |
| python:3.13.11 | `registry.semaphoreci.com/python:3.13.11` |
| python:3.13.11-node | `registry.semaphoreci.com/python:3.13.11-node` |
| python:3.13.12 | `registry.semaphoreci.com/python:3.13.12` |
| python:3.13.12-node | `registry.semaphoreci.com/python:3.13.12-node` |
| python:3.13.13 | `registry.semaphoreci.com/python:3.13.13` |
| python:3.13.13-browsers | `registry.semaphoreci.com/python:3.13.13-browsers` |
| python:3.13.13-node | `registry.semaphoreci.com/python:3.13.13-node` |
| python:3.13.13-node-browsers | `registry.semaphoreci.com/python:3.13.13-node-browsers` |
| python:3.13.14 | `registry.semaphoreci.com/python:3.13.14` |
| python:3.13.14-browsers | `registry.semaphoreci.com/python:3.13.14-browsers` |
| python:3.13.14-node | `registry.semaphoreci.com/python:3.13.14-node` |
| python:3.13.14-node-browsers | `registry.semaphoreci.com/python:3.13.14-node-browsers` |
| python:3.13.15 | `registry.semaphoreci.com/python:3.13.15` |
| python:3.13.15-browsers | `registry.semaphoreci.com/python:3.13.15-browsers` |
| python:3.13.15-node | `registry.semaphoreci.com/python:3.13.15-node` |
| python:3.13.15-node-browsers | `registry.semaphoreci.com/python:3.13.15-node-browsers` |
| python:3.14 | `registry.semaphoreci.com/python:3.14` |  
| python:3.14-browsers | `registry.semaphoreci.com/python:3.14-browsers` |
| python:3.14-node | `registry.semaphoreci.com/python:3.14-node` |
| python:3.14-node-browsers | `registry.semaphoreci.com/python:3.14-node-browsers` |  
| python:3.14.0 | `registry.semaphoreci.com/python:3.14.0` |
| python:3.14.0-node | `registry.semaphoreci.com/python:3.14.0-node` |
| python:3.14.2 | `registry.semaphoreci.com/python:3.14.2` |
| python:3.14.2-node | `registry.semaphoreci.com/python:3.14.2-node` |
| python:3.14.3 | `registry.semaphoreci.com/python:3.14.3` |
| python:3.14.3-node | `registry.semaphoreci.com/python:3.14.3-node` |
| python:3.14.4 | `registry.semaphoreci.com/python:3.14.4` |
| python:3.14.4-browsers | `registry.semaphoreci.com/python:3.14.4-browsers` |
| python:3.14.4-node | `registry.semaphoreci.com/python:3.14.4-node` |
| python:3.14.4-node-browsers | `registry.semaphoreci.com/python:3.14.4-node-browsers` |
| python:3.14.5 | `registry.semaphoreci.com/python:3.14.5` |
| python:3.14.5-browsers | `registry.semaphoreci.com/python:3.14.5-browsers` |
| python:3.14.5-node | `registry.semaphoreci.com/python:3.14.5-node` |
| python:3.14.5-node-browsers | `registry.semaphoreci.com/python:3.14.5-node-browsers` |
| python:3.14.6 | `registry.semaphoreci.com/python:3.14.6` |
| python:3.14.6-browsers | `registry.semaphoreci.com/python:3.14.6-browsers` |
| python:3.14.6-node | `registry.semaphoreci.com/python:3.14.6-node` |
| python:3.14.6-node-browsers | `registry.semaphoreci.com/python:3.14.6-node-browsers` |
| python:3.14.7 | `registry.semaphoreci.com/python:3.14.7` |
| python:3.14.7-browsers | `registry.semaphoreci.com/python:3.14.7-browsers` |
| python:3.14.7-node | `registry.semaphoreci.com/python:3.14.7-node` |
| python:3.14.7-node-browsers | `registry.semaphoreci.com/python:3.14.7-node-browsers` |

</div>
</details>

### Go

Go images come in four variants:

- **base**: base images matching the Golang official images
- **node**: base image extended with Node.js
- **browsers**: base image extended with Firefox, Google Chrome, and chromedriver
- **node-browsers**: base image extended with Node.js, Firefox, Google Chrome, and chromedriver. Useful for running browser-based pipelines

<details>
<summary>Go images</summary>
<div>

| Image | Link |
|--------|--------|
| golang:1 | `registry.semaphoreci.com/golang:1` |
| golang:1-browsers | `registry.semaphoreci.com/golang:1-browsers` |
| golang:1-node | `registry.semaphoreci.com/golang:1-node` |
| golang:1-node-browsers | `registry.semaphoreci.com/golang:1-node-browsers` |
| golang:1.14 | `registry.semaphoreci.com/golang:1.14` |  
| golang:1.14-browsers | `registry.semaphoreci.com/golang:1.14-browsers` |
| golang:1.14-node | `registry.semaphoreci.com/golang:1.14-node` |
| golang:1.14-node-browsers | `registry.semaphoreci.com/golang:1.14-node-browsers` |  
| golang:1.14.13 | `registry.semaphoreci.com/golang:1.14.13` |
| golang:1.14.13-browsers | `registry.semaphoreci.com/golang:1.14.13-browsers` |
| golang:1.14.13-node | `registry.semaphoreci.com/golang:1.14.13-node` |
| golang:1.14.13-node-browsers | `registry.semaphoreci.com/golang:1.14.13-node-browsers` |
| golang:1.14.14 | `registry.semaphoreci.com/golang:1.14.14` |
| golang:1.14.14-browsers | `registry.semaphoreci.com/golang:1.14.14-browsers` |
| golang:1.14.14-node | `registry.semaphoreci.com/golang:1.14.14-node` |
| golang:1.14.14-node-browsers | `registry.semaphoreci.com/golang:1.14.14-node-browsers` |
| golang:1.15 | `registry.semaphoreci.com/golang:1.15` |  
| golang:1.15-browsers | `registry.semaphoreci.com/golang:1.15-browsers` |
| golang:1.15-node | `registry.semaphoreci.com/golang:1.15-node` |
| golang:1.15-node-browsers | `registry.semaphoreci.com/golang:1.15-node-browsers` |  
| golang:1.15.6 | `registry.semaphoreci.com/golang:1.15.6` |
| golang:1.15.6-browsers | `registry.semaphoreci.com/golang:1.15.6-browsers` |
| golang:1.15.6-node | `registry.semaphoreci.com/golang:1.15.6-node` |
| golang:1.15.6-node-browsers | `registry.semaphoreci.com/golang:1.15.6-node-browsers` |
| golang:1.15.7 | `registry.semaphoreci.com/golang:1.15.7` |
| golang:1.15.7-browsers | `registry.semaphoreci.com/golang:1.15.7-browsers` |
| golang:1.15.7-node | `registry.semaphoreci.com/golang:1.15.7-node` |
| golang:1.15.7-node-browsers | `registry.semaphoreci.com/golang:1.15.7-node-browsers` |
| golang:1.15.8 | `registry.semaphoreci.com/golang:1.15.8` |
| golang:1.15.8-browsers | `registry.semaphoreci.com/golang:1.15.8-browsers` |
| golang:1.15.8-node | `registry.semaphoreci.com/golang:1.15.8-node` |
| golang:1.15.8-node-browsers | `registry.semaphoreci.com/golang:1.15.8-node-browsers` |
| golang:1.15.11 | `registry.semaphoreci.com/golang:1.15.11` |
| golang:1.15.11-browsers | `registry.semaphoreci.com/golang:1.15.11-browsers` |
| golang:1.15.11-node | `registry.semaphoreci.com/golang:1.15.11-node` |
| golang:1.15.11-node-browsers | `registry.semaphoreci.com/golang:1.15.11-node-browsers` |
| golang:1.15.12 | `registry.semaphoreci.com/golang:1.15.12` |
| golang:1.15.12-browsers | `registry.semaphoreci.com/golang:1.15.12-browsers` |
| golang:1.15.12-node | `registry.semaphoreci.com/golang:1.15.12-node` |
| golang:1.15.12-node-browsers | `registry.semaphoreci.com/golang:1.15.12-node-browsers` |
| golang:1.15.13 | `registry.semaphoreci.com/golang:1.15.13` |
| golang:1.15.13-browsers | `registry.semaphoreci.com/golang:1.15.13-browsers` |
| golang:1.15.13-node | `registry.semaphoreci.com/golang:1.15.13-node` |
| golang:1.15.13-node-browsers | `registry.semaphoreci.com/golang:1.15.13-node-browsers` |
| golang:1.15.14 | `registry.semaphoreci.com/golang:1.15.14` |
| golang:1.15.14-browsers | `registry.semaphoreci.com/golang:1.15.14-browsers` |
| golang:1.15.14-node | `registry.semaphoreci.com/golang:1.15.14-node` |
| golang:1.15.14-node-browsers | `registry.semaphoreci.com/golang:1.15.14-node-browsers` |
| golang:1.16 | `registry.semaphoreci.com/golang:1.16` |  
| golang:1.16-browsers | `registry.semaphoreci.com/golang:1.16-browsers` |
| golang:1.16-node | `registry.semaphoreci.com/golang:1.16-node` |
| golang:1.16-node-browsers | `registry.semaphoreci.com/golang:1.16-node-browsers` |  
| golang:1.16.0 | `registry.semaphoreci.com/golang:1.16.0` |
| golang:1.16.0-browsers | `registry.semaphoreci.com/golang:1.16.0-browsers` |
| golang:1.16.0-node | `registry.semaphoreci.com/golang:1.16.0-node` |
| golang:1.16.0-node-browsers | `registry.semaphoreci.com/golang:1.16.0-node-browsers` |
| golang:1.16.3 | `registry.semaphoreci.com/golang:1.16.3` |
| golang:1.16.3-browsers | `registry.semaphoreci.com/golang:1.16.3-browsers` |
| golang:1.16.3-node | `registry.semaphoreci.com/golang:1.16.3-node` |
| golang:1.16.3-node-browsers | `registry.semaphoreci.com/golang:1.16.3-node-browsers` |
| golang:1.16.4 | `registry.semaphoreci.com/golang:1.16.4` |
| golang:1.16.4-browsers | `registry.semaphoreci.com/golang:1.16.4-browsers` |
| golang:1.16.4-node | `registry.semaphoreci.com/golang:1.16.4-node` |
| golang:1.16.4-node-browsers | `registry.semaphoreci.com/golang:1.16.4-node-browsers` |
| golang:1.16.5 | `registry.semaphoreci.com/golang:1.16.5` |
| golang:1.16.5-browsers | `registry.semaphoreci.com/golang:1.16.5-browsers` |
| golang:1.16.5-node | `registry.semaphoreci.com/golang:1.16.5-node` |
| golang:1.16.5-node-browsers | `registry.semaphoreci.com/golang:1.16.5-node-browsers` |
| golang:1.16.6 | `registry.semaphoreci.com/golang:1.16.6` |
| golang:1.16.6-browsers | `registry.semaphoreci.com/golang:1.16.6-browsers` |
| golang:1.16.6-node | `registry.semaphoreci.com/golang:1.16.6-node` |
| golang:1.16.6-node-browsers | `registry.semaphoreci.com/golang:1.16.6-node-browsers` |
| golang:1.16.7 | `registry.semaphoreci.com/golang:1.16.7` |
| golang:1.16.7-browsers | `registry.semaphoreci.com/golang:1.16.7-browsers` |
| golang:1.16.7-node | `registry.semaphoreci.com/golang:1.16.7-node` |
| golang:1.16.7-node-browsers | `registry.semaphoreci.com/golang:1.16.7-node-browsers` |
| golang:1.16.8 | `registry.semaphoreci.com/golang:1.16.8` |
| golang:1.16.8-browsers | `registry.semaphoreci.com/golang:1.16.8-browsers` |
| golang:1.16.8-node | `registry.semaphoreci.com/golang:1.16.8-node` |
| golang:1.16.8-node-browsers | `registry.semaphoreci.com/golang:1.16.8-node-browsers` |
| golang:1.16.9 | `registry.semaphoreci.com/golang:1.16.9` |
| golang:1.16.9-browsers | `registry.semaphoreci.com/golang:1.16.9-browsers` |
| golang:1.16.9-node | `registry.semaphoreci.com/golang:1.16.9-node` |
| golang:1.16.9-node-browsers | `registry.semaphoreci.com/golang:1.16.9-node-browsers` |
| golang:1.16.10 | `registry.semaphoreci.com/golang:1.16.10` |
| golang:1.16.10-browsers | `registry.semaphoreci.com/golang:1.16.10-browsers` |
| golang:1.16.10-node | `registry.semaphoreci.com/golang:1.16.10-node` |
| golang:1.16.10-node-browsers | `registry.semaphoreci.com/golang:1.16.10-node-browsers` |
| golang:1.16.11 | `registry.semaphoreci.com/golang:1.16.11` |
| golang:1.16.11-browsers | `registry.semaphoreci.com/golang:1.16.11-browsers` |
| golang:1.16.11-node | `registry.semaphoreci.com/golang:1.16.11-node` |
| golang:1.16.11-node-browsers | `registry.semaphoreci.com/golang:1.16.11-node-browsers` |
| golang:1.16.12 | `registry.semaphoreci.com/golang:1.16.12` |
| golang:1.16.12-browsers | `registry.semaphoreci.com/golang:1.16.12-browsers` |
| golang:1.16.12-node | `registry.semaphoreci.com/golang:1.16.12-node` |
| golang:1.16.12-node-browsers | `registry.semaphoreci.com/golang:1.16.12-node-browsers` |
| golang:1.16.13 | `registry.semaphoreci.com/golang:1.16.13` |
| golang:1.16.13-browsers | `registry.semaphoreci.com/golang:1.16.13-browsers` |
| golang:1.16.13-node | `registry.semaphoreci.com/golang:1.16.13-node` |
| golang:1.16.13-node-browsers | `registry.semaphoreci.com/golang:1.16.13-node-browsers` |
| golang:1.16.14 | `registry.semaphoreci.com/golang:1.16.14` |
| golang:1.16.14-browsers | `registry.semaphoreci.com/golang:1.16.14-browsers` |
| golang:1.16.14-node | `registry.semaphoreci.com/golang:1.16.14-node` |
| golang:1.16.14-node-browsers | `registry.semaphoreci.com/golang:1.16.14-node-browsers` |
| golang:1.17 | `registry.semaphoreci.com/golang:1.17` |  
| golang:1.17-browsers | `registry.semaphoreci.com/golang:1.17-browsers` |
| golang:1.17-node | `registry.semaphoreci.com/golang:1.17-node` |
| golang:1.17-node-browsers | `registry.semaphoreci.com/golang:1.17-node-browsers` |  
| golang:1.17.0 | `registry.semaphoreci.com/golang:1.17.0` |
| golang:1.17.0-browsers | `registry.semaphoreci.com/golang:1.17.0-browsers` |
| golang:1.17.0-node | `registry.semaphoreci.com/golang:1.17.0-node` |
| golang:1.17.0-node-browsers | `registry.semaphoreci.com/golang:1.17.0-node-browsers` |
| golang:1.17.1 | `registry.semaphoreci.com/golang:1.17.1` |
| golang:1.17.1-browsers | `registry.semaphoreci.com/golang:1.17.1-browsers` |
| golang:1.17.1-node | `registry.semaphoreci.com/golang:1.17.1-node` |
| golang:1.17.1-node-browsers | `registry.semaphoreci.com/golang:1.17.1-node-browsers` |
| golang:1.17.2 | `registry.semaphoreci.com/golang:1.17.2` |
| golang:1.17.2-browsers | `registry.semaphoreci.com/golang:1.17.2-browsers` |
| golang:1.17.2-node | `registry.semaphoreci.com/golang:1.17.2-node` |
| golang:1.17.2-node-browsers | `registry.semaphoreci.com/golang:1.17.2-node-browsers` |
| golang:1.17.3 | `registry.semaphoreci.com/golang:1.17.3` |
| golang:1.17.3-browsers | `registry.semaphoreci.com/golang:1.17.3-browsers` |
| golang:1.17.3-node | `registry.semaphoreci.com/golang:1.17.3-node` |
| golang:1.17.3-node-browsers | `registry.semaphoreci.com/golang:1.17.3-node-browsers` |
| golang:1.17.4 | `registry.semaphoreci.com/golang:1.17.4` |
| golang:1.17.4-browsers | `registry.semaphoreci.com/golang:1.17.4-browsers` |
| golang:1.17.4-node | `registry.semaphoreci.com/golang:1.17.4-node` |
| golang:1.17.4-node-browsers | `registry.semaphoreci.com/golang:1.17.4-node-browsers` |
| golang:1.17.5 | `registry.semaphoreci.com/golang:1.17.5` |
| golang:1.17.5-browsers | `registry.semaphoreci.com/golang:1.17.5-browsers` |
| golang:1.17.5-node | `registry.semaphoreci.com/golang:1.17.5-node` |
| golang:1.17.5-node-browsers | `registry.semaphoreci.com/golang:1.17.5-node-browsers` |
| golang:1.17.6 | `registry.semaphoreci.com/golang:1.17.6` |
| golang:1.17.6-browsers | `registry.semaphoreci.com/golang:1.17.6-browsers` |
| golang:1.17.6-node | `registry.semaphoreci.com/golang:1.17.6-node` |
| golang:1.17.6-node-browsers | `registry.semaphoreci.com/golang:1.17.6-node-browsers` |
| golang:1.17.7 | `registry.semaphoreci.com/golang:1.17.7` |
| golang:1.17.7-browsers | `registry.semaphoreci.com/golang:1.17.7-browsers` |
| golang:1.17.7-node | `registry.semaphoreci.com/golang:1.17.7-node` |
| golang:1.17.7-node-browsers | `registry.semaphoreci.com/golang:1.17.7-node-browsers` |
| golang:1.17.8 | `registry.semaphoreci.com/golang:1.17.8` |
| golang:1.17.8-browsers | `registry.semaphoreci.com/golang:1.17.8-browsers` |
| golang:1.17.8-node | `registry.semaphoreci.com/golang:1.17.8-node` |
| golang:1.17.8-node-browsers | `registry.semaphoreci.com/golang:1.17.8-node-browsers` |
| golang:1.17.9 | `registry.semaphoreci.com/golang:1.17.9` |
| golang:1.17.9-browsers | `registry.semaphoreci.com/golang:1.17.9-browsers` |
| golang:1.17.9-node | `registry.semaphoreci.com/golang:1.17.9-node` |
| golang:1.17.9-node-browsers | `registry.semaphoreci.com/golang:1.17.9-node-browsers` |
| golang:1.17.10 | `registry.semaphoreci.com/golang:1.17.10` |
| golang:1.17.10-browsers | `registry.semaphoreci.com/golang:1.17.10-browsers` |
| golang:1.17.10-node | `registry.semaphoreci.com/golang:1.17.10-node` |
| golang:1.17.10-node-browsers | `registry.semaphoreci.com/golang:1.17.10-node-browsers` |
| golang:1.17.11 | `registry.semaphoreci.com/golang:1.17.11` |
| golang:1.17.11-browsers | `registry.semaphoreci.com/golang:1.17.11-browsers` |
| golang:1.17.11-node | `registry.semaphoreci.com/golang:1.17.11-node` |
| golang:1.17.11-node-browsers | `registry.semaphoreci.com/golang:1.17.11-node-browsers` |
| golang:1.17.12 | `registry.semaphoreci.com/golang:1.17.12` |
| golang:1.17.12-browsers | `registry.semaphoreci.com/golang:1.17.12-browsers` |
| golang:1.17.12-node | `registry.semaphoreci.com/golang:1.17.12-node` |
| golang:1.17.12-node-browsers | `registry.semaphoreci.com/golang:1.17.12-node-browsers` |
| golang:1.18 | `registry.semaphoreci.com/golang:1.18` |  
| golang:1.18-browsers | `registry.semaphoreci.com/golang:1.18-browsers` |
| golang:1.18-node | `registry.semaphoreci.com/golang:1.18-node` |
| golang:1.18-node-browsers | `registry.semaphoreci.com/golang:1.18-node-browsers` |  
| golang:1.18.0 | `registry.semaphoreci.com/golang:1.18.0` |
| golang:1.18.0-browsers | `registry.semaphoreci.com/golang:1.18.0-browsers` |
| golang:1.18.0-node | `registry.semaphoreci.com/golang:1.18.0-node` |
| golang:1.18.0-node-browsers | `registry.semaphoreci.com/golang:1.18.0-node-browsers` |
| golang:1.18.1 | `registry.semaphoreci.com/golang:1.18.1` |
| golang:1.18.1-browsers | `registry.semaphoreci.com/golang:1.18.1-browsers` |
| golang:1.18.1-node | `registry.semaphoreci.com/golang:1.18.1-node` |
| golang:1.18.1-node-browsers | `registry.semaphoreci.com/golang:1.18.1-node-browsers` |
| golang:1.18.2 | `registry.semaphoreci.com/golang:1.18.2` |
| golang:1.18.2-browsers | `registry.semaphoreci.com/golang:1.18.2-browsers` |
| golang:1.18.2-node | `registry.semaphoreci.com/golang:1.18.2-node` |
| golang:1.18.2-node-browsers | `registry.semaphoreci.com/golang:1.18.2-node-browsers` |
| golang:1.18.3 | `registry.semaphoreci.com/golang:1.18.3` |
| golang:1.18.3-browsers | `registry.semaphoreci.com/golang:1.18.3-browsers` |
| golang:1.18.3-node | `registry.semaphoreci.com/golang:1.18.3-node` |
| golang:1.18.3-node-browsers | `registry.semaphoreci.com/golang:1.18.3-node-browsers` |
| golang:1.18.4 | `registry.semaphoreci.com/golang:1.18.4` |
| golang:1.18.4-browsers | `registry.semaphoreci.com/golang:1.18.4-browsers` |
| golang:1.18.4-node | `registry.semaphoreci.com/golang:1.18.4-node` |
| golang:1.18.4-node-browsers | `registry.semaphoreci.com/golang:1.18.4-node-browsers` |
| golang:1.18.5 | `registry.semaphoreci.com/golang:1.18.5` |
| golang:1.18.5-browsers | `registry.semaphoreci.com/golang:1.18.5-browsers` |
| golang:1.18.5-node | `registry.semaphoreci.com/golang:1.18.5-node` |
| golang:1.18.5-node-browsers | `registry.semaphoreci.com/golang:1.18.5-node-browsers` |
| golang:1.18.6 | `registry.semaphoreci.com/golang:1.18.6` |
| golang:1.18.6-browsers | `registry.semaphoreci.com/golang:1.18.6-browsers` |
| golang:1.18.6-node | `registry.semaphoreci.com/golang:1.18.6-node` |
| golang:1.18.6-node-browsers | `registry.semaphoreci.com/golang:1.18.6-node-browsers` |
| golang:1.18.7 | `registry.semaphoreci.com/golang:1.18.7` |
| golang:1.18.7-browsers | `registry.semaphoreci.com/golang:1.18.7-browsers` |
| golang:1.18.7-node | `registry.semaphoreci.com/golang:1.18.7-node` |
| golang:1.18.7-node-browsers | `registry.semaphoreci.com/golang:1.18.7-node-browsers` |
| golang:1.18.8 | `registry.semaphoreci.com/golang:1.18.8` |
| golang:1.18.8-browsers | `registry.semaphoreci.com/golang:1.18.8-browsers` |
| golang:1.18.8-node | `registry.semaphoreci.com/golang:1.18.8-node` |
| golang:1.18.8-node-browsers | `registry.semaphoreci.com/golang:1.18.8-node-browsers` |
| golang:1.18.9 | `registry.semaphoreci.com/golang:1.18.9` |
| golang:1.18.9-browsers | `registry.semaphoreci.com/golang:1.18.9-browsers` |
| golang:1.18.9-node | `registry.semaphoreci.com/golang:1.18.9-node` |
| golang:1.18.9-node-browsers | `registry.semaphoreci.com/golang:1.18.9-node-browsers` |
| golang:1.18.10 | `registry.semaphoreci.com/golang:1.18.10` |
| golang:1.18.10-node | `registry.semaphoreci.com/golang:1.18.10-node` |
| golang:1.19 | `registry.semaphoreci.com/golang:1.19` |  
| golang:1.19-browsers | `registry.semaphoreci.com/golang:1.19-browsers` |
| golang:1.19-node | `registry.semaphoreci.com/golang:1.19-node` |
| golang:1.19-node-browsers | `registry.semaphoreci.com/golang:1.19-node-browsers` |  
| golang:1.19.0 | `registry.semaphoreci.com/golang:1.19.0` |
| golang:1.19.0-browsers | `registry.semaphoreci.com/golang:1.19.0-browsers` |
| golang:1.19.0-node | `registry.semaphoreci.com/golang:1.19.0-node` |
| golang:1.19.0-node-browsers | `registry.semaphoreci.com/golang:1.19.0-node-browsers` |
| golang:1.19.1 | `registry.semaphoreci.com/golang:1.19.1` |
| golang:1.19.1-browsers | `registry.semaphoreci.com/golang:1.19.1-browsers` |
| golang:1.19.1-node | `registry.semaphoreci.com/golang:1.19.1-node` |
| golang:1.19.1-node-browsers | `registry.semaphoreci.com/golang:1.19.1-node-browsers` |
| golang:1.19.2 | `registry.semaphoreci.com/golang:1.19.2` |
| golang:1.19.2-browsers | `registry.semaphoreci.com/golang:1.19.2-browsers` |
| golang:1.19.2-node | `registry.semaphoreci.com/golang:1.19.2-node` |
| golang:1.19.2-node-browsers | `registry.semaphoreci.com/golang:1.19.2-node-browsers` |
| golang:1.19.3 | `registry.semaphoreci.com/golang:1.19.3` |
| golang:1.19.3-browsers | `registry.semaphoreci.com/golang:1.19.3-browsers` |
| golang:1.19.3-node | `registry.semaphoreci.com/golang:1.19.3-node` |
| golang:1.19.3-node-browsers | `registry.semaphoreci.com/golang:1.19.3-node-browsers` |
| golang:1.19.4 | `registry.semaphoreci.com/golang:1.19.4` |
| golang:1.19.4-browsers | `registry.semaphoreci.com/golang:1.19.4-browsers` |
| golang:1.19.4-node | `registry.semaphoreci.com/golang:1.19.4-node` |
| golang:1.19.4-node-browsers | `registry.semaphoreci.com/golang:1.19.4-node-browsers` |
| golang:1.19.5 | `registry.semaphoreci.com/golang:1.19.5` |
| golang:1.19.5-browsers | `registry.semaphoreci.com/golang:1.19.5-browsers` |
| golang:1.19.5-node | `registry.semaphoreci.com/golang:1.19.5-node` |
| golang:1.19.7 | `registry.semaphoreci.com/golang:1.19.7` |
| golang:1.19.7-browsers | `registry.semaphoreci.com/golang:1.19.7-browsers` |
| golang:1.19.7-node | `registry.semaphoreci.com/golang:1.19.7-node` |
| golang:1.19.8 | `registry.semaphoreci.com/golang:1.19.8` |
| golang:1.19.8-browsers | `registry.semaphoreci.com/golang:1.19.8-browsers` |
| golang:1.19.8-node | `registry.semaphoreci.com/golang:1.19.8-node` |
| golang:1.19.8-node-browsers | `registry.semaphoreci.com/golang:1.19.8-node-browsers` |
| golang:1.19.9 | `registry.semaphoreci.com/golang:1.19.9` |
| golang:1.19.9-browsers | `registry.semaphoreci.com/golang:1.19.9-browsers` |
| golang:1.19.9-node | `registry.semaphoreci.com/golang:1.19.9-node` |
| golang:1.19.10 | `registry.semaphoreci.com/golang:1.19.10` |
| golang:1.19.10-node | `registry.semaphoreci.com/golang:1.19.10-node` |
| golang:1.19.11 | `registry.semaphoreci.com/golang:1.19.11` |
| golang:1.19.11-browsers | `registry.semaphoreci.com/golang:1.19.11-browsers` |
| golang:1.19.11-node | `registry.semaphoreci.com/golang:1.19.11-node` |
| golang:1.19.11-node-browsers | `registry.semaphoreci.com/golang:1.19.11-node-browsers` |
| golang:1.20 | `registry.semaphoreci.com/golang:1.20` |  
| golang:1.20-browsers | `registry.semaphoreci.com/golang:1.20-browsers` |
| golang:1.20-node | `registry.semaphoreci.com/golang:1.20-node` |
| golang:1.20-node-browsers | `registry.semaphoreci.com/golang:1.20-node-browsers` |  
| golang:1.20.2 | `registry.semaphoreci.com/golang:1.20.2` |
| golang:1.20.2-browsers | `registry.semaphoreci.com/golang:1.20.2-browsers` |
| golang:1.20.2-node | `registry.semaphoreci.com/golang:1.20.2-node` |
| golang:1.20.2-node-browsers | `registry.semaphoreci.com/golang:1.20.2-node-browsers` |
| golang:1.20.3 | `registry.semaphoreci.com/golang:1.20.3` |
| golang:1.20.3-browsers | `registry.semaphoreci.com/golang:1.20.3-browsers` |
| golang:1.20.3-node | `registry.semaphoreci.com/golang:1.20.3-node` |
| golang:1.20.3-node-browsers | `registry.semaphoreci.com/golang:1.20.3-node-browsers` |
| golang:1.20.4 | `registry.semaphoreci.com/golang:1.20.4` |
| golang:1.20.4-browsers | `registry.semaphoreci.com/golang:1.20.4-browsers` |
| golang:1.20.4-node | `registry.semaphoreci.com/golang:1.20.4-node` |
| golang:1.20.4-node-browsers | `registry.semaphoreci.com/golang:1.20.4-node-browsers` |
| golang:1.20.5 | `registry.semaphoreci.com/golang:1.20.5` |
| golang:1.20.5-node | `registry.semaphoreci.com/golang:1.20.5-node` |
| golang:1.20.6 | `registry.semaphoreci.com/golang:1.20.6` |
| golang:1.20.6-browsers | `registry.semaphoreci.com/golang:1.20.6-browsers` |
| golang:1.20.6-node | `registry.semaphoreci.com/golang:1.20.6-node` |
| golang:1.20.6-node-browsers | `registry.semaphoreci.com/golang:1.20.6-node-browsers` |
| golang:1.20.7 | `registry.semaphoreci.com/golang:1.20.7` |
| golang:1.20.7-browsers | `registry.semaphoreci.com/golang:1.20.7-browsers` |
| golang:1.20.7-node | `registry.semaphoreci.com/golang:1.20.7-node` |
| golang:1.20.7-node-browsers | `registry.semaphoreci.com/golang:1.20.7-node-browsers` |
| golang:1.20.8 | `registry.semaphoreci.com/golang:1.20.8` |
| golang:1.20.8-browsers | `registry.semaphoreci.com/golang:1.20.8-browsers` |
| golang:1.20.8-node | `registry.semaphoreci.com/golang:1.20.8-node` |
| golang:1.20.8-node-browsers | `registry.semaphoreci.com/golang:1.20.8-node-browsers` |
| golang:1.20.10 | `registry.semaphoreci.com/golang:1.20.10` |
| golang:1.20.10-browsers | `registry.semaphoreci.com/golang:1.20.10-browsers` |
| golang:1.20.10-node | `registry.semaphoreci.com/golang:1.20.10-node` |
| golang:1.20.10-node-browsers | `registry.semaphoreci.com/golang:1.20.10-node-browsers` |
| golang:1.20.11 | `registry.semaphoreci.com/golang:1.20.11` |
| golang:1.20.11-browsers | `registry.semaphoreci.com/golang:1.20.11-browsers` |
| golang:1.20.11-node | `registry.semaphoreci.com/golang:1.20.11-node` |
| golang:1.20.11-node-browsers | `registry.semaphoreci.com/golang:1.20.11-node-browsers` |
| golang:1.21 | `registry.semaphoreci.com/golang:1.21` |  
| golang:1.21-browsers | `registry.semaphoreci.com/golang:1.21-browsers` |
| golang:1.21-node | `registry.semaphoreci.com/golang:1.21-node` |
| golang:1.21-node-browsers | `registry.semaphoreci.com/golang:1.21-node-browsers` |  
| golang:1.21.0 | `registry.semaphoreci.com/golang:1.21.0` |
| golang:1.21.0-browsers | `registry.semaphoreci.com/golang:1.21.0-browsers` |
| golang:1.21.0-node | `registry.semaphoreci.com/golang:1.21.0-node` |
| golang:1.21.0-node-browsers | `registry.semaphoreci.com/golang:1.21.0-node-browsers` |
| golang:1.21.1 | `registry.semaphoreci.com/golang:1.21.1` |
| golang:1.21.1-browsers | `registry.semaphoreci.com/golang:1.21.1-browsers` |
| golang:1.21.1-node | `registry.semaphoreci.com/golang:1.21.1-node` |
| golang:1.21.1-node-browsers | `registry.semaphoreci.com/golang:1.21.1-node-browsers` |
| golang:1.21.3 | `registry.semaphoreci.com/golang:1.21.3` |
| golang:1.21.3-browsers | `registry.semaphoreci.com/golang:1.21.3-browsers` |
| golang:1.21.3-node | `registry.semaphoreci.com/golang:1.21.3-node` |
| golang:1.21.3-node-browsers | `registry.semaphoreci.com/golang:1.21.3-node-browsers` |
| golang:1.21.4 | `registry.semaphoreci.com/golang:1.21.4` |
| golang:1.21.4-browsers | `registry.semaphoreci.com/golang:1.21.4-browsers` |
| golang:1.21.4-node | `registry.semaphoreci.com/golang:1.21.4-node` |
| golang:1.21.4-node-browsers | `registry.semaphoreci.com/golang:1.21.4-node-browsers` |
| golang:1.21.7 | `registry.semaphoreci.com/golang:1.21.7` |
| golang:1.21.7-browsers | `registry.semaphoreci.com/golang:1.21.7-browsers` |
| golang:1.21.7-node | `registry.semaphoreci.com/golang:1.21.7-node` |
| golang:1.21.7-node-browsers | `registry.semaphoreci.com/golang:1.21.7-node-browsers` |
| golang:1.21.9 | `registry.semaphoreci.com/golang:1.21.9` |
| golang:1.21.9-node | `registry.semaphoreci.com/golang:1.21.9-node` |
| golang:1.22 | `registry.semaphoreci.com/golang:1.22` |  
| golang:1.22-browsers | `registry.semaphoreci.com/golang:1.22-browsers` |
| golang:1.22-node | `registry.semaphoreci.com/golang:1.22-node` |
| golang:1.22-node-browsers | `registry.semaphoreci.com/golang:1.22-node-browsers` |  
| golang:1.22.0 | `registry.semaphoreci.com/golang:1.22.0` |
| golang:1.22.0-browsers | `registry.semaphoreci.com/golang:1.22.0-browsers` |
| golang:1.22.0-node | `registry.semaphoreci.com/golang:1.22.0-node` |
| golang:1.22.0-node-browsers | `registry.semaphoreci.com/golang:1.22.0-node-browsers` |
| golang:1.22.2 | `registry.semaphoreci.com/golang:1.22.2` |
| golang:1.22.2-node | `registry.semaphoreci.com/golang:1.22.2-node` |
| golang:1.22.8 | `registry.semaphoreci.com/golang:1.22.8` |
| golang:1.22.8-browsers | `registry.semaphoreci.com/golang:1.22.8-browsers` |
| golang:1.22.8-node | `registry.semaphoreci.com/golang:1.22.8-node` |
| golang:1.22.8-node-browsers | `registry.semaphoreci.com/golang:1.22.8-node-browsers` |
| golang:1.22.9 | `registry.semaphoreci.com/golang:1.22.9` |
| golang:1.22.9-browsers | `registry.semaphoreci.com/golang:1.22.9-browsers` |
| golang:1.22.9-node | `registry.semaphoreci.com/golang:1.22.9-node` |
| golang:1.22.9-node-browsers | `registry.semaphoreci.com/golang:1.22.9-node-browsers` |
| golang:1.22.10 | `registry.semaphoreci.com/golang:1.22.10` |
| golang:1.22.10-browsers | `registry.semaphoreci.com/golang:1.22.10-browsers` |
| golang:1.22.10-node | `registry.semaphoreci.com/golang:1.22.10-node` |
| golang:1.22.10-node-browsers | `registry.semaphoreci.com/golang:1.22.10-node-browsers` |
| golang:1.22.11 | `registry.semaphoreci.com/golang:1.22.11` |
| golang:1.22.11-browsers | `registry.semaphoreci.com/golang:1.22.11-browsers` |
| golang:1.22.11-node | `registry.semaphoreci.com/golang:1.22.11-node` |
| golang:1.22.11-node-browsers | `registry.semaphoreci.com/golang:1.22.11-node-browsers` |
| golang:1.23 | `registry.semaphoreci.com/golang:1.23` |  
| golang:1.23-browsers | `registry.semaphoreci.com/golang:1.23-browsers` |
| golang:1.23-node | `registry.semaphoreci.com/golang:1.23-node` |
| golang:1.23-node-browsers | `registry.semaphoreci.com/golang:1.23-node-browsers` |  
| golang:1.23.2 | `registry.semaphoreci.com/golang:1.23.2` |
| golang:1.23.2-browsers | `registry.semaphoreci.com/golang:1.23.2-browsers` |
| golang:1.23.2-node | `registry.semaphoreci.com/golang:1.23.2-node` |
| golang:1.23.2-node-browsers | `registry.semaphoreci.com/golang:1.23.2-node-browsers` |
| golang:1.23.3 | `registry.semaphoreci.com/golang:1.23.3` |
| golang:1.23.3-browsers | `registry.semaphoreci.com/golang:1.23.3-browsers` |
| golang:1.23.3-node | `registry.semaphoreci.com/golang:1.23.3-node` |
| golang:1.23.3-node-browsers | `registry.semaphoreci.com/golang:1.23.3-node-browsers` |
| golang:1.23.4 | `registry.semaphoreci.com/golang:1.23.4` |
| golang:1.23.4-browsers | `registry.semaphoreci.com/golang:1.23.4-browsers` |
| golang:1.23.4-node | `registry.semaphoreci.com/golang:1.23.4-node` |
| golang:1.23.4-node-browsers | `registry.semaphoreci.com/golang:1.23.4-node-browsers` |
| golang:1.23.5 | `registry.semaphoreci.com/golang:1.23.5` |
| golang:1.23.5-browsers | `registry.semaphoreci.com/golang:1.23.5-browsers` |
| golang:1.23.5-node | `registry.semaphoreci.com/golang:1.23.5-node` |
| golang:1.23.5-node-browsers | `registry.semaphoreci.com/golang:1.23.5-node-browsers` |
| golang:1.23.6 | `registry.semaphoreci.com/golang:1.23.6` |
| golang:1.23.6-node | `registry.semaphoreci.com/golang:1.23.6-node` |
| golang:1.23.7 | `registry.semaphoreci.com/golang:1.23.7` |
| golang:1.23.7-node | `registry.semaphoreci.com/golang:1.23.7-node` |
| golang:1.23.8 | `registry.semaphoreci.com/golang:1.23.8` |
| golang:1.23.8-node | `registry.semaphoreci.com/golang:1.23.8-node` |
| golang:1.23.9 | `registry.semaphoreci.com/golang:1.23.9` |
| golang:1.23.9-browsers | `registry.semaphoreci.com/golang:1.23.9-browsers` |
| golang:1.23.9-node | `registry.semaphoreci.com/golang:1.23.9-node` |
| golang:1.23.9-node-browsers | `registry.semaphoreci.com/golang:1.23.9-node-browsers` |
| golang:1.23.10 | `registry.semaphoreci.com/golang:1.23.10` |
| golang:1.23.10-browsers | `registry.semaphoreci.com/golang:1.23.10-browsers` |
| golang:1.23.10-node | `registry.semaphoreci.com/golang:1.23.10-node` |
| golang:1.23.10-node-browsers | `registry.semaphoreci.com/golang:1.23.10-node-browsers` |
| golang:1.23.11 | `registry.semaphoreci.com/golang:1.23.11` |
| golang:1.23.11-node | `registry.semaphoreci.com/golang:1.23.11-node` |
| golang:1.24 | `registry.semaphoreci.com/golang:1.24` |  
| golang:1.24-browsers | `registry.semaphoreci.com/golang:1.24-browsers` |
| golang:1.24-node | `registry.semaphoreci.com/golang:1.24-node` |
| golang:1.24-node-browsers | `registry.semaphoreci.com/golang:1.24-node-browsers` |  
| golang:1.24.0 | `registry.semaphoreci.com/golang:1.24.0` |
| golang:1.24.0-node | `registry.semaphoreci.com/golang:1.24.0-node` |
| golang:1.24.1 | `registry.semaphoreci.com/golang:1.24.1` |
| golang:1.24.1-node | `registry.semaphoreci.com/golang:1.24.1-node` |
| golang:1.24.2 | `registry.semaphoreci.com/golang:1.24.2` |
| golang:1.24.2-node | `registry.semaphoreci.com/golang:1.24.2-node` |
| golang:1.24.3 | `registry.semaphoreci.com/golang:1.24.3` |
| golang:1.24.3-browsers | `registry.semaphoreci.com/golang:1.24.3-browsers` |
| golang:1.24.3-node | `registry.semaphoreci.com/golang:1.24.3-node` |
| golang:1.24.3-node-browsers | `registry.semaphoreci.com/golang:1.24.3-node-browsers` |
| golang:1.24.4 | `registry.semaphoreci.com/golang:1.24.4` |
| golang:1.24.4-browsers | `registry.semaphoreci.com/golang:1.24.4-browsers` |
| golang:1.24.4-node | `registry.semaphoreci.com/golang:1.24.4-node` |
| golang:1.24.4-node-browsers | `registry.semaphoreci.com/golang:1.24.4-node-browsers` |
| golang:1.24.5 | `registry.semaphoreci.com/golang:1.24.5` |
| golang:1.24.5-browsers | `registry.semaphoreci.com/golang:1.24.5-browsers` |
| golang:1.24.5-node | `registry.semaphoreci.com/golang:1.24.5-node` |
| golang:1.24.6 | `registry.semaphoreci.com/golang:1.24.6` |
| golang:1.24.7 | `registry.semaphoreci.com/golang:1.24.7` |
| golang:1.24.7-node | `registry.semaphoreci.com/golang:1.24.7-node` |
| golang:1.24.9 | `registry.semaphoreci.com/golang:1.24.9` |
| golang:1.24.9-node | `registry.semaphoreci.com/golang:1.24.9-node` |
| golang:1.24.10 | `registry.semaphoreci.com/golang:1.24.10` |
| golang:1.24.10-node | `registry.semaphoreci.com/golang:1.24.10-node` |
| golang:1.24.11 | `registry.semaphoreci.com/golang:1.24.11` |
| golang:1.24.11-node | `registry.semaphoreci.com/golang:1.24.11-node` |
| golang:1.24.12 | `registry.semaphoreci.com/golang:1.24.12` |
| golang:1.24.12-node | `registry.semaphoreci.com/golang:1.24.12-node` |
| golang:1.25 | `registry.semaphoreci.com/golang:1.25` |  
| golang:1.25-browsers | `registry.semaphoreci.com/golang:1.25-browsers` |
| golang:1.25-node | `registry.semaphoreci.com/golang:1.25-node` |
| golang:1.25-node-browsers | `registry.semaphoreci.com/golang:1.25-node-browsers` |  
| golang:1.25.1 | `registry.semaphoreci.com/golang:1.25.1` |
| golang:1.25.1-node | `registry.semaphoreci.com/golang:1.25.1-node` |
| golang:1.25.3 | `registry.semaphoreci.com/golang:1.25.3` |
| golang:1.25.3-node | `registry.semaphoreci.com/golang:1.25.3-node` |
| golang:1.25.4 | `registry.semaphoreci.com/golang:1.25.4` |
| golang:1.25.4-node | `registry.semaphoreci.com/golang:1.25.4-node` |
| golang:1.25.5 | `registry.semaphoreci.com/golang:1.25.5` |
| golang:1.25.5-node | `registry.semaphoreci.com/golang:1.25.5-node` |
| golang:1.25.6 | `registry.semaphoreci.com/golang:1.25.6` |
| golang:1.25.6-node | `registry.semaphoreci.com/golang:1.25.6-node` |
| golang:1.25.7 | `registry.semaphoreci.com/golang:1.25.7` |
| golang:1.25.7-node | `registry.semaphoreci.com/golang:1.25.7-node` |
| golang:1.25.8 | `registry.semaphoreci.com/golang:1.25.8` |
| golang:1.25.8-node | `registry.semaphoreci.com/golang:1.25.8-node` |
| golang:1.25.9 | `registry.semaphoreci.com/golang:1.25.9` |
| golang:1.25.9-browsers | `registry.semaphoreci.com/golang:1.25.9-browsers` |
| golang:1.25.9-node | `registry.semaphoreci.com/golang:1.25.9-node` |
| golang:1.25.9-node-browsers | `registry.semaphoreci.com/golang:1.25.9-node-browsers` |
| golang:1.25.10 | `registry.semaphoreci.com/golang:1.25.10` |
| golang:1.25.10-browsers | `registry.semaphoreci.com/golang:1.25.10-browsers` |
| golang:1.25.10-node | `registry.semaphoreci.com/golang:1.25.10-node` |
| golang:1.25.10-node-browsers | `registry.semaphoreci.com/golang:1.25.10-node-browsers` |
| golang:1.25.11 | `registry.semaphoreci.com/golang:1.25.11` |
| golang:1.25.11-browsers | `registry.semaphoreci.com/golang:1.25.11-browsers` |
| golang:1.25.11-node | `registry.semaphoreci.com/golang:1.25.11-node` |
| golang:1.25.11-node-browsers | `registry.semaphoreci.com/golang:1.25.11-node-browsers` |
| golang:1.25.12 | `registry.semaphoreci.com/golang:1.25.12` |
| golang:1.25.12-browsers | `registry.semaphoreci.com/golang:1.25.12-browsers` |
| golang:1.25.12-node | `registry.semaphoreci.com/golang:1.25.12-node` |
| golang:1.25.12-node-browsers | `registry.semaphoreci.com/golang:1.25.12-node-browsers` |
| golang:1.26 | `registry.semaphoreci.com/golang:1.26` |  
| golang:1.26-browsers | `registry.semaphoreci.com/golang:1.26-browsers` |
| golang:1.26-node | `registry.semaphoreci.com/golang:1.26-node` |
| golang:1.26-node-browsers | `registry.semaphoreci.com/golang:1.26-node-browsers` |  
| golang:1.26.0 | `registry.semaphoreci.com/golang:1.26.0` |
| golang:1.26.0-node | `registry.semaphoreci.com/golang:1.26.0-node` |
| golang:1.26.1 | `registry.semaphoreci.com/golang:1.26.1` |
| golang:1.26.1-node | `registry.semaphoreci.com/golang:1.26.1-node` |
| golang:1.26.2 | `registry.semaphoreci.com/golang:1.26.2` |
| golang:1.26.2-browsers | `registry.semaphoreci.com/golang:1.26.2-browsers` |
| golang:1.26.2-node | `registry.semaphoreci.com/golang:1.26.2-node` |
| golang:1.26.2-node-browsers | `registry.semaphoreci.com/golang:1.26.2-node-browsers` |
| golang:1.26.3 | `registry.semaphoreci.com/golang:1.26.3` |
| golang:1.26.3-browsers | `registry.semaphoreci.com/golang:1.26.3-browsers` |
| golang:1.26.3-node | `registry.semaphoreci.com/golang:1.26.3-node` |
| golang:1.26.3-node-browsers | `registry.semaphoreci.com/golang:1.26.3-node-browsers` |
| golang:1.26.4 | `registry.semaphoreci.com/golang:1.26.4` |
| golang:1.26.4-browsers | `registry.semaphoreci.com/golang:1.26.4-browsers` |
| golang:1.26.4-node | `registry.semaphoreci.com/golang:1.26.4-node` |
| golang:1.26.4-node-browsers | `registry.semaphoreci.com/golang:1.26.4-node-browsers` |
| golang:1.26.5 | `registry.semaphoreci.com/golang:1.26.5` |
| golang:1.26.5-browsers | `registry.semaphoreci.com/golang:1.26.5-browsers` |
| golang:1.26.5-node | `registry.semaphoreci.com/golang:1.26.5-node` |
| golang:1.26.5-node-browsers | `registry.semaphoreci.com/golang:1.26.5-node-browsers` |
| golang:1.26.7 | `registry.semaphoreci.com/golang:1.26.7` |
| golang:1.26.7-browsers | `registry.semaphoreci.com/golang:1.26.7-browsers` |
| golang:1.26.7-node | `registry.semaphoreci.com/golang:1.26.7-node` |
| golang:1.26.7-node-browsers | `registry.semaphoreci.com/golang:1.26.7-node-browsers` |
| golang:1.26.8 | `registry.semaphoreci.com/golang:1.26.8` |
| golang:1.26.8-browsers | `registry.semaphoreci.com/golang:1.26.8-browsers` |
| golang:1.26.8-node | `registry.semaphoreci.com/golang:1.26.8-node` |
| golang:1.26.8-node-browsers | `registry.semaphoreci.com/golang:1.26.8-node-browsers` |
| golang:1.27 | `registry.semaphoreci.com/golang:1.27` |  
| golang:1.27-browsers | `registry.semaphoreci.com/golang:1.27-browsers` |
| golang:1.27-node | `registry.semaphoreci.com/golang:1.27-node` |
| golang:1.27-node-browsers | `registry.semaphoreci.com/golang:1.27-node-browsers` |  
| golang:1.27.0 | `registry.semaphoreci.com/golang:1.27.0` |
| golang:1.27.0-browsers | `registry.semaphoreci.com/golang:1.27.0-browsers` |
| golang:1.27.0-node | `registry.semaphoreci.com/golang:1.27.0-node` |
| golang:1.27.0-node-browsers | `registry.semaphoreci.com/golang:1.27.0-node-browsers` |
| golang:1.27.1 | `registry.semaphoreci.com/golang:1.27.1` |
| golang:1.27.1-browsers | `registry.semaphoreci.com/golang:1.27.1-browsers` |
| golang:1.27.1-node | `registry.semaphoreci.com/golang:1.27.1-node` |
| golang:1.27.1-node-browsers | `registry.semaphoreci.com/golang:1.27.1-node-browsers` |

</div>
</details>

### Ruby

Ruby images come in four variants:

- **base**: base images matching the Ruby official images
- **node**: base image extended with Node.js
- **browsers**: base image extended with Firefox, Google Chrome, and chromedriver
- **node-browsers**: base image extended with Node.js, Firefox, Google Chrome, and chromedriver. Useful for running browser-based pipelines

<details>
<summary>Ruby images</summary>
<div>

| Image | Link |
|--------|--------|
| ruby:2 | `registry.semaphoreci.com/ruby:2` |
| ruby:2-browsers | `registry.semaphoreci.com/ruby:2-browsers` |
| ruby:2-node | `registry.semaphoreci.com/ruby:2-node` |
| ruby:2-node-browsers | `registry.semaphoreci.com/ruby:2-node-browsers` |
| ruby:2.4-node-browsers | `registry.semaphoreci.com/ruby:2.4-node-browsers` |  
| ruby:2.5 | `registry.semaphoreci.com/ruby:2.5` |  
| ruby:2.5-browsers | `registry.semaphoreci.com/ruby:2.5-browsers` |
| ruby:2.5-node | `registry.semaphoreci.com/ruby:2.5-node` |
| ruby:2.5-node-browsers | `registry.semaphoreci.com/ruby:2.5-node-browsers` |  
| ruby:2.5.8 | `registry.semaphoreci.com/ruby:2.5.8` |
| ruby:2.5.8-browsers | `registry.semaphoreci.com/ruby:2.5.8-browsers` |
| ruby:2.5.8-node | `registry.semaphoreci.com/ruby:2.5.8-node` |
| ruby:2.5.8-node-browsers | `registry.semaphoreci.com/ruby:2.5.8-node-browsers` |
| ruby:2.5.9 | `registry.semaphoreci.com/ruby:2.5.9` |
| ruby:2.5.9-browsers | `registry.semaphoreci.com/ruby:2.5.9-browsers` |
| ruby:2.5.9-node | `registry.semaphoreci.com/ruby:2.5.9-node` |
| ruby:2.5.9-node-browsers | `registry.semaphoreci.com/ruby:2.5.9-node-browsers` |
| ruby:2.6 | `registry.semaphoreci.com/ruby:2.6` |  
| ruby:2.6-browsers | `registry.semaphoreci.com/ruby:2.6-browsers` |
| ruby:2.6-node | `registry.semaphoreci.com/ruby:2.6-node` |
| ruby:2.6-node-browsers | `registry.semaphoreci.com/ruby:2.6-node-browsers` |  
| ruby:2.6.6 | `registry.semaphoreci.com/ruby:2.6.6` |
| ruby:2.6.6-browsers | `registry.semaphoreci.com/ruby:2.6.6-browsers` |
| ruby:2.6.6-node | `registry.semaphoreci.com/ruby:2.6.6-node` |
| ruby:2.6.6-node-browsers | `registry.semaphoreci.com/ruby:2.6.6-node-browsers` |
| ruby:2.6.7 | `registry.semaphoreci.com/ruby:2.6.7` |
| ruby:2.6.7-browsers | `registry.semaphoreci.com/ruby:2.6.7-browsers` |
| ruby:2.6.7-node | `registry.semaphoreci.com/ruby:2.6.7-node` |
| ruby:2.6.7-node-browsers | `registry.semaphoreci.com/ruby:2.6.7-node-browsers` |
| ruby:2.6.8 | `registry.semaphoreci.com/ruby:2.6.8` |
| ruby:2.6.8-browsers | `registry.semaphoreci.com/ruby:2.6.8-browsers` |
| ruby:2.6.8-node | `registry.semaphoreci.com/ruby:2.6.8-node` |
| ruby:2.6.8-node-browsers | `registry.semaphoreci.com/ruby:2.6.8-node-browsers` |
| ruby:2.6.9 | `registry.semaphoreci.com/ruby:2.6.9` |
| ruby:2.6.9-browsers | `registry.semaphoreci.com/ruby:2.6.9-browsers` |
| ruby:2.6.9-node | `registry.semaphoreci.com/ruby:2.6.9-node` |
| ruby:2.6.9-node-browsers | `registry.semaphoreci.com/ruby:2.6.9-node-browsers` |
| ruby:2.7 | `registry.semaphoreci.com/ruby:2.7` |  
| ruby:2.7-browsers | `registry.semaphoreci.com/ruby:2.7-browsers` |
| ruby:2.7-node | `registry.semaphoreci.com/ruby:2.7-node` |
| ruby:2.7-node-browsers | `registry.semaphoreci.com/ruby:2.7-node-browsers` |  
| ruby:2.7.2 | `registry.semaphoreci.com/ruby:2.7.2` |
| ruby:2.7.2-browsers | `registry.semaphoreci.com/ruby:2.7.2-browsers` |
| ruby:2.7.2-node | `registry.semaphoreci.com/ruby:2.7.2-node` |
| ruby:2.7.2-node-browsers | `registry.semaphoreci.com/ruby:2.7.2-node-browsers` |
| ruby:2.7.3 | `registry.semaphoreci.com/ruby:2.7.3` |
| ruby:2.7.3-browsers | `registry.semaphoreci.com/ruby:2.7.3-browsers` |
| ruby:2.7.3-node | `registry.semaphoreci.com/ruby:2.7.3-node` |
| ruby:2.7.3-node-browsers | `registry.semaphoreci.com/ruby:2.7.3-node-browsers` |
| ruby:2.7.4 | `registry.semaphoreci.com/ruby:2.7.4` |
| ruby:2.7.4-browsers | `registry.semaphoreci.com/ruby:2.7.4-browsers` |
| ruby:2.7.4-node | `registry.semaphoreci.com/ruby:2.7.4-node` |
| ruby:2.7.4-node-browsers | `registry.semaphoreci.com/ruby:2.7.4-node-browsers` |
| ruby:2.7.5 | `registry.semaphoreci.com/ruby:2.7.5` |
| ruby:2.7.5-browsers | `registry.semaphoreci.com/ruby:2.7.5-browsers` |
| ruby:2.7.5-node | `registry.semaphoreci.com/ruby:2.7.5-node` |
| ruby:2.7.5-node-browsers | `registry.semaphoreci.com/ruby:2.7.5-node-browsers` |
| ruby:2.7.6 | `registry.semaphoreci.com/ruby:2.7.6` |
| ruby:2.7.6-browsers | `registry.semaphoreci.com/ruby:2.7.6-browsers` |
| ruby:2.7.6-node | `registry.semaphoreci.com/ruby:2.7.6-node` |
| ruby:2.7.6-node-browsers | `registry.semaphoreci.com/ruby:2.7.6-node-browsers` |
| ruby:2.7.7 | `registry.semaphoreci.com/ruby:2.7.7` |
| ruby:2.7.7-browsers | `registry.semaphoreci.com/ruby:2.7.7-browsers` |
| ruby:2.7.7-node | `registry.semaphoreci.com/ruby:2.7.7-node` |
| ruby:2.7.7-node-browsers | `registry.semaphoreci.com/ruby:2.7.7-node-browsers` |
| ruby:2.7.8 | `registry.semaphoreci.com/ruby:2.7.8` |
| ruby:3 | `registry.semaphoreci.com/ruby:3` |
| ruby:3-browsers | `registry.semaphoreci.com/ruby:3-browsers` |
| ruby:3-node | `registry.semaphoreci.com/ruby:3-node` |
| ruby:3-node-browsers | `registry.semaphoreci.com/ruby:3-node-browsers` |
| ruby:3.0 | `registry.semaphoreci.com/ruby:3.0` |  
| ruby:3.0-browsers | `registry.semaphoreci.com/ruby:3.0-browsers` |
| ruby:3.0-node | `registry.semaphoreci.com/ruby:3.0-node` |
| ruby:3.0-node-browsers | `registry.semaphoreci.com/ruby:3.0-node-browsers` |  
| ruby:3.0.0 | `registry.semaphoreci.com/ruby:3.0.0` |
| ruby:3.0.0-browsers | `registry.semaphoreci.com/ruby:3.0.0-browsers` |
| ruby:3.0.0-node | `registry.semaphoreci.com/ruby:3.0.0-node` |
| ruby:3.0.0-node-browsers | `registry.semaphoreci.com/ruby:3.0.0-node-browsers` |
| ruby:3.0.1 | `registry.semaphoreci.com/ruby:3.0.1` |  
| ruby:3.0.1-browsers | `registry.semaphoreci.com/ruby:3.0.1-browsers` |
| ruby:3.0.1-node | `registry.semaphoreci.com/ruby:3.0.1-node` |
| ruby:3.0.1-node-browsers | `registry.semaphoreci.com/ruby:3.0.1-node-browsers` |  
| ruby:3.0.2 | `registry.semaphoreci.com/ruby:3.0.2` |  
| ruby:3.0.2-browsers | `registry.semaphoreci.com/ruby:3.0.2-browsers` |
| ruby:3.0.2-node | `registry.semaphoreci.com/ruby:3.0.2-node` |
| ruby:3.0.2-node-browsers | `registry.semaphoreci.com/ruby:3.0.2-node-browsers` |  
| ruby:3.0.3 | `registry.semaphoreci.com/ruby:3.0.3` |  
| ruby:3.0.3-browsers | `registry.semaphoreci.com/ruby:3.0.3-browsers` |
| ruby:3.0.3-node | `registry.semaphoreci.com/ruby:3.0.3-node` |
| ruby:3.0.3-node-browsers | `registry.semaphoreci.com/ruby:3.0.3-node-browsers` |  
| ruby:3.0.4 | `registry.semaphoreci.com/ruby:3.0.4` |  
| ruby:3.0.4-browsers | `registry.semaphoreci.com/ruby:3.0.4-browsers` |
| ruby:3.0.4-node | `registry.semaphoreci.com/ruby:3.0.4-node` |
| ruby:3.0.4-node-browsers | `registry.semaphoreci.com/ruby:3.0.4-node-browsers` |  
| ruby:3.0.5 | `registry.semaphoreci.com/ruby:3.0.5` |  
| ruby:3.0.5-browsers | `registry.semaphoreci.com/ruby:3.0.5-browsers` |
| ruby:3.0.5-node | `registry.semaphoreci.com/ruby:3.0.5-node` |
| ruby:3.0.5-node-browsers | `registry.semaphoreci.com/ruby:3.0.5-node-browsers` |  
| ruby:3.0.6 | `registry.semaphoreci.com/ruby:3.0.6` |  
| ruby:3.0.6-browsers | `registry.semaphoreci.com/ruby:3.0.6-browsers` |
| ruby:3.0.6-node | `registry.semaphoreci.com/ruby:3.0.6-node` |
| ruby:3.0.6-node-browsers | `registry.semaphoreci.com/ruby:3.0.6-node-browsers` |  
| ruby:3.0.7 | `registry.semaphoreci.com/ruby:3.0.7` |
| ruby:3.0.7-node | `registry.semaphoreci.com/ruby:3.0.7-node` |
| ruby:3.1 | `registry.semaphoreci.com/ruby:3.1` |  
| ruby:3.1-browsers | `registry.semaphoreci.com/ruby:3.1-browsers` |
| ruby:3.1-node | `registry.semaphoreci.com/ruby:3.1-node` |
| ruby:3.1-node-browsers | `registry.semaphoreci.com/ruby:3.1-node-browsers` |  
| ruby:3.1.0 | `registry.semaphoreci.com/ruby:3.1.0` |  
| ruby:3.1.0-browsers | `registry.semaphoreci.com/ruby:3.1.0-browsers` |
| ruby:3.1.0-node | `registry.semaphoreci.com/ruby:3.1.0-node` |
| ruby:3.1.0-node-browsers | `registry.semaphoreci.com/ruby:3.1.0-node-browsers` |  
| ruby:3.1.1 | `registry.semaphoreci.com/ruby:3.1.1` |  
| ruby:3.1.1-browsers | `registry.semaphoreci.com/ruby:3.1.1-browsers` |
| ruby:3.1.1-node | `registry.semaphoreci.com/ruby:3.1.1-node` |
| ruby:3.1.1-node-browsers | `registry.semaphoreci.com/ruby:3.1.1-node-browsers` |  
| ruby:3.1.2 | `registry.semaphoreci.com/ruby:3.1.2` |  
| ruby:3.1.2-browsers | `registry.semaphoreci.com/ruby:3.1.2-browsers` |
| ruby:3.1.2-node | `registry.semaphoreci.com/ruby:3.1.2-node` |
| ruby:3.1.2-node-browsers | `registry.semaphoreci.com/ruby:3.1.2-node-browsers` |  
| ruby:3.1.3 | `registry.semaphoreci.com/ruby:3.1.3` |  
| ruby:3.1.3-browsers | `registry.semaphoreci.com/ruby:3.1.3-browsers` |
| ruby:3.1.3-node | `registry.semaphoreci.com/ruby:3.1.3-node` |
| ruby:3.1.3-node-browsers | `registry.semaphoreci.com/ruby:3.1.3-node-browsers` |  
| ruby:3.1.4 | `registry.semaphoreci.com/ruby:3.1.4` |  
| ruby:3.1.4-browsers | `registry.semaphoreci.com/ruby:3.1.4-browsers` |
| ruby:3.1.4-node | `registry.semaphoreci.com/ruby:3.1.4-node` |
| ruby:3.1.4-node-browsers | `registry.semaphoreci.com/ruby:3.1.4-node-browsers` |  
| ruby:3.1.5 | `registry.semaphoreci.com/ruby:3.1.5` |
| ruby:3.1.5-node | `registry.semaphoreci.com/ruby:3.1.5-node` |
| ruby:3.1.6 | `registry.semaphoreci.com/ruby:3.1.6` |
| ruby:3.1.6-browsers | `registry.semaphoreci.com/ruby:3.1.6-browsers` |
| ruby:3.1.6-node | `registry.semaphoreci.com/ruby:3.1.6-node` |
| ruby:3.1.6-node-browsers | `registry.semaphoreci.com/ruby:3.1.6-node-browsers` |
| ruby:3.2 | `registry.semaphoreci.com/ruby:3.2` |  
| ruby:3.2-browsers | `registry.semaphoreci.com/ruby:3.2-browsers` |
| ruby:3.2-node | `registry.semaphoreci.com/ruby:3.2-node` |
| ruby:3.2-node-browsers | `registry.semaphoreci.com/ruby:3.2-node-browsers` |  
| ruby:3.2.0 | `registry.semaphoreci.com/ruby:3.2.0` |  
| ruby:3.2.0-browsers | `registry.semaphoreci.com/ruby:3.2.0-browsers` |
| ruby:3.2.0-node | `registry.semaphoreci.com/ruby:3.2.0-node` |
| ruby:3.2.0-node-browsers | `registry.semaphoreci.com/ruby:3.2.0-node-browsers` |  
| ruby:3.2.2 | `registry.semaphoreci.com/ruby:3.2.2` |  
| ruby:3.2.2-browsers | `registry.semaphoreci.com/ruby:3.2.2-browsers` |
| ruby:3.2.2-node | `registry.semaphoreci.com/ruby:3.2.2-node` |
| ruby:3.2.2-node-browsers | `registry.semaphoreci.com/ruby:3.2.2-node-browsers` |  
| ruby:3.2.3 | `registry.semaphoreci.com/ruby:3.2.3` |  
| ruby:3.2.3-browsers | `registry.semaphoreci.com/ruby:3.2.3-browsers` |
| ruby:3.2.3-node | `registry.semaphoreci.com/ruby:3.2.3-node` |
| ruby:3.2.3-node-browsers | `registry.semaphoreci.com/ruby:3.2.3-node-browsers` |  
| ruby:3.2.4 | `registry.semaphoreci.com/ruby:3.2.4` |
| ruby:3.2.4-node | `registry.semaphoreci.com/ruby:3.2.4-node` |
| ruby:3.2.5 | `registry.semaphoreci.com/ruby:3.2.5` |
| ruby:3.2.5-browsers | `registry.semaphoreci.com/ruby:3.2.5-browsers` |
| ruby:3.2.5-node | `registry.semaphoreci.com/ruby:3.2.5-node` |
| ruby:3.2.5-node-browsers | `registry.semaphoreci.com/ruby:3.2.5-node-browsers` |
| ruby:3.2.6 | `registry.semaphoreci.com/ruby:3.2.6` |
| ruby:3.2.6-browsers | `registry.semaphoreci.com/ruby:3.2.6-browsers` |
| ruby:3.2.6-node | `registry.semaphoreci.com/ruby:3.2.6-node` |
| ruby:3.2.6-node-browsers | `registry.semaphoreci.com/ruby:3.2.6-node-browsers` |
| ruby:3.2.8 | `registry.semaphoreci.com/ruby:3.2.8` |
| ruby:3.2.8-browsers | `registry.semaphoreci.com/ruby:3.2.8-browsers` |
| ruby:3.2.8-node | `registry.semaphoreci.com/ruby:3.2.8-node` |
| ruby:3.2.8-node-browsers | `registry.semaphoreci.com/ruby:3.2.8-node-browsers` |
| ruby:3.2.9 | `registry.semaphoreci.com/ruby:3.2.9` |
| ruby:3.2.9-node | `registry.semaphoreci.com/ruby:3.2.9-node` |
| ruby:3.2.10 | `registry.semaphoreci.com/ruby:3.2.10` |
| ruby:3.2.11 | `registry.semaphoreci.com/ruby:3.2.11` |
| ruby:3.2.11-browsers | `registry.semaphoreci.com/ruby:3.2.11-browsers` |
| ruby:3.2.11-node | `registry.semaphoreci.com/ruby:3.2.11-node` |
| ruby:3.2.11-node-browsers | `registry.semaphoreci.com/ruby:3.2.11-node-browsers` |
| ruby:3.3 | `registry.semaphoreci.com/ruby:3.3` |
| ruby:3.3-browsers | `registry.semaphoreci.com/ruby:3.3-browsers` |
| ruby:3.3-node | `registry.semaphoreci.com/ruby:3.3-node` |
| ruby:3.3-node-browsers | `registry.semaphoreci.com/ruby:3.3-node-browsers` |
| ruby:3.3.0 | `registry.semaphoreci.com/ruby:3.3.0` |  
| ruby:3.3.0-browsers | `registry.semaphoreci.com/ruby:3.3.0-browsers` |
| ruby:3.3.0-node | `registry.semaphoreci.com/ruby:3.3.0-node` |
| ruby:3.3.0-node-browsers | `registry.semaphoreci.com/ruby:3.3.0-node-browsers` |  
| ruby:3.3.1 | `registry.semaphoreci.com/ruby:3.3.1` |
| ruby:3.3.1-node | `registry.semaphoreci.com/ruby:3.3.1-node` |
| ruby:3.3.2 | `registry.semaphoreci.com/ruby:3.3.2` |
| ruby:3.3.2-node | `registry.semaphoreci.com/ruby:3.3.2-node` |
| ruby:3.3.3 | `registry.semaphoreci.com/ruby:3.3.3` |
| ruby:3.3.3-node | `registry.semaphoreci.com/ruby:3.3.3-node` |
| ruby:3.3.4 | `registry.semaphoreci.com/ruby:3.3.4` |
| ruby:3.3.4-browsers | `registry.semaphoreci.com/ruby:3.3.4-browsers` |
| ruby:3.3.4-node | `registry.semaphoreci.com/ruby:3.3.4-node` |
| ruby:3.3.4-node-browsers | `registry.semaphoreci.com/ruby:3.3.4-node-browsers` |
| ruby:3.3.5 | `registry.semaphoreci.com/ruby:3.3.5` |
| ruby:3.3.5-browsers | `registry.semaphoreci.com/ruby:3.3.5-browsers` |
| ruby:3.3.5-node | `registry.semaphoreci.com/ruby:3.3.5-node` |
| ruby:3.3.5-node-browsers | `registry.semaphoreci.com/ruby:3.3.5-node-browsers` |
| ruby:3.3.6 | `registry.semaphoreci.com/ruby:3.3.6` |
| ruby:3.3.6-browsers | `registry.semaphoreci.com/ruby:3.3.6-browsers` |
| ruby:3.3.6-node | `registry.semaphoreci.com/ruby:3.3.6-node` |
| ruby:3.3.6-node-browsers | `registry.semaphoreci.com/ruby:3.3.6-node-browsers` |
| ruby:3.3.7 | `registry.semaphoreci.com/ruby:3.3.7` |
| ruby:3.3.7-browsers | `registry.semaphoreci.com/ruby:3.3.7-browsers` |
| ruby:3.3.7-node | `registry.semaphoreci.com/ruby:3.3.7-node` |
| ruby:3.3.7-node-browsers | `registry.semaphoreci.com/ruby:3.3.7-node-browsers` |
| ruby:3.3.8 | `registry.semaphoreci.com/ruby:3.3.8` |
| ruby:3.3.8-browsers | `registry.semaphoreci.com/ruby:3.3.8-browsers` |
| ruby:3.3.8-node | `registry.semaphoreci.com/ruby:3.3.8-node` |
| ruby:3.3.8-node-browsers | `registry.semaphoreci.com/ruby:3.3.8-node-browsers` |
| ruby:3.3.9 | `registry.semaphoreci.com/ruby:3.3.9` |
| ruby:3.3.9-node | `registry.semaphoreci.com/ruby:3.3.9-node` |
| ruby:3.3.10 | `registry.semaphoreci.com/ruby:3.3.10` |
| ruby:3.3.11 | `registry.semaphoreci.com/ruby:3.3.11` |
| ruby:3.3.11-browsers | `registry.semaphoreci.com/ruby:3.3.11-browsers` |
| ruby:3.3.11-node | `registry.semaphoreci.com/ruby:3.3.11-node` |
| ruby:3.3.11-node-browsers | `registry.semaphoreci.com/ruby:3.3.11-node-browsers` |
| ruby:3.3.12 | `registry.semaphoreci.com/ruby:3.3.12` |
| ruby:3.3.12-browsers | `registry.semaphoreci.com/ruby:3.3.12-browsers` |
| ruby:3.3.12-node | `registry.semaphoreci.com/ruby:3.3.12-node` |
| ruby:3.3.12-node-browsers | `registry.semaphoreci.com/ruby:3.3.12-node-browsers` |
| ruby:3.4 | `registry.semaphoreci.com/ruby:3.4` |
| ruby:3.4-browsers | `registry.semaphoreci.com/ruby:3.4-browsers` |
| ruby:3.4-node | `registry.semaphoreci.com/ruby:3.4-node` |
| ruby:3.4-node-browsers | `registry.semaphoreci.com/ruby:3.4-node-browsers` |
| ruby:3.4.1 | `registry.semaphoreci.com/ruby:3.4.1` |
| ruby:3.4.1-browsers | `registry.semaphoreci.com/ruby:3.4.1-browsers` |
| ruby:3.4.1-node | `registry.semaphoreci.com/ruby:3.4.1-node` |
| ruby:3.4.1-node-browsers | `registry.semaphoreci.com/ruby:3.4.1-node-browsers` |
| ruby:3.4.2 | `registry.semaphoreci.com/ruby:3.4.2` |
| ruby:3.4.3 | `registry.semaphoreci.com/ruby:3.4.3` |
| ruby:3.4.3-browsers | `registry.semaphoreci.com/ruby:3.4.3-browsers` |
| ruby:3.4.3-node | `registry.semaphoreci.com/ruby:3.4.3-node` |
| ruby:3.4.3-node-browsers | `registry.semaphoreci.com/ruby:3.4.3-node-browsers` |
| ruby:3.4.4 | `registry.semaphoreci.com/ruby:3.4.4` |
| ruby:3.4.4-browsers | `registry.semaphoreci.com/ruby:3.4.4-browsers` |
| ruby:3.4.4-node | `registry.semaphoreci.com/ruby:3.4.4-node` |
| ruby:3.4.4-node-browsers | `registry.semaphoreci.com/ruby:3.4.4-node-browsers` |
| ruby:3.4.5 | `registry.semaphoreci.com/ruby:3.4.5` |
| ruby:3.4.5-node | `registry.semaphoreci.com/ruby:3.4.5-node` |
| ruby:3.4.7 | `registry.semaphoreci.com/ruby:3.4.7` |
| ruby:3.4.7-node | `registry.semaphoreci.com/ruby:3.4.7-node` |
| ruby:3.4.8 | `registry.semaphoreci.com/ruby:3.4.8` |
| ruby:3.4.9 | `registry.semaphoreci.com/ruby:3.4.9` |
| ruby:3.4.9-browsers | `registry.semaphoreci.com/ruby:3.4.9-browsers` |
| ruby:3.4.9-node | `registry.semaphoreci.com/ruby:3.4.9-node` |
| ruby:3.4.9-node-browsers | `registry.semaphoreci.com/ruby:3.4.9-node-browsers` |
| ruby:3.4.10 | `registry.semaphoreci.com/ruby:3.4.10` |
| ruby:3.4.10-browsers | `registry.semaphoreci.com/ruby:3.4.10-browsers` |
| ruby:3.4.10-node | `registry.semaphoreci.com/ruby:3.4.10-node` |
| ruby:3.4.10-node-browsers | `registry.semaphoreci.com/ruby:3.4.10-node-browsers` |
| ruby:3.4.11 | `registry.semaphoreci.com/ruby:3.4.11` |
| ruby:3.4.11-browsers | `registry.semaphoreci.com/ruby:3.4.11-browsers` |
| ruby:3.4.11-node | `registry.semaphoreci.com/ruby:3.4.11-node` |
| ruby:3.4.11-node-browsers | `registry.semaphoreci.com/ruby:3.4.11-node-browsers` |
| ruby:4 | `registry.semaphoreci.com/ruby:4` |
| ruby:4-browsers | `registry.semaphoreci.com/ruby:4-browsers` |
| ruby:4-node | `registry.semaphoreci.com/ruby:4-node` |
| ruby:4-node-browsers | `registry.semaphoreci.com/ruby:4-node-browsers` |
| ruby:4.0 | `registry.semaphoreci.com/ruby:4.0` |
| ruby:4.0-browsers | `registry.semaphoreci.com/ruby:4.0-browsers` |
| ruby:4.0-node | `registry.semaphoreci.com/ruby:4.0-node` |
| ruby:4.0-node-browsers | `registry.semaphoreci.com/ruby:4.0-node-browsers` |
| ruby:4.0.0 | `registry.semaphoreci.com/ruby:4.0.0` |
| ruby:4.0.1 | `registry.semaphoreci.com/ruby:4.0.1` |
| ruby:4.0.2 | `registry.semaphoreci.com/ruby:4.0.2` |
| ruby:4.0.2-browsers | `registry.semaphoreci.com/ruby:4.0.2-browsers` |
| ruby:4.0.2-node | `registry.semaphoreci.com/ruby:4.0.2-node` |
| ruby:4.0.2-node-browsers | `registry.semaphoreci.com/ruby:4.0.2-node-browsers` |
| ruby:4.0.3 | `registry.semaphoreci.com/ruby:4.0.3` |
| ruby:4.0.3-browsers | `registry.semaphoreci.com/ruby:4.0.3-browsers` |
| ruby:4.0.3-node | `registry.semaphoreci.com/ruby:4.0.3-node` |
| ruby:4.0.3-node-browsers | `registry.semaphoreci.com/ruby:4.0.3-node-browsers` |
| ruby:4.0.5 | `registry.semaphoreci.com/ruby:4.0.5` |
| ruby:4.0.5-browsers | `registry.semaphoreci.com/ruby:4.0.5-browsers` |
| ruby:4.0.5-node | `registry.semaphoreci.com/ruby:4.0.5-node` |
| ruby:4.0.5-node-browsers | `registry.semaphoreci.com/ruby:4.0.5-node-browsers` |
| ruby:4.0.6 | `registry.semaphoreci.com/ruby:4.0.6` |
| ruby:4.0.6-browsers | `registry.semaphoreci.com/ruby:4.0.6-browsers` |
| ruby:4.0.6-node | `registry.semaphoreci.com/ruby:4.0.6-node` |
| ruby:4.0.6-node-browsers | `registry.semaphoreci.com/ruby:4.0.6-node-browsers` |
| ruby:4.0.7 | `registry.semaphoreci.com/ruby:4.0.7` |
| ruby:4.0.7-browsers | `registry.semaphoreci.com/ruby:4.0.7-browsers` |
| ruby:4.0.7-node | `registry.semaphoreci.com/ruby:4.0.7-node` |
| ruby:4.0.7-node-browsers | `registry.semaphoreci.com/ruby:4.0.7-node-browsers` |



</div>
</details>


### PHP

PHP images come in four variants:

- **base**: base images matching the PHP official images
- **node**: base image extended with Node.js
- **browsers**: base image extended with Firefox, Google Chrome, and chromedriver
- **node-browsers**: base image extended with Node.js, Firefox, Google Chrome, and chromedriver. Useful for running browser-based pipelines

<details>
<summary>PHP images</summary>
<div>

| Image | Link |
|--------|--------|
| php:7 | `registry.semaphoreci.com/php:7` |
| php:7-browsers | `registry.semaphoreci.com/php:7-browsers` |
| php:7-node | `registry.semaphoreci.com/php:7-node` |
| php:7-node-browsers | `registry.semaphoreci.com/php:7-node-browsers` |
| php:7.3 | `registry.semaphoreci.com/php:7.3` |
| php:7.3-browsers | `registry.semaphoreci.com/php:7.3-browsers` |
| php:7.3-node | `registry.semaphoreci.com/php:7.3-node` |
| php:7.3-node-browsers | `registry.semaphoreci.com/php:7.3-node-browsers` |
| php:7.3.26 | `registry.semaphoreci.com/php:7.3.26` |
| php:7.3.26-browsers | `registry.semaphoreci.com/php:7.3.26-browsers` |
| php:7.3.26-node | `registry.semaphoreci.com/php:7.3.26-node` |
| php:7.3.26-node-browsers | `registry.semaphoreci.com/php:7.3.26-node-browsers` |
| php:7.3.27 | `registry.semaphoreci.com/php:7.3.27` |
| php:7.3.27-browsers | `registry.semaphoreci.com/php:7.3.27-browsers` |
| php:7.3.27-node | `registry.semaphoreci.com/php:7.3.27-node` |
| php:7.3.27-node-browsers | `registry.semaphoreci.com/php:7.3.27-node-browsers` |
| php:7.3.28 | `registry.semaphoreci.com/php:7.3.28` |
| php:7.3.28-browsers | `registry.semaphoreci.com/php:7.3.28-browsers` |
| php:7.3.28-node | `registry.semaphoreci.com/php:7.3.28-node` |
| php:7.3.28-node-browsers | `registry.semaphoreci.com/php:7.3.28-node-browsers` |
| php:7.3.29 | `registry.semaphoreci.com/php:7.3.29` |
| php:7.3.29-browsers | `registry.semaphoreci.com/php:7.3.29-browsers` |
| php:7.3.29-node | `registry.semaphoreci.com/php:7.3.29-node` |
| php:7.3.29-node-browsers | `registry.semaphoreci.com/php:7.3.29-node-browsers` |
| php:7.3.30 | `registry.semaphoreci.com/php:7.3.30` |
| php:7.3.30-browsers | `registry.semaphoreci.com/php:7.3.30-browsers` |
| php:7.3.30-node | `registry.semaphoreci.com/php:7.3.30-node` |
| php:7.3.30-node-browsers | `registry.semaphoreci.com/php:7.3.30-node-browsers` |
| php:7.3.31 | `registry.semaphoreci.com/php:7.3.31` |
| php:7.3.31-browsers | `registry.semaphoreci.com/php:7.3.31-browsers` |
| php:7.3.31-node | `registry.semaphoreci.com/php:7.3.31-node` |
| php:7.3.31-node-browsers | `registry.semaphoreci.com/php:7.3.31-node-browsers` |
| php:7.3.32 | `registry.semaphoreci.com/php:7.3.32` |
| php:7.3.32-browsers | `registry.semaphoreci.com/php:7.3.32-browsers` |
| php:7.3.32-node | `registry.semaphoreci.com/php:7.3.32-node` |
| php:7.3.32-node-browsers | `registry.semaphoreci.com/php:7.3.32-node-browsers` |
| php:7.3.33 | `registry.semaphoreci.com/php:7.3.33` |
| php:7.3.33-browsers | `registry.semaphoreci.com/php:7.3.33-browsers` |
| php:7.3.33-node | `registry.semaphoreci.com/php:7.3.33-node` |
| php:7.3.33-node-browsers | `registry.semaphoreci.com/php:7.3.33-node-browsers` |
| php:7.4 | `registry.semaphoreci.com/php:7.4` |
| php:7.4-browsers | `registry.semaphoreci.com/php:7.4-browsers` |
| php:7.4-node | `registry.semaphoreci.com/php:7.4-node` |
| php:7.4-node-browsers | `registry.semaphoreci.com/php:7.4-node-browsers` |
| php:7.4.14 | `registry.semaphoreci.com/php:7.4.14` |
| php:7.4.14-browsers | `registry.semaphoreci.com/php:7.4.14-browsers` |
| php:7.4.14-node | `registry.semaphoreci.com/php:7.4.14-node` |
| php:7.4.14-node-browsers | `registry.semaphoreci.com/php:7.4.14-node-browsers` |
| php:7.4.15 | `registry.semaphoreci.com/php:7.4.15` |
| php:7.4.15-browsers | `registry.semaphoreci.com/php:7.4.15-browsers` |
| php:7.4.15-node | `registry.semaphoreci.com/php:7.4.15-node` |
| php:7.4.15-node-browsers | `registry.semaphoreci.com/php:7.4.15-node-browsers` |
| php:7.4.16 | `registry.semaphoreci.com/php:7.4.16` |
| php:7.4.16-browsers | `registry.semaphoreci.com/php:7.4.16-browsers` |
| php:7.4.16-node | `registry.semaphoreci.com/php:7.4.16-node` |
| php:7.4.16-node-browsers | `registry.semaphoreci.com/php:7.4.16-node-browsers` |
| php:7.4.18 | `registry.semaphoreci.com/php:7.4.18` |
| php:7.4.18-browsers | `registry.semaphoreci.com/php:7.4.18-browsers` |
| php:7.4.18-node | `registry.semaphoreci.com/php:7.4.18-node` |
| php:7.4.18-node-browsers | `registry.semaphoreci.com/php:7.4.18-node-browsers` |
| php:7.4.19 | `registry.semaphoreci.com/php:7.4.19` |
| php:7.4.19-browsers | `registry.semaphoreci.com/php:7.4.19-browsers` |
| php:7.4.19-node | `registry.semaphoreci.com/php:7.4.19-node` |
| php:7.4.19-node-browsers | `registry.semaphoreci.com/php:7.4.19-node-browsers` |
| php:7.4.20 | `registry.semaphoreci.com/php:7.4.20` |
| php:7.4.20-browsers | `registry.semaphoreci.com/php:7.4.20-browsers` |
| php:7.4.20-node | `registry.semaphoreci.com/php:7.4.20-node` |
| php:7.4.20-node-browsers | `registry.semaphoreci.com/php:7.4.20-node-browsers` |
| php:7.4.22 | `registry.semaphoreci.com/php:7.4.22` |
| php:7.4.22-browsers | `registry.semaphoreci.com/php:7.4.22-browsers` |
| php:7.4.22-node | `registry.semaphoreci.com/php:7.4.22-node` |
| php:7.4.22-node-browsers | `registry.semaphoreci.com/php:7.4.22-node-browsers` |
| php:7.4.23 | `registry.semaphoreci.com/php:7.4.23` |
| php:7.4.23-browsers | `registry.semaphoreci.com/php:7.4.23-browsers` |
| php:7.4.23-node | `registry.semaphoreci.com/php:7.4.23-node` |
| php:7.4.23-node-browsers | `registry.semaphoreci.com/php:7.4.23-node-browsers` |
| php:7.4.24 | `registry.semaphoreci.com/php:7.4.24` |
| php:7.4.24-browsers | `registry.semaphoreci.com/php:7.4.24-browsers` |
| php:7.4.24-node | `registry.semaphoreci.com/php:7.4.24-node` |
| php:7.4.24-node-browsers | `registry.semaphoreci.com/php:7.4.24-node-browsers` |
| php:7.4.25 | `registry.semaphoreci.com/php:7.4.25` |
| php:7.4.25-browsers | `registry.semaphoreci.com/php:7.4.25-browsers` |
| php:7.4.25-node | `registry.semaphoreci.com/php:7.4.25-node` |
| php:7.4.25-node-browsers | `registry.semaphoreci.com/php:7.4.25-node-browsers` |
| php:7.4.26 | `registry.semaphoreci.com/php:7.4.26` |
| php:7.4.26-browsers | `registry.semaphoreci.com/php:7.4.26-browsers` |
| php:7.4.26-node | `registry.semaphoreci.com/php:7.4.26-node` |
| php:7.4.26-node-browsers | `registry.semaphoreci.com/php:7.4.26-node-browsers` |
| php:7.4.27 | `registry.semaphoreci.com/php:7.4.27` |
| php:7.4.27-browsers | `registry.semaphoreci.com/php:7.4.27-browsers` |
| php:7.4.27-node | `registry.semaphoreci.com/php:7.4.27-node` |
| php:7.4.27-node-browsers | `registry.semaphoreci.com/php:7.4.27-node-browsers` |
| php:7.4.28 | `registry.semaphoreci.com/php:7.4.28` |
| php:7.4.28-browsers | `registry.semaphoreci.com/php:7.4.28-browsers` |
| php:7.4.28-node | `registry.semaphoreci.com/php:7.4.28-node` |
| php:7.4.28-node-browsers | `registry.semaphoreci.com/php:7.4.28-node-browsers` |
| php:7.4.29 | `registry.semaphoreci.com/php:7.4.29` |
| php:7.4.29-browsers | `registry.semaphoreci.com/php:7.4.29-browsers` |
| php:7.4.29-node | `registry.semaphoreci.com/php:7.4.29-node` |
| php:7.4.29-node-browsers | `registry.semaphoreci.com/php:7.4.29-node-browsers` |
| php:7.4.30 | `registry.semaphoreci.com/php:7.4.30` |
| php:7.4.30-browsers | `registry.semaphoreci.com/php:7.4.30-browsers` |
| php:7.4.30-node | `registry.semaphoreci.com/php:7.4.30-node` |
| php:7.4.30-node-browsers | `registry.semaphoreci.com/php:7.4.30-node-browsers` |
| php:7.4.32 | `registry.semaphoreci.com/php:7.4.32` |
| php:7.4.32-browsers | `registry.semaphoreci.com/php:7.4.32-browsers` |
| php:7.4.32-node | `registry.semaphoreci.com/php:7.4.32-node` |
| php:7.4.32-node-browsers | `registry.semaphoreci.com/php:7.4.32-node-browsers` |
| php:8 | `registry.semaphoreci.com/php:8` |
| php:8-browsers | `registry.semaphoreci.com/php:8-browsers` |
| php:8-node | `registry.semaphoreci.com/php:8-node` |
| php:8-node-browsers | `registry.semaphoreci.com/php:8-node-browsers` |
| php:8.0 | `registry.semaphoreci.com/php:8.0` |
| php:8.0-browsers | `registry.semaphoreci.com/php:8.0-browsers` |
| php:8.0-node | `registry.semaphoreci.com/php:8.0-node` |
| php:8.0-node-browsers | `registry.semaphoreci.com/php:8.0-node-browsers` |
| php:8.0.0 | `registry.semaphoreci.com/php:8.0.0` |
| php:8.0.1 | `registry.semaphoreci.com/php:8.0.1` |
| php:8.0.1-browsers | `registry.semaphoreci.com/php:8.0.1-browsers` |
| php:8.0.1-node | `registry.semaphoreci.com/php:8.0.1-node` |
| php:8.0.1-node-browsers | `registry.semaphoreci.com/php:8.0.1-node-browsers` |
| php:8.0.2 | `registry.semaphoreci.com/php:8.0.2` |
| php:8.0.2-browsers | `registry.semaphoreci.com/php:8.0.2-browsers` |
| php:8.0.2-node | `registry.semaphoreci.com/php:8.0.2-node` |
| php:8.0.2-node-browsers | `registry.semaphoreci.com/php:8.0.2-node-browsers` |
| php:8.0.3 | `registry.semaphoreci.com/php:8.0.3` |
| php:8.0.3-browsers | `registry.semaphoreci.com/php:8.0.3-browsers` |
| php:8.0.3-node | `registry.semaphoreci.com/php:8.0.3-node` |
| php:8.0.3-node-browsers | `registry.semaphoreci.com/php:8.0.3-node-browsers` |
| php:8.0.5 | `registry.semaphoreci.com/php:8.0.5` |
| php:8.0.5-browsers | `registry.semaphoreci.com/php:8.0.5-browsers` |
| php:8.0.5-node | `registry.semaphoreci.com/php:8.0.5-node` |
| php:8.0.5-node-browsers | `registry.semaphoreci.com/php:8.0.5-node-browsers` |
| php:8.0.6 | `registry.semaphoreci.com/php:8.0.6` |
| php:8.0.6-browsers | `registry.semaphoreci.com/php:8.0.6-browsers` |
| php:8.0.6-node | `registry.semaphoreci.com/php:8.0.6-node` |
| php:8.0.6-node-browsers | `registry.semaphoreci.com/php:8.0.6-node-browsers` |
| php:8.0.7 | `registry.semaphoreci.com/php:8.0.7` |
| php:8.0.7-browsers | `registry.semaphoreci.com/php:8.0.7-browsers` |
| php:8.0.7-node | `registry.semaphoreci.com/php:8.0.7-node` |
| php:8.0.7-node-browsers | `registry.semaphoreci.com/php:8.0.7-node-browsers` |
| php:8.0.9 | `registry.semaphoreci.com/php:8.0.9` |
| php:8.0.9-browsers | `registry.semaphoreci.com/php:8.0.9-browsers` |
| php:8.0.9-node | `registry.semaphoreci.com/php:8.0.9-node` |
| php:8.0.9-node-browsers | `registry.semaphoreci.com/php:8.0.9-node-browsers` |
| php:8.0.10 | `registry.semaphoreci.com/php:8.0.10` |
| php:8.0.10-browsers | `registry.semaphoreci.com/php:8.0.10-browsers` |
| php:8.0.10-node | `registry.semaphoreci.com/php:8.0.10-node` |
| php:8.0.10-node-browsers | `registry.semaphoreci.com/php:8.0.10-node-browsers` |
| php:8.0.11 | `registry.semaphoreci.com/php:8.0.11` |
| php:8.0.11-browsers | `registry.semaphoreci.com/php:8.0.11-browsers` |
| php:8.0.11-node | `registry.semaphoreci.com/php:8.0.11-node` |
| php:8.0.11-node-browsers | `registry.semaphoreci.com/php:8.0.11-node-browsers` |
| php:8.0.12 | `registry.semaphoreci.com/php:8.0.12` |
| php:8.0.12-browsers | `registry.semaphoreci.com/php:8.0.12-browsers` |
| php:8.0.12-node | `registry.semaphoreci.com/php:8.0.12-node` |
| php:8.0.12-node-browsers | `registry.semaphoreci.com/php:8.0.12-node-browsers` |
| php:8.0.13 | `registry.semaphoreci.com/php:8.0.13` |
| php:8.0.13-browsers | `registry.semaphoreci.com/php:8.0.13-browsers` |
| php:8.0.13-node | `registry.semaphoreci.com/php:8.0.13-node` |
| php:8.0.13-node-browsers | `registry.semaphoreci.com/php:8.0.13-node-browsers` |
| php:8.0.14 | `registry.semaphoreci.com/php:8.0.14` |
| php:8.0.14-browsers | `registry.semaphoreci.com/php:8.0.14-browsers` |
| php:8.0.14-node | `registry.semaphoreci.com/php:8.0.14-node` |
| php:8.0.14-node-browsers | `registry.semaphoreci.com/php:8.0.14-node-browsers` |
| php:8.0.15 | `registry.semaphoreci.com/php:8.0.15` |
| php:8.0.15-browsers | `registry.semaphoreci.com/php:8.0.15-browsers` |
| php:8.0.15-node | `registry.semaphoreci.com/php:8.0.15-node` |
| php:8.0.15-node-browsers | `registry.semaphoreci.com/php:8.0.15-node-browsers` |
| php:8.0.16 | `registry.semaphoreci.com/php:8.0.16` |
| php:8.0.16-browsers | `registry.semaphoreci.com/php:8.0.16-browsers` |
| php:8.0.16-node | `registry.semaphoreci.com/php:8.0.16-node` |
| php:8.0.16-node-browsers | `registry.semaphoreci.com/php:8.0.16-node-browsers` |
| php:8.0.17 | `registry.semaphoreci.com/php:8.0.17` |
| php:8.0.17-browsers | `registry.semaphoreci.com/php:8.0.17-browsers` |
| php:8.0.17-node | `registry.semaphoreci.com/php:8.0.17-node` |
| php:8.0.17-node-browsers | `registry.semaphoreci.com/php:8.0.17-node-browsers` |
| php:8.0.18 | `registry.semaphoreci.com/php:8.0.18` |
| php:8.0.18-browsers | `registry.semaphoreci.com/php:8.0.18-browsers` |
| php:8.0.18-node | `registry.semaphoreci.com/php:8.0.18-node` |
| php:8.0.18-node-browsers | `registry.semaphoreci.com/php:8.0.18-node-browsers` |
| php:8.0.19 | `registry.semaphoreci.com/php:8.0.19` |
| php:8.0.19-browsers | `registry.semaphoreci.com/php:8.0.19-browsers` |
| php:8.0.19-node | `registry.semaphoreci.com/php:8.0.19-node` |
| php:8.0.19-node-browsers | `registry.semaphoreci.com/php:8.0.19-node-browsers` |
| php:8.0.20 | `registry.semaphoreci.com/php:8.0.20` |
| php:8.0.20-browsers | `registry.semaphoreci.com/php:8.0.20-browsers` |
| php:8.0.20-node | `registry.semaphoreci.com/php:8.0.20-node` |
| php:8.0.20-node-browsers | `registry.semaphoreci.com/php:8.0.20-node-browsers` |
| php:8.0.21 | `registry.semaphoreci.com/php:8.0.21` |
| php:8.0.21-browsers | `registry.semaphoreci.com/php:8.0.21-browsers` |
| php:8.0.21-node | `registry.semaphoreci.com/php:8.0.21-node` |
| php:8.0.21-node-browsers | `registry.semaphoreci.com/php:8.0.21-node-browsers` |
| php:8.0.22 | `registry.semaphoreci.com/php:8.0.22` |
| php:8.0.22-browsers | `registry.semaphoreci.com/php:8.0.22-browsers` |
| php:8.0.22-node | `registry.semaphoreci.com/php:8.0.22-node` |
| php:8.0.22-node-browsers | `registry.semaphoreci.com/php:8.0.22-node-browsers` |
| php:8.0.24 | `registry.semaphoreci.com/php:8.0.24` |
| php:8.0.24-browsers | `registry.semaphoreci.com/php:8.0.24-browsers` |
| php:8.0.24-node | `registry.semaphoreci.com/php:8.0.24-node` |
| php:8.0.24-node-browsers | `registry.semaphoreci.com/php:8.0.24-node-browsers` |
| php:8.0.25 | `registry.semaphoreci.com/php:8.0.25` |
| php:8.0.25-browsers | `registry.semaphoreci.com/php:8.0.25-browsers` |
| php:8.0.25-node | `registry.semaphoreci.com/php:8.0.25-node` |
| php:8.0.25-node-browsers | `registry.semaphoreci.com/php:8.0.25-node-browsers` |
| php:8.0.26 | `registry.semaphoreci.com/php:8.0.26` |
| php:8.0.26-browsers | `registry.semaphoreci.com/php:8.0.26-browsers` |
| php:8.0.26-node | `registry.semaphoreci.com/php:8.0.26-node` |
| php:8.0.26-node-browsers | `registry.semaphoreci.com/php:8.0.26-node-browsers` |
| php:8.0.29 | `registry.semaphoreci.com/php:8.0.29` |
| php:8.0.29-browsers | `registry.semaphoreci.com/php:8.0.29-browsers` |
| php:8.0.29-node | `registry.semaphoreci.com/php:8.0.29-node` |
| php:8.0.29-node-browsers | `registry.semaphoreci.com/php:8.0.29-node-browsers` |
| php:8.0.30 | `registry.semaphoreci.com/php:8.0.30` |
| php:8.0.30-browsers | `registry.semaphoreci.com/php:8.0.30-browsers` |
| php:8.0.30-node | `registry.semaphoreci.com/php:8.0.30-node` |
| php:8.0.30-node-browsers | `registry.semaphoreci.com/php:8.0.30-node-browsers` |
| php:8.1 | `registry.semaphoreci.com/php:8.1` |
| php:8.1-browsers | `registry.semaphoreci.com/php:8.1-browsers` |
| php:8.1-node | `registry.semaphoreci.com/php:8.1-node` |
| php:8.1-node-browsers | `registry.semaphoreci.com/php:8.1-node-browsers` |
| php:8.1.0 | `registry.semaphoreci.com/php:8.1.0` |
| php:8.1.0-browsers | `registry.semaphoreci.com/php:8.1.0-browsers` |
| php:8.1.0-node | `registry.semaphoreci.com/php:8.1.0-node` |
| php:8.1.0-node-browsers | `registry.semaphoreci.com/php:8.1.0-node-browsers` |
| php:8.1.1 | `registry.semaphoreci.com/php:8.1.1` |
| php:8.1.1-browsers | `registry.semaphoreci.com/php:8.1.1-browsers` |
| php:8.1.1-node | `registry.semaphoreci.com/php:8.1.1-node` |
| php:8.1.1-node-browsers | `registry.semaphoreci.com/php:8.1.1-node-browsers` |
| php:8.1.2 | `registry.semaphoreci.com/php:8.1.2` |
| php:8.1.2-browsers | `registry.semaphoreci.com/php:8.1.2-browsers` |
| php:8.1.2-node | `registry.semaphoreci.com/php:8.1.2-node` |
| php:8.1.2-node-browsers | `registry.semaphoreci.com/php:8.1.2-node-browsers` |
| php:8.1.3 | `registry.semaphoreci.com/php:8.1.3` |
| php:8.1.3-browsers | `registry.semaphoreci.com/php:8.1.3-browsers` |
| php:8.1.3-node | `registry.semaphoreci.com/php:8.1.3-node` |
| php:8.1.3-node-browsers | `registry.semaphoreci.com/php:8.1.3-node-browsers` |
| php:8.1.4 | `registry.semaphoreci.com/php:8.1.4` |
| php:8.1.4-browsers | `registry.semaphoreci.com/php:8.1.4-browsers` |
| php:8.1.4-node | `registry.semaphoreci.com/php:8.1.4-node` |
| php:8.1.4-node-browsers | `registry.semaphoreci.com/php:8.1.4-node-browsers` |
| php:8.1.5 | `registry.semaphoreci.com/php:8.1.5` |
| php:8.1.5-browsers | `registry.semaphoreci.com/php:8.1.5-browsers` |
| php:8.1.5-node | `registry.semaphoreci.com/php:8.1.5-node` |
| php:8.1.5-node-browsers | `registry.semaphoreci.com/php:8.1.5-node-browsers` |
| php:8.1.6 | `registry.semaphoreci.com/php:8.1.6` |
| php:8.1.6-browsers | `registry.semaphoreci.com/php:8.1.6-browsers` |
| php:8.1.6-node | `registry.semaphoreci.com/php:8.1.6-node` |
| php:8.1.6-node-browsers | `registry.semaphoreci.com/php:8.1.6-node-browsers` |
| php:8.1.7 | `registry.semaphoreci.com/php:8.1.7` |
| php:8.1.7-browsers | `registry.semaphoreci.com/php:8.1.7-browsers` |
| php:8.1.7-node | `registry.semaphoreci.com/php:8.1.7-node` |
| php:8.1.7-node-browsers | `registry.semaphoreci.com/php:8.1.7-node-browsers` |
| php:8.1.8 | `registry.semaphoreci.com/php:8.1.8` |
| php:8.1.8-browsers | `registry.semaphoreci.com/php:8.1.8-browsers` |
| php:8.1.8-node | `registry.semaphoreci.com/php:8.1.8-node` |
| php:8.1.8-node-browsers | `registry.semaphoreci.com/php:8.1.8-node-browsers` |
| php:8.1.9 | `registry.semaphoreci.com/php:8.1.9` |
| php:8.1.9-browsers | `registry.semaphoreci.com/php:8.1.9-browsers` |
| php:8.1.9-node | `registry.semaphoreci.com/php:8.1.9-node` |
| php:8.1.9-node-browsers | `registry.semaphoreci.com/php:8.1.9-node-browsers` |
| php:8.1.11 | `registry.semaphoreci.com/php:8.1.11` |
| php:8.1.11-browsers | `registry.semaphoreci.com/php:8.1.11-browsers` |
| php:8.1.11-node | `registry.semaphoreci.com/php:8.1.11-node` |
| php:8.1.11-node-browsers | `registry.semaphoreci.com/php:8.1.11-node-browsers` |
| php:8.1.12 | `registry.semaphoreci.com/php:8.1.12` |
| php:8.1.12-browsers | `registry.semaphoreci.com/php:8.1.12-browsers` |
| php:8.1.12-node | `registry.semaphoreci.com/php:8.1.12-node` |
| php:8.1.12-node-browsers | `registry.semaphoreci.com/php:8.1.12-node-browsers` |
| php:8.1.13 | `registry.semaphoreci.com/php:8.1.13` |
| php:8.1.13-browsers | `registry.semaphoreci.com/php:8.1.13-browsers` |
| php:8.1.13-node | `registry.semaphoreci.com/php:8.1.13-node` |
| php:8.1.13-node-browsers | `registry.semaphoreci.com/php:8.1.13-node-browsers` |
| php:8.1.20 | `registry.semaphoreci.com/php:8.1.20` |
| php:8.1.21 | `registry.semaphoreci.com/php:8.1.21` |
| php:8.1.21-browsers | `registry.semaphoreci.com/php:8.1.21-browsers` |
| php:8.1.21-node | `registry.semaphoreci.com/php:8.1.21-node` |
| php:8.1.21-node-browsers | `registry.semaphoreci.com/php:8.1.21-node-browsers` |
| php:8.1.23 | `registry.semaphoreci.com/php:8.1.23` |
| php:8.1.23-browsers | `registry.semaphoreci.com/php:8.1.23-browsers` |
| php:8.1.23-node | `registry.semaphoreci.com/php:8.1.23-node` |
| php:8.1.23-node-browsers | `registry.semaphoreci.com/php:8.1.23-node-browsers` |
| php:8.1.24 | `registry.semaphoreci.com/php:8.1.24` |
| php:8.1.24-browsers | `registry.semaphoreci.com/php:8.1.24-browsers` |
| php:8.1.24-node | `registry.semaphoreci.com/php:8.1.24-node` |
| php:8.1.24-node-browsers | `registry.semaphoreci.com/php:8.1.24-node-browsers` |
| php:8.1.25 | `registry.semaphoreci.com/php:8.1.25` |
| php:8.1.26 | `registry.semaphoreci.com/php:8.1.26` |
| php:8.1.27 | `registry.semaphoreci.com/php:8.1.27` |
| php:8.1.27-browsers | `registry.semaphoreci.com/php:8.1.27-browsers` |
| php:8.1.27-node | `registry.semaphoreci.com/php:8.1.27-node` |
| php:8.1.27-node-browsers | `registry.semaphoreci.com/php:8.1.27-node-browsers` |
| php:8.1.30 | `registry.semaphoreci.com/php:8.1.30` |
| php:8.1.30-browsers | `registry.semaphoreci.com/php:8.1.30-browsers` |
| php:8.1.30-node | `registry.semaphoreci.com/php:8.1.30-node` |
| php:8.1.30-node-browsers | `registry.semaphoreci.com/php:8.1.30-node-browsers` |
| php:8.1.31 | `registry.semaphoreci.com/php:8.1.31` |
| php:8.1.31-browsers | `registry.semaphoreci.com/php:8.1.31-browsers` |
| php:8.1.31-node | `registry.semaphoreci.com/php:8.1.31-node` |
| php:8.1.31-node-browsers | `registry.semaphoreci.com/php:8.1.31-node-browsers` |
| php:8.1.32 | `registry.semaphoreci.com/php:8.1.32` |
| php:8.1.32-browsers | `registry.semaphoreci.com/php:8.1.32-browsers` |
| php:8.1.32-node | `registry.semaphoreci.com/php:8.1.32-node` |
| php:8.1.32-node-browsers | `registry.semaphoreci.com/php:8.1.32-node-browsers` |
| php:8.1.33 | `registry.semaphoreci.com/php:8.1.33` |
| php:8.2 | `registry.semaphoreci.com/php:8.2` |
| php:8.2-browsers | `registry.semaphoreci.com/php:8.2-browsers` |
| php:8.2-node | `registry.semaphoreci.com/php:8.2-node` |
| php:8.2-node-browsers | `registry.semaphoreci.com/php:8.2-node-browsers` |
| php:8.2.0 | `registry.semaphoreci.com/php:8.2.0` |
| php:8.2.0-browsers | `registry.semaphoreci.com/php:8.2.0-browsers` |
| php:8.2.0-node | `registry.semaphoreci.com/php:8.2.0-node` |
| php:8.2.0-node-browsers | `registry.semaphoreci.com/php:8.2.0-node-browsers` |
| php:8.2.7 | `registry.semaphoreci.com/php:8.2.7` |
| php:8.2.8 | `registry.semaphoreci.com/php:8.2.8` |
| php:8.2.8-browsers | `registry.semaphoreci.com/php:8.2.8-browsers` |
| php:8.2.8-node | `registry.semaphoreci.com/php:8.2.8-node` |
| php:8.2.8-node-browsers | `registry.semaphoreci.com/php:8.2.8-node-browsers` |
| php:8.2.9 | `registry.semaphoreci.com/php:8.2.9` |
| php:8.2.10 | `registry.semaphoreci.com/php:8.2.10` |
| php:8.2.10-browsers | `registry.semaphoreci.com/php:8.2.10-browsers` |
| php:8.2.10-node | `registry.semaphoreci.com/php:8.2.10-node` |
| php:8.2.10-node-browsers | `registry.semaphoreci.com/php:8.2.10-node-browsers` |
| php:8.2.11 | `registry.semaphoreci.com/php:8.2.11` |
| php:8.2.11-browsers | `registry.semaphoreci.com/php:8.2.11-browsers` |
| php:8.2.11-node | `registry.semaphoreci.com/php:8.2.11-node` |
| php:8.2.11-node-browsers | `registry.semaphoreci.com/php:8.2.11-node-browsers` |
| php:8.2.12 | `registry.semaphoreci.com/php:8.2.12` |
| php:8.2.13 | `registry.semaphoreci.com/php:8.2.13` |
| php:8.2.15 | `registry.semaphoreci.com/php:8.2.15` |
| php:8.2.15-browsers | `registry.semaphoreci.com/php:8.2.15-browsers` |
| php:8.2.15-node | `registry.semaphoreci.com/php:8.2.15-node` |
| php:8.2.15-node-browsers | `registry.semaphoreci.com/php:8.2.15-node-browsers` |
| php:8.2.24 | `registry.semaphoreci.com/php:8.2.24` |
| php:8.2.24-browsers | `registry.semaphoreci.com/php:8.2.24-browsers` |
| php:8.2.24-node | `registry.semaphoreci.com/php:8.2.24-node` |
| php:8.2.24-node-browsers | `registry.semaphoreci.com/php:8.2.24-node-browsers` |
| php:8.2.25 | `registry.semaphoreci.com/php:8.2.25` |
| php:8.2.25-browsers | `registry.semaphoreci.com/php:8.2.25-browsers` |
| php:8.2.25-node | `registry.semaphoreci.com/php:8.2.25-node` |
| php:8.2.25-node-browsers | `registry.semaphoreci.com/php:8.2.25-node-browsers` |
| php:8.2.26 | `registry.semaphoreci.com/php:8.2.26` |
| php:8.2.26-browsers | `registry.semaphoreci.com/php:8.2.26-browsers` |
| php:8.2.26-node | `registry.semaphoreci.com/php:8.2.26-node` |
| php:8.2.26-node-browsers | `registry.semaphoreci.com/php:8.2.26-node-browsers` |
| php:8.2.27 | `registry.semaphoreci.com/php:8.2.27` |
| php:8.2.27-browsers | `registry.semaphoreci.com/php:8.2.27-browsers` |
| php:8.2.27-node | `registry.semaphoreci.com/php:8.2.27-node` |
| php:8.2.27-node-browsers | `registry.semaphoreci.com/php:8.2.27-node-browsers` |
| php:8.2.28 | `registry.semaphoreci.com/php:8.2.28` |
| php:8.2.28-browsers | `registry.semaphoreci.com/php:8.2.28-browsers` |
| php:8.2.28-node | `registry.semaphoreci.com/php:8.2.28-node` |
| php:8.2.28-node-browsers | `registry.semaphoreci.com/php:8.2.28-node-browsers` |
| php:8.2.30 | `registry.semaphoreci.com/php:8.2.30` |
| php:8.2.30-browsers | `registry.semaphoreci.com/php:8.2.30-browsers` |
| php:8.2.30-node | `registry.semaphoreci.com/php:8.2.30-node` |
| php:8.2.30-node-browsers | `registry.semaphoreci.com/php:8.2.30-node-browsers` |
| php:8.2.31 | `registry.semaphoreci.com/php:8.2.31` |
| php:8.2.31-browsers | `registry.semaphoreci.com/php:8.2.31-browsers` |
| php:8.2.31-node | `registry.semaphoreci.com/php:8.2.31-node` |
| php:8.2.31-node-browsers | `registry.semaphoreci.com/php:8.2.31-node-browsers` |
| php:8.2.33 | `registry.semaphoreci.com/php:8.2.33` |
| php:8.2.33-browsers | `registry.semaphoreci.com/php:8.2.33-browsers` |
| php:8.2.33-node | `registry.semaphoreci.com/php:8.2.33-node` |
| php:8.2.33-node-browsers | `registry.semaphoreci.com/php:8.2.33-node-browsers` |
| php:8.2.34 | `registry.semaphoreci.com/php:8.2.34` |
| php:8.2.34-browsers | `registry.semaphoreci.com/php:8.2.34-browsers` |
| php:8.2.34-node | `registry.semaphoreci.com/php:8.2.34-node` |
| php:8.2.34-node-browsers | `registry.semaphoreci.com/php:8.2.34-node-browsers` |
| php:8.3 | `registry.semaphoreci.com/php:8.3` |
| php:8.3-browsers | `registry.semaphoreci.com/php:8.3-browsers` |
| php:8.3-node | `registry.semaphoreci.com/php:8.3-node` |
| php:8.3-node-browsers | `registry.semaphoreci.com/php:8.3-node-browsers` |
| php:8.3.0 | `registry.semaphoreci.com/php:8.3.0` |
| php:8.3.2 | `registry.semaphoreci.com/php:8.3.2` |
| php:8.3.2-browsers | `registry.semaphoreci.com/php:8.3.2-browsers` |
| php:8.3.2-node | `registry.semaphoreci.com/php:8.3.2-node` |
| php:8.3.2-node-browsers | `registry.semaphoreci.com/php:8.3.2-node-browsers` |
| php:8.3.6 | `registry.semaphoreci.com/php:8.3.6` |
| php:8.3.12 | `registry.semaphoreci.com/php:8.3.12` |
| php:8.3.12-browsers | `registry.semaphoreci.com/php:8.3.12-browsers` |
| php:8.3.12-node | `registry.semaphoreci.com/php:8.3.12-node` |
| php:8.3.12-node-browsers | `registry.semaphoreci.com/php:8.3.12-node-browsers` |
| php:8.3.13 | `registry.semaphoreci.com/php:8.3.13` |
| php:8.3.13-browsers | `registry.semaphoreci.com/php:8.3.13-browsers` |
| php:8.3.13-node | `registry.semaphoreci.com/php:8.3.13-node` |
| php:8.3.13-node-browsers | `registry.semaphoreci.com/php:8.3.13-node-browsers` |
| php:8.3.14 | `registry.semaphoreci.com/php:8.3.14` |
| php:8.3.14-browsers | `registry.semaphoreci.com/php:8.3.14-browsers` |
| php:8.3.14-node | `registry.semaphoreci.com/php:8.3.14-node` |
| php:8.3.14-node-browsers | `registry.semaphoreci.com/php:8.3.14-node-browsers` |
| php:8.3.15 | `registry.semaphoreci.com/php:8.3.15` |
| php:8.3.15-browsers | `registry.semaphoreci.com/php:8.3.15-browsers` |
| php:8.3.15-node | `registry.semaphoreci.com/php:8.3.15-node` |
| php:8.3.15-node-browsers | `registry.semaphoreci.com/php:8.3.15-node-browsers` |
| php:8.3.16 | `registry.semaphoreci.com/php:8.3.16` |
| php:8.3.16-browsers | `registry.semaphoreci.com/php:8.3.16-browsers` |
| php:8.3.16-node | `registry.semaphoreci.com/php:8.3.16-node` |
| php:8.3.16-node-browsers | `registry.semaphoreci.com/php:8.3.16-node-browsers` |
| php:8.3.20 | `registry.semaphoreci.com/php:8.3.20` |
| php:8.3.20-browsers | `registry.semaphoreci.com/php:8.3.20-browsers` |
| php:8.3.20-node | `registry.semaphoreci.com/php:8.3.20-node` |
| php:8.3.20-node-browsers | `registry.semaphoreci.com/php:8.3.20-node-browsers` |
| php:8.3.21 | `registry.semaphoreci.com/php:8.3.21` |
| php:8.3.21-browsers | `registry.semaphoreci.com/php:8.3.21-browsers` |
| php:8.3.21-node | `registry.semaphoreci.com/php:8.3.21-node` |
| php:8.3.21-node-browsers | `registry.semaphoreci.com/php:8.3.21-node-browsers` |
| php:8.3.22 | `registry.semaphoreci.com/php:8.3.22` |
| php:8.3.22-browsers | `registry.semaphoreci.com/php:8.3.22-browsers` |
| php:8.3.22-node | `registry.semaphoreci.com/php:8.3.22-node` |
| php:8.3.22-node-browsers | `registry.semaphoreci.com/php:8.3.22-node-browsers` |
| php:8.3.25 | `registry.semaphoreci.com/php:8.3.25` |
| php:8.3.27 | `registry.semaphoreci.com/php:8.3.27` |
| php:8.3.28 | `registry.semaphoreci.com/php:8.3.28` |
| php:8.3.30 | `registry.semaphoreci.com/php:8.3.30` |
| php:8.3.30-browsers | `registry.semaphoreci.com/php:8.3.30-browsers` |
| php:8.3.30-node | `registry.semaphoreci.com/php:8.3.30-node` |
| php:8.3.30-node-browsers | `registry.semaphoreci.com/php:8.3.30-node-browsers` |
| php:8.3.31 | `registry.semaphoreci.com/php:8.3.31` |
| php:8.3.31-browsers | `registry.semaphoreci.com/php:8.3.31-browsers` |
| php:8.3.31-node | `registry.semaphoreci.com/php:8.3.31-node` |
| php:8.3.31-node-browsers | `registry.semaphoreci.com/php:8.3.31-node-browsers` |
| php:8.3.33 | `registry.semaphoreci.com/php:8.3.33` |
| php:8.3.33-browsers | `registry.semaphoreci.com/php:8.3.33-browsers` |
| php:8.3.33-node | `registry.semaphoreci.com/php:8.3.33-node` |
| php:8.3.33-node-browsers | `registry.semaphoreci.com/php:8.3.33-node-browsers` |
| php:8.3.35 | `registry.semaphoreci.com/php:8.3.35` |
| php:8.3.35-browsers | `registry.semaphoreci.com/php:8.3.35-browsers` |
| php:8.3.35-node | `registry.semaphoreci.com/php:8.3.35-node` |
| php:8.3.35-node-browsers | `registry.semaphoreci.com/php:8.3.35-node-browsers` |
| php:8.4 | `registry.semaphoreci.com/php:8.4` |
| php:8.4-browsers | `registry.semaphoreci.com/php:8.4-browsers` |
| php:8.4-node | `registry.semaphoreci.com/php:8.4-node` |
| php:8.4-node-browsers | `registry.semaphoreci.com/php:8.4-node-browsers` |
| php:8.4.1 | `registry.semaphoreci.com/php:8.4.1` |
| php:8.4.1-browsers | `registry.semaphoreci.com/php:8.4.1-browsers` |
| php:8.4.1-node | `registry.semaphoreci.com/php:8.4.1-node` |
| php:8.4.1-node-browsers | `registry.semaphoreci.com/php:8.4.1-node-browsers` |
| php:8.4.2 | `registry.semaphoreci.com/php:8.4.2` |
| php:8.4.2-browsers | `registry.semaphoreci.com/php:8.4.2-browsers` |
| php:8.4.2-node | `registry.semaphoreci.com/php:8.4.2-node` |
| php:8.4.2-node-browsers | `registry.semaphoreci.com/php:8.4.2-node-browsers` |
| php:8.4.3 | `registry.semaphoreci.com/php:8.4.3` |
| php:8.4.3-browsers | `registry.semaphoreci.com/php:8.4.3-browsers` |
| php:8.4.3-node | `registry.semaphoreci.com/php:8.4.3-node` |
| php:8.4.3-node-browsers | `registry.semaphoreci.com/php:8.4.3-node-browsers` |
| php:8.4.4 | `registry.semaphoreci.com/php:8.4.4` |
| php:8.4.5 | `registry.semaphoreci.com/php:8.4.5` |
| php:8.4.6 | `registry.semaphoreci.com/php:8.4.6` |
| php:8.4.6-browsers | `registry.semaphoreci.com/php:8.4.6-browsers` |
| php:8.4.6-node | `registry.semaphoreci.com/php:8.4.6-node` |
| php:8.4.6-node-browsers | `registry.semaphoreci.com/php:8.4.6-node-browsers` |
| php:8.4.7 | `registry.semaphoreci.com/php:8.4.7` |
| php:8.4.7-browsers | `registry.semaphoreci.com/php:8.4.7-browsers` |
| php:8.4.7-node | `registry.semaphoreci.com/php:8.4.7-node` |
| php:8.4.7-node-browsers | `registry.semaphoreci.com/php:8.4.7-node-browsers` |
| php:8.4.8 | `registry.semaphoreci.com/php:8.4.8` |
| php:8.4.8-browsers | `registry.semaphoreci.com/php:8.4.8-browsers` |
| php:8.4.8-node | `registry.semaphoreci.com/php:8.4.8-node` |
| php:8.4.8-node-browsers | `registry.semaphoreci.com/php:8.4.8-node-browsers` |
| php:8.4.10 | `registry.semaphoreci.com/php:8.4.10` |
| php:8.4.20 | `registry.semaphoreci.com/php:8.4.20` |
| php:8.4.20-browsers | `registry.semaphoreci.com/php:8.4.20-browsers` |
| php:8.4.20-node | `registry.semaphoreci.com/php:8.4.20-node` |
| php:8.4.20-node-browsers | `registry.semaphoreci.com/php:8.4.20-node-browsers` |
| php:8.4.21 | `registry.semaphoreci.com/php:8.4.21` |
| php:8.4.21-browsers | `registry.semaphoreci.com/php:8.4.21-browsers` |
| php:8.4.21-node | `registry.semaphoreci.com/php:8.4.21-node` |
| php:8.4.21-node-browsers | `registry.semaphoreci.com/php:8.4.21-node-browsers` |
| php:8.4.22 | `registry.semaphoreci.com/php:8.4.22` |
| php:8.4.22-browsers | `registry.semaphoreci.com/php:8.4.22-browsers` |
| php:8.4.22-node | `registry.semaphoreci.com/php:8.4.22-node` |
| php:8.4.22-node-browsers | `registry.semaphoreci.com/php:8.4.22-node-browsers` |
| php:8.4.24 | `registry.semaphoreci.com/php:8.4.24` |
| php:8.4.24-browsers | `registry.semaphoreci.com/php:8.4.24-browsers` |
| php:8.4.24-node | `registry.semaphoreci.com/php:8.4.24-node` |
| php:8.4.24-node-browsers | `registry.semaphoreci.com/php:8.4.24-node-browsers` |
| php:8.4.25 | `registry.semaphoreci.com/php:8.4.25` |
| php:8.4.26 | `registry.semaphoreci.com/php:8.4.26` |
| php:8.4.26-browsers | `registry.semaphoreci.com/php:8.4.26-browsers` |
| php:8.4.26-node | `registry.semaphoreci.com/php:8.4.26-node` |
| php:8.4.26-node-browsers | `registry.semaphoreci.com/php:8.4.26-node-browsers` |
| php:8.5 | `registry.semaphoreci.com/php:8.5` |
| php:8.5-browsers | `registry.semaphoreci.com/php:8.5-browsers` |
| php:8.5-node | `registry.semaphoreci.com/php:8.5-node` |
| php:8.5-node-browsers | `registry.semaphoreci.com/php:8.5-node-browsers` |
| php:8.5.0 | `registry.semaphoreci.com/php:8.5.0` |
| php:8.5.1 | `registry.semaphoreci.com/php:8.5.1` |
| php:8.5.2 | `registry.semaphoreci.com/php:8.5.2` |
| php:8.5.3 | `registry.semaphoreci.com/php:8.5.3` |
| php:8.5.4 | `registry.semaphoreci.com/php:8.5.4` |
| php:8.5.5 | `registry.semaphoreci.com/php:8.5.5` |
| php:8.5.5-browsers | `registry.semaphoreci.com/php:8.5.5-browsers` |
| php:8.5.5-node | `registry.semaphoreci.com/php:8.5.5-node` |
| php:8.5.5-node-browsers | `registry.semaphoreci.com/php:8.5.5-node-browsers` |
| php:8.5.6 | `registry.semaphoreci.com/php:8.5.6` |
| php:8.5.6-browsers | `registry.semaphoreci.com/php:8.5.6-browsers` |
| php:8.5.6-node | `registry.semaphoreci.com/php:8.5.6-node` |
| php:8.5.6-node-browsers | `registry.semaphoreci.com/php:8.5.6-node-browsers` |
| php:8.5.7 | `registry.semaphoreci.com/php:8.5.7` |
| php:8.5.7-browsers | `registry.semaphoreci.com/php:8.5.7-browsers` |
| php:8.5.7-node | `registry.semaphoreci.com/php:8.5.7-node` |
| php:8.5.7-node-browsers | `registry.semaphoreci.com/php:8.5.7-node-browsers` |
| php:8.5.9 | `registry.semaphoreci.com/php:8.5.9` |
| php:8.5.9-browsers | `registry.semaphoreci.com/php:8.5.9-browsers` |
| php:8.5.9-node | `registry.semaphoreci.com/php:8.5.9-node` |
| php:8.5.9-node-browsers | `registry.semaphoreci.com/php:8.5.9-node-browsers` |
| php:8.5.10 | `registry.semaphoreci.com/php:8.5.10` |
| php:8.5.11 | `registry.semaphoreci.com/php:8.5.11` |
| php:8.5.11-browsers | `registry.semaphoreci.com/php:8.5.11-browsers` |
| php:8.5.11-node | `registry.semaphoreci.com/php:8.5.11-node` |
| php:8.5.11-node-browsers | `registry.semaphoreci.com/php:8.5.11-node-browsers` |

</div>
</details>

### Rust

Rust images come in four variants:

- **base**: base images matching the Rust official images
- **node**: base image extended with Node.js
- **browsers**: base image extended with Firefox, Google Chrome, and chromedriver
- **node-browsers**: base image extended with Node.js, Firefox, Google Chrome, and chromedriver. Useful for running browser-based pipelines

<details>
<summary>Rust images</summary>
<div>

| Image | Link |
|--------|--------|
| rust:1 | `registry.semaphoreci.com/rust:1` |
| rust:1-browsers | `registry.semaphoreci.com/rust:1-browsers` |
| rust:1-node | `registry.semaphoreci.com/rust:1-node` |
| rust:1-node-browsers | `registry.semaphoreci.com/rust:1-node-browsers` |
| rust:1.49 | `registry.semaphoreci.com/rust:1.49` |
| rust:1.49-browsers | `registry.semaphoreci.com/rust:1.49-browsers` |
| rust:1.49-node | `registry.semaphoreci.com/rust:1.49-node` |
| rust:1.49-node-browsers | `registry.semaphoreci.com/rust:1.49-node-browsers` |
| rust:1.49.0 | `registry.semaphoreci.com/rust:1.49.0` |
| rust:1.49.0-browsers | `registry.semaphoreci.com/rust:1.49.0-browsers` |
| rust:1.49.0-node | `registry.semaphoreci.com/rust:1.49.0-node` |
| rust:1.49.0-node-browsers | `registry.semaphoreci.com/rust:1.49.0-node-browsers` |
| rust:1.50 | `registry.semaphoreci.com/rust:1.50` |
| rust:1.50-browsers | `registry.semaphoreci.com/rust:1.50-browsers` |
| rust:1.50-node | `registry.semaphoreci.com/rust:1.50-node` |
| rust:1.50-node-browsers | `registry.semaphoreci.com/rust:1.50-node-browsers` |
| rust:1.50.0 | `registry.semaphoreci.com/rust:1.50.0` |
| rust:1.50.0-browsers | `registry.semaphoreci.com/rust:1.50.0-browsers` |
| rust:1.50.0-node | `registry.semaphoreci.com/rust:1.50.0-node` |
| rust:1.50.0-node-browsers | `registry.semaphoreci.com/rust:1.50.0-node-browsers` |
| rust:1.51 | `registry.semaphoreci.com/rust:1.51` |
| rust:1.51-browsers | `registry.semaphoreci.com/rust:1.51-browsers` |
| rust:1.51-node | `registry.semaphoreci.com/rust:1.51-node` |
| rust:1.51-node-browsers | `registry.semaphoreci.com/rust:1.51-node-browsers` |
| rust:1.51.0 | `registry.semaphoreci.com/rust:1.51.0` |
| rust:1.51.0-browsers | `registry.semaphoreci.com/rust:1.51.0-browsers` |
| rust:1.51.0-node | `registry.semaphoreci.com/rust:1.51.0-node` |
| rust:1.51.0-node-browsers | `registry.semaphoreci.com/rust:1.51.0-node-browsers` |
| rust:1.52 | `registry.semaphoreci.com/rust:1.52` |
| rust:1.52-browsers | `registry.semaphoreci.com/rust:1.52-browsers` |
| rust:1.52-node | `registry.semaphoreci.com/rust:1.52-node` |
| rust:1.52-node-browsers | `registry.semaphoreci.com/rust:1.52-node-browsers` |
| rust:1.52.1 | `registry.semaphoreci.com/rust:1.52.1` |
| rust:1.52.1-browsers | `registry.semaphoreci.com/rust:1.52.1-browsers` |
| rust:1.52.1-node | `registry.semaphoreci.com/rust:1.52.1-node` |
| rust:1.52.1-node-browsers | `registry.semaphoreci.com/rust:1.52.1-node-browsers` |
| rust:1.53 | `registry.semaphoreci.com/rust:1.53` |
| rust:1.53-browsers | `registry.semaphoreci.com/rust:1.53-browsers` |
| rust:1.53-node | `registry.semaphoreci.com/rust:1.53-node` |
| rust:1.53-node-browsers | `registry.semaphoreci.com/rust:1.53-node-browsers` |
| rust:1.53.0 | `registry.semaphoreci.com/rust:1.53.0` |
| rust:1.53.0-browsers | `registry.semaphoreci.com/rust:1.53.0-browsers` |
| rust:1.53.0-node | `registry.semaphoreci.com/rust:1.53.0-node` |
| rust:1.53.0-node-browsers | `registry.semaphoreci.com/rust:1.53.0-node-browsers` |
| rust:1.54 | `registry.semaphoreci.com/rust:1.54` |
| rust:1.54-browsers | `registry.semaphoreci.com/rust:1.54-browsers` |
| rust:1.54-node | `registry.semaphoreci.com/rust:1.54-node` |
| rust:1.54-node-browsers | `registry.semaphoreci.com/rust:1.54-node-browsers` |
| rust:1.54.0 | `registry.semaphoreci.com/rust:1.54.0` |
| rust:1.54.0-browsers | `registry.semaphoreci.com/rust:1.54.0-browsers` |
| rust:1.54.0-node | `registry.semaphoreci.com/rust:1.54.0-node` |
| rust:1.54.0-node-browsers | `registry.semaphoreci.com/rust:1.54.0-node-browsers` |
| rust:1.55 | `registry.semaphoreci.com/rust:1.55` |
| rust:1.55-browsers | `registry.semaphoreci.com/rust:1.55-browsers` |
| rust:1.55-node | `registry.semaphoreci.com/rust:1.55-node` |
| rust:1.55-node-browsers | `registry.semaphoreci.com/rust:1.55-node-browsers` |
| rust:1.55.0 | `registry.semaphoreci.com/rust:1.55.0` |
| rust:1.55.0-browsers | `registry.semaphoreci.com/rust:1.55.0-browsers` |
| rust:1.55.0-node | `registry.semaphoreci.com/rust:1.55.0-node` |
| rust:1.55.0-node-browsers | `registry.semaphoreci.com/rust:1.55.0-node-browsers` |
| rust:1.56 | `registry.semaphoreci.com/rust:1.56` |
| rust:1.56-browsers | `registry.semaphoreci.com/rust:1.56-browsers` |
| rust:1.56-node | `registry.semaphoreci.com/rust:1.56-node` |
| rust:1.56-node-browsers | `registry.semaphoreci.com/rust:1.56-node-browsers` |
| rust:1.56.0 | `registry.semaphoreci.com/rust:1.56.0` |
| rust:1.56.0-browsers | `registry.semaphoreci.com/rust:1.56.0-browsers` |
| rust:1.56.0-node | `registry.semaphoreci.com/rust:1.56.0-node` |
| rust:1.56.0-node-browsers | `registry.semaphoreci.com/rust:1.56.0-node-browsers` |
| rust:1.56.1 | `registry.semaphoreci.com/rust:1.56.1` |
| rust:1.56.1-browsers | `registry.semaphoreci.com/rust:1.56.1-browsers` |
| rust:1.56.1-node | `registry.semaphoreci.com/rust:1.56.1-node` |
| rust:1.56.1-node-browsers | `registry.semaphoreci.com/rust:1.56.1-node-browsers` |
| rust:1.57 | `registry.semaphoreci.com/rust:1.57` |
| rust:1.57-browsers | `registry.semaphoreci.com/rust:1.57-browsers` |
| rust:1.57-node | `registry.semaphoreci.com/rust:1.57-node` |
| rust:1.57-node-browsers | `registry.semaphoreci.com/rust:1.57-node-browsers` |
| rust:1.57.0 | `registry.semaphoreci.com/rust:1.57.0` |
| rust:1.57.0-browsers | `registry.semaphoreci.com/rust:1.57.0-browsers` |
| rust:1.57.0-node | `registry.semaphoreci.com/rust:1.57.0-node` |
| rust:1.57.0-node-browsers | `registry.semaphoreci.com/rust:1.57.0-node-browsers` |
| rust:1.58 | `registry.semaphoreci.com/rust:1.58` |
| rust:1.58-browsers | `registry.semaphoreci.com/rust:1.58-browsers` |
| rust:1.58-node | `registry.semaphoreci.com/rust:1.58-node` |
| rust:1.58-node-browsers | `registry.semaphoreci.com/rust:1.58-node-browsers` |
| rust:1.58.1 | `registry.semaphoreci.com/rust:1.58.1` |
| rust:1.58.1-browsers | `registry.semaphoreci.com/rust:1.58.1-browsers` |
| rust:1.58.1-node | `registry.semaphoreci.com/rust:1.58.1-node` |
| rust:1.58.1-node-browsers | `registry.semaphoreci.com/rust:1.58.1-node-browsers` |
| rust:1.59 | `registry.semaphoreci.com/rust:1.59` |
| rust:1.59-browsers | `registry.semaphoreci.com/rust:1.59-browsers` |
| rust:1.59-node | `registry.semaphoreci.com/rust:1.59-node` |
| rust:1.59-node-browsers | `registry.semaphoreci.com/rust:1.59-node-browsers` |
| rust:1.59.0 | `registry.semaphoreci.com/rust:1.59.0` |
| rust:1.59.0-browsers | `registry.semaphoreci.com/rust:1.59.0-browsers` |
| rust:1.59.0-node | `registry.semaphoreci.com/rust:1.59.0-node` |
| rust:1.59.0-node-browsers | `registry.semaphoreci.com/rust:1.59.0-node-browsers` |
| rust:1.60 | `registry.semaphoreci.com/rust:1.60` |
| rust:1.60-browsers | `registry.semaphoreci.com/rust:1.60-browsers` |
| rust:1.60-node | `registry.semaphoreci.com/rust:1.60-node` |
| rust:1.60-node-browsers | `registry.semaphoreci.com/rust:1.60-node-browsers` |
| rust:1.60.0 | `registry.semaphoreci.com/rust:1.60.0` |
| rust:1.60.0-browsers | `registry.semaphoreci.com/rust:1.60.0-browsers` |
| rust:1.60.0-node | `registry.semaphoreci.com/rust:1.60.0-node` |
| rust:1.60.0-node-browsers | `registry.semaphoreci.com/rust:1.60.0-node-browsers` |
| rust:1.61 | `registry.semaphoreci.com/rust:1.61` |
| rust:1.61-browsers | `registry.semaphoreci.com/rust:1.61-browsers` |
| rust:1.61-node | `registry.semaphoreci.com/rust:1.61-node` |
| rust:1.61-node-browsers | `registry.semaphoreci.com/rust:1.61-node-browsers` |
| rust:1.61.0 | `registry.semaphoreci.com/rust:1.61.0` |
| rust:1.61.0-browsers | `registry.semaphoreci.com/rust:1.61.0-browsers` |
| rust:1.61.0-node | `registry.semaphoreci.com/rust:1.61.0-node` |
| rust:1.61.0-node-browsers | `registry.semaphoreci.com/rust:1.61.0-node-browsers` |
| rust:1.62 | `registry.semaphoreci.com/rust:1.62` |
| rust:1.62-browsers | `registry.semaphoreci.com/rust:1.62-browsers` |
| rust:1.62-node | `registry.semaphoreci.com/rust:1.62-node` |
| rust:1.62-node-browsers | `registry.semaphoreci.com/rust:1.62-node-browsers` |
| rust:1.62.0 | `registry.semaphoreci.com/rust:1.62.0` |
| rust:1.62.0-browsers | `registry.semaphoreci.com/rust:1.62.0-browsers` |
| rust:1.62.0-node | `registry.semaphoreci.com/rust:1.62.0-node` |
| rust:1.62.0-node-browsers | `registry.semaphoreci.com/rust:1.62.0-node-browsers` |
| rust:1.62.1 | `registry.semaphoreci.com/rust:1.62.1` |
| rust:1.62.1-browsers | `registry.semaphoreci.com/rust:1.62.1-browsers` |
| rust:1.62.1-node | `registry.semaphoreci.com/rust:1.62.1-node` |
| rust:1.62.1-node-browsers | `registry.semaphoreci.com/rust:1.62.1-node-browsers` |
| rust:1.63 | `registry.semaphoreci.com/rust:1.63` |
| rust:1.63-browsers | `registry.semaphoreci.com/rust:1.63-browsers` |
| rust:1.63-node | `registry.semaphoreci.com/rust:1.63-node` |
| rust:1.63-node-browsers | `registry.semaphoreci.com/rust:1.63-node-browsers` |
| rust:1.63.0 | `registry.semaphoreci.com/rust:1.63.0` |
| rust:1.63.0-browsers | `registry.semaphoreci.com/rust:1.63.0-browsers` |
| rust:1.63.0-node | `registry.semaphoreci.com/rust:1.63.0-node` |
| rust:1.63.0-node-browsers | `registry.semaphoreci.com/rust:1.63.0-node-browsers` |
| rust:1.64 | `registry.semaphoreci.com/rust:1.64` |
| rust:1.64-browsers | `registry.semaphoreci.com/rust:1.64-browsers` |
| rust:1.64-node | `registry.semaphoreci.com/rust:1.64-node` |
| rust:1.64-node-browsers | `registry.semaphoreci.com/rust:1.64-node-browsers` |
| rust:1.64.0 | `registry.semaphoreci.com/rust:1.64.0` |
| rust:1.64.0-browsers | `registry.semaphoreci.com/rust:1.64.0-browsers` |
| rust:1.64.0-node | `registry.semaphoreci.com/rust:1.64.0-node` |
| rust:1.64.0-node-browsers | `registry.semaphoreci.com/rust:1.64.0-node-browsers` |
| rust:1.65 | `registry.semaphoreci.com/rust:1.65` |
| rust:1.65-browsers | `registry.semaphoreci.com/rust:1.65-browsers` |
| rust:1.65-node | `registry.semaphoreci.com/rust:1.65-node` |
| rust:1.65-node-browsers | `registry.semaphoreci.com/rust:1.65-node-browsers` |
| rust:1.65.0 | `registry.semaphoreci.com/rust:1.65.0` |
| rust:1.65.0-browsers | `registry.semaphoreci.com/rust:1.65.0-browsers` |
| rust:1.65.0-node | `registry.semaphoreci.com/rust:1.65.0-node` |
| rust:1.65.0-node-browsers | `registry.semaphoreci.com/rust:1.65.0-node-browsers` |
| rust:1.66 | `registry.semaphoreci.com/rust:1.66` |
| rust:1.66-browsers | `registry.semaphoreci.com/rust:1.66-browsers` |
| rust:1.66-node | `registry.semaphoreci.com/rust:1.66-node` |
| rust:1.66-node-browsers | `registry.semaphoreci.com/rust:1.66-node-browsers` |
| rust:1.66.0 | `registry.semaphoreci.com/rust:1.66.0` |
| rust:1.66.0-browsers | `registry.semaphoreci.com/rust:1.66.0-browsers` |
| rust:1.66.0-node | `registry.semaphoreci.com/rust:1.66.0-node` |
| rust:1.66.0-node-browsers | `registry.semaphoreci.com/rust:1.66.0-node-browsers` |
| rust:1.67 | `registry.semaphoreci.com/rust:1.67` |
| rust:1.67-browsers | `registry.semaphoreci.com/rust:1.67-browsers` |
| rust:1.67-node | `registry.semaphoreci.com/rust:1.67-node` |
| rust:1.67-node-browsers | `registry.semaphoreci.com/rust:1.67-node-browsers` |
| rust:1.67.0 | `registry.semaphoreci.com/rust:1.67.0` |
| rust:1.67.0-browsers | `registry.semaphoreci.com/rust:1.67.0-browsers` |
| rust:1.67.0-node | `registry.semaphoreci.com/rust:1.67.0-node` |
| rust:1.67.0-node-browsers | `registry.semaphoreci.com/rust:1.67.0-node-browsers` |
| rust:1.68 | `registry.semaphoreci.com/rust:1.68` |
| rust:1.68-browsers | `registry.semaphoreci.com/rust:1.68-browsers` |
| rust:1.68-node | `registry.semaphoreci.com/rust:1.68-node` |
| rust:1.68-node-browsers | `registry.semaphoreci.com/rust:1.68-node-browsers` |
| rust:1.68.2 | `registry.semaphoreci.com/rust:1.68.2` |
| rust:1.68.2-browsers | `registry.semaphoreci.com/rust:1.68.2-browsers` |
| rust:1.68.2-node | `registry.semaphoreci.com/rust:1.68.2-node` |
| rust:1.68.2-node-browsers | `registry.semaphoreci.com/rust:1.68.2-node-browsers` |
| rust:1.69 | `registry.semaphoreci.com/rust:1.69` |
| rust:1.69-browsers | `registry.semaphoreci.com/rust:1.69-browsers` |
| rust:1.69-node | `registry.semaphoreci.com/rust:1.69-node` |
| rust:1.69-node-browsers | `registry.semaphoreci.com/rust:1.69-node-browsers` |
| rust:1.69.0 | `registry.semaphoreci.com/rust:1.69.0` |
| rust:1.69.0-browsers | `registry.semaphoreci.com/rust:1.69.0-browsers` |
| rust:1.69.0-node | `registry.semaphoreci.com/rust:1.69.0-node` |
| rust:1.69.0-node-browsers | `registry.semaphoreci.com/rust:1.69.0-node-browsers` |
| rust:1.70 | `registry.semaphoreci.com/rust:1.70` |
| rust:1.70-browsers | `registry.semaphoreci.com/rust:1.70-browsers` |
| rust:1.70-node | `registry.semaphoreci.com/rust:1.70-node` |
| rust:1.70-node-browsers | `registry.semaphoreci.com/rust:1.70-node-browsers` |
| rust:1.70.0 | `registry.semaphoreci.com/rust:1.70.0` |
| rust:1.70.0-browsers | `registry.semaphoreci.com/rust:1.70.0-browsers` |
| rust:1.70.0-node | `registry.semaphoreci.com/rust:1.70.0-node` |
| rust:1.70.0-node-browsers | `registry.semaphoreci.com/rust:1.70.0-node-browsers` |
| rust:1.71 | `registry.semaphoreci.com/rust:1.71` |
| rust:1.71-node | `registry.semaphoreci.com/rust:1.71-node` |
| rust:1.71.0 | `registry.semaphoreci.com/rust:1.71.0` |
| rust:1.71.0-node | `registry.semaphoreci.com/rust:1.71.0-node` |
| rust:1.72 | `registry.semaphoreci.com/rust:1.72` |
| rust:1.72-browsers | `registry.semaphoreci.com/rust:1.72-browsers` |
| rust:1.72-node | `registry.semaphoreci.com/rust:1.72-node` |
| rust:1.72-node-browsers | `registry.semaphoreci.com/rust:1.72-node-browsers` |
| rust:1.72.0 | `registry.semaphoreci.com/rust:1.72.0` |
| rust:1.72.0-browsers | `registry.semaphoreci.com/rust:1.72.0-browsers` |
| rust:1.72.0-node | `registry.semaphoreci.com/rust:1.72.0-node` |
| rust:1.72.0-node-browsers | `registry.semaphoreci.com/rust:1.72.0-node-browsers` |
| rust:1.72.1 | `registry.semaphoreci.com/rust:1.72.1` |
| rust:1.72.1-browsers | `registry.semaphoreci.com/rust:1.72.1-browsers` |
| rust:1.72.1-node | `registry.semaphoreci.com/rust:1.72.1-node` |
| rust:1.72.1-node-browsers | `registry.semaphoreci.com/rust:1.72.1-node-browsers` |
| rust:1.73 | `registry.semaphoreci.com/rust:1.73` |
| rust:1.73-browsers | `registry.semaphoreci.com/rust:1.73-browsers` |
| rust:1.73-node | `registry.semaphoreci.com/rust:1.73-node` |
| rust:1.73-node-browsers | `registry.semaphoreci.com/rust:1.73-node-browsers` |
| rust:1.73.0 | `registry.semaphoreci.com/rust:1.73.0` |
| rust:1.73.0-browsers | `registry.semaphoreci.com/rust:1.73.0-browsers` |
| rust:1.73.0-node | `registry.semaphoreci.com/rust:1.73.0-node` |
| rust:1.73.0-node-browsers | `registry.semaphoreci.com/rust:1.73.0-node-browsers` |
| rust:1.74 | `registry.semaphoreci.com/rust:1.74` |
| rust:1.74-browsers | `registry.semaphoreci.com/rust:1.74-browsers` |
| rust:1.74-node | `registry.semaphoreci.com/rust:1.74-node` |
| rust:1.74-node-browsers | `registry.semaphoreci.com/rust:1.74-node-browsers` |
| rust:1.74.0 | `registry.semaphoreci.com/rust:1.74.0` |
| rust:1.74.0-browsers | `registry.semaphoreci.com/rust:1.74.0-browsers` |
| rust:1.74.0-node | `registry.semaphoreci.com/rust:1.74.0-node` |
| rust:1.74.0-node-browsers | `registry.semaphoreci.com/rust:1.74.0-node-browsers` |
| rust:1.75 | `registry.semaphoreci.com/rust:1.75` |
| rust:1.75-browsers | `registry.semaphoreci.com/rust:1.75-browsers` |
| rust:1.75-node | `registry.semaphoreci.com/rust:1.75-node` |
| rust:1.75-node-browsers | `registry.semaphoreci.com/rust:1.75-node-browsers` |
| rust:1.75.0 | `registry.semaphoreci.com/rust:1.75.0` |
| rust:1.75.0-browsers | `registry.semaphoreci.com/rust:1.75.0-browsers` |
| rust:1.75.0-node | `registry.semaphoreci.com/rust:1.75.0-node` |
| rust:1.75.0-node-browsers | `registry.semaphoreci.com/rust:1.75.0-node-browsers` |
| rust:1.76 | `registry.semaphoreci.com/rust:1.76` |
| rust:1.76-node | `registry.semaphoreci.com/rust:1.76-node` |
| rust:1.76.0 | `registry.semaphoreci.com/rust:1.76.0` |
| rust:1.76.0-node | `registry.semaphoreci.com/rust:1.76.0-node` |
| rust:1.77 | `registry.semaphoreci.com/rust:1.77` |
| rust:1.77-node | `registry.semaphoreci.com/rust:1.77-node` |
| rust:1.77.2 | `registry.semaphoreci.com/rust:1.77.2` |
| rust:1.77.2-node | `registry.semaphoreci.com/rust:1.77.2-node` |
| rust:1.82 | `registry.semaphoreci.com/rust:1.82` |
| rust:1.82-browsers | `registry.semaphoreci.com/rust:1.82-browsers` |
| rust:1.82-node | `registry.semaphoreci.com/rust:1.82-node` |
| rust:1.82-node-browsers | `registry.semaphoreci.com/rust:1.82-node-browsers` |
| rust:1.82.0 | `registry.semaphoreci.com/rust:1.82.0` |
| rust:1.82.0-browsers | `registry.semaphoreci.com/rust:1.82.0-browsers` |
| rust:1.82.0-node | `registry.semaphoreci.com/rust:1.82.0-node` |
| rust:1.82.0-node-browsers | `registry.semaphoreci.com/rust:1.82.0-node-browsers` |
| rust:1.83 | `registry.semaphoreci.com/rust:1.83` |
| rust:1.83-browsers | `registry.semaphoreci.com/rust:1.83-browsers` |
| rust:1.83-node | `registry.semaphoreci.com/rust:1.83-node` |
| rust:1.83-node-browsers | `registry.semaphoreci.com/rust:1.83-node-browsers` |
| rust:1.83.0 | `registry.semaphoreci.com/rust:1.83.0` |
| rust:1.83.0-browsers | `registry.semaphoreci.com/rust:1.83.0-browsers` |
| rust:1.83.0-node | `registry.semaphoreci.com/rust:1.83.0-node` |
| rust:1.83.0-node-browsers | `registry.semaphoreci.com/rust:1.83.0-node-browsers` |
| rust:1.84 | `registry.semaphoreci.com/rust:1.84` |
| rust:1.84-browsers | `registry.semaphoreci.com/rust:1.84-browsers` |
| rust:1.84-node | `registry.semaphoreci.com/rust:1.84-node` |
| rust:1.84-node-browsers | `registry.semaphoreci.com/rust:1.84-node-browsers` |
| rust:1.84.1 | `registry.semaphoreci.com/rust:1.84.1` |
| rust:1.84.1-browsers | `registry.semaphoreci.com/rust:1.84.1-browsers` |
| rust:1.84.1-node | `registry.semaphoreci.com/rust:1.84.1-node` |
| rust:1.84.1-node-browsers | `registry.semaphoreci.com/rust:1.84.1-node-browsers` |
| rust:1.85 | `registry.semaphoreci.com/rust:1.85` |
| rust:1.85-node | `registry.semaphoreci.com/rust:1.85-node` |
| rust:1.85.0 | `registry.semaphoreci.com/rust:1.85.0` |
| rust:1.85.0-node | `registry.semaphoreci.com/rust:1.85.0-node` |
| rust:1.85.1 | `registry.semaphoreci.com/rust:1.85.1` |
| rust:1.85.1-node | `registry.semaphoreci.com/rust:1.85.1-node` |
| rust:1.86 | `registry.semaphoreci.com/rust:1.86` |
| rust:1.86-browsers | `registry.semaphoreci.com/rust:1.86-browsers` |
| rust:1.86-node | `registry.semaphoreci.com/rust:1.86-node` |
| rust:1.86-node-browsers | `registry.semaphoreci.com/rust:1.86-node-browsers` |
| rust:1.86.0 | `registry.semaphoreci.com/rust:1.86.0` |
| rust:1.86.0-browsers | `registry.semaphoreci.com/rust:1.86.0-browsers` |
| rust:1.86.0-node | `registry.semaphoreci.com/rust:1.86.0-node` |
| rust:1.86.0-node-browsers | `registry.semaphoreci.com/rust:1.86.0-node-browsers` |
| rust:1.87 | `registry.semaphoreci.com/rust:1.87` |
| rust:1.87-browsers | `registry.semaphoreci.com/rust:1.87-browsers` |
| rust:1.87-node | `registry.semaphoreci.com/rust:1.87-node` |
| rust:1.87-node-browsers | `registry.semaphoreci.com/rust:1.87-node-browsers` |
| rust:1.87.0 | `registry.semaphoreci.com/rust:1.87.0` |
| rust:1.87.0-browsers | `registry.semaphoreci.com/rust:1.87.0-browsers` |
| rust:1.87.0-node | `registry.semaphoreci.com/rust:1.87.0-node` |
| rust:1.87.0-node-browsers | `registry.semaphoreci.com/rust:1.87.0-node-browsers` |
| rust:1.88 | `registry.semaphoreci.com/rust:1.88` |
| rust:1.88-browsers | `registry.semaphoreci.com/rust:1.88-browsers` |
| rust:1.88-node | `registry.semaphoreci.com/rust:1.88-node` |
| rust:1.88-node-browsers | `registry.semaphoreci.com/rust:1.88-node-browsers` |
| rust:1.88.0 | `registry.semaphoreci.com/rust:1.88.0` |
| rust:1.88.0-browsers | `registry.semaphoreci.com/rust:1.88.0-browsers` |
| rust:1.88.0-node | `registry.semaphoreci.com/rust:1.88.0-node` |
| rust:1.88.0-node-browsers | `registry.semaphoreci.com/rust:1.88.0-node-browsers` |
| rust:1.89 | `registry.semaphoreci.com/rust:1.89` |
| rust:1.89.0 | `registry.semaphoreci.com/rust:1.89.0` |
| rust:1.91 | `registry.semaphoreci.com/rust:1.91` |
| rust:1.91-node | `registry.semaphoreci.com/rust:1.91-node` |
| rust:1.91.0 | `registry.semaphoreci.com/rust:1.91.0` |
| rust:1.91.0-node | `registry.semaphoreci.com/rust:1.91.0-node` |
| rust:1.91.1 | `registry.semaphoreci.com/rust:1.91.1` |
| rust:1.91.1-node | `registry.semaphoreci.com/rust:1.91.1-node` |
| rust:1.92 | `registry.semaphoreci.com/rust:1.92` |
| rust:1.92-node | `registry.semaphoreci.com/rust:1.92-node` |
| rust:1.92.0 | `registry.semaphoreci.com/rust:1.92.0` |
| rust:1.92.0-node | `registry.semaphoreci.com/rust:1.92.0-node` |
| rust:1.93 | `registry.semaphoreci.com/rust:1.93` |
| rust:1.93-node | `registry.semaphoreci.com/rust:1.93-node` |
| rust:1.93.0 | `registry.semaphoreci.com/rust:1.93.0` |
| rust:1.93.0-node | `registry.semaphoreci.com/rust:1.93.0-node` |
| rust:1.93.1 | `registry.semaphoreci.com/rust:1.93.1` |
| rust:1.93.1-node | `registry.semaphoreci.com/rust:1.93.1-node` |
| rust:1.94 | `registry.semaphoreci.com/rust:1.94` |
| rust:1.94-browsers | `registry.semaphoreci.com/rust:1.94-browsers` |
| rust:1.94-node | `registry.semaphoreci.com/rust:1.94-node` |
| rust:1.94-node-browsers | `registry.semaphoreci.com/rust:1.94-node-browsers` |
| rust:1.94.1 | `registry.semaphoreci.com/rust:1.94.1` |
| rust:1.94.1-browsers | `registry.semaphoreci.com/rust:1.94.1-browsers` |
| rust:1.94.1-node | `registry.semaphoreci.com/rust:1.94.1-node` |
| rust:1.94.1-node-browsers | `registry.semaphoreci.com/rust:1.94.1-node-browsers` |
| rust:1.95 | `registry.semaphoreci.com/rust:1.95` |
| rust:1.95-browsers | `registry.semaphoreci.com/rust:1.95-browsers` |
| rust:1.95-node | `registry.semaphoreci.com/rust:1.95-node` |
| rust:1.95-node-browsers | `registry.semaphoreci.com/rust:1.95-node-browsers` |
| rust:1.95.0 | `registry.semaphoreci.com/rust:1.95.0` |
| rust:1.95.0-browsers | `registry.semaphoreci.com/rust:1.95.0-browsers` |
| rust:1.95.0-node | `registry.semaphoreci.com/rust:1.95.0-node` |
| rust:1.95.0-node-browsers | `registry.semaphoreci.com/rust:1.95.0-node-browsers` |
| rust:1.96 | `registry.semaphoreci.com/rust:1.96` |
| rust:1.96-browsers | `registry.semaphoreci.com/rust:1.96-browsers` |
| rust:1.96-node | `registry.semaphoreci.com/rust:1.96-node` |
| rust:1.96-node-browsers | `registry.semaphoreci.com/rust:1.96-node-browsers` |
| rust:1.96.0 | `registry.semaphoreci.com/rust:1.96.0` |
| rust:1.96.0-browsers | `registry.semaphoreci.com/rust:1.96.0-browsers` |
| rust:1.96.0-node | `registry.semaphoreci.com/rust:1.96.0-node` |
| rust:1.96.0-node-browsers | `registry.semaphoreci.com/rust:1.96.0-node-browsers` |
| rust:1.96.1 | `registry.semaphoreci.com/rust:1.96.1` |
| rust:1.96.1-browsers | `registry.semaphoreci.com/rust:1.96.1-browsers` |
| rust:1.96.1-node | `registry.semaphoreci.com/rust:1.96.1-node` |
| rust:1.96.1-node-browsers | `registry.semaphoreci.com/rust:1.96.1-node-browsers` |
| rust:1.97 | `registry.semaphoreci.com/rust:1.97` |
| rust:1.97-browsers | `registry.semaphoreci.com/rust:1.97-browsers` |
| rust:1.97-node | `registry.semaphoreci.com/rust:1.97-node` |
| rust:1.97-node-browsers | `registry.semaphoreci.com/rust:1.97-node-browsers` |
| rust:1.97.1 | `registry.semaphoreci.com/rust:1.97.1` |
| rust:1.97.1-browsers | `registry.semaphoreci.com/rust:1.97.1-browsers` |
| rust:1.97.1-node | `registry.semaphoreci.com/rust:1.97.1-node` |
| rust:1.97.1-node-browsers | `registry.semaphoreci.com/rust:1.97.1-node-browsers` |
| rust:1.98 | `registry.semaphoreci.com/rust:1.98` |
| rust:1.98-browsers | `registry.semaphoreci.com/rust:1.98-browsers` |
| rust:1.98-node | `registry.semaphoreci.com/rust:1.98-node` |
| rust:1.98-node-browsers | `registry.semaphoreci.com/rust:1.98-node-browsers` |
| rust:1.98.0 | `registry.semaphoreci.com/rust:1.98.0` |
| rust:1.98.0-browsers | `registry.semaphoreci.com/rust:1.98.0-browsers` |
| rust:1.98.0-node | `registry.semaphoreci.com/rust:1.98.0-node` |
| rust:1.98.0-node-browsers | `registry.semaphoreci.com/rust:1.98.0-node-browsers` |
| rust:1.98.1 | `registry.semaphoreci.com/rust:1.98.1` |
| rust:1.98.1-browsers | `registry.semaphoreci.com/rust:1.98.1-browsers` |
| rust:1.98.1-node | `registry.semaphoreci.com/rust:1.98.1-node` |
| rust:1.98.1-node-browsers | `registry.semaphoreci.com/rust:1.98.1-node-browsers` |

</div>
</details>


### Elixir

<details>
<summary>Elixir images</summary>
<div>

| Image | Link |
|--------|--------|
| elixir:1.6 | `registry.semaphoreci.com/elixir:1.6` |  
| elixir:1.6-browsers | `registry.semaphoreci.com/elixir:1.6-browsers` |
| elixir:1.6-node | `registry.semaphoreci.com/elixir:1.6-node` |
| elixir:1.6-node-browsers | `registry.semaphoreci.com/elixir:1.6-node-browsers` |
| elixir:1.6.6 | `registry.semaphoreci.com/elixir:1.6.6` |
| elixir:1.6.6-browsers | `registry.semaphoreci.com/elixir:1.6.6-browsers` |
| elixir:1.6.6-node | `registry.semaphoreci.com/elixir:1.6.6-node` |
| elixir:1.7 | `registry.semaphoreci.com/elixir:1.7` |  
| elixir:1.7-browsers | `registry.semaphoreci.com/elixir:1.7-browsers` |
| elixir:1.7-node | `registry.semaphoreci.com/elixir:1.7-node` |
| elixir:1.7-node-browsers | `registry.semaphoreci.com/elixir:1.7-node-browsers` |
| elixir:1.7.4 | `registry.semaphoreci.com/elixir:1.7.4` |
| elixir:1.7.4-browsers | `registry.semaphoreci.com/elixir:1.7.4-browsers` |
| elixir:1.7.4-node | `registry.semaphoreci.com/elixir:1.7.4-node` |
| elixir:1.8 | `registry.semaphoreci.com/elixir:1.8` |  
| elixir:1.8-browsers | `registry.semaphoreci.com/elixir:1.8-browsers` |
| elixir:1.8-node | `registry.semaphoreci.com/elixir:1.8-node` |
| elixir:1.8-node-browsers | `registry.semaphoreci.com/elixir:1.8-node-browsers` |
| elixir:1.8.2 | `registry.semaphoreci.com/elixir:1.8.2` |
| elixir:1.8.2-browsers | `registry.semaphoreci.com/elixir:1.8.2-browsers` |
| elixir:1.8.2-node | `registry.semaphoreci.com/elixir:1.8.2-node` |
| elixir:1.9 | `registry.semaphoreci.com/elixir:1.9` |  
| elixir:1.9-browsers | `registry.semaphoreci.com/elixir:1.9-browsers` |
| elixir:1.9-node | `registry.semaphoreci.com/elixir:1.9-node` |
| elixir:1.9.4 | `registry.semaphoreci.com/elixir:1.9.4` |
| elixir:1.9.4-browsers | `registry.semaphoreci.com/elixir:1.9.4-browsers` |
| elixir:1.9.4-node | `registry.semaphoreci.com/elixir:1.9.4-node` |
| elixir:1.10 | `registry.semaphoreci.com/elixir:1.10` |  
| elixir:1.10-browsers | `registry.semaphoreci.com/elixir:1.10-browsers` |
| elixir:1.10-node | `registry.semaphoreci.com/elixir:1.10-node` |
| elixir:1.10.3 | `registry.semaphoreci.com/elixir:1.10.3` |
| elixir:1.10.4 | `registry.semaphoreci.com/elixir:1.10.4` |
| elixir:1.10.4-browsers | `registry.semaphoreci.com/elixir:1.10.4-browsers` |
| elixir:1.10.4-node | `registry.semaphoreci.com/elixir:1.10.4-node` |
| elixir:1.11 | `registry.semaphoreci.com/elixir:1.11` |  
| elixir:1.11-browsers | `registry.semaphoreci.com/elixir:1.11-browsers` |
| elixir:1.11-node | `registry.semaphoreci.com/elixir:1.11-node` |
| elixir:1.11.1 | `registry.semaphoreci.com/elixir:1.11.1` |
| elixir:1.11.2 | `registry.semaphoreci.com/elixir:1.11.2` |
| elixir:1.11.3 | `registry.semaphoreci.com/elixir:1.11.3` |
| elixir:1.11.3-browsers | `registry.semaphoreci.com/elixir:1.11.3-browsers` |
| elixir:1.11.3-node | `registry.semaphoreci.com/elixir:1.11.3-node` |
| elixir:1.11.4 | `registry.semaphoreci.com/elixir:1.11.4` |
| elixir:1.11.4-browsers | `registry.semaphoreci.com/elixir:1.11.4-browsers` |
| elixir:1.11.4-node | `registry.semaphoreci.com/elixir:1.11.4-node` |
| elixir:1.12 | `registry.semaphoreci.com/elixir:1.12` |  
| elixir:1.12-browsers | `registry.semaphoreci.com/elixir:1.12-browsers` |
| elixir:1.12-node | `registry.semaphoreci.com/elixir:1.12-node` |
| elixir:1.12.0 | `registry.semaphoreci.com/elixir:1.12.0` |
| elixir:1.12.0-browsers | `registry.semaphoreci.com/elixir:1.12.0-browsers` |
| elixir:1.12.0-node | `registry.semaphoreci.com/elixir:1.12.0-node` |
| elixir:1.12.1 | `registry.semaphoreci.com/elixir:1.12.1` |
| elixir:1.12.1-browsers | `registry.semaphoreci.com/elixir:1.12.1-browsers` |
| elixir:1.12.1-node | `registry.semaphoreci.com/elixir:1.12.1-node` |
| elixir:1.12.2 | `registry.semaphoreci.com/elixir:1.12.2` |
| elixir:1.12.2-browsers | `registry.semaphoreci.com/elixir:1.12.2-browsers` |
| elixir:1.12.2-node | `registry.semaphoreci.com/elixir:1.12.2-node` |
| elixir:1.12.3 | `registry.semaphoreci.com/elixir:1.12.3` |
| elixir:1.12.3-browsers | `registry.semaphoreci.com/elixir:1.12.3-browsers` |
| elixir:1.12.3-node | `registry.semaphoreci.com/elixir:1.12.3-node` |
| elixir:1.13 | `registry.semaphoreci.com/elixir:1.13` |  
| elixir:1.13-browsers | `registry.semaphoreci.com/elixir:1.13-browsers` |
| elixir:1.13-node | `registry.semaphoreci.com/elixir:1.13-node` |
| elixir:1.13.0 | `registry.semaphoreci.com/elixir:1.13.0` |
| elixir:1.13.0-browsers | `registry.semaphoreci.com/elixir:1.13.0-browsers` |
| elixir:1.13.0-node | `registry.semaphoreci.com/elixir:1.13.0-node` |
| elixir:1.13.1 | `registry.semaphoreci.com/elixir:1.13.1` |
| elixir:1.13.1-browsers | `registry.semaphoreci.com/elixir:1.13.1-browsers` |
| elixir:1.13.1-node | `registry.semaphoreci.com/elixir:1.13.1-node` |
| elixir:1.13.2 | `registry.semaphoreci.com/elixir:1.13.2` |
| elixir:1.13.2-browsers | `registry.semaphoreci.com/elixir:1.13.2-browsers` |
| elixir:1.13.2-node | `registry.semaphoreci.com/elixir:1.13.2-node` |
| elixir:1.13.3 | `registry.semaphoreci.com/elixir:1.13.3` |
| elixir:1.13.3-browsers | `registry.semaphoreci.com/elixir:1.13.3-browsers` |
| elixir:1.13.3-node | `registry.semaphoreci.com/elixir:1.13.3-node` |
| elixir:1.13.4 | `registry.semaphoreci.com/elixir:1.13.4` |
| elixir:1.13.4-browsers | `registry.semaphoreci.com/elixir:1.13.4-browsers` |
| elixir:1.13.4-node | `registry.semaphoreci.com/elixir:1.13.4-node` |
| elixir:1.14 | `registry.semaphoreci.com/elixir:1.14` |  
| elixir:1.14-browsers | `registry.semaphoreci.com/elixir:1.14-browsers` |
| elixir:1.14-node | `registry.semaphoreci.com/elixir:1.14-node` |
| elixir:1.14.0 | `registry.semaphoreci.com/elixir:1.14.0` |
| elixir:1.14.0-browsers | `registry.semaphoreci.com/elixir:1.14.0-browsers` |
| elixir:1.14.0-node | `registry.semaphoreci.com/elixir:1.14.0-node` |
| elixir:1.14.1 | `registry.semaphoreci.com/elixir:1.14.1` |
| elixir:1.14.1-browsers | `registry.semaphoreci.com/elixir:1.14.1-browsers` |
| elixir:1.14.1-node | `registry.semaphoreci.com/elixir:1.14.1-node` |
| elixir:1.14.2 | `registry.semaphoreci.com/elixir:1.14.2` |
| elixir:1.14.2-browsers | `registry.semaphoreci.com/elixir:1.14.2-browsers` |
| elixir:1.14.2-node | `registry.semaphoreci.com/elixir:1.14.2-node` |
| elixir:1.14.3 | `registry.semaphoreci.com/elixir:1.14.3` |
| elixir:1.14.3-node | `registry.semaphoreci.com/elixir:1.14.3-node` |
| elixir:1.14.4 | `registry.semaphoreci.com/elixir:1.14.4` |
| elixir:1.14.4-node | `registry.semaphoreci.com/elixir:1.14.4-node` |
| elixir:1.14.5 | `registry.semaphoreci.com/elixir:1.14.5` |
| elixir:1.14.5-browsers | `registry.semaphoreci.com/elixir:1.14.5-browsers` |
| elixir:1.14.5-node | `registry.semaphoreci.com/elixir:1.14.5-node` |
| elixir:1.15 | `registry.semaphoreci.com/elixir:1.15` |  
| elixir:1.15-browsers | `registry.semaphoreci.com/elixir:1.15-browsers` |
| elixir:1.15-node | `registry.semaphoreci.com/elixir:1.15-node` |
| elixir:1.15.0 | `registry.semaphoreci.com/elixir:1.15.0` |
| elixir:1.15.0-browsers | `registry.semaphoreci.com/elixir:1.15.0-browsers` |
| elixir:1.15.0-node | `registry.semaphoreci.com/elixir:1.15.0-node` |
| elixir:1.15.1 | `registry.semaphoreci.com/elixir:1.15.1` |
| elixir:1.15.1-browsers | `registry.semaphoreci.com/elixir:1.15.1-browsers` |
| elixir:1.15.1-node | `registry.semaphoreci.com/elixir:1.15.1-node` |
| elixir:1.15.4 | `registry.semaphoreci.com/elixir:1.15.4` |
| elixir:1.15.4-browsers | `registry.semaphoreci.com/elixir:1.15.4-browsers` |
| elixir:1.15.4-node | `registry.semaphoreci.com/elixir:1.15.4-node` |
| elixir:1.15.6 | `registry.semaphoreci.com/elixir:1.15.6` |
| elixir:1.15.6-browsers | `registry.semaphoreci.com/elixir:1.15.6-browsers` |
| elixir:1.15.6-node | `registry.semaphoreci.com/elixir:1.15.6-node` |
| elixir:1.15.7 | `registry.semaphoreci.com/elixir:1.15.7` |
| elixir:1.15.7-browsers | `registry.semaphoreci.com/elixir:1.15.7-browsers` |
| elixir:1.15.7-node | `registry.semaphoreci.com/elixir:1.15.7-node` |
| elixir:1.15.8 | `registry.semaphoreci.com/elixir:1.15.8` |
| elixir:1.15.8-browsers | `registry.semaphoreci.com/elixir:1.15.8-browsers` |
| elixir:1.15.8-node | `registry.semaphoreci.com/elixir:1.15.8-node` |
| elixir:1.16 | `registry.semaphoreci.com/elixir:1.16` |  
| elixir:1.16-browsers | `registry.semaphoreci.com/elixir:1.16-browsers` |
| elixir:1.16-node | `registry.semaphoreci.com/elixir:1.16-node` |
| elixir:1.16.1 | `registry.semaphoreci.com/elixir:1.16.1` |
| elixir:1.16.1-browsers | `registry.semaphoreci.com/elixir:1.16.1-browsers` |
| elixir:1.16.1-node | `registry.semaphoreci.com/elixir:1.16.1-node` |
| elixir:1.16.2 | `registry.semaphoreci.com/elixir:1.16.2` |
| elixir:1.16.2-node | `registry.semaphoreci.com/elixir:1.16.2-node` |
| elixir:1.16.3 | `registry.semaphoreci.com/elixir:1.16.3` |
| elixir:1.16.3-browsers | `registry.semaphoreci.com/elixir:1.16.3-browsers` |
| elixir:1.16.3-node | `registry.semaphoreci.com/elixir:1.16.3-node` |
| elixir:1.17 | `registry.semaphoreci.com/elixir:1.17` |  
| elixir:1.17-browsers | `registry.semaphoreci.com/elixir:1.17-browsers` |
| elixir:1.17-node | `registry.semaphoreci.com/elixir:1.17-node` |
| elixir:1.17.3 | `registry.semaphoreci.com/elixir:1.17.3` |
| elixir:1.17.3-browsers | `registry.semaphoreci.com/elixir:1.17.3-browsers` |
| elixir:1.17.3-node | `registry.semaphoreci.com/elixir:1.17.3-node` |
| elixir:1.18 | `registry.semaphoreci.com/elixir:1.18` |  
| elixir:1.18-browsers | `registry.semaphoreci.com/elixir:1.18-browsers` |
| elixir:1.18-node | `registry.semaphoreci.com/elixir:1.18-node` |
| elixir:1.18.0 | `registry.semaphoreci.com/elixir:1.18.0` |
| elixir:1.18.0-browsers | `registry.semaphoreci.com/elixir:1.18.0-browsers` |
| elixir:1.18.0-node | `registry.semaphoreci.com/elixir:1.18.0-node` |
| elixir:1.18.1 | `registry.semaphoreci.com/elixir:1.18.1` |
| elixir:1.18.1-browsers | `registry.semaphoreci.com/elixir:1.18.1-browsers` |
| elixir:1.18.1-node | `registry.semaphoreci.com/elixir:1.18.1-node` |
| elixir:1.18.2 | `registry.semaphoreci.com/elixir:1.18.2` |
| elixir:1.18.3 | `registry.semaphoreci.com/elixir:1.18.3` |
| elixir:1.18.3-browsers | `registry.semaphoreci.com/elixir:1.18.3-browsers` |
| elixir:1.18.3-node | `registry.semaphoreci.com/elixir:1.18.3-node` |
| elixir:1.18.4 | `registry.semaphoreci.com/elixir:1.18.4` |
| elixir:1.18.4-browsers | `registry.semaphoreci.com/elixir:1.18.4-browsers` |
| elixir:1.18.4-node | `registry.semaphoreci.com/elixir:1.18.4-node` |
| elixir:1.19 | `registry.semaphoreci.com/elixir:1.19` |  
| elixir:1.19-browsers | `registry.semaphoreci.com/elixir:1.19-browsers` |
| elixir:1.19-node | `registry.semaphoreci.com/elixir:1.19-node` |
| elixir:1.19.1 | `registry.semaphoreci.com/elixir:1.19.1` |
| elixir:1.19.1-node | `registry.semaphoreci.com/elixir:1.19.1-node` |
| elixir:1.19.3 | `registry.semaphoreci.com/elixir:1.19.3` |
| elixir:1.19.3-node | `registry.semaphoreci.com/elixir:1.19.3-node` |
| elixir:1.19.4 | `registry.semaphoreci.com/elixir:1.19.4` |
| elixir:1.19.4-node | `registry.semaphoreci.com/elixir:1.19.4-node` |
| elixir:1.19.5 | `registry.semaphoreci.com/elixir:1.19.5` |
| elixir:1.19.5-browsers | `registry.semaphoreci.com/elixir:1.19.5-browsers` |
| elixir:1.19.5-node | `registry.semaphoreci.com/elixir:1.19.5-node` |
| elixir:1.19.6 | `registry.semaphoreci.com/elixir:1.19.6` |
| elixir:1.19.6-browsers | `registry.semaphoreci.com/elixir:1.19.6-browsers` |
| elixir:1.19.6-node | `registry.semaphoreci.com/elixir:1.19.6-node` |
| elixir:1.20 | `registry.semaphoreci.com/elixir:1.20` |  
| elixir:1.20-browsers | `registry.semaphoreci.com/elixir:1.20-browsers` |
| elixir:1.20-node | `registry.semaphoreci.com/elixir:1.20-node` |
| elixir:1.20.1 | `registry.semaphoreci.com/elixir:1.20.1` |
| elixir:1.20.1-browsers | `registry.semaphoreci.com/elixir:1.20.1-browsers` |
| elixir:1.20.1-node | `registry.semaphoreci.com/elixir:1.20.1-node` |
| elixir:1.20.2 | `registry.semaphoreci.com/elixir:1.20.2` |
| elixir:1.20.2-browsers | `registry.semaphoreci.com/elixir:1.20.2-browsers` |
| elixir:1.20.2-node | `registry.semaphoreci.com/elixir:1.20.2-node` |
| elixir:1.20.3 | `registry.semaphoreci.com/elixir:1.20.3` |
| elixir:1.20.3-browsers | `registry.semaphoreci.com/elixir:1.20.3-browsers` |
| elixir:1.20.3-node | `registry.semaphoreci.com/elixir:1.20.3-node` |
| elixir:1.20.4 | `registry.semaphoreci.com/elixir:1.20.4` |
| elixir:1.20.4-browsers | `registry.semaphoreci.com/elixir:1.20.4-browsers` |
| elixir:1.20.4-node | `registry.semaphoreci.com/elixir:1.20.4-node` |

</div>
</details>

### Erlang

<details>
<summary>Erlang images</summary>
<div>

| Image | Link |
|--------|--------|
| erlang:18 | `registry.semaphoreci.com/erlang:18` |
| erlang:18.3 | `registry.semaphoreci.com/erlang:18.3` |
| erlang:18.3.4 | `registry.semaphoreci.com/erlang:18.3.4` |
| erlang:18.3.4.11 | `registry.semaphoreci.com/erlang:18.3.4.11` |
| erlang:19 | `registry.semaphoreci.com/erlang:19` |
| erlang:19.3 | `registry.semaphoreci.com/erlang:19.3` |
| erlang:19.3.6 | `registry.semaphoreci.com/erlang:19.3.6` |
| erlang:19.3.6.13 | `registry.semaphoreci.com/erlang:19.3.6.13` |
| erlang:20 | `registry.semaphoreci.com/erlang:20` |
| erlang:20.3 | `registry.semaphoreci.com/erlang:20.3` |
| erlang:20.3.8 | `registry.semaphoreci.com/erlang:20.3.8` |
| erlang:20.3.8.26 | `registry.semaphoreci.com/erlang:20.3.8.26` |
| erlang:21 | `registry.semaphoreci.com/erlang:21` |
| erlang:21.3 | `registry.semaphoreci.com/erlang:21.3` |
| erlang:21.3.8 | `registry.semaphoreci.com/erlang:21.3.8` |
| erlang:21.3.8.18 | `registry.semaphoreci.com/erlang:21.3.8.18` |
| erlang:21.3.8.20 | `registry.semaphoreci.com/erlang:21.3.8.20` |
| erlang:21.3.8.21 | `registry.semaphoreci.com/erlang:21.3.8.21` |
| erlang:21.3.8.22 | `registry.semaphoreci.com/erlang:21.3.8.22` |
| erlang:21.3.8.23 | `registry.semaphoreci.com/erlang:21.3.8.23` |
| erlang:21.3.8.24 | `registry.semaphoreci.com/erlang:21.3.8.24` |
| erlang:22 | `registry.semaphoreci.com/erlang:22` |
| erlang:22.3 | `registry.semaphoreci.com/erlang:22.3` |
| erlang:22.3.4 | `registry.semaphoreci.com/erlang:22.3.4` |
| erlang:22.3.4.12 | `registry.semaphoreci.com/erlang:22.3.4.12` |
| erlang:22.3.4.13 | `registry.semaphoreci.com/erlang:22.3.4.13` |
| erlang:22.3.4.15 | `registry.semaphoreci.com/erlang:22.3.4.15` |
| erlang:22.3.4.16 | `registry.semaphoreci.com/erlang:22.3.4.16` |
| erlang:22.3.4.17 | `registry.semaphoreci.com/erlang:22.3.4.17` |
| erlang:22.3.4.19 | `registry.semaphoreci.com/erlang:22.3.4.19` |
| erlang:22.3.4.20 | `registry.semaphoreci.com/erlang:22.3.4.20` |
| erlang:22.3.4.21 | `registry.semaphoreci.com/erlang:22.3.4.21` |
| erlang:22.3.4.22 | `registry.semaphoreci.com/erlang:22.3.4.22` |
| erlang:22.3.4.23 | `registry.semaphoreci.com/erlang:22.3.4.23` |
| erlang:22.3.4.24 | `registry.semaphoreci.com/erlang:22.3.4.24` |
| erlang:22.3.4.25 | `registry.semaphoreci.com/erlang:22.3.4.25` |
| erlang:22.3.4.26 | `registry.semaphoreci.com/erlang:22.3.4.26` |
| erlang:22.3.4.27 | `registry.semaphoreci.com/erlang:22.3.4.27` |
| erlang:23 | `registry.semaphoreci.com/erlang:23` |
| erlang:23.1 | `registry.semaphoreci.com/erlang:23.1` |
| erlang:23.1.1 | `registry.semaphoreci.com/erlang:23.1.1` |
| erlang:23.1.1.0 | `registry.semaphoreci.com/erlang:23.1.1.0` |
| erlang:23.1.4 | `registry.semaphoreci.com/erlang:23.1.4` |
| erlang:23.1.4.0 | `registry.semaphoreci.com/erlang:23.1.4.0` |
| erlang:23.2 | `registry.semaphoreci.com/erlang:23.2` |
| erlang:23.2.1 | `registry.semaphoreci.com/erlang:23.2.1` |
| erlang:23.2.1.0 | `registry.semaphoreci.com/erlang:23.2.1.0` |
| erlang:23.2.3 | `registry.semaphoreci.com/erlang:23.2.3` |
| erlang:23.2.3.0 | `registry.semaphoreci.com/erlang:23.2.3.0` |
| erlang:23.2.6 | `registry.semaphoreci.com/erlang:23.2.6` |
| erlang:23.2.6.0 | `registry.semaphoreci.com/erlang:23.2.6.0` |
| erlang:23.3 | `registry.semaphoreci.com/erlang:23.3` |
| erlang:23.3.1 | `registry.semaphoreci.com/erlang:23.3.1` |
| erlang:23.3.1.0 | `registry.semaphoreci.com/erlang:23.3.1.0` |
| erlang:23.3.2 | `registry.semaphoreci.com/erlang:23.3.2` |
| erlang:23.3.2.0 | `registry.semaphoreci.com/erlang:23.3.2.0` |
| erlang:23.3.4 | `registry.semaphoreci.com/erlang:23.3.4` |
| erlang:23.3.4.1 | `registry.semaphoreci.com/erlang:23.3.4.1` |
| erlang:23.3.4.2 | `registry.semaphoreci.com/erlang:23.3.4.2` |
| erlang:23.3.4.4 | `registry.semaphoreci.com/erlang:23.3.4.4` |
| erlang:23.3.4.5 | `registry.semaphoreci.com/erlang:23.3.4.5` |
| erlang:23.3.4.6 | `registry.semaphoreci.com/erlang:23.3.4.6` |
| erlang:23.3.4.7 | `registry.semaphoreci.com/erlang:23.3.4.7` |
| erlang:23.3.4.8 | `registry.semaphoreci.com/erlang:23.3.4.8` |
| erlang:23.3.4.9 | `registry.semaphoreci.com/erlang:23.3.4.9` |
| erlang:23.3.4.10 | `registry.semaphoreci.com/erlang:23.3.4.10` |
| erlang:23.3.4.11 | `registry.semaphoreci.com/erlang:23.3.4.11` |
| erlang:23.3.4.13 | `registry.semaphoreci.com/erlang:23.3.4.13` |
| erlang:23.3.4.14 | `registry.semaphoreci.com/erlang:23.3.4.14` |
| erlang:23.3.4.15 | `registry.semaphoreci.com/erlang:23.3.4.15` |
| erlang:23.3.4.16 | `registry.semaphoreci.com/erlang:23.3.4.16` |
| erlang:23.3.4.17 | `registry.semaphoreci.com/erlang:23.3.4.17` |
| erlang:23.3.4.18 | `registry.semaphoreci.com/erlang:23.3.4.18` |
| erlang:23.3.4.19 | `registry.semaphoreci.com/erlang:23.3.4.19` |
| erlang:23.3.4.20 | `registry.semaphoreci.com/erlang:23.3.4.20` |
| erlang:24 | `registry.semaphoreci.com/erlang:24` |
| erlang:24.0 | `registry.semaphoreci.com/erlang:24.0` |
| erlang:24.0.1 | `registry.semaphoreci.com/erlang:24.0.1` |
| erlang:24.0.1.0 | `registry.semaphoreci.com/erlang:24.0.1.0` |
| erlang:24.0.2 | `registry.semaphoreci.com/erlang:24.0.2` |
| erlang:24.0.2.0 | `registry.semaphoreci.com/erlang:24.0.2.0` |
| erlang:24.0.3 | `registry.semaphoreci.com/erlang:24.0.3` |
| erlang:24.0.3.0 | `registry.semaphoreci.com/erlang:24.0.3.0` |
| erlang:24.0.5 | `registry.semaphoreci.com/erlang:24.0.5` |
| erlang:24.0.5.0 | `registry.semaphoreci.com/erlang:24.0.5.0` |
| erlang:24.0.6 | `registry.semaphoreci.com/erlang:24.0.6` |
| erlang:24.0.6.0 | `registry.semaphoreci.com/erlang:24.0.6.0` |
| erlang:24.1 | `registry.semaphoreci.com/erlang:24.1` |
| erlang:24.1.0 | `registry.semaphoreci.com/erlang:24.1.0` |
| erlang:24.1.0.0 | `registry.semaphoreci.com/erlang:24.1.0.0` |
| erlang:24.1.3 | `registry.semaphoreci.com/erlang:24.1.3` |
| erlang:24.1.3.0 | `registry.semaphoreci.com/erlang:24.1.3.0` |
| erlang:24.1.7 | `registry.semaphoreci.com/erlang:24.1.7` |
| erlang:24.1.7.0 | `registry.semaphoreci.com/erlang:24.1.7.0` |
| erlang:24.2 | `registry.semaphoreci.com/erlang:24.2` |
| erlang:24.2.0 | `registry.semaphoreci.com/erlang:24.2.0` |
| erlang:24.2.0.0 | `registry.semaphoreci.com/erlang:24.2.0.0` |
| erlang:24.2.1 | `registry.semaphoreci.com/erlang:24.2.1` |
| erlang:24.2.1.0 | `registry.semaphoreci.com/erlang:24.2.1.0` |
| erlang:24.2.2 | `registry.semaphoreci.com/erlang:24.2.2` |
| erlang:24.2.2.0 | `registry.semaphoreci.com/erlang:24.2.2.0` |
| erlang:24.3 | `registry.semaphoreci.com/erlang:24.3` |
| erlang:24.3.3 | `registry.semaphoreci.com/erlang:24.3.3` |
| erlang:24.3.3.0 | `registry.semaphoreci.com/erlang:24.3.3.0` |
| erlang:24.3.4 | `registry.semaphoreci.com/erlang:24.3.4` |
| erlang:24.3.4.0 | `registry.semaphoreci.com/erlang:24.3.4.0` |
| erlang:24.3.4.2 | `registry.semaphoreci.com/erlang:24.3.4.2` |
| erlang:24.3.4.4 | `registry.semaphoreci.com/erlang:24.3.4.4` |
| erlang:24.3.4.5 | `registry.semaphoreci.com/erlang:24.3.4.5` |
| erlang:24.3.4.6 | `registry.semaphoreci.com/erlang:24.3.4.6` |
| erlang:24.3.4.7 | `registry.semaphoreci.com/erlang:24.3.4.7` |
| erlang:24.3.4.10 | `registry.semaphoreci.com/erlang:24.3.4.10` |
| erlang:24.3.4.11 | `registry.semaphoreci.com/erlang:24.3.4.11` |
| erlang:24.3.4.12 | `registry.semaphoreci.com/erlang:24.3.4.12` |
| erlang:24.3.4.13 | `registry.semaphoreci.com/erlang:24.3.4.13` |
| erlang:24.3.4.15 | `registry.semaphoreci.com/erlang:24.3.4.15` |
| erlang:24.3.4.16 | `registry.semaphoreci.com/erlang:24.3.4.16` |
| erlang:24.3.4.17 | `registry.semaphoreci.com/erlang:24.3.4.17` |
| erlang:25 | `registry.semaphoreci.com/erlang:25` |
| erlang:25.0 | `registry.semaphoreci.com/erlang:25.0` |
| erlang:25.0.0 | `registry.semaphoreci.com/erlang:25.0.0` |
| erlang:25.0.0.0 | `registry.semaphoreci.com/erlang:25.0.0.0` |
| erlang:25.0.2 | `registry.semaphoreci.com/erlang:25.0.2` |
| erlang:25.0.2.0 | `registry.semaphoreci.com/erlang:25.0.2.0` |
| erlang:25.0.3 | `registry.semaphoreci.com/erlang:25.0.3` |
| erlang:25.0.3.0 | `registry.semaphoreci.com/erlang:25.0.3.0` |
| erlang:25.0.4 | `registry.semaphoreci.com/erlang:25.0.4` |
| erlang:25.0.4.0 | `registry.semaphoreci.com/erlang:25.0.4.0` |
| erlang:25.1 | `registry.semaphoreci.com/erlang:25.1` |
| erlang:25.1.0 | `registry.semaphoreci.com/erlang:25.1.0` |
| erlang:25.1.0.0 | `registry.semaphoreci.com/erlang:25.1.0.0` |
| erlang:25.1.2 | `registry.semaphoreci.com/erlang:25.1.2` |
| erlang:25.1.2.0 | `registry.semaphoreci.com/erlang:25.1.2.0` |
| erlang:25.2 | `registry.semaphoreci.com/erlang:25.2` |
| erlang:25.2.0 | `registry.semaphoreci.com/erlang:25.2.0` |
| erlang:25.2.0.0 | `registry.semaphoreci.com/erlang:25.2.0.0` |
| erlang:25.2.1 | `registry.semaphoreci.com/erlang:25.2.1` |
| erlang:25.2.1.0 | `registry.semaphoreci.com/erlang:25.2.1.0` |
| erlang:25.3 | `registry.semaphoreci.com/erlang:25.3` |
| erlang:25.3.0 | `registry.semaphoreci.com/erlang:25.3.0` |
| erlang:25.3.0.0 | `registry.semaphoreci.com/erlang:25.3.0.0` |
| erlang:25.3.1 | `registry.semaphoreci.com/erlang:25.3.1` |
| erlang:25.3.1.0 | `registry.semaphoreci.com/erlang:25.3.1.0` |
| erlang:25.3.2 | `registry.semaphoreci.com/erlang:25.3.2` |
| erlang:25.3.2.1 | `registry.semaphoreci.com/erlang:25.3.2.1` |
| erlang:25.3.2.2 | `registry.semaphoreci.com/erlang:25.3.2.2` |
| erlang:25.3.2.3 | `registry.semaphoreci.com/erlang:25.3.2.3` |
| erlang:25.3.2.6 | `registry.semaphoreci.com/erlang:25.3.2.6` |
| erlang:25.3.2.8 | `registry.semaphoreci.com/erlang:25.3.2.8` |
| erlang:25.3.2.9 | `registry.semaphoreci.com/erlang:25.3.2.9` |
| erlang:25.3.2.11 | `registry.semaphoreci.com/erlang:25.3.2.11` |
| erlang:25.3.2.13 | `registry.semaphoreci.com/erlang:25.3.2.13` |
| erlang:25.3.2.16 | `registry.semaphoreci.com/erlang:25.3.2.16` |
| erlang:25.3.2.20 | `registry.semaphoreci.com/erlang:25.3.2.20` |
| erlang:25.3.2.21 | `registry.semaphoreci.com/erlang:25.3.2.21` |
| erlang:26 | `registry.semaphoreci.com/erlang:26` |
| erlang:26.0 | `registry.semaphoreci.com/erlang:26.0` |
| erlang:26.0.0 | `registry.semaphoreci.com/erlang:26.0.0` |
| erlang:26.0.0.0 | `registry.semaphoreci.com/erlang:26.0.0.0` |
| erlang:26.0.1 | `registry.semaphoreci.com/erlang:26.0.1` |
| erlang:26.0.1.0 | `registry.semaphoreci.com/erlang:26.0.1.0` |
| erlang:26.0.2 | `registry.semaphoreci.com/erlang:26.0.2` |
| erlang:26.0.2.0 | `registry.semaphoreci.com/erlang:26.0.2.0` |
| erlang:26.1 | `registry.semaphoreci.com/erlang:26.1` |
| erlang:26.1.2 | `registry.semaphoreci.com/erlang:26.1.2` |
| erlang:26.1.2.0 | `registry.semaphoreci.com/erlang:26.1.2.0` |
| erlang:26.2 | `registry.semaphoreci.com/erlang:26.2` |
| erlang:26.2.1 | `registry.semaphoreci.com/erlang:26.2.1` |
| erlang:26.2.1.0 | `registry.semaphoreci.com/erlang:26.2.1.0` |
| erlang:26.2.2 | `registry.semaphoreci.com/erlang:26.2.2` |
| erlang:26.2.2.0 | `registry.semaphoreci.com/erlang:26.2.2.0` |
| erlang:26.2.4 | `registry.semaphoreci.com/erlang:26.2.4` |
| erlang:26.2.4.0 | `registry.semaphoreci.com/erlang:26.2.4.0` |
| erlang:26.2.5 | `registry.semaphoreci.com/erlang:26.2.5` |
| erlang:26.2.5.2 | `registry.semaphoreci.com/erlang:26.2.5.2` |
| erlang:26.2.5.6 | `registry.semaphoreci.com/erlang:26.2.5.6` |
| erlang:26.2.5.11 | `registry.semaphoreci.com/erlang:26.2.5.11` |
| erlang:26.2.5.13 | `registry.semaphoreci.com/erlang:26.2.5.13` |
| erlang:26.2.5.15 | `registry.semaphoreci.com/erlang:26.2.5.15` |
| erlang:26.2.5.16 | `registry.semaphoreci.com/erlang:26.2.5.16` |
| erlang:26.2.5.18 | `registry.semaphoreci.com/erlang:26.2.5.18` |
| erlang:26.2.5.19 | `registry.semaphoreci.com/erlang:26.2.5.19` |
| erlang:26.2.5.21 | `registry.semaphoreci.com/erlang:26.2.5.21` |
| erlang:27 | `registry.semaphoreci.com/erlang:27` |
| erlang:27.1 | `registry.semaphoreci.com/erlang:27.1` |
| erlang:27.1.1 | `registry.semaphoreci.com/erlang:27.1.1` |
| erlang:27.1.1.0 | `registry.semaphoreci.com/erlang:27.1.1.0` |
| erlang:27.1.2 | `registry.semaphoreci.com/erlang:27.1.2` |
| erlang:27.1.2.0 | `registry.semaphoreci.com/erlang:27.1.2.0` |
| erlang:27.2 | `registry.semaphoreci.com/erlang:27.2` |
| erlang:27.2.1 | `registry.semaphoreci.com/erlang:27.2.1` |
| erlang:27.2.1.0 | `registry.semaphoreci.com/erlang:27.2.1.0` |
| erlang:27.2.4 | `registry.semaphoreci.com/erlang:27.2.4` |
| erlang:27.2.4.0 | `registry.semaphoreci.com/erlang:27.2.4.0` |
| erlang:27.3 | `registry.semaphoreci.com/erlang:27.3` |
| erlang:27.3.0 | `registry.semaphoreci.com/erlang:27.3.0` |
| erlang:27.3.0.0 | `registry.semaphoreci.com/erlang:27.3.0.0` |
| erlang:27.3.3 | `registry.semaphoreci.com/erlang:27.3.3` |
| erlang:27.3.3.0 | `registry.semaphoreci.com/erlang:27.3.3.0` |
| erlang:27.3.4 | `registry.semaphoreci.com/erlang:27.3.4` |
| erlang:27.3.4.0 | `registry.semaphoreci.com/erlang:27.3.4.0` |
| erlang:27.3.4.2 | `registry.semaphoreci.com/erlang:27.3.4.2` |
| erlang:27.3.4.3 | `registry.semaphoreci.com/erlang:27.3.4.3` |
| erlang:27.3.4.6 | `registry.semaphoreci.com/erlang:27.3.4.6` |
| erlang:27.3.4.8 | `registry.semaphoreci.com/erlang:27.3.4.8` |
| erlang:27.3.4.9 | `registry.semaphoreci.com/erlang:27.3.4.9` |
| erlang:27.3.4.10 | `registry.semaphoreci.com/erlang:27.3.4.10` |
| erlang:27.3.4.12 | `registry.semaphoreci.com/erlang:27.3.4.12` |
| erlang:27.3.4.13 | `registry.semaphoreci.com/erlang:27.3.4.13` |
| erlang:27.3.4.15 | `registry.semaphoreci.com/erlang:27.3.4.15` |
| erlang:27.3.4.16 | `registry.semaphoreci.com/erlang:27.3.4.16` |
| erlang:27.3.4.18 | `registry.semaphoreci.com/erlang:27.3.4.18` |
| erlang:28 | `registry.semaphoreci.com/erlang:28` |
| erlang:28.0 | `registry.semaphoreci.com/erlang:28.0` |
| erlang:28.0.0 | `registry.semaphoreci.com/erlang:28.0.0` |
| erlang:28.0.0.0 | `registry.semaphoreci.com/erlang:28.0.0.0` |
| erlang:28.0.1 | `registry.semaphoreci.com/erlang:28.0.1` |
| erlang:28.0.1.0 | `registry.semaphoreci.com/erlang:28.0.1.0` |
| erlang:28.0.2 | `registry.semaphoreci.com/erlang:28.0.2` |
| erlang:28.0.2.0 | `registry.semaphoreci.com/erlang:28.0.2.0` |
| erlang:28.1 | `registry.semaphoreci.com/erlang:28.1` |
| erlang:28.1.0 | `registry.semaphoreci.com/erlang:28.1.0` |
| erlang:28.1.0.0 | `registry.semaphoreci.com/erlang:28.1.0.0` |
| erlang:28.2 | `registry.semaphoreci.com/erlang:28.2` |
| erlang:28.2.0 | `registry.semaphoreci.com/erlang:28.2.0` |
| erlang:28.2.0.0 | `registry.semaphoreci.com/erlang:28.2.0.0` |
| erlang:28.3 | `registry.semaphoreci.com/erlang:28.3` |
| erlang:28.3.0 | `registry.semaphoreci.com/erlang:28.3.0` |
| erlang:28.3.0.0 | `registry.semaphoreci.com/erlang:28.3.0.0` |
| erlang:28.3.1 | `registry.semaphoreci.com/erlang:28.3.1` |
| erlang:28.3.1.0 | `registry.semaphoreci.com/erlang:28.3.1.0` |
| erlang:28.3.2 | `registry.semaphoreci.com/erlang:28.3.2` |
| erlang:28.3.2.0 | `registry.semaphoreci.com/erlang:28.3.2.0` |
| erlang:28.4 | `registry.semaphoreci.com/erlang:28.4` |
| erlang:28.4.1 | `registry.semaphoreci.com/erlang:28.4.1` |
| erlang:28.4.1.0 | `registry.semaphoreci.com/erlang:28.4.1.0` |
| erlang:28.4.2 | `registry.semaphoreci.com/erlang:28.4.2` |
| erlang:28.4.2.0 | `registry.semaphoreci.com/erlang:28.4.2.0` |
| erlang:28.5 | `registry.semaphoreci.com/erlang:28.5` |
| erlang:28.5.0 | `registry.semaphoreci.com/erlang:28.5.0` |
| erlang:28.5.0.1 | `registry.semaphoreci.com/erlang:28.5.0.1` |
| erlang:28.5.0.2 | `registry.semaphoreci.com/erlang:28.5.0.2` |
| erlang:28.5.0.4 | `registry.semaphoreci.com/erlang:28.5.0.4` |
| erlang:28.5.0.5 | `registry.semaphoreci.com/erlang:28.5.0.5` |
| erlang:28.5.0.7 | `registry.semaphoreci.com/erlang:28.5.0.7` |
| erlang:29 | `registry.semaphoreci.com/erlang:29` |
| erlang:29.0 | `registry.semaphoreci.com/erlang:29.0` |
| erlang:29.0.1 | `registry.semaphoreci.com/erlang:29.0.1` |
| erlang:29.0.1.0 | `registry.semaphoreci.com/erlang:29.0.1.0` |
| erlang:29.0.2 | `registry.semaphoreci.com/erlang:29.0.2` |
| erlang:29.0.2.0 | `registry.semaphoreci.com/erlang:29.0.2.0` |
| erlang:29.0.4 | `registry.semaphoreci.com/erlang:29.0.4` |
| erlang:29.0.4.0 | `registry.semaphoreci.com/erlang:29.0.4.0` |
| erlang:29.0.5 | `registry.semaphoreci.com/erlang:29.0.5` |
| erlang:29.0.5.0 | `registry.semaphoreci.com/erlang:29.0.5.0` |
| erlang:29.1 | `registry.semaphoreci.com/erlang:29.1` |
| erlang:29.1.1 | `registry.semaphoreci.com/erlang:29.1.1` |
| erlang:29.1.1.0 | `registry.semaphoreci.com/erlang:29.1.1.0` |

</div>
</details>

### Haskell

<details>
<summary>Haskell images</summary>
<div>

| Image | Link |
|--------|--------|
| haskell:8 | `registry.semaphoreci.com/haskell:8` |  
| haskell:8.6 | `registry.semaphoreci.com/haskell:8.6` |  
| haskell:8.8 | `registry.semaphoreci.com/haskell:8.8` |  
| haskell:8.8.4 | `registry.semaphoreci.com/haskell:8.8.4` |  
| haskell:8.10 | `registry.semaphoreci.com/haskell:8.10` |  
| haskell:8.10.2 | `registry.semaphoreci.com/haskell:8.10.2` |  
| haskell:8.10.4 | `registry.semaphoreci.com/haskell:8.10.4` |  
| haskell:8.10.7 | `registry.semaphoreci.com/haskell:8.10.7` |  
| haskell:9 | `registry.semaphoreci.com/haskell:9` |  
| haskell:9.0 | `registry.semaphoreci.com/haskell:9.0` |  
| haskell:9.0.1 | `registry.semaphoreci.com/haskell:9.0.1` |  
| haskell:9.0.2 | `registry.semaphoreci.com/haskell:9.0.2` |  
| haskell:9.2 | `registry.semaphoreci.com/haskell:9.2` |  
| haskell:9.2.1 | `registry.semaphoreci.com/haskell:9.2.1` |  
| haskell:9.2.2 | `registry.semaphoreci.com/haskell:9.2.2` |  
| haskell:9.2.3 | `registry.semaphoreci.com/haskell:9.2.3` |  
| haskell:9.2.4 | `registry.semaphoreci.com/haskell:9.2.4` |  
| haskell:9.2.5 | `registry.semaphoreci.com/haskell:9.2.5` |  
| haskell:9.2.7 | `registry.semaphoreci.com/haskell:9.2.7` |  
| haskell:9.2.8 | `registry.semaphoreci.com/haskell:9.2.8` |  
| haskell:9.4 | `registry.semaphoreci.com/haskell:9.4` |  
| haskell:9.4.2 | `registry.semaphoreci.com/haskell:9.4.2` |  
| haskell:9.4.3 | `registry.semaphoreci.com/haskell:9.4.3` |  
| haskell:9.4.4 | `registry.semaphoreci.com/haskell:9.4.4` |  
| haskell:9.4.5 | `registry.semaphoreci.com/haskell:9.4.5` |  
| haskell:9.4.7 | `registry.semaphoreci.com/haskell:9.4.7` |  
| haskell:9.4.8 | `registry.semaphoreci.com/haskell:9.4.8` |  
| haskell:9.6 | `registry.semaphoreci.com/haskell:9.6` |  
| haskell:9.6.2 | `registry.semaphoreci.com/haskell:9.6.2` |  
| haskell:9.6.3 | `registry.semaphoreci.com/haskell:9.6.3` |  
| haskell:9.6.4 | `registry.semaphoreci.com/haskell:9.6.4` |  
| haskell:9.8 | `registry.semaphoreci.com/haskell:9.8` |  
| haskell:9.8.1 | `registry.semaphoreci.com/haskell:9.8.1` |  
| haskell:9.8.2 | `registry.semaphoreci.com/haskell:9.8.2` |  

</div>
</details>

## Service images for sem-service

This section lists utility images for [sem-service](../../reference/toolbox#sem-service).

### MySQL

<details>
<summary>MySQL images</summary>
<div>
  
| Image | Link |
|--------|--------|
| mysql:5 | `registry.semaphoreci.com/mysql:5` |
| mysql:5.5 | `registry.semaphoreci.com/mysql:5.5` |    
| mysql:5.5.62 | `registry.semaphoreci.com/mysql:5.5.62` |    
| mysql:5.6 | `registry.semaphoreci.com/mysql:5.6` |    
| mysql:5.6.50 | `registry.semaphoreci.com/mysql:5.6.50` |    
| mysql:5.6.51 | `registry.semaphoreci.com/mysql:5.6.51` |    
| mysql:5.7 | `registry.semaphoreci.com/mysql:5.7` |    
| mysql:5.7.13 | `registry.semaphoreci.com/mysql:5.7.13` |    
| mysql:5.7.25 | `registry.semaphoreci.com/mysql:5.7.25` |    
| mysql:5.7.27 | `registry.semaphoreci.com/mysql:5.7.27` |    
| mysql:5.7.31 | `registry.semaphoreci.com/mysql:5.7.31` |    
| mysql:5.7.32 | `registry.semaphoreci.com/mysql:5.7.32` |    
| mysql:5.7.33 | `registry.semaphoreci.com/mysql:5.7.33` |    
| mysql:8 | `registry.semaphoreci.com/mysql:8` |    
| mysql:8.0 | `registry.semaphoreci.com/mysql:8.0` |    
| mysql:8.0.4 | `registry.semaphoreci.com/mysql:8.0.4` |    
| mysql:8.0.16 | `registry.semaphoreci.com/mysql:8.0.16` |    
| mysql:8.0.22 | `registry.semaphoreci.com/mysql:8.0.22` |    
| mysql:8.0.23 | `registry.semaphoreci.com/mysql:8.0.23` |    
| mysql:8.0.34 | `registry.semaphoreci.com/mysql:8.0.34` |    
| mysql:8.0.42 | `registry.semaphoreci.com/mysql:8.0.42` |    
| mysql:8.4 | `registry.semaphoreci.com/mysql:8.4` |    
| mysql:8.4.5 | `registry.semaphoreci.com/mysql:8.4.5` |    
| mysql:9 | `registry.semaphoreci.com/mysql:9` |    
| mysql:9.3 | `registry.semaphoreci.com/mysql:9.3` |    
| mysql:9.3.0 | `registry.semaphoreci.com/mysql:9.3.0` |    

</div>
</details>

### PostgreSQL

<details>
<summary>PostgreSQL images</summary>
<div>
  
| Image | Link |
|--------|--------|
| postgres:9 | `registry.semaphoreci.com/postgres:9` |
| postgres:9.4 | `registry.semaphoreci.com/postgres:9.4` |    
| postgres:9.4.26 | `registry.semaphoreci.com/postgres:9.4.26` |    
| postgres:9.5 | `registry.semaphoreci.com/postgres:9.5` |    
| postgres:9.5.15 | `registry.semaphoreci.com/postgres:9.5.15` |    
| postgres:9.5.23 | `registry.semaphoreci.com/postgres:9.5.23` |    
| postgres:9.6 | `registry.semaphoreci.com/postgres:9.6` |    
| postgres:9.6.6 | `registry.semaphoreci.com/postgres:9.6.6` |    
| postgres:9.6.11 | `registry.semaphoreci.com/postgres:9.6.11` |    
| postgres:9.6.18 | `registry.semaphoreci.com/postgres:9.6.18` |    
| postgres:9.6.19 | `registry.semaphoreci.com/postgres:9.6.19` |    
| postgres:10 | `registry.semaphoreci.com/postgres:10` |    
| postgres:10.0 | `registry.semaphoreci.com/postgres:10.0` |    
| postgres:10.5 | `registry.semaphoreci.com/postgres:10.5` |    
| postgres:10.6 | `registry.semaphoreci.com/postgres:10.6` |    
| postgres:10.7 | `registry.semaphoreci.com/postgres:10.7` |    
| postgres:10.11 | `registry.semaphoreci.com/postgres:10.11` |    
| postgres:10.12 | `registry.semaphoreci.com/postgres:10.12` |    
| postgres:10.13 | `registry.semaphoreci.com/postgres:10.13` |    
| postgres:10.14 | `registry.semaphoreci.com/postgres:10.14` |    
| postgres:10.16 | `registry.semaphoreci.com/postgres:10.16` |    
| postgres:11 | `registry.semaphoreci.com/postgres:11` |    
| postgres:11.0 | `registry.semaphoreci.com/postgres:11.0` |    
| postgres:11.2 | `registry.semaphoreci.com/postgres:11.2` |    
| postgres:11.5 | `registry.semaphoreci.com/postgres:11.5` |    
| postgres:11.6 | `registry.semaphoreci.com/postgres:11.6` |    
| postgres:11.7 | `registry.semaphoreci.com/postgres:11.7` |    
| postgres:11.8 | `registry.semaphoreci.com/postgres:11.8` |    
| postgres:11.9 | `registry.semaphoreci.com/postgres:11.9` |    
| postgres:11.11 | `registry.semaphoreci.com/postgres:11.11` |    
| postgres:12 | `registry.semaphoreci.com/postgres:12` |    
| postgres:12.1 | `registry.semaphoreci.com/postgres:12.1` |    
| postgres:12.2 | `registry.semaphoreci.com/postgres:12.2` |    
| postgres:12.3 | `registry.semaphoreci.com/postgres:12.3` |    
| postgres:12.4 | `registry.semaphoreci.com/postgres:12.4` |    
| postgres:12.6 | `registry.semaphoreci.com/postgres:12.6` |    
| postgres:13 | `registry.semaphoreci.com/postgres:13` |  
| postgres:13.0 | `registry.semaphoreci.com/postgres:13.0` |  
| postgres:13.2 | `registry.semaphoreci.com/postgres:13.2` |  
| postgres:14 | `registry.semaphoreci.com/postgres:14` |  
| postgres:14.1 | `registry.semaphoreci.com/postgres:14.1` |  
| postgres:14.2 | `registry.semaphoreci.com/postgres:14.2` |  
| postgres:14.8 | `registry.semaphoreci.com/postgres:14.8` |  
| postgres:15 | `registry.semaphoreci.com/postgres:15` |  
| postgres:15.1 | `registry.semaphoreci.com/postgres:15.1` |  
| postgres:16 | `registry.semaphoreci.com/postgres:16` |  
| postgres:16.10 | `registry.semaphoreci.com/postgres:16.10` |  
| postgres:17 | `registry.semaphoreci.com/postgres:17` |  
| postgres:17.2 | `registry.semaphoreci.com/postgres:17.2` |  
| postgres:17.6 | `registry.semaphoreci.com/postgres:17.6` |  
| postgres:18 | `registry.semaphoreci.com/postgres:18` |  
| postgres:18.1 | `registry.semaphoreci.com/postgres:18.1` |  

</div>
</details>

### PostGIS

This is a PostgreSQL container extended with [PostGIS](https://postgis.net/).

<details>
<summary>PostGIS images</summary>
<div>

| Image | Link |
|--------|--------|
| postgis:9.5-2.5 | `registry.semaphoreci.com/postgis:9.5-2.5` |    
| postgis:9.5-3.0 | `registry.semaphoreci.com/postgis:9.5-3.0` |    
| postgis:9.6-2.5 | `registry.semaphoreci.com/postgis:9.6-2.5` |    
| postgis:9.6-3.0 | `registry.semaphoreci.com/postgis:9.6-3.0` |    
| postgis:10-2.5 | `registry.semaphoreci.com/postgis:10-2.5` |    
| postgis:10-3.0 | `registry.semaphoreci.com/postgis:10-3.0` |    
| postgis:11-2.5 | `registry.semaphoreci.com/postgis:11-2.5` |    
| postgis:11-3.0 | `registry.semaphoreci.com/postgis:11-3.0` |    
| postgis:12-2.5 | `registry.semaphoreci.com/postgis:12-2.5` |    
| postgis:12-3.0 | `registry.semaphoreci.com/postgis:12-3.0` |    
| postgis:13-3.0 | `registry.semaphoreci.com/postgis:13-3.0` |    
| postgis:14-3.1 | `registry.semaphoreci.com/postgis:14-3.1` |    
| postgis:15-3.3 | `registry.semaphoreci.com/postgis:15-3.3` |    
| postgis:15-3.4 | `registry.semaphoreci.com/postgis:15-3.4` |    
| postgis:16-3.4 | `registry.semaphoreci.com/postgis:16-3.4` |    
| postgis:17-3.5 | `registry.semaphoreci.com/postgis:17-3.5` |    
| postgis:18-3.6 | `registry.semaphoreci.com/postgis:18-3.6` |    

</div>
</details>

### MongoDB

<details>
<summary>MongoDB images</summary>
<div>

| Image | Link |
|--------|--------|
| mongo:3 | `registry.semaphoreci.com/mongo:3` |    
| mongo:3.2 | `registry.semaphoreci.com/mongo:3.2` |    
| mongo:3.2.21 | `registry.semaphoreci.com/mongo:3.2.21` |    
| mongo:3.6 | `registry.semaphoreci.com/mongo:3.6` |    
| mongo:3.6.20 | `registry.semaphoreci.com/mongo:3.6.20` |    
| mongo:4 | `registry.semaphoreci.com/mongo:4` |    
| mongo:4.0 | `registry.semaphoreci.com/mongo:4.0` |    
| mongo:4.0.20 | `registry.semaphoreci.com/mongo:4.0.20` |    
| mongo:4.1 | `registry.semaphoreci.com/mongo:4.1` |    
| mongo:4.1.13 | `registry.semaphoreci.com/mongo:4.1.13` |    
| mongo:4.2 | `registry.semaphoreci.com/mongo:4.2` |    
| mongo:4.2.10 | `registry.semaphoreci.com/mongo:4.2.10` |    
| mongo:4.2.13 | `registry.semaphoreci.com/mongo:4.2.13` |    
| mongo:4.4 | `registry.semaphoreci.com/mongo:4.4` |    
| mongo:4.4.1 | `registry.semaphoreci.com/mongo:4.4.1` |    
| mongo:4.4.4 | `registry.semaphoreci.com/mongo:4.4.4` |    
| mongo:5 | `registry.semaphoreci.com/mongo:5` |    
| mongo:5.0 | `registry.semaphoreci.com/mongo:5.0` |    
| mongo:5.0.1 | `registry.semaphoreci.com/mongo:5.0.1` |    
| mongo:5.0.2 | `registry.semaphoreci.com/mongo:5.0.2` |    
| mongo:5.0.3 | `registry.semaphoreci.com/mongo:5.0.3` |    
| mongo:5.0.4 | `registry.semaphoreci.com/mongo:5.0.4` |    
| mongo:5.0.5 | `registry.semaphoreci.com/mongo:5.0.5` |    
| mongo:5.0.6 | `registry.semaphoreci.com/mongo:5.0.6` |    
| mongo:5.0.7 | `registry.semaphoreci.com/mongo:5.0.7` |    
| mongo:5.0.8 | `registry.semaphoreci.com/mongo:5.0.8` |    
| mongo:5.0.9 | `registry.semaphoreci.com/mongo:5.0.9` |    
| mongo:6 | `registry.semaphoreci.com/mongo:6` |    
| mongo:6.0 | `registry.semaphoreci.com/mongo:6.0` |    
| mongo:6.0.8 | `registry.semaphoreci.com/mongo:6.0.8` |    
| mongo:7 | `registry.semaphoreci.com/mongo:7` |    
| mongo:7.0 | `registry.semaphoreci.com/mongo:7.0` |    
| mongo:7.0.18 | `registry.semaphoreci.com/mongo:7.0.18` |    
| mongo:8 | `registry.semaphoreci.com/mongo:8` |    
| mongo:8.0 | `registry.semaphoreci.com/mongo:8.0` |    
| mongo:8.0.6 | `registry.semaphoreci.com/mongo:8.0.6` |    

</div>
</details>

### Redis

<details>
<summary>Redis images</summary>
<div>

| Image | Link |
|--------|--------|
| redis:2 | `registry.semaphoreci.com/redis:2` |    
| redis:2.8 | `registry.semaphoreci.com/redis:2.8` |    
| redis:2.8.23 | `registry.semaphoreci.com/redis:2.8.23` |    
| redis:3 | `registry.semaphoreci.com/redis:3` |    
| redis:3.2 | `registry.semaphoreci.com/redis:3.2` |    
| redis:3.2.4 | `registry.semaphoreci.com/redis:3.2.4` |    
| redis:3.2.12 | `registry.semaphoreci.com/redis:3.2.12` |    
| redis:4 | `registry.semaphoreci.com/redis:4` |    
| redis:4.0 | `registry.semaphoreci.com/redis:4.0` |    
| redis:4.0.12 | `registry.semaphoreci.com/redis:4.0.12` |    
| redis:4.0.14 | `registry.semaphoreci.com/redis:4.0.14` |    
| redis:5 | `registry.semaphoreci.com/redis:5` |    
| redis:5.0 | `registry.semaphoreci.com/redis:5.0` |    
| redis:5.0.6 | `registry.semaphoreci.com/redis:5.0.6` |    
| redis:5.0.9 | `registry.semaphoreci.com/redis:5.0.9` |    
| redis:6 | `registry.semaphoreci.com/redis:6` |    
| redis:6.0 | `registry.semaphoreci.com/redis:6.0` |    
| redis:6.0.5 | `registry.semaphoreci.com/redis:6.0.5` |    
| redis:6.0.8 | `registry.semaphoreci.com/redis:6.0.8` |    
| redis:6.2 | `registry.semaphoreci.com/redis:6.2` |
| redis:6.2.1 | `registry.semaphoreci.com/redis:6.2.1` |
| redis:6.2.7 | `registry.semaphoreci.com/redis:6.2.7` |
| redis:7 | `registry.semaphoreci.com/redis:7` |
| redis:7.0 | `registry.semaphoreci.com/redis:7.0` |
| redis:7.0.5 | `registry.semaphoreci.com/redis:7.0.5` |
| redis:7.2 | `registry.semaphoreci.com/redis:7.2` |
| redis:7.2.4 | `registry.semaphoreci.com/redis:7.2.4` |
| redis:8 | `registry.semaphoreci.com/redis:8` |
| redis:8.0 | `registry.semaphoreci.com/redis:8.0` |
| redis:8.0.2 | `registry.semaphoreci.com/redis:8.0.2` |

</div>
</details>

### Valkey

<details>
<summary>Valkey images</summary>
<div>

| Image | Link |
|--------|--------|
| valkey:7 | `registry.semaphoreci.com/valkey:7` |
| valkey:7.2 | `registry.semaphoreci.com/valkey:7.2` |
| valkey:7.2.6 | `registry.semaphoreci.com/valkey:7.2.6` |
| valkey:8 | `registry.semaphoreci.com/valkey:8` |
| valkey:8.1 | `registry.semaphoreci.com/valkey:8.1` |
| valkey:8.1.2 | `registry.semaphoreci.com/valkey:8.1.2` |
| valkey:9 | `registry.semaphoreci.com/valkey:9` |
| valkey:9.1.2 | `registry.semaphoreci.com/valkey:9.1.2` |

</div>
</details>

### ElasticSearch

<details>
<summary>ElasticSearch images</summary>
<div>
   
| Image | Link |
|--------|--------|
| elasticsearch:1 | `registry.semaphoreci.com/elasticsearch:1` |    
| elasticsearch:1.7 | `registry.semaphoreci.com/elasticsearch:1.7` |    
| elasticsearch:1.7.6 | `registry.semaphoreci.com/elasticsearch:1.7.6` |    
| elasticsearch:2 | `registry.semaphoreci.com/elasticsearch:2` |    
| elasticsearch:2.4 | `registry.semaphoreci.com/elasticsearch:2.4` |    
| elasticsearch:2.4.6 | `registry.semaphoreci.com/elasticsearch:2.4.6` |    
| elasticsearch:5 | `registry.semaphoreci.com/elasticsearch:5` |    
| elasticsearch:5.4 | `registry.semaphoreci.com/elasticsearch:5.4` |    
| elasticsearch:5.4.3 | `registry.semaphoreci.com/elasticsearch:5.4.3` |    
| elasticsearch:5.5 | `registry.semaphoreci.com/elasticsearch:5.5` |    
| elasticsearch:5.5.2 | `registry.semaphoreci.com/elasticsearch:5.5.2` |    
| elasticsearch:5.6 | `registry.semaphoreci.com/elasticsearch:5.6` |    
| elasticsearch:5.6.16 | `registry.semaphoreci.com/elasticsearch:5.6.16` |    
| elasticsearch:6 | `registry.semaphoreci.com/elasticsearch:6` |    
| elasticsearch:6.5 | `registry.semaphoreci.com/elasticsearch:6.5` |    
| elasticsearch:6.5.1 | `registry.semaphoreci.com/elasticsearch:6.5.1` |    
| elasticsearch:6.5.4 | `registry.semaphoreci.com/elasticsearch:6.5.4` |    
| elasticsearch:6.6 | `registry.semaphoreci.com/elasticsearch:6.6` |    
| elasticsearch:6.6.2 | `registry.semaphoreci.com/elasticsearch:6.6.2` |    
| elasticsearch:6.8 | `registry.semaphoreci.com/elasticsearch:6.8` |    
| elasticsearch:6.8.1 | `registry.semaphoreci.com/elasticsearch:6.8.1` |    
| elasticsearch:6.8.13 | `registry.semaphoreci.com/elasticsearch:6.8.13` |    
| elasticsearch:7 | `registry.semaphoreci.com/elasticsearch:7` |    
| elasticsearch:7.1 | `registry.semaphoreci.com/elasticsearch:7.1` |    
| elasticsearch:7.1.1 | `registry.semaphoreci.com/elasticsearch:7.1.1` |    
| elasticsearch:7.2 | `registry.semaphoreci.com/elasticsearch:7.2` |    
| elasticsearch:7.2.0 | `registry.semaphoreci.com/elasticsearch:7.2.0` |    
| elasticsearch:7.2.1 | `registry.semaphoreci.com/elasticsearch:7.2.1` |    
| elasticsearch:7.3 | `registry.semaphoreci.com/elasticsearch:7.3` |    
| elasticsearch:7.3.1 | `registry.semaphoreci.com/elasticsearch:7.3.1` |    
| elasticsearch:7.3.2 | `registry.semaphoreci.com/elasticsearch:7.3.2` |    
| elasticsearch:7.4 | `registry.semaphoreci.com/elasticsearch:7.4` |    
| elasticsearch:7.4.2 | `registry.semaphoreci.com/elasticsearch:7.4.2` |    
| elasticsearch:7.5 | `registry.semaphoreci.com/elasticsearch:7.5` |    
| elasticsearch:7.5.0 | `registry.semaphoreci.com/elasticsearch:7.5.0` |    
| elasticsearch:7.5.1 | `registry.semaphoreci.com/elasticsearch:7.5.1` |    
| elasticsearch:7.5.2 | `registry.semaphoreci.com/elasticsearch:7.5.2` |    
| elasticsearch:7.6 | `registry.semaphoreci.com/elasticsearch:7.6` |    
| elasticsearch:7.6.0 | `registry.semaphoreci.com/elasticsearch:7.6.0` |    
| elasticsearch:7.6.2 | `registry.semaphoreci.com/elasticsearch:7.6.2` |    
| elasticsearch:7.7 | `registry.semaphoreci.com/elasticsearch:7.7` |    
| elasticsearch:7.7.0 | `registry.semaphoreci.com/elasticsearch:7.7.0` |    
| elasticsearch:7.7.1 | `registry.semaphoreci.com/elasticsearch:7.7.1` |    
| elasticsearch:7.8 | `registry.semaphoreci.com/elasticsearch:7.8` |    
| elasticsearch:7.8.1 | `registry.semaphoreci.com/elasticsearch:7.8.1` |    
| elasticsearch:7.9 | `registry.semaphoreci.com/elasticsearch:7.9` |   
| elasticsearch:7.9.0 | `registry.semaphoreci.com/elasticsearch:7.9.0` |   
| elasticsearch:7.9.2 | `registry.semaphoreci.com/elasticsearch:7.9.2` |   
| elasticsearch:7.9.3 | `registry.semaphoreci.com/elasticsearch:7.9.3` |   
| elasticsearch:7.10.0 | `registry.semaphoreci.com/elasticsearch:7.10.0` |   
| elasticsearch:7.11 | `registry.semaphoreci.com/elasticsearch:7.11` |   
| elasticsearch:7.11.2 | `registry.semaphoreci.com/elasticsearch:7.11.2` |   
| elasticsearch:7.12 | `registry.semaphoreci.com/elasticsearch:7.12` |   
| elasticsearch:7.12.0 | `registry.semaphoreci.com/elasticsearch:7.12.0` |   
| elasticsearch:7.12.1 | `registry.semaphoreci.com/elasticsearch:7.12.1` |   
| elasticsearch:7.17.7 | `registry.semaphoreci.com/elasticsearch:7.17.7` |   
| elasticsearch:8.5.1 | `registry.semaphoreci.com/elasticsearch:8.5.1` |   
| elasticsearch:8.5.3 | `registry.semaphoreci.com/elasticsearch:8.5.3` |   
| elasticsearch:8.9.2 | `registry.semaphoreci.com/elasticsearch:8.9.2` |   
| elasticsearch:8.11.3 | `registry.semaphoreci.com/elasticsearch:8.11.3` |   
| elasticsearch:9.5.5 | `registry.semaphoreci.com/elasticsearch:9.5.5` |

</div>
</details>

### OpenSearch

<details>
<summary>OpenSearch images</summary>
<div>

| Image | Link |
|--------|--------|
| opensearch:1 | `registry.semaphoreci.com/opensearch:1` |
| opensearch:1.3.9 | `registry.semaphoreci.com/opensearch:1.3.9` |
| opensearch:2 | `registry.semaphoreci.com/opensearch:2` |
| opensearch:2.6.0 | `registry.semaphoreci.com/opensearch:2.6.0` |
| opensearch:2.7.0 | `registry.semaphoreci.com/opensearch:2.7.0` |
| opensearch:3.5.0 | `registry.semaphoreci.com/opensearch:3.5.0` |
| opensearch:3.7.0 | `registry.semaphoreci.com/opensearch:3.7.0` |
| opensearch:3.8.0 | `registry.semaphoreci.com/opensearch:3.8.0` |

</div>
</details>

### Memcached

<details>
<summary>Memcached images</summary>
<div>

| Image | Link |
|--------|--------|
| memcached:1.5 | `registry.semaphoreci.com/memcached:1.5` |    
| memcached:1.5.22 | `registry.semaphoreci.com/memcached:1.5.22` |    
| memcached:1.6 | `registry.semaphoreci.com/memcached:1.6` |    
| memcached:1.6.7 | `registry.semaphoreci.com/memcached:1.6.7` |    
| memcached:1.6.9 | `registry.semaphoreci.com/memcached:1.6.9` |    

</div>
</details>

### RabbitMQ

<details>
<summary>RabbitMQ images</summary>
<div>

| Image | Link |
|--------|--------|
| rabbitmq:3 | `registry.semaphoreci.com/rabbitmq:3` | 
| rabbitmq:3.6 | `registry.semaphoreci.com/rabbitmq:3.6` | 
| rabbitmq:3.6.16 | `registry.semaphoreci.com/rabbitmq:3.6.16` | 
| rabbitmq:3.8 | `registry.semaphoreci.com/rabbitmq:3.8` |  
| rabbitmq:3.8.2 | `registry.semaphoreci.com/rabbitmq:3.8.2` |  
| rabbitmq:3.8.9 | `registry.semaphoreci.com/rabbitmq:3.8.9` |  
| rabbitmq:3.8.14 | `registry.semaphoreci.com/rabbitmq:3.8.14` |  

</div>
</details>

### CassandraDB

<details>
<summary>CassandraDB images</summary>
<div>

| Image | Link |
|--------|--------|
| cassandra:3 | `registry.semaphoreci.com/cassandra:3` |  
| cassandra:3.11 | `registry.semaphoreci.com/cassandra:3.11` |  
| cassandra:3.11.3 | `registry.semaphoreci.com/cassandra:3.11.3` |  
| cassandra:3.11.8 | `registry.semaphoreci.com/cassandra:3.11.8` |  

</div>
</details>

### Rethink DB

<details>
<summary>RethinkDB images</summary>
<div>

| Image | Link |
|--------|--------|
| rethinkdb:2 | `registry.semaphoreci.com/rethinkdb:2` |  
| rethinkdb:2.3 | `registry.semaphoreci.com/rethinkdb:2.3` |  
| rethinkdb:2.3.6 | `registry.semaphoreci.com/rethinkdb:2.3.6` |  
| rethinkdb:2.4 | `registry.semaphoreci.com/rethinkdb:2.4` |  
| rethinkdb:2.4.1 | `registry.semaphoreci.com/rethinkdb:2.4.1` |  

</div>
</details>

## Other utility images

### ClickHouse

<details>
<summary>ClickHouse images</summary>
<div>

| Image | Link |
|--------|--------|
| clickhouse:26.8 | `registry.semaphoreci.com/clickhouse:26.8` |

</div>
</details>

## See also

- [How to run jobs inside Docker containers](../pipelines#docker-environments)
- [How to work with Docker](./docker)
- [Reference sem-service command line tool](../../reference/toolbox#sem-service)
