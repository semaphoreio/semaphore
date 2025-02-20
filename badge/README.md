# Badges

## Overview
The Badges project is an Elixir application that provides status badges for projects. These badges can be used to display the current status of a project's branches, such as whether the latest build passed or failed. The application integrates with Semaphore to fetch the status of the projects and generate the corresponding badges.

## Features
- Generate status badges for public and private projects.
- Support for different badge styles.
- Integration with Semaphore CI for fetching project statuses.
- Caching of badge data to improve performance.
- Health check endpoint to verify the service is running.

## Usage
The application provides several endpoints for fetching badges:

- `/is_alive`: Health check endpoint.
- `/badges/:project_name/branches/*branch_name`: Fetch the badge for a specific branch.
- `/badges/:project_name`: Fetch the badge for the default branch.

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
