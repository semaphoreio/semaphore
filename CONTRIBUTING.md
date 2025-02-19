# Contributing to Semaphore

Thank you for your interest in contributing to Semaphore! This document provides guidelines and information for contributors.

## Table of Contents
- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Repository Structure](#repository-structure)
- [Development Process](#development-process)
- [Submitting Changes](#submitting-changes)
- [Community](#community)

## Code of Conduct

By participating in this project, you are expected to uphold our [Code of Conduct](CODE_OF_CONDUCT.md).

## Getting Started

### Repository Structure
Our repository contains both open-source and enterprise code:
- Open-source code: All code outside the `ee/` directory (Apache 2.0 license)
- Enterprise code: All code within the `ee/` directory (proprietary license)

Please ensure you're working in the appropriate directory based on the feature you're developing.

## Development Process

### 1. Finding Issues to Work On
- Check our issue tracker for open issues
- Look for issues tagged with `good-first-issue` or `help-wanted`
- Feel free to ask questions in the issue comments

### 2. Making Changes
1. Fork the repository
2. Create a new branch from `main`:
   ```
   git checkout -b feature/your-feature-name
   ```
3. Make your changes
4. Write or update tests as needed
5. Ensure all tests pass locally

### 3. Code Style
Our codebase follows these principles:
- Keep code simple and readable
- Add comments for complex logic
- Follow existing patterns in the codebase
- Document public APIs

## Submitting Changes

### Pull Request Process
1. Update relevant documentation
2. Add an entry to CHANGELOG.md if applicable
3. Ensure your PR includes only related changes
4. Fill out the PR template completely
5. Request review from maintainers

### PR Requirements
- Clear, descriptive title
- Reference related issues
- Test coverage for new features
- Updated documentation
- Clean commit history

### Review Process
1. Maintainers will review your code
2. Address any requested changes
3. Once approved, maintainers will merge your PR

## Community

### Getting Help
- GitHub Discussions: Technical questions and feature discussions
- Issue Tracker: Bug reports and feature requests
- [Community Chat]: Quick questions and community discussions

### Communication Tips
- Be clear and concise
- Provide context for your questions
- Be patient with responses
- Help others when you can

## Additional Resources
- [Documentation](docs-link)
- [Development Setup Guide](development-guide-link)
- [API Reference](api-reference-link)

## Recognition
Contributors are recognized in:
- Release notes
- Contributors list
- Project documentation

Thank you for contributing to Semaphore!