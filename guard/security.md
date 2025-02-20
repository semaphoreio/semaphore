1. Service description 

The service is tasked with User management and authorization

2. Features service is implementing/supporting

- Inviting users to the organization
- Role-Based Access Control
- Syncing permissions with GitHub repositories
- Managing user groups for organizations
- User provisioning via SCIM and SSO via SAML

3. Credentials service has access to (e.g. GitHub token, DB password, GCE service account, RabbitMQ pass)
   (Rate them with high, medium, and low in terms of blast radius if exposed)

 - HIGH It has access to the `guard` database (although it can access every other db because of the shared credentials)
 - MEDIUM Credentials for connecting to RabbitMQ
 - LOW Credentials for connecting to Sentry
 - LOW Credentials for connecting to Sparkpost API
 - MEDIUM Credentials for connecting to Redis
 - HIGH Secret for encrypting user sessions

4. Sensitive data service is either storing in the db or having access to in the runtime (Rate them with high, medium, low in terms of blast radius if exposed)

Sensitive data being handled/stored:

 - MEDIUM User emails, GH usernames, and url's to the repositories users have access to
 - MEDIUM Personal information received from the SAML/SCIM provider
 - MEDIUM: Public RSA key from the SAML provider.
 - MEDIUM:  Authentication token that SCIM providers use.	

5. Services that are connecting to this service (sync through API, or async through RabbitMQ)

- Zebra
  - Pings guard to list user's permission on all Public API requests it is handling. 
- Front
  - CRUD for user management and role management
- Monolith
  - When it receives a webhook from GH/BB that access to a given repo has been altered, it pings Guard through the RabbitMQ, so that Guard can refresh permissions.
- Organization API
  - When the organization is created/deleted, it notifies Guard via RabbitMQ.
- User API
  - When a new user is created, or an existing user is deleted
- `v1alpha` public API
  - The old API calls guard directly to validate the user's permissions before passing the request to the destination service. The new version of API uses a sidecar container to check user permissions, (PermissionPatrol) so it does not communicate with Guard directly.


6. APIs service is exposing (can be just to the link to the intern_api proto file)

 - https://github.com/renderedtext/internal_api/blob/master/rbac.proto
 - https://github.com/renderedtext/internal_api/blob/master/okta.proto
 - https://github.com/renderedtext/internal_api/blob/master/groups.proto
 - https://github.com/renderedtext/internal_api/blob/master/okta.proto

7. What are the potential attack vectors? (Identify possible entry points for attackers, such as APIs, remote code execution, external dependencies, and data store)

 - 7.1. gRPC internal API used by Front, and its UI forms
 - 7.2. We use the trust-the-network approach, so any service within our network (even those not listed in the point [5]) can request whatever it wants from the guard.
 - 7.3. Service accepts requests from SAML/SCIM providers


8. Are we doing enough logging and monitoring to be able to detect a compromise of a service or data leakage? What logging and monitoring should we add.

What we have for monitoring right now:
  - Resource usage (CPU and RAM) for all deployments
  - Response times for authorization requests
  - Number of (frequency of) authorization requests

What are we logging:
  - All the errors in the groups api, and the reason for the error
  - For every function that is changing permissions (role management) we are logging every time the function is called, with which parameters is it called, and the result of the function (how many roles were assigned and to whom)
  - For SAML we are not logging all the requests, but we are monitoring the number of incoming requests, and how many SSO attempts were successful vs how many failed
  - For SCIM, we are logging every request to every endpoint together with every failure. We also have audit logs for SCIM endpoints. 
  - All the workers are logging each time they receive a message and start processing it, as well as when they finish with the processing. Some of them are logging the message itself.

9. High level flow chart how service is working. (e.g. getting webhook from GitHub, Store it, Send it to plumber, send job request to build server). Can be a link to Whimsical board.

https://whimsical.com/guard-6t6MyfW1ZhcuuPyaw7k5Ei
