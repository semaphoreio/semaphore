# Development Setup

This guide helps you set up a development environment for Semaphore.

## Prerequisites

- **Git** (2.25+)
- **Docker** (20.10+) with BuildKit enabled
- **Docker Compose** (2.0+)
- **VS Code** with Dev Containers extension (recommended)

## Quick Start with Dev Containers

Some resources to read before starting:

- [CLI](https://github.com/devcontainers/cli)
- [VSCode](https://code.visualstudio.com/docs/devcontainers/containers)
- [nvim](https://github.com/esensar/nvim-dev-container)
- [GitHub Codespaces](https://docs.github.com/en/codespaces/setting-up-your-project-for-codespaces/adding-a-dev-container-configuration/introduction-to-dev-containers)

Many Semaphore services include dev container configuration for instant setup:

```bash
# Clone the repository
git clone https://github.com/semaphoreio/semaphore.git
cd semaphore

# Open any service with dev container support
code auth/  # or front/, secrethub/, projecthub/, etc.

# VS Code will prompt to "Reopen in Container"
# Click yes and wait for the container to build
```

**That's it!** The dev container provides:

- Pre-configured development environment
- All dependencies installed
- Proper networking between services
- Integrated terminal and debugging

## Manual Docker Setup

For services without dev containers or if not using VS Code:

```bash
# Enable Docker BuildKit
export DOCKER_BUILDKIT=1

# Navigate to service
cd auth

# Build and run tests
make build
make test.ex
```

## Service Development

### Elixir Services

```bash
cd auth  # or any Elixir service

# Common commands
make build        # Build development image
make test.ex      # Run tests
make format.ex    # Format code
make lint.ex      # Run linter
make console.ex   # Interactive shell
```

### Go Services

```bash
cd bootstrapper  # or any Go service

# Common commands
make build       # Build service
make test        # Run tests
make lint        # Run linter
```

### Frontend Development

```bash
cd front

# Build and test
make build
make test.ex TEST_FLAGS='--exclude browser:true'
make test.js
make lint.js
```

## Common Tasks

### Running Tests

```bash
# Run all tests
make test.ex

# Run specific test file
make test.ex TEST_FILE="test/specific_test.exs"

# Run with flags
make test.ex TEST_FLAGS="--only integration"
```

### Code Quality

```bash
# Format code (Elixir)
make format.ex

# Lint code
make lint.ex      # Elixir
make lint         # Go

# Security scans
make check.docker
make check.ex.deps
```

## Troubleshooting

### Docker BuildKit Issues

```bash
# Ensure BuildKit is enabled
export DOCKER_BUILDKIT=1
```

### Permission Issues

```bash
# Fix file permissions
sudo chown -R $(id -u):$(id -g) .
```

### Clean Rebuild

```bash
# Remove build artifacts
rm -rf _build deps node_modules
make build
```

## Next Steps

1. **Pick a service** to work on
2. **Open in VS Code** for automatic setup
3. **Check service README** for specific instructions
4. **Join [Discord](https://discord.gg/FBuUrV24NH)** for help

---

**Need help?** Check [GitHub Discussions](https://github.com/semaphoreio/semaphore/discussions) or ask on Discord!
