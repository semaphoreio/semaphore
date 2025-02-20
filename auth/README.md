# Auth

Responsibilities of the Auth system:

 - Reject unauthenticated calls
 - Check CLI version, reject outdated clients.
 - Do authentication and authorization for Admins and Moderators of Semaphore

## Definitions

### https check

checks the schema and redirects to `https` if schema is set to `http`

### redirect_to param

Based on that params user is redirected to previously visited page after successful login

### logged user headers

- `x-semaphore-user-id` - UUID of logged user
- `x-semaphore-user-anonymous` - false if user is logged

### organization headers

- `x-semaphore-org-username` - username of current organization
- `x-semaphore-org-id` - UUID of current organization
