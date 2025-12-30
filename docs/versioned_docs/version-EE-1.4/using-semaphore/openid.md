---
description: OIDC secures access to cloud providers
---

# OpenID Connect







OpenID Connect (OIDC) allows you to establish a more secure trust relationship between Semaphore and cloud providers such as AWS or Google Cloud.

## Overview

<Available plans={['Enterprise']}/>

Semaphore users traditionally use [secrets](./secrets) to inject credentials or API keys in jobs that need to interact with cloud providers. Every time the CI pipeline needs to deploy an application or fetch resources from a Docker registry or S3 bucket, we need to supply a secret to authorize Semaphore to access your cloud.

These long-lived credentials present a challenge to maintain security or face exposure to security threats. Access and usage of these secrets need to be carefully monitored. Secrets need to be regularly rotated and the provided access rights on the cloud should follow the principle of least privilege.

OpenID Connect (OIDC) provides an alternative way to interact with the cloud. Instead of secrets, OIDC uses short-lived access tokens that do not require secret maintenance.

## How to configure OpenID Connect

This section explains how to connect OpenID to your cloud provider.

### AWS

To connect to Amazon Web Services (AWS) from Semaphore using OpenID Connect, you will need to perform the following steps.

<details>
<summary>Step 1: Create identity provider</summary>
<div>


<Steps>

1. Log in to the [AWS IAM Console](https://console.aws.amazon.com/iam/)
2. Under **Access management**, select **Identity providers**
3. Press **Add provider**
4. Select **OpenID connect**
5. In **Provider URL** and **Audience** type your [organization URL](./organizations#general-settings), e.g. `https://my-org.semaphoreci.com`
6. Press **Add provider**
   
    ![Creating an OIDC Identity Provider](./img/aws-identity-provider.jpg)

</Steps>

</div>
</details>

<details>
<summary>Step 2: Configure a role and trust policy</summary>
<div>


<Steps>

1. Log in to the [AWS IAM Console](https://console.aws.amazon.com/iam/)
2. Under **Access management**, select **Roles**
3. Press **Create role**
4. Select **Web identity**
5. Under **Identity provider** and **Audience**, select the provider you created in Step 1
6. Press **Next**
7. Choose the permissions you want this role to have. This typically involves selecting a policy that allows access to the AWS resources your pipelines need. For example, if your pipelines need access to S3, you might choose the `AmazonS3FullAccess` policy.
8. Press **Next**
9. Type the **Role name** and an optional description
10. Press **Create role**

    ![Adding an OIDC role](./img/add-oidc-role.jpg)

</Steps>

Next, edit the trust policy as follows:


<Steps>

1. Select the newly created Role by name. You may need to use the search box to locate it
2. Select the **Trust relationships** tab
3. Press **Edit trust policy**
4. Edit the `Condition` section (see below for details)
5. Press **Update policy**

</Steps>

The trust policy uses JSON to configure what projects and branches can access the resources assigned to this role. 
    
- Use `StringEquals` to define specific projects and branches 
- Use `StringLike` to match projects and branches using a pattern
- You can combine `StringEquals` and `StringLike` in the same `Condition`

The following example shows how to grant permissions to:

- organization:`my-org` 
- project id: `936a5312-a3b8-4921-8b3f-2cec8baac574`
- repository: `web`
- branch: `main`

```json title="Assigning trust relationship by the exact name"
"Condition": {
    "StringEquals": {
        "my-org.semaphoreci.com:aud": "https://my-org.semaphoreci.com",
        "my-org.semaphoreci.com:sub": "org:my-org:project:936a5312-a3b8-4921-8b3f-2cec8baac574:repo:web:ref_type:branch:ref:refs/heads/main"
 }
}
```

The next example shows how to grant permissions to:

- organization `my-org` 
- project id `936a5312-a3b8-4921-8b3f-2cec8baac574`
- repository `web`
- all branches

```json title="Assigning trust relationship by pattern match"
"Condition": {
    "StringLike": {
        "<org-url>.semaphoreci.com:sub":
        "org:<org-url>:project:936a5312-a3b8-4921-8b3f-2cec8baac574:repo:web:ref_type:branch:ref:refs/heads/*",
 },
}
```

</div>
</details>

<details>
<summary>Step 3: Use OIDC in your Semaphore pipelines</summary>
<div>

You can now use OIDC to access your AWS resources from any of your pipelines.  

In order authenticate with AWS add these commands to the Semaphore [job](./jobs) that needs access.

```shell "Job commands to authenticate"
export ROLE_ARN="YOUR_AWS_ROLE_NAME"
export SESSION_NAME="semaphore-job-${SEMAPHORE_JOB_ID}"
export CREDENTIALS=$(aws sts assume-role-with-web-identity --role-arn $ROLE_ARN --role-session-name $SESSION_NAME --web-identity-token $SEMAPHORE_OIDC_TOKEN)
export AWS_ACCESS_KEY_ID=$(echo $CREDENTIALS | jq -r '.Credentials.AccessKeyId')
export AWS_SESSION_TOKEN=$(echo $CREDENTIALS | jq -r '.Credentials.SessionToken')
export AWS_SECRET_ACCESS_KEY=$(echo $CREDENTIALS | jq -r '.Credentials.SecretAccessKey')
```

:::note

Replace `YOUR_AWS_ROLE_NAME` with the Role you created in Step 2

:::

</div>
</details>

### Google Cloud

You can use [gcloud](https://cloud.google.com/sdk/gcloud) to set up and configure the connection between Google Cloud and Semaphore. See the [Google Cloud Identity Federation documentation](https://cloud.google.com/iam/docs/configuring-workload-identity-federation#oidc_1) for more details.

To configure OIDC identity provider in GCP, you will perform the following actions.

<details>
<summary>Step 1: Create a new identity pool</summary>
<div>


<Steps>

1. Define a `POOL_ID` name. This unique name served to identify a Google Cloud IAM pool. For example: `semaphoreci-com-identity-pool`
2. Store the pool in an environment variable, e.g `semaphoreci-com-identity-pool`

    ```shell title="Define a name for the identity pool"
    export POOL_ID="<unique-pool-name>" 
    ```

3. Create the identify pool

    ```shell title="Create identity pool"
    gcloud iam workload-identity-pools create $POOL_ID \
    --location="global" \
    --description="Semaphore OIDC Pool" \
    --display-name=$POOL_ID
    ```

</Steps>

</div>
</details>


<details>
<summary>Step 2: Configure the mapping and conditions</summary>
<div>

Next, we need to map fields from the Semaphore OIDC provider to Google Cloud attributes and set conditions where Semaphore can access the identity pool. See [attribute mapping](https://cloud.google.com/iam/docs/configuring-workload-identity-federation#mappings-and-conditions) and [condition mapping](https://cloud.google.com/iam/docs/configuring-workload-identity-federation#mappings-and-conditions) to learn more.


<Steps>

1. Define `PROVIDER_ID` with a unique name for the OIDC provider, for example: `semaphoreci-com`. The variable `ISSUER_URI` should contain your [organization URL](./organizations#general-settings), e.g. `https://my-org.semaphoreci.com`

    ```shell title="Define PROVIDER_ID and ISSUER_URI"
    export PROVIDER_ID="<unique-provider-name>"
    export ISSUER_URI="https://my-org.semaphoreci.com"
    ```

2. Use the following template to grant Google Cloud access to the identity pool created in Step 1. 

    **Note**: Google Cloud has a 127-byte limit for mapped attributes. Semaphore's JWT subject can exceed this limit, so we'll use shorter JWT claims for the mapping.

    Replace:
    - `<REPOSITORY>` with your repository name, e.g. `web`
    - `<BRANCH>` with the branch that can access the cloud resources, e.g. `main`
    - `<PROJECT_NAME>` with your project name on Semaphore

    ```shell title="Grant access to the identity pool"
    gcloud iam workload-identity-pools providers create-oidc $PROVIDER_ID \
    --location="global" \
    --workload-identity-pool=$POOL_ID \
    --issuer-uri="$ISSUER_URI" \
    --allowed-audiences="$ISSUER_URI" \
    --attribute-mapping="google.subject=assertion.repo,google.branch=assertion.branch" \
    --attribute-condition="assertion.repo == '<REPOSITORY>' && assertion.branch == '<BRANCH>' && assertion.prj == '<PROJECT_NAME>'"
    ```

    This configuration:
    - Maps the repository name from the JWT to `google.subject` 
    - Maps the branch name from the JWT to `google.branch`
    - Uses attribute conditions to verify the specific repository, branch, and project from the JWT claims
    - Avoids the 127-byte limit by using shorter JWT claims instead of the full subject

</Steps>

</div>
</details>


<details>
<summary>Step 3: Connect the pool with a Google Cloud service account</summary>
<div>

Connecting to the pool allows Semaphore to impersonate your Google Cloud service account. To create the connection follow these steps:


<Steps>

1. Define environment variables:
    - `<REPOSITORY>` is the repository name, e.g. `web`
    - `<BRANCH>` is the branch, e.g. `main`

    ```shell
    export SUBJECT="<REPOSITORY>"
    export PROJECT_NUMBER=$(gcloud projects describe $(gcloud config get-value core/project) --format=value\(projectNumber\))
    export MEMBER_ID="principal://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL_ID/subject/$SUBJECT"
    ```

2. Bind the workload identity user to the service account

    ```shell
    # ID of the service account who you want to impersonate in the pipelines
    export SERVICE_ACCOUNT_EMAIL="myemail@example.com" 

    gcloud iam service-accounts add-iam-policy-binding $SERVICE_ACCOUNT_EMAIL \
        --role=roles/iam.workloadIdentityUser \
     --member="MEMBER_ID"
    ```

</Steps>

See [Granting external identities impersonation permissions](https://cloud.google.com/iam/docs/using-workload-identity-federation#impersonate) to learn more about service accounts.
</div>
</details>

<details>
<summary> Step 4: Use OIDC connection in Semaphore jobs</summary>
<div>

Add the following commands to the Semaphore [job](./jobs) that needs to access your Google Cloud resources

```shell title="Using OIDC in a Semaphore job"
export POOL_ID="<YOUR_POOL_ID>"
export PROVIDER_ID="<YOUR_PROVIDER_ID_NAME>"
export PROJECT_ID="<YOUR_GOOGLE_CLOUD_PROJECT_ID>" 
export SERVICE_ACCOUNT_EMAIL="<YOUR_SERVICE_ACCOUNT_EMAIL>" 
export POOL_URI="projects/$PROJECT_ID/locations/global/workloadIdentityPools/$POOL_ID/providers/$PROVIDER_ID"
echo $SEMAPHORE_OIDC_TOKEN > /tmp/oidc_token
gcloud iam workload-identity-pools create-cred-config $POOL_URI --service-account="$SERVICE_ACCOUNT_EMAIL" --service-account-token-lifetime-seconds=600 --output-file=/home/semaphore/creds.json --credential-source-file=/tmp/oidc_token --credential-source-type="text"
export GOOGLE_APPLICATION_CREDENTIALS=/home/semaphore/creds.json
gcloud auth login --cred-file=/home/semaphore/creds.json
gcloud projects list
```

</div>
</details>

### HashiCorp Vault

To use OIDC to access [HashiCorp Vault], you need to set up a trust relationship with Semaphore. This configuration uses JWT tokens as the authentication method. See [HashiCorp's JWT/OIDC documentation](https://developer.hashicorp.com/vault/docs/auth/jwt) to learn more.


<details>
<summary>Step 1: Enable JWT Support on HashiCorp Vault</summary>
<div>

The first step is to enable JWT authentication support on the Vault:

<Steps>

1. Execute the following command to enable JWT on your vault

    ```shell
    vault auth enable jwt
    ```
    
2. Define a variable with your [organization URL](./organizations#general-settings), e.g. `https://my-org.semaphoreci.com`

    ```shell
    export PROVIDER_URL="https://my-org.semaphoreci.com"
    ```

3. Enable JWT for your Semaphore organization

    ```shell
    vault write auth/jwt/config bound_issuer="$PROVIDER_URL" oidc_discovery_url="$PROVIDER_URL"
    ```

</Steps>

</div>
</details>
<details>
<summary>Step 2: Configure roles and policies for accessing secrets</summary>
<div>
Configure a policy that grants access to specific paths that will be accessed by your Semaphore pipelines. For more details, read Vault's Policies documentation.


<Steps>

1. Create a policy granting access to paths in your Vault. See [Vault policies](https://developer.hashicorp.com/vault/docs/concepts/policies) to learn more about this feature

    ```shell title="Setting read-only permissions to secret/data/production folder"
    vault policy write example-policy - <<EOF
    path "secret/data/production/*" {
    capabilities = [ "read" ]
    }
    EOF
    ```

2. Create a role to access the Vault resources
    - Replace `<REPOSITORY>` with your repository
    - Replace `<BRANCH>` with the branch that can access the Vault

    ```shell title="Creating a role"
    vault write auth/jwt/role/example-role -<<EOF
    {
    "role_type": "jwt",
    "user_claim": "actor",
    "bound_claims": {
     "repo": "<REPOSITORY>",
     "branch": "<BRANCH>"
    },
    "policies": ["example-policy"],
    "ttl": "5m"
    }
    EOF
    ```

</Steps>

</div>
</details>

<details>
<summary>Step 3: Access Vault secrets from your Semaphore jobs</summary>
<div>

To access the Vault from a Semaphore [job](./jobs), add the following commands at the beginning:

```shell
export VAULT_TOKEN=$(vault write -field=token auth/jwt/login role=example-role jwt=$SEMAPHORE_OIDC_TOKEN)
vault kv get -field=value secret/data/production/my-secret
```
</div>
</details>

## Implementation details

See the [OIDC token reference page](../reference/openid) to learn how the OIDC tokens are created and what fields are available.

## See also

- [How to integrate Semaphore with Okta](./okta)
- [Semaphore organizations](./organizations)

