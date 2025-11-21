---
description: Manage Semaphore users
---

# Managing User Accounts

Semaphore users a [Role Based Access Control](./rbac) model to manage permissions at the organization and project level.

## Manage your user profile {#profile}

You can manage your Semaphore user profile details such as email address, username, and access token.

### How to change your username {#profile-username}

To change your Semaphore username, follow these steps:

<Steps>

1. Open your user menu on the top-right corner
2. Select **Profile settings**

    ![Profile menu](./img/profile-menu.jpg)

3. Under **Screen name**, type your new name

    ![User profile page](./img/user-profile-page.jpg)

4. Press **Save changes**

</Steps>

### How to change your email address {#profile-email}

:::warning

Changing your user profile email address can revoke access to integrations such as GitHub and BitBucket. You may need to reconnect your repositories after changing your email address.

:::

To change your Semaphore email address, follow these steps:

<Steps>

1. Open your user menu on the top-right corner
2. Select **Profile settings**

    ![Profile menu](./img/profile-menu.jpg)

3. Under **Email Address**, type your email address

    ![User profile page](./img/user-profile-page.jpg)

4. Press **Update email**

5. Confirm the change

</Steps>

### How to reset your personal API token {#profile-token}

:::warning

Changing your access token will revoke access to the [Semaphore API](../reference/api) and access via the [Semaphore CLI](../reference/semaphore-cli). Only reset your token if you have lost access to it or suspect someone else has been using it on your behalf.

:::

To reset your Semaphore API token, follow these steps:

<Steps>

1. Open your user menu on the top-right corner
2. Select **Profile settings**

    ![Profile menu](./img/profile-menu.jpg)

3. Under **API Token** press **Reset API Token**

    ![User profile page](./img/user-profile-page.jpg)

4. Confirm the change, copy the new to token and save it on a safe place

</Steps>

## Managing Semaphore users {#people}

Semaphore users a [Role Based Access Control](./rbac) model to manage permissions at the organization and project level.

To manage users in your organization, open the organization menu and select **People**. This tab shows users and groups in your organization along with their roles and groups.

![The people tab](./img/people-tab.jpg)

### How to invite users {#add-people}

To invite a user to your organization, press the **Add people** button:

![Add people button](./img/add-people-button.jpg)

<Steps>

1. Select one of the available tabs

    - Type the user's handle, e.g. `TomFern`, or select the user from the list. Usernames are case-sensitive and all characters are considered. Ensure the handle is entered accurately to avoid errors.
    - If you don't see the user in the list. Ensure they have repository access in **GitHub** or **BitBucket** for at least one project in your organization

    ![Invite users](./img/invite-users.jpg)

2. Press **Add selected**
3. Optionally, set their [role](#roles-people)


</Steps>

:::info

If you see an error with the message "error finding USERNAME: 401", it's likely that the your Semaphore account, as the inviter, is no longer linked to GitHub or BitBucket.

To fix the issue, reconnect your account by granting access again via [GitHub](./connect-github-oauth#connect-oauth) or [Bitbucket](./connect-bitbucket#grant-bb). This should restore your ability to send invitations.

:::

### How to remove users {#remove-users}

Users can only be removed from the organization when they don't own any projects. You must [transfer the ownership](./projects#owner-change) of all the user's projects before they can be removed from the organization.

To remove a user, go to the people option in the organization menu and follow these steps:

<Steps>

1. Transfer any [project ownership](./projects#owner-change) the user may have to another individual. The user must not own any projects
2. Press the **X** button next to the username of the user you want to remove

  ![Removing a user from the organization](./img/remove-user.jpg)

</Steps>
   
Upon removal, access to all projects in the organization are revoked.

:::note

Only an Admins, Owner, or dedicated [custom roles](./rbac#custom-roles) can remove users from the organization.

:::

### How to download list of users as CSV {#csv-users}

Organization owners and admins can export a list of all users in their Semaphore organization.

To download the list, follow these steps:

<Steps>

1. In the **People** section, press **Download .csv**

    ![Download .csv button location](./img/csv-users.jpg)

2. Semaphore will generate a .csv file containing the following user details:

    - Semaphore account name
    - Email address
    - GitHub username
    - Bitbucket username
    - GitLab username

</Steps>


### How to change user roles {#roles-people}

To change the role of a user, press the **Change Role** button next to the person.

![Changing user roles](./img/change-roles.jpg)

See [organization roles](./rbac#org) to learn what roles are available.

### How to create groups {#add-groups}

<Available plans={['Enterprise']}/>

User groups streamline user management by allowing bulk actions. After creating a group, you can:

- Add members to the group
- Assign a role to the group

All members of the group automatically inherit the permissions associated with the assigned role.

As an example, let's say you want to give the Finance team access to the [Billing pages](./billing) in your organization. To achieve that you can:

1. Create a [custom role](#custom) with view permissions on the Billing page
2. Create a Finance group
3. Assign the new custom role to the group
4. Add everyone in the Finance team to the group
5. As the team changes, you can add or delete persons from the group

To create a group, open the organization menu and select **People**. 

<Steps>

1. Press on **Create group**
2. Type in the group name and description
3. Type the names of the persons to add to the group
4. Press **Save changes** to create the group

  ![Add group](./img/add-group.jpg)

</Steps>

The new group has the [member](./rbac#org-member) role by default. You can change it by pressing the **Modify Role** button and selecting a different role.

You can also define [custom organization roles](#custom) if none of the pre-defined roles suit your needs.

### How to change group roles {#group-role}

To change the role of a group, press the **Change Role** button next to the group.

![Changing the roles of a group](./img/group-role.jpg)

### How to add members groups {#change-groups}

To add or remove users in a group, press the **Modify group** button next to it.

- Press the **X** button to remove the user from the group
- Type the name of the persons you want to add to the group
- Press **Save changes** to finish editing the group

![Add group](./img/add-group.jpg)

### How to view pre-defined roles {#org-roles}

Semaphore provides pre-defined roles for organizations. You can see what actions each role can perform by following these steps:

<Steps>

1. Open the Organization **Settings** menu
2. Select **Roles**
    ![Settings Role location](./img/settings-roles.jpg)
3. In the **Organization Roles** section, press the eye button next to the role you want to examine

</Steps>

The actions with enabled checkbox are allowed for that role.

![Organization admin allowed actions](./img/org-admin-roles.jpg)

### How to create custom roles {#custom}

<Available plans={['Enterprise']}/>

Create custom roles to give your users the precise permissions they need. 

<Steps>

1. Open the Organization **Settings** menu
2. Select **Roles**
3. On the **Organization Roles** section, press **New Role**
4. Give a name a description to the new role
5. Enable the permissions allowed to the role. You can use the search box to narrow down options
6. Press **Save changes**

  ![Creating a new organization role](./img/org-role-create-custom.jpg)

</Steps>

## See also

- [Role-Based Access Controls](./rbac)
- [Okta integration](./okta)

