# Gofer Service

## Overview

Gofer is an Elixir-based service that implements the Switch feature for pipeline orchestration. It enables automated workflow creation by managing the scheduling and execution of pipelines based on configurable triggers and conditions.

## Core Features

- **Switch Management**: Implements the Switch feature that controls pipeline execution flow
  - Switches can be placed after any pipeline
  - Each switch belongs to one source pipeline and can trigger multiple target pipelines
  - Supports both automatic and manual pipeline scheduling

- **Target Management**: 
  - Define multiple target pipelines for each switch
  - Configure environment variables for target pipelines
  - Set up auto-trigger conditions and auto-promote rules

- **Deployment Management**:
  - Handles deployment synchronization with SecretHub
  - Provides dynamic supervision for deployment processes
  - Implements RBAC (Role-Based Access Control)

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
