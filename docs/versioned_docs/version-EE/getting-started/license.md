---
description: Semaphore License
---

# Get a License

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
import Available from '@site/src/components/Available';
import VideoTutorial from '@site/src/components/VideoTutorial';
import Steps from '@site/src/components/Steps';
import FeatureNotAvailable from '@site/src/components/FeatureNotAvailable';
import { NiceButton, ButtonContainer } from '@site/src/components/NiceButton';
import { GKEIcon, EKSIcon, UbuntuIcon, GCPCompute, AWSEC2Icon } from '@site/src/components/CustomIcons';

This page explains how to obtain a Semaphore Enterprise Edition (EE) license and under which conditions you are required to pay to run your Semaphore EE instance.

## Overview {#overview}

Every Semaphore EE instance must have a valid and current license in order to run. The license is applied during installation and renewed yearly.

## Free Enterprise Edition {#free}

You might not need to pay for the license. If the following conditions apply, you can get a license free and skip the [payment section](#payment):

- You expect to have fewer than 50 users for the Semaphore instance
- Your company must have less than 5,000,000 US Dollars ARR (Annual Recurring Revenue)

If you do not fulfill these requirements, you must [contact support for payment details] once you install your Semaphore instance.

## Obtain a license {#obtain}

In order to obtain or renew a license, follow these steps:

<Steps>

1. Go to the [Semaphore License Hub](https://license-server.test.sonprem.com/)
2. Fill in the required fields
3. Read and accept the [Terms of Service](https://github.com/semaphoreio/semaphore/blob/main/ee/LICENSE)
4. Fill in the verification code sent to the provided email
5. Find the link to download the license in your email
6. Download the license file
7. Continue the [Semaphore installation](./install)

</Steps>

## Payment {#payment}

:::note

You might not need to pay for the license if you fulfill the free license criteria. See [free Enterprise Edition eligibility criteria](#free) for more details.

:::

After you have [obtained your license](#obtain) and installed your Semaphore instance, you must contact Semaphore support at: `support@semaphore.io` to obtain the payment details for your license.

## See also

- [Installation guide](./install)
- [Getting started guide](./guided-tour)
- [Migration guide](./migration/overview)

