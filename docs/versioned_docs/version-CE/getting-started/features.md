---
description: Feature comparison between Semaphore editions
---

# Feature Comparison

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
import Available from '@site/src/components/Available';
import VideoTutorial from '@site/src/components/VideoTutorial';
import Steps from '@site/src/components/Steps';
import FeatureNotAvailable from '@site/src/components/FeatureNotAvailable';

This page compares the features available across all [Semaphore editions](./about-semaphore).

## CI/CD Workflows

| Feature | Semaphore Cloud | Semaphore CE | Semaphore EE |
|--|--|--|--|
| Visual editor | Yes | Yes | Yes |
| Artifacts | Yes | Yes | Yes |
| Tasks | Yes | Yes | Yes |
| SSH Debug | Yes | No | No |
| Cache | Yes | Yes | Yes |
| Monorepo support | Yes | Yes | Yes |
| Initialization jobs | Yes | Yes | Yes |
| Self-hosted agents | Yes | Yes | Yes |
| GitHub support | Yes | Yes | Yes |
| GitLab support | Yes | Yes | Yes |
| BitBucket support | Yes | Yes | Yes |
| Any Git Server support | No | Yes | Yes |
| Promotions | Yes | No | Yes |
| Parameterized promotions | Yes | No | Yes |
| Deployment targets | Yes | No | Yes |
| Pre-flight checks | Yes | No | Yes |
| sem-service & sem-version | Yes | No | No |


## Dashboards

| Feature | Semaphore Cloud | Semaphore CE | Semaphore EE |
|--|--|--|--|
| Test reports | Yes | Yes | Yes |
| Markdown reports | Yes | Yes | Yes |
| Activity monitor | Yes | Yes | Yes |
| Custom Dashboards | Yes | No | Yes |
| Flaky tests | Yes | No | Yes |
| Project insights | Yes | No | Yes |
| Organization health | Yes | No | Yes |


## Security and compliance

| Feature | Semaphore Cloud | Semaphore CE | Semaphore EE |
|--|--|--|--|
| Project-level secrets | Yes | Yes | Yes |
| Organization secrets | Yes | Yes | Yes |
| Policies for accessing secrets | Yes | No | Yes |
| Audit logs | Yes | No | Yes |


## User and permissions management 

| Feature | Semaphore Cloud | Semaphore CE | Semaphore EE |
|--|--|--|--|
| Multiple organizations | Yes | No | No |
| Invite users to your organization | Yes | Yes | Yes |
| Organization roles | Yes | Yes | Yes |
| Project roles | Yes | Yes (*) | Yes |
| User groups | Yes | No | Yes |
| Custom Roles | Yes | No | Yes |

(*) Project roles exist but cannot be manually assigned to individual users. The role is assigned based on project membership and server roles.

## Integrations 

| Feature | Semaphore Cloud | Semaphore CE | Semaphore EE |
|--|--|--|--|
| Repository status checks | Yes | Yes | Yes |
| Repository badges | Yes | Yes | Yes |
| Slack notifications | Yes | Yes | Yes |
| Webhook notifications | Yes | Yes | Yes |
| SAML/SCIM integrations | Yes | No | Yes |
| Okta integration | Yes | No | Yes |
| OpenID Connect | Yes | No | Yes |
| GitHub SSO | Yes | No | Yes |

## See also

- [Guided tour](./guided-tour)
- [Migration guides](./migration/overview)

