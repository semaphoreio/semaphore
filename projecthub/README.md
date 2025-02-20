# Projecthub

Projecthub is responsible for managing projects on Semaphore. It serves the internal projecthub API.

## Overview

Projecthub is a service designed to manage projects within Semaphore. It provides an API for internal use and integrates with the "front" database in production. The development environment is set up using Docker, and migrations are managed to keep the database schema in sync with the production environment.

## Features

- Manage projects within Semaphore
- Provide an internal API for project management
- Integrate with the "front" database in production
- Use Docker for development environment setup
- Manage database schema migrations

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
