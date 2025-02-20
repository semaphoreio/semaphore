# PublicAPI

Service serves as a public HTTP API for Pipelines service.
It receives requests from users, and if they pass authorization
it repacks them and sends them to Pipelines service via internal gRPC API.
When response is received from Pipelines service, it is forwarded to user over HTTP.

## Usage

Useful commands can be found in [Makefile](Makefile). Some of them are:

- `make console` - runs console inside docker container
- `make unit-test` - for running unit tests

To run the API locally and connect it with plumber:
- `make console` - enter console inside docker container
- `iex -S mix` - start the server

## Adding a new version

When adding a new version create a branch and name it `v<version-number>` (e.g. `v1`).
In launchpad2 add a new deployment and set up the routes with the version number for the new version, call it `public-api-v<version-number>` (e.g. `public-api-v1`).