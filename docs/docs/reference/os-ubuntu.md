---
description: Ubuntu Image Reference
---

# Linux Ubuntu Images

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
import Available from '@site/src/components/Available';
import VideoTutorial from '@site/src/components/VideoTutorial';
import Steps from '@site/src/components/Steps';

This page describes the Ubuntu images supported on Semaphore Cloud.

## Overview

The Operating System image defines what OS and software are pre-installed in your [agents](../using-semaphore/pipelines#agents). 

This page describes OS images to run on Linux-based Semaphore Cloud [machines](./machine-types). You can add more OS options using [self-hosted agents](../using-semaphore/self-hosted).

### Installing packages {#install}

You have full `sudo` passwordless permissions to install and modify OS packages as needed. Ubuntu package manager is [apt](https://ubuntu.com/server/docs/package-management).

To install a package, run:

```shell
sudo apt-get update
sudo apt-get install -y <package-name>
```

:::info

Packages are installed from a package repository located near the machines for more performance.

:::

### Disabled repositories {#disabled-repos}

Due to occasional issues with some of the repositories that break the pipeline during the `apt-get update` command, the following package sources repositories have been disabled and moved to `/etc/apt/sources.list.d/disabled`:

- `azure-cli.list`
- `devel_kubic_libcontainers_stable.list`
- `docker.list`
- `firefox.list`
- `git.list`
- `google-cloud-sdk.list`
- `gradle.list`
- `helm.list`
- `pypy.list`
- `python.list`
- `yarn.list`

If you need any of these package repositories, execute the following command:

```shell
sudo mv /etc/apt/sources.list.d/disabled/<package-repository-file.list> /etc/apt/sources.list.d/
sudo apt-get update
```

### Nested virtualization {#nested-virtualization}

Linux-based machines support nested virtualization. You can create virtual machines inside the virtual machine running your agent using [libvirt]

Follow these commands to use nested virtualization:

<Steps>

1. Check that nested virtualization is supported. The output should be `0`
    ```shell
    grep -cw vmx /proc/cpuinfo
    ```
2. Install the required packages
    ```shell
    sudo apt-get install -y uvtool sshpass net-tools netcat-openbsd
    ```
3. Download prebuilt Ubuntu cloud image
    ```shell
    uvt-simplestreams-libvirt --verbose sync --source http://cloud-images.ubuntu.com/daily release=focal arch=amd64
    uvt-simplestreams-libvirt query
    ```
4. Create a new SSH keypair
    ```shell
    rm -rf ~/.ssh/id_rsa
    echo | ssh-keygen -t rsa  -f ~/.ssh/id_rsa
    ```
5. Create the VM
    ```shell
    uvt-kvm create vm1 --memory 1024 --cpu 1 --disk 4 --password ubuntu --bridge virbr0
    uvt-kvm list
    ```
6. Wait for the machine to be up and IP to be available
    ```shell
    IP=""
    while [ -z $IP ];do IP=$(arp -an | grep $(virsh dumpxml vm1| grep "mac address" | cut -d"'" -f2)|cut -d"(" -f2|cut -d")" -f1);done
    echo $IP
    while ! nc -w5 -z $IP 22; do  echo "Sleep while $IP is up";sleep 1; done
    ```
7. Run the commands in the VM using SSH. For example, this runs `uname -a`
    ```shell
    sshpass -p "ubuntu" -v  ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ubuntu@$IP -t 'uname -a'
    ```
</Steps>

The predefined default network for nested virtualization is 192.168.123.0/24. The base VM provides virbr0 interface with the IP address: 192.168.123.1.

## See also

- [How to configure agents](../using-semaphore/pipelines#agents)
- [Self-hosted agents](../using-semaphore/self-hosted)
- [Machine type references](./machine-types)
- [Apple macOS images reference](./os-apple)
