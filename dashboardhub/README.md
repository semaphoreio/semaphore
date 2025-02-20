# Dashboardhub

Dashboardhub is a platform for managing and monitoring project dashboards. It provides GRPC APIs for internal and public access, integrates with external repositories, and supports secure authentication and event management.

## Features

- **GRPC APIs**: Internal and public GRPC servers for managing dashboards.
- **Authentication**: Secure user authentication.
- **Event Management**: Event handling and logging.

## Available Commands

The following commands are available in the [Makefile](Makefile) and [Root Makefile](../Makefile):

### Development
- `make dev.setup` - Sets up the development environment
- `make console.ex` - Run an interactive shell inside the Docker container
- `make format.ex` - Format the code

### Testing
- `make test.ex` - Runs the tests
- `make deps.check` - Checks dependencies
- `make format.check` - Checks formatting
- `make lint` - Runs code linting (credo)