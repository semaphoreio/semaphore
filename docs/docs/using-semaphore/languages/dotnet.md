---
description: .NET Guide
sidebar_position: 9
---

# .NET

Semaphore Ubuntu images include the .NET SDK and PowerShell.

This page shows how to inspect installed versions, build .NET projects, run tests, and speed up pipelines with caching.

## Check installed versions

Use the following commands to inspect available .NET and PowerShell versions:

```bash
dotnet --info
dotnet --list-sdks
dotnet --list-runtimes
pwsh --version
```

## Build a .NET project

The following example restores dependencies and builds a project in Release mode:

```yaml
version: v1.0
name: .NET pipeline
agent:
  machine:
    type: f1-standard-2
    os_image: ubuntu2404
blocks:
  - name: Build
    task:
      jobs:
        - name: Build application
          commands:
            - checkout
            - dotnet --info
            - dotnet restore
            - dotnet build --configuration Release --no-restore
```

## Run tests

Use `dotnet test` to execute your test suite:

```yaml
version: v1.0
name: .NET tests
agent:
  machine:
    type: f1-standard-2
    os_image: ubuntu2404
blocks:
  - name: Test
    task:
      jobs:
        - name: Run tests
          commands:
            - checkout
            - dotnet restore
            - dotnet test --configuration Release --no-restore
```

## Cache NuGet packages

Caching NuGet packages can make pipelines faster.

Set `NUGET_PACKAGES` to a project-local directory, then restore and store the cache:

```bash
export NUGET_PACKAGES=.nuget/packages
checkout
cache restore
dotnet restore
cache store
```

In subsequent jobs, restore the cache before building or testing:

```bash
export NUGET_PACKAGES=.nuget/packages
checkout
cache restore
dotnet build --configuration Release --no-restore
```

## Use PowerShell

PowerShell is available as `pwsh`.

Example:

```yaml
version: v1.0
name: .NET with PowerShell
agent:
  machine:
    type: f1-standard-2
    os_image: ubuntu2404
blocks:
  - name: Run PowerShell
    task:
      jobs:
        - name: PowerShell script
          commands:
            - checkout
            - pwsh -Command "Get-ChildItem"
            - pwsh -File ./scripts/build.ps1
```

## Build and test in one pipeline

The following pipeline restores dependencies, builds the application, and runs tests:

```yaml
version: v1.0
name: .NET example
agent:
  machine:
    type: f1-standard-2
    os_image: ubuntu2404
blocks:
  - name: Build and test
    task:
      jobs:
        - name: .NET
          commands:
            - checkout
            - dotnet --info
            - dotnet restore
            - dotnet build --configuration Release --no-restore
            - dotnet test --configuration Release --no-build
```

## Example using a solution file

If your repository contains a solution file, you can target it explicitly:

```bash
dotnet restore MyApp.sln
dotnet build MyApp.sln --configuration Release --no-restore
dotnet test MyApp.sln --configuration Release --no-build
```
