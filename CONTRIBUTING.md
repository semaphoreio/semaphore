# Contributing to Semaphore

Thank you for your interest in contributing to Semaphore! This document provides guidelines and information for contributors.

## Quick Start

**Ready to contribute?**

1. **Fork the repository** on GitHub
2. **Clone your fork**: `git clone https://github.com/YOUR_USERNAME/semaphore.git`
3. **Create a feature branch**: `git checkout -b feature/your-feature-name`
4. **Open in VS Code**: Most services have dev container support for easy setup
5. **Make your changes** and ensure all tests pass
6. **Create a Pull Request** from your fork

> [!IMPORTANT]
> 🚦 **All CI checks must pass before review.**

## Repository Structure

Our monorepo contains multiple services:

- **Community Edition**: All code outside `ee/` directory (Apache 2.0 license)
- **Enterprise Edition**: Code within `ee/` directory (commercial license)

### Technology Stack

- **Elixir**: Core services (auth, guard, projecthub, secrethub, etc.)
- **Go**: Infrastructure services (bootstrapper, encryptor, repohub, etc.)
- **TS/React**: Frontend (front/)
- **Ruby**: Github hook processing (github_hooks)

## Development Workflow

### 1. Fork & Setup

```bash
# Fork repository on GitHub, then:
git clone https://github.com/YOUR_USERNAME/semaphore.git
cd semaphore
git remote add upstream https://github.com/semaphoreio/semaphore.git
```

### 2. Create Feature Branch

```bash
git checkout -b feature/descriptive-name
# or: fix/bug-description, docs/update-readme, etc.
```

### 3. Development & Testing

**Most services include VS Code dev container support for instant setup:**

```bash
# Open any service with dev container support
code auth/  # VS Code will prompt to "Reopen in Container"
```

**For services without dev containers, use Docker directly:**

```bash
cd service_name
make build
make test.ex     # For Elixir services
make test        # For Go services
```

### 4. Ensure CI Will Pass

**Before pushing, run these checks locally:**

```bash
# Elixir services
make format.ex   # Format code
make lint.ex     # Run linter
make test.ex     # Run tests

# Go services
make lint
make test

# All services
make check.docker  # Security scan
```

### 5. Create Pull Request

- **Push your branch** to your fork
- **Create PR** from your fork to `semaphoreio/semaphore:main`
- **Fill out the PR template** completely
- **Wait for review** - maintainers will be automatically assigned

## Code Guidelines

### Commit Messages

Use [conventional commits](https://www.conventionalcommits.org/):

```text
feat(auth): add OAuth2 token refresh mechanism

- Implement automatic token refresh logic
- Add retry mechanism for expired tokens
- Update auth middleware to handle refresh
```

### Testing Requirements

- **New features**: Include unit tests
- **Bug fixes**: Include regression tests
- **API changes**: Update integration tests
- **Frontend changes**: Consider browser test coverage

## Getting Help

- **[GitHub Discussions](https://github.com/semaphoreio/semaphore/discussions)**: Questions and discussions
- **[Discord](https://discord.gg/FBuUrV24NH)**: Real-time chat
- **[Good First Issues](https://github.com/semaphoreio/semaphore/labels/good%20first%20issue)**: Beginner-friendly tasks

## Additional Resources

- **[Development Setup](DEVELOPMENT.md)**: Detailed environment setup
- **[Roadmap](ROADMAP.md)**: Project direction and priorities
- **[Code of Conduct](CODE_OF_CONDUCT.md)**: Community guidelines

---

**Ready to contribute?** Pick a [good first issue](https://github.com/semaphoreio/semaphore/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22) or say hello on [Discord](https://discord.gg/FBuUrV24NH)! 👋
