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

### Android

Android images come in two variants:

- **base**: base images matching the Android official images
- **node**: base image extended with Node.js
- **flutter**: base image extended with Flutter


<details>
<summary>Android images</summary>
<div>

| Image | Link |
|--------|--------|
| android:25 | `registry.semaphoreci.com/android:25` |
| android:25-flutter | `registry.semaphoreci.com/android:25-flutter` |
| android:25-node | `registry.semaphoreci.com/android:25-node` |
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
- **node-browsers**: base image extended with Node.js, Firefox, Google Chrome, and chromedriver. Useful for running browser-based pipelines

<details>
<summary>Node images</summary>
<div>

| Image | Link |
|--------|--------|
| node:10 | `registry.semaphoreci.com/node:10` |  
| node:10-browsers | `registry.semaphoreci.com/node:10-browsers` |   
| node:12 | `registry.semaphoreci.com/node:12` |  
| node:12-browsers | `registry.semaphoreci.com/node:12-browsers` |  
| node:14 | `registry.semaphoreci.com/node:14` |  
| node:14-browsers | `registry.semaphoreci.com/node:14-browsers` |  
| node:15 | `registry.semaphoreci.com/node:15` |  
| node:15-browsers | `registry.semaphoreci.com/node:15-browsers` |  
| node:16 | `registry.semaphoreci.com/node:16` |  
| node:16-browsers | `registry.semaphoreci.com/node:16-browsers` |  
| node:17 | `registry.semaphoreci.com/node:17` |  
| node:17-browsers | `registry.semaphoreci.com/node:17-browsers` |  
| node:18 | `registry.semaphoreci.com/node:18` |  
| node:18-browsers | `registry.semaphoreci.com/node:18-browsers` |  
| node:19 | `registry.semaphoreci.com/node:19` |  
| node:19-browsers | `registry.semaphoreci.com/node:19-browsers` |  
| node:20 | `registry.semaphoreci.com/node:20` |  
| node:20-browsers | `registry.semaphoreci.com/node:20-browsers` |  
| node:21 | `registry.semaphoreci.com/node:21` |  
| node:21-browsers | `registry.semaphoreci.com/node:21-browsers` |  
| node:22 | `registry.semaphoreci.com/node:22` |  
| node:22-browsers | `registry.semaphoreci.com/node:22-browsers` |  
| node:23 | `registry.semaphoreci.com/node:23` |  
| node:23-browsers | `registry.semaphoreci.com/node:23-browsers` |  
| node:24 | `registry.semaphoreci.com/node:24` |  
| node:24-browsers | `registry.semaphoreci.com/node:24-browsers` |  
| node:25 | `registry.semaphoreci.com/node:25` |  
| node:25-browsers | `registry.semaphoreci.com/node:25-browsers` |  
| node:26 | `registry.semaphoreci.com/node:26` |  
| node:26-browsers | `registry.semaphoreci.com/node:26-browsers` |  

</div>
</details>

### Python

Python images come in two variants:

- **base**: base images matching the Python official images
- **node-browsers**: base image extended with Node.js, Firefox, Google Chrome, and chromedriver. Useful for running browser-based pipelines

<details>
<summary>Python images</summary>
<div>

| Image | Link |
|--------|--------|
| python:3.2 | `registry.semaphoreci.com/python:3.2` |  
| python:3.2-node-browsers | `registry.semaphoreci.com/python:3.2-node-browsers` |  
| python:3.3 | `registry.semaphoreci.com/python:3.3` |  
| python:3.3-node-browsers | `registry.semaphoreci.com/python:3.3-node-browsers` |  
| python:3.4 | `registry.semaphoreci.com/python:3.4` |  
| python:3.4-node-browsers | `registry.semaphoreci.com/python:3.4-node-browsers` |  
| python:3.5 | `registry.semaphoreci.com/python:3.5` |  
| python:3.5-node-browsers | `registry.semaphoreci.com/python:3.5-node-browsers` |  
| python:3.6 | `registry.semaphoreci.com/python:3.6` |  
| python:3.6-node-browsers | `registry.semaphoreci.com/python:3.6-node-browsers` |  
| python:3.7 | `registry.semaphoreci.com/python:3.7` |  
| python:3.7-node-browsers | `registry.semaphoreci.com/python:3.7-node-browsers` |  
| python:3.8 | `registry.semaphoreci.com/python:3.8` |  
| python:3.8-node-browsers | `registry.semaphoreci.com/python:3.8-node-browsers` |  
| python:3.9 | `registry.semaphoreci.com/python:3.9` |  
| python:3.9-node-browsers | `registry.semaphoreci.com/python:3.9-node-browsers` |  
| python:3.10 | `registry.semaphoreci.com/python:3.10` |  
| python:3.10-node-browsers | `registry.semaphoreci.com/python:3.10-node-browsers` |  
| python:3.11 | `registry.semaphoreci.com/python:3.11` |  
| python:3.11-node-browsers | `registry.semaphoreci.com/python:3.11-node-browsers` |  
| python:3.12 | `registry.semaphoreci.com/python:3.12` |  
| python:3.12-node-browsers | `registry.semaphoreci.com/python:3.12-node-browsers` |  
| python:3.13 | `registry.semaphoreci.com/python:3.13` |  
| python:3.13-node-browsers | `registry.semaphoreci.com/python:3.13-node-browsers` |  
| python:3.14 | `registry.semaphoreci.com/python:3.14` |  
| python:3.14-node-browsers | `registry.semaphoreci.com/python:3.14-node-browsers` |  

</div>
</details>

### Go

Go images come in two variants:

- **base**: base images matching the Golang official images
- **node-browsers**: base image extended with Node.js, Firefox, Google Chrome, and chromedriver. Useful for running browser-based pipelines

<details>
<summary>Go images</summary>
<div>

| Image | Link |
|--------|--------|
| golang:1.14 | `registry.semaphoreci.com/golang:1.14` |  
| golang:1.14-node-browsers | `registry.semaphoreci.com/golang:1.14-node-browsers` |  
| golang:1.15 | `registry.semaphoreci.com/golang:1.15` |  
| golang:1.15-node-browsers | `registry.semaphoreci.com/golang:1.15-node-browsers` |  
| golang:1.16 | `registry.semaphoreci.com/golang:1.16` |  
| golang:1.16-node-browsers | `registry.semaphoreci.com/golang:1.16-node-browsers` |  
| golang:1.17 | `registry.semaphoreci.com/golang:1.17` |  
| golang:1.17-node-browsers | `registry.semaphoreci.com/golang:1.17-node-browsers` |  
| golang:1.18 | `registry.semaphoreci.com/golang:1.18` |  
| golang:1.18-node-browsers | `registry.semaphoreci.com/golang:1.18-node-browsers` |  
| golang:1.19 | `registry.semaphoreci.com/golang:1.19` |  
| golang:1.19-node-browsers | `registry.semaphoreci.com/golang:1.19-node-browsers` |  
| golang:1.20 | `registry.semaphoreci.com/golang:1.20` |  
| golang:1.20-node-browsers | `registry.semaphoreci.com/golang:1.20-node-browsers` |  
| golang:1.21 | `registry.semaphoreci.com/golang:1.21` |  
| golang:1.21-node-browsers | `registry.semaphoreci.com/golang:1.21-node-browsers` |  
| golang:1.22 | `registry.semaphoreci.com/golang:1.22` |  
| golang:1.22-node-browsers | `registry.semaphoreci.com/golang:1.22-node-browsers` |  
| golang:1.23 | `registry.semaphoreci.com/golang:1.23` |  
| golang:1.23-node-browsers | `registry.semaphoreci.com/golang:1.23-node-browsers` |  
| golang:1.24 | `registry.semaphoreci.com/golang:1.24` |  
| golang:1.24-node-browsers | `registry.semaphoreci.com/golang:1.24-node-browsers` |  
| golang:1.25 | `registry.semaphoreci.com/golang:1.25` |  
| golang:1.25-node-browsers | `registry.semaphoreci.com/golang:1.25-node-browsers` |  
| golang:1.26 | `registry.semaphoreci.com/golang:1.26` |  
| golang:1.26-node-browsers | `registry.semaphoreci.com/golang:1.26-node-browsers` |  
| golang:1.27 | `registry.semaphoreci.com/golang:1.27` |  
| golang:1.27-node-browsers | `registry.semaphoreci.com/golang:1.27-node-browsers` |  

</div>
</details>

### Ruby

Ruby images come in two variants:

- **base**: base images matching the Ruby official images
- **node-browsers**: base image extended with Node.js, Firefox, Google Chrome, and chromedriver. Useful for running browser-based pipelines

<details>
<summary>Ruby images</summary>
<div>

| Image | Link |
|--------|--------|
| ruby:2.0 | `registry.semaphoreci.com/ruby:2.0` |  
| ruby:2.0-node-browsers | `registry.semaphoreci.com/ruby:2.0-node-browsers` |  
| ruby:2.1 | `registry.semaphoreci.com/ruby:2.1` |  
| ruby:2.1-node-browsers | `registry.semaphoreci.com/ruby:2.1-node-browsers` |  
| ruby:2.2 | `registry.semaphoreci.com/ruby:2.2` |  
| ruby:2.2-node-browsers | `registry.semaphoreci.com/ruby:2.2-node-browsers` |  
| ruby:2.3 | `registry.semaphoreci.com/ruby:2.3` |  
| ruby:2.3-node-browsers | `registry.semaphoreci.com/ruby:2.3-node-browsers` |  
| ruby:2.4 | `registry.semaphoreci.com/ruby:2.4` |  
| ruby:2.4-node-browsers | `registry.semaphoreci.com/ruby:2.4-node-browsers` |  
| ruby:2.5 | `registry.semaphoreci.com/ruby:2.5` |  
| ruby:2.5-node-browsers | `registry.semaphoreci.com/ruby:2.5-node-browsers` |  
| ruby:2.5 | `registry.semaphoreci.com/ruby:2.5` |  
| ruby:2.5-node-browsers | `registry.semaphoreci.com/ruby:2.5-node-browsers` |  
| ruby:2.6 | `registry.semaphoreci.com/ruby:2.6` |  
| ruby:2.6-node-browsers | `registry.semaphoreci.com/ruby:2.6-node-browsers` |  
| ruby:2.7 | `registry.semaphoreci.com/ruby:2.7` |  
| ruby:2.7-node-browsers | `registry.semaphoreci.com/ruby:2.7-node-browsers` |  
| ruby:3.0 | `registry.semaphoreci.com/ruby:3.0` |  
| ruby:3.0-node-browsers | `registry.semaphoreci.com/ruby:3.0-node-browsers` |  
| ruby:3.0.1 | `registry.semaphoreci.com/ruby:3.0.1` |  
| ruby:3.0.1-node-browsers | `registry.semaphoreci.com/ruby:3.0.1-node-browsers` |  
| ruby:3.0.2 | `registry.semaphoreci.com/ruby:3.0.2` |  
| ruby:3.0.2-node-browsers | `registry.semaphoreci.com/ruby:3.0.2-node-browsers` |  
| ruby:3.0.3 | `registry.semaphoreci.com/ruby:3.0.3` |  
| ruby:3.0.3-node-browsers | `registry.semaphoreci.com/ruby:3.0.3-node-browsers` |  
| ruby:3.0.4 | `registry.semaphoreci.com/ruby:3.0.4` |  
| ruby:3.0.4-node-browsers | `registry.semaphoreci.com/ruby:3.0.4-node-browsers` |  
| ruby:3.0.5 | `registry.semaphoreci.com/ruby:3.0.5` |  
| ruby:3.0.5-node-browsers | `registry.semaphoreci.com/ruby:3.0.5-node-browsers` |  
| ruby:3.0.6 | `registry.semaphoreci.com/ruby:3.0.6` |  
| ruby:3.0.6-node-browsers | `registry.semaphoreci.com/ruby:3.0.6-node-browsers` |  
| ruby:3.1 | `registry.semaphoreci.com/ruby:3.1` |  
| ruby:3.1-node-browsers | `registry.semaphoreci.com/ruby:3.1-node-browsers` |  
| ruby:3.1.0 | `registry.semaphoreci.com/ruby:3.1.0` |  
| ruby:3.1.0-node-browsers | `registry.semaphoreci.com/ruby:3.1.0-node-browsers` |  
| ruby:3.1.1 | `registry.semaphoreci.com/ruby:3.1.1` |  
| ruby:3.1.1-node-browsers | `registry.semaphoreci.com/ruby:3.1.1-node-browsers` |  
| ruby:3.1.2 | `registry.semaphoreci.com/ruby:3.1.2` |  
| ruby:3.1.2-node-browsers | `registry.semaphoreci.com/ruby:3.1.2-node-browsers` |  
| ruby:3.1.3 | `registry.semaphoreci.com/ruby:3.1.3` |  
| ruby:3.1.3-node-browsers | `registry.semaphoreci.com/ruby:3.1.3-node-browsers` |  
| ruby:3.1.4 | `registry.semaphoreci.com/ruby:3.1.4` |  
| ruby:3.1.4-node-browsers | `registry.semaphoreci.com/ruby:3.1.4-node-browsers` |  
| ruby:3.2 | `registry.semaphoreci.com/ruby:3.2` |  
| ruby:3.2-node-browsers | `registry.semaphoreci.com/ruby:3.2-node-browsers` |  
| ruby:3.2.0 | `registry.semaphoreci.com/ruby:3.2.0` |  
| ruby:3.2.0-node-browsers | `registry.semaphoreci.com/ruby:3.2.0-node-browsers` |  
| ruby:3.2.2 | `registry.semaphoreci.com/ruby:3.2.2` |  
| ruby:3.2.2-node-browsers | `registry.semaphoreci.com/ruby:3.2.2-node-browsers` |  
| ruby:3.2.3 | `registry.semaphoreci.com/ruby:3.2.3` |  
| ruby:3.2.3-node-browsers | `registry.semaphoreci.com/ruby:3.2.3-node-browsers` |  
| ruby:3.3 | `registry.semaphoreci.com/ruby:3.3` |
| ruby:3.3-node-browsers | `registry.semaphoreci.com/ruby:3.3-node-browsers` |
| ruby:3.3.0 | `registry.semaphoreci.com/ruby:3.3.0` |  
| ruby:3.3.0-node-browsers | `registry.semaphoreci.com/ruby:3.3.0-node-browsers` |  
| ruby:3.3.1 | `registry.semaphoreci.com/ruby:3.3.1` |
| ruby:3.3.2 | `registry.semaphoreci.com/ruby:3.3.2` |
| ruby:3.3.3 | `registry.semaphoreci.com/ruby:3.3.3` |
| ruby:3.3.4 | `registry.semaphoreci.com/ruby:3.3.4` |
| ruby:3.3.4-node-browsers | `registry.semaphoreci.com/ruby:3.3.4-node-browsers` |
| ruby:3.3.5 | `registry.semaphoreci.com/ruby:3.3.5` |
| ruby:3.3.5-node-browsers | `registry.semaphoreci.com/ruby:3.3.5-node-browsers` |
| ruby:3.3.6 | `registry.semaphoreci.com/ruby:3.3.6` |
| ruby:3.3.6-node-browsers | `registry.semaphoreci.com/ruby:3.3.6-node-browsers` |
| ruby:3.3.7 | `registry.semaphoreci.com/ruby:3.3.7` |
| ruby:3.3.7-node-browsers | `registry.semaphoreci.com/ruby:3.3.7-node-browsers` |
| ruby:3.3.8 | `registry.semaphoreci.com/ruby:3.3.8` |
| ruby:3.3.8-node-browsers | `registry.semaphoreci.com/ruby:3.3.8-node-browsers` |
| ruby:3.3.9 | `registry.semaphoreci.com/ruby:3.3.9` |
| ruby:3.3.10 | `registry.semaphoreci.com/ruby:3.3.10` |
| ruby:3.3.11 | `registry.semaphoreci.com/ruby:3.3.11` |
| ruby:3.4 | `registry.semaphoreci.com/ruby:3.4` |
| ruby:3.4-node-browsers | `registry.semaphoreci.com/ruby:3.4-node-browsers` |
| ruby:3.4.1 | `registry.semaphoreci.com/ruby:3.4.1` |
| ruby:3.4.1-node-browsers | `registry.semaphoreci.com/ruby:3.4.1-node-browsers` |
| ruby:3.4.2 | `registry.semaphoreci.com/ruby:3.4.2` |
| ruby:3.4.3 | `registry.semaphoreci.com/ruby:3.4.3` |
| ruby:3.4.3-node-browsers | `registry.semaphoreci.com/ruby:3.4.3-node-browsers` |
| ruby:3.4.4 | `registry.semaphoreci.com/ruby:3.4.4` |
| ruby:3.4.4-node-browsers | `registry.semaphoreci.com/ruby:3.4.4-node-browsers` |
| ruby:3.4.5 | `registry.semaphoreci.com/ruby:3.4.5` |
| ruby:3.4.7 | `registry.semaphoreci.com/ruby:3.4.7` |
| ruby:3.4.8 | `registry.semaphoreci.com/ruby:3.4.8` |
| ruby:3.4.9 | `registry.semaphoreci.com/ruby:3.4.9` |
| ruby:3.4.9-node-browsers | `registry.semaphoreci.com/ruby:3.4.9-node-browsers` |
| ruby:3.4.10 | `registry.semaphoreci.com/ruby:3.4.10` |
| ruby:3.4.10-node-browsers | `registry.semaphoreci.com/ruby:3.4.10-node-browsers` |
| ruby:4 | `registry.semaphoreci.com/ruby:4` |
| ruby:4-node-browsers | `registry.semaphoreci.com/ruby:4-node-browsers` |
| ruby:4.0 | `registry.semaphoreci.com/ruby:4.0` |
| ruby:4.0-node-browsers | `registry.semaphoreci.com/ruby:4.0-node-browsers` |
| ruby:4.0.0 | `registry.semaphoreci.com/ruby:4.0.0` |
| ruby:4.0.1 | `registry.semaphoreci.com/ruby:4.0.1` |
| ruby:4.0.2 | `registry.semaphoreci.com/ruby:4.0.2` |
| ruby:4.0.2-node-browsers | `registry.semaphoreci.com/ruby:4.0.2-node-browsers` |
| ruby:4.0.3 | `registry.semaphoreci.com/ruby:4.0.3` |
| ruby:4.0.3-node-browsers | `registry.semaphoreci.com/ruby:4.0.3-node-browsers` |
| ruby:4.0.5 | `registry.semaphoreci.com/ruby:4.0.5` |
| ruby:4.0.5-node-browsers | `registry.semaphoreci.com/ruby:4.0.5-node-browsers` |
| ruby:4.0.6 | `registry.semaphoreci.com/ruby:4.0.6` |
| ruby:4.0.6-node-browsers | `registry.semaphoreci.com/ruby:4.0.6-node-browsers` |



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
| php:5.6 | `registry.semaphoreci.com/php:5.6` |
| php:7.2 | `registry.semaphoreci.com/php:7.2` |
| php:7.3 | `registry.semaphoreci.com/php:7.3` |
| php:7.4 | `registry.semaphoreci.com/php:7.4` |
| php:8.0 | `registry.semaphoreci.com/php:8.0` |
| php:8.1 | `registry.semaphoreci.com/php:8.1` |
| php:8.2 | `registry.semaphoreci.com/php:8.2` |
| php:8.3 | `registry.semaphoreci.com/php:8.3` |
| php:8.4 | `registry.semaphoreci.com/php:8.4` |
| php:8.5 | `registry.semaphoreci.com/php:8.5` |
| php:5.6-node | `registry.semaphoreci.com/php:5.6-node` |
| php:7.2-node | `registry.semaphoreci.com/php:7.2-node` |
| php:7.3-node | `registry.semaphoreci.com/php:7.3-node` |
| php:7.4-node | `registry.semaphoreci.com/php:7.4-node` |
| php:8.0-node | `registry.semaphoreci.com/php:8.0-node` |
| php:8.1-node | `registry.semaphoreci.com/php:8.1-node` |
| php:8.2-node | `registry.semaphoreci.com/php:8.2-node` |
| php:8.3-node | `registry.semaphoreci.com/php:8.3-node` |
| php:8.4-node | `registry.semaphoreci.com/php:8.4-node` |
| php:8.5-node | `registry.semaphoreci.com/php:8.5-node` |
| php:5.6-browsers | `registry.semaphoreci.com/php:5.6-browsers` |
| php:7.2-browsers | `registry.semaphoreci.com/php:7.2-browsers` |
| php:7.3-browsers | `registry.semaphoreci.com/php:7.3-browsers` |
| php:7.4-browsers | `registry.semaphoreci.com/php:7.4-browsers` |
| php:8.0-browsers | `registry.semaphoreci.com/php:8.0-browsers` |
| php:8.1-browsers | `registry.semaphoreci.com/php:8.1-browsers` |
| php:8.2-browsers | `registry.semaphoreci.com/php:8.2-browsers` |
| php:8.3-browsers | `registry.semaphoreci.com/php:8.3-browsers` |
| php:8.4-browsers | `registry.semaphoreci.com/php:8.4-browsers` |
| php:8.5-browsers | `registry.semaphoreci.com/php:8.5-browsers` |
| php:5.6-node-browsers | `registry.semaphoreci.com/php:5.6-node-browsers` |
| php:7.2-node-browsers | `registry.semaphoreci.com/php:7.2-node-browsers` |
| php:7.3-node-browsers | `registry.semaphoreci.com/php:7.3-node-browsers` |
| php:7.4-node-browsers | `registry.semaphoreci.com/php:7.4-node-browsers` |
| php:8.0-node-browsers | `registry.semaphoreci.com/php:8.0-node-browsers` |
| php:8.1-node-browsers | `registry.semaphoreci.com/php:8.1-node-browsers` |
| php:8.2-node-browsers | `registry.semaphoreci.com/php:8.2-node-browsers` |
| php:8.3-node-browsers | `registry.semaphoreci.com/php:8.3-node-browsers` |
| php:8.4-node-browsers | `registry.semaphoreci.com/php:8.4-node-browsers` |
| php:8.5-node-browsers | `registry.semaphoreci.com/php:8.5-node-browsers` |

</div>
</details>

### Rust

Rust images come in two variants:

- **base**: base images matching the Rust official images
- **node-browsers**: base image extended with Node.js, Firefox, Google Chrome, and chromedriver. Useful for running browser-based pipelines

<details>
<summary>Rust images</summary>
<div>

| Image | Link |
|--------|--------|
| rust:1.45 | `registry.semaphoreci.com/rust:1.45` |
| rust:1.45-node-browsers | `registry.semaphoreci.com/rust:1.45-node-browsers` |
| rust:1.46 | `registry.semaphoreci.com/rust:1.46` |
| rust:1.46-node-browsers | `registry.semaphoreci.com/rust:1.46-node-browsers` |
| rust:1.47 | `registry.semaphoreci.com/rust:1.47` |
| rust:1.47-node-browsers | `registry.semaphoreci.com/rust:1.47-node-browsers` |
| rust:1.49 | `registry.semaphoreci.com/rust:1.49` |
| rust:1.49-node-browsers | `registry.semaphoreci.com/rust:1.49-node-browsers` |
| rust:1.50 | `registry.semaphoreci.com/rust:1.50` |
| rust:1.50-node-browsers | `registry.semaphoreci.com/rust:1.50-node-browsers` |
| rust:1.51 | `registry.semaphoreci.com/rust:1.51` |
| rust:1.51-node-browsers | `registry.semaphoreci.com/rust:1.51-node-browsers` |
| rust:1.52 | `registry.semaphoreci.com/rust:1.52` |
| rust:1.52-node-browsers | `registry.semaphoreci.com/rust:1.52-node-browsers` |
| rust:1.53 | `registry.semaphoreci.com/rust:1.53` |
| rust:1.53-node-browsers | `registry.semaphoreci.com/rust:1.53-node-browsers` |
| rust:1.54 | `registry.semaphoreci.com/rust:1.54` |
| rust:1.54-node-browsers | `registry.semaphoreci.com/rust:1.54-node-browsers` |
| rust:1.55 | `registry.semaphoreci.com/rust:1.55` |
| rust:1.55-node-browsers | `registry.semaphoreci.com/rust:1.55-node-browsers` |
| rust:1.56 | `registry.semaphoreci.com/rust:1.56` |
| rust:1.56-node-browsers | `registry.semaphoreci.com/rust:1.56-node-browsers` |
| rust:1.57 | `registry.semaphoreci.com/rust:1.57` |
| rust:1.57-node-browsers | `registry.semaphoreci.com/rust:1.57-node-browsers` |
| rust:1.58 | `registry.semaphoreci.com/rust:1.58` |
| rust:1.58-node-browsers | `registry.semaphoreci.com/rust:1.58-node-browsers` |
| rust:1.59 | `registry.semaphoreci.com/rust:1.59` |
| rust:1.59-node-browsers | `registry.semaphoreci.com/rust:1.59-node-browsers` |
| rust:1.60 | `registry.semaphoreci.com/rust:1.60` |
| rust:1.60-node-browsers | `registry.semaphoreci.com/rust:1.60-node-browsers` |
| rust:1.61 | `registry.semaphoreci.com/rust:1.61` |
| rust:1.61-node-browsers | `registry.semaphoreci.com/rust:1.61-node-browsers` |
| rust:1.62 | `registry.semaphoreci.com/rust:1.62` |
| rust:1.62-node-browsers | `registry.semaphoreci.com/rust:1.62-node-browsers` |
| rust:1.63 | `registry.semaphoreci.com/rust:1.63` |
| rust:1.63-node-browsers | `registry.semaphoreci.com/rust:1.63-node-browsers` |
| rust:1.64 | `registry.semaphoreci.com/rust:1.64` |
| rust:1.64-node-browsers | `registry.semaphoreci.com/rust:1.64-node-browsers` |
| rust:1.65 | `registry.semaphoreci.com/rust:1.65` |
| rust:1.65-node-browsers | `registry.semaphoreci.com/rust:1.65-node-browsers` |
| rust:1.66 | `registry.semaphoreci.com/rust:1.66` |
| rust:1.66-node-browsers | `registry.semaphoreci.com/rust:1.66-node-browsers` |
| rust:1.67 | `registry.semaphoreci.com/rust:1.67` |
| rust:1.67-node-browsers | `registry.semaphoreci.com/rust:1.67-node-browsers` |
| rust:1.68 | `registry.semaphoreci.com/rust:1.68` |
| rust:1.68-node-browsers | `registry.semaphoreci.com/rust:1.68-node-browsers` |
| rust:1.69 | `registry.semaphoreci.com/rust:1.69` |
| rust:1.69-node-browsers | `registry.semaphoreci.com/rust:1.69-node-browsers` |
| rust:1.70 | `registry.semaphoreci.com/rust:1.70` |
| rust:1.70-node-browsers | `registry.semaphoreci.com/rust:1.70-node-browsers` |
| rust:1.72 | `registry.semaphoreci.com/rust:1.72` |
| rust:1.72-node-browsers | `registry.semaphoreci.com/rust:1.72-node-browsers` |
| rust:1.73 | `registry.semaphoreci.com/rust:1.73` |
| rust:1.73-node-browsers | `registry.semaphoreci.com/rust:1.73-node-browsers` |
| rust:1.74 | `registry.semaphoreci.com/rust:1.74` |
| rust:1.74-node-browsers | `registry.semaphoreci.com/rust:1.74-node-browsers` |
| rust:1.75 | `registry.semaphoreci.com/rust:1.75` |
| rust:1.75-node-browsers | `registry.semaphoreci.com/rust:1.75-node-browsers` |
| rust:1.82 | `registry.semaphoreci.com/rust:1.82` |
| rust:1.82-node-browsers | `registry.semaphoreci.com/rust:1.82-node-browsers` |
| rust:1.83 | `registry.semaphoreci.com/rust:1.83` |
| rust:1.83-node-browsers | `registry.semaphoreci.com/rust:1.83-node-browsers` |
| rust:1.84 | `registry.semaphoreci.com/rust:1.84` |
| rust:1.84-node-browsers | `registry.semaphoreci.com/rust:1.84-node-browsers` |
| rust:1.86 | `registry.semaphoreci.com/rust:1.86` |
| rust:1.86-node-browsers | `registry.semaphoreci.com/rust:1.86-node-browsers` |
| rust:1.87 | `registry.semaphoreci.com/rust:1.87` |
| rust:1.87-node-browsers | `registry.semaphoreci.com/rust:1.87-node-browsers` |
| rust:1.88 | `registry.semaphoreci.com/rust:1.88` |
| rust:1.88-node-browsers | `registry.semaphoreci.com/rust:1.88-node-browsers` |
| rust:1.94 | `registry.semaphoreci.com/rust:1.94` |
| rust:1.94-node-browsers | `registry.semaphoreci.com/rust:1.94-node-browsers` |
| rust:1.95 | `registry.semaphoreci.com/rust:1.95` |
| rust:1.95-node-browsers | `registry.semaphoreci.com/rust:1.95-node-browsers` |
| rust:1.96 | `registry.semaphoreci.com/rust:1.96` |
| rust:1.96-node-browsers | `registry.semaphoreci.com/rust:1.96-node-browsers` |
| rust:1.97 | `registry.semaphoreci.com/rust:1.97` |
| rust:1.97-node-browsers | `registry.semaphoreci.com/rust:1.97-node-browsers` |
| rust:1.98 | `registry.semaphoreci.com/rust:1.98` |
| rust:1.98-node-browsers | `registry.semaphoreci.com/rust:1.98-node-browsers` |

</div>
</details>


### Elixir

<details>
<summary>Elixir images</summary>
<div>

| Image | Link |
|--------|--------|
| elixir:1.4 | `registry.semaphoreci.com/elixir:1.4` |  
| elixir:1.5 | `registry.semaphoreci.com/elixir:1.5` |  
| elixir:1.6 | `registry.semaphoreci.com/elixir:1.6` |  
| elixir:1.7 | `registry.semaphoreci.com/elixir:1.7` |  
| elixir:1.8 | `registry.semaphoreci.com/elixir:1.8` |  
| elixir:1.9 | `registry.semaphoreci.com/elixir:1.9` |  
| elixir:1.10 | `registry.semaphoreci.com/elixir:1.10` |  
| elixir:1.11 | `registry.semaphoreci.com/elixir:1.11` |  
| elixir:1.12 | `registry.semaphoreci.com/elixir:1.12` |  
| elixir:1.13 | `registry.semaphoreci.com/elixir:1.13` |  
| elixir:1.14 | `registry.semaphoreci.com/elixir:1.14` |  
| elixir:1.15 | `registry.semaphoreci.com/elixir:1.15` |  
| elixir:1.16 | `registry.semaphoreci.com/elixir:1.16` |  
| elixir:1.17 | `registry.semaphoreci.com/elixir:1.17` |  
| elixir:1.18 | `registry.semaphoreci.com/elixir:1.18` |  
| elixir:1.19 | `registry.semaphoreci.com/elixir:1.19` |  
| elixir:1.20 | `registry.semaphoreci.com/elixir:1.20` |  

</div>
</details>

### Haskell

<details>
<summary>Haskell images</summary>
<div>

| Image | Link |
|--------|--------|
| haskell:8 | `registry.semaphoreci.com/haskell:8` |  
| haskell:8.4 | `registry.semaphoreci.com/haskell:8.4` |  
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

### Unity

These are cached images of [Dockerized Unity Editor](https://hub.docker.com/r/unityci/editor). These come in three variants:

- **android**: Unity Editor for Android
- **webgl**: Unity Editor with WebGL
- **ios**: Unity Editor for iOS

<details>
<summary>Unity images</summary>
<div>

| Image | Link |
|--------|--------|
| unityci/editor:2020.3.25f1-android-0 | `registry.semaphoreci.com/unityci/editor:2020.3.25f1-android-0` |  
| unityci/editor:ubuntu-2020.3.25f1-webgl-0.15.0 | `registry.semaphoreci.com/unityci/editor:ubuntu-2020.3.25f1-webgl-0.15.0` |  
| unityci/editor:ubuntu-2020.3.25f1-ios-0.15.0 | `registry.semaphoreci.com/unityci/editor:ubuntu-2020.3.25f1-ios-0.15.0` |  

</div>
</details>

## See also

- [How to run jobs inside Docker containers](../pipelines#docker-environments)
- [How to work with Docker](./docker)
- [Reference sem-service command line tool](../../reference/toolbox#sem-service)
