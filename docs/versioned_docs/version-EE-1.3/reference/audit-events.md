---
description: Audit log events reference
---

# Audit Log Events Reference

import Tabs from '@theme/Tabs';
import TabItem from '@theme/TabItem';
import Available from '@site/src/components/Available';
import VideoTutorial from '@site/src/components/VideoTutorial';

Each audit log entry shows applicable information about an event, such as:

- Action that was performed
- The user (actor) who performed the action
- Resource affected by the action
- Date and time of the action
- IP address and medium of the interface used to perform the action

## Audit log entry fields

All audited events contain the following fields:

- [Resource](#resource-field)
- [Operation](#operation-field)
- User ID (The user who initiated this action.)
- [Medium](#medium-field)
- Timestamp

Some events contain the following fields:

- Resource ID
- Resource Name
- IP address
- Username
- Description
- Metadata (some metadata regarding the event, must be valid JSON)

### Resource field {#resource-field}

Possible values of **Resource** field:

- Project
- User
- Workflow
- Pipeline
- DebugSession
- PeriodicScheduler
- Secret
- Notification
- Dashboard
- Job
- Artifact
- Organization

### Operation field {#operation-field}

Values of **Operation** field:

- Added
- Removed
- Modified
- Started
- Stopped
- Promoted
- Demoted
- Rebuild
- Download

### Medium field {#medium-field}

Operation can be done from one of the following Mediums:

- Web
- API
- CLI

## See also

- [Security audit log](../using-semaphore/organizations#audit-log)
