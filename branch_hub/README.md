# BranchHub

BranchHub is an Elixir-based application designed to manage branches within a project. It provides a set of features to create, update, retrieve, and list branches, as well as to handle branch-related operations such as filtering and archiving.

## Features

- Branch Management: Create, update, and retrieve branches with various attributes such as name, display name, project ID, and reference type.
- gRPC API: Expose branch management functionalities via gRPC services, including describe, list, find or create, archive, and filter operations.
- Database Integration: Utilize Ecto and PostgreSQL for persistent storage of branch data.

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
