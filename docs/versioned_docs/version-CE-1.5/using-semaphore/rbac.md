---
Description: Manage user access with RBAC
---

# Role Based Access Control







Manage user permissions in your server and projects with Role Based Access Control (RBAC). This page describes gives an overview of RBAC and how to assign roles to users.

## Overview

Semaphore uses a RBAC model to determine what actions users can take in server and projects.

A server [Admin](#org-admin) or [Owner](#org-owner) must invite users via their GitHub or BitBucket accounts before they can access the Semaphore server or any of the projects.

## Role scopes {#scopes}

Semaphore manages roles at the [Server level](#org): these roles allow users to perform various server actions. Users need to be added to the server before they can access projects.

## Server roles {#org}

Server roles control what actions the users may perform in Semaphore. Users need to be added to the server via their GitHub or BitBucket usernames before they can be granted a role. Only users who are part of the server can log in to Semaphore.

The only exception is when a user is added via the [Okta integration](./okta).

### Member {#org-member}

Server members can access the homepage and the projects they are assigned to. They can't modify any settings.

This is the default role assigned when a user is added to the server.

Among other actions, members can:

- View the server's activity
- View and manage [notifications](./notifications)
- Create [projects](./projects)
- View and manage [self-hosted agents](./self-hosted)

For the full list of member permissions, see [server roles](./organizations#org-roles).

### Admin {#org-admin}

Admins can modify settings within the server or any of its projects. They do not have access to billing information, and they cannot change general server details, such as the server name and URL.

Only Admins and Owners can invite users to the server.

In addition to the [member permissions](#org-member), admins can:

- View and manage server settings
- Invite users to the server
- Remove people from the server

For the full list of admin permissions, see [server roles](./organizations#org-roles).

### Owner {#org-owner}

The owner of the server is the person that created it. A server can have multiple owners.  Owners have access to all functionalities within the server and any of its projects. Only Admins and Owners can invite users to the server.

For the full list of owner permissions, see [server roles](./organizations#org-roles).

To remove an owner, see [how to remove an owner](https://docs.semaphoreci.com/using-semaphore/organizations#remove-owner).

## See also

- [How to manage users](./organizations#people)
- [How to manage project access](./projects#people)
