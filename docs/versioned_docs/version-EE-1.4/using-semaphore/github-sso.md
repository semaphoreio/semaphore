---
description: Single Sign On with GitHub
---

# Single Sign On with GitHub







Semaphore supports repositories hosted on GitHub with SAML single sign-on (SSO). This GitHub feature is available in the GitHub Enterprise Cloud offering.

To authorize Semaphore to access repositories hosted on GitHub SSO, you need to grant Semaphore access to your organization on GitHub.

These are the steps to accomplish this:

<Steps>

1. Go to your [GitHub Settings](https://github.com/settings/profile)
2. Select **Applications**
3. Select **Authorized OAuth Apps**
4. From the list of application choose "Semaphore 2.0"
5. Choose your GitHub **Organization access** and click either **Grant** or **Request Access**
6. The organization Admin has to approve the request

</Steps>

Once access is granted, you can connect Semaphore to your GitHub Enterprise repositories and create [projects](./projects).

## See also

- [Connecting to GitHub using GitHub App](./connect-github)
- [Getting Started Guide](../getting-started/quickstart)
- [Using OAuth with GitHub](./connect-github-oauth)
- [Semaphore Organizations](./organizations)
