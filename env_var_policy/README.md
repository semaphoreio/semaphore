# EnvVarPolicy

Shared by Zebra, Plumber and Secrethub: the names of the environment variables
Semaphore supplies to jobs (which pipelines, parameters, secrets and containers
must not set), and the rules user-defined variable names must follow.

```elixir
{:env_var_policy, path: "../env_var_policy"}
```

Add a name here when a service starts injecting a new platform variable.

Run the tests with `make test` (in Docker locally, directly on CI).
