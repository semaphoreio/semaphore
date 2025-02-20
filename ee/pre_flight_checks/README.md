# PreFlightChecks service

## Overview

The PreFlightChecks service is responsible for managing CRUD operation on Pre-Flight checks
defined on both project and organization levels.

The Front service is the main client of the PreFlightChecks service since it exposes the UI for
managing the Pre-Flight checks.

The other notable client is the Plumber service that calls the PreFlightChecks service to
fetch the commands Pre-Flight checks that need to be included in initialization jobs. 

## Available Commands

The following commands are available in the [Makefile](Makefile) and [Root Makefile](../Makefile):

### Development
- `make dev.setup` - Sets up the development environment
- `make console.ex` - Run an interactive elixir shell inside the Docker container
- `make console.bash` - Run an interactive bash shell inside the Docker container
- `make format.ex` - Format the code

### Testing
- `make test.ex.setup` - Setups the environment needed for testing
- `make test.ex` - Runs the tests
- `make lint` - Runs code linting (credo)
