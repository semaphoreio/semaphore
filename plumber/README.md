# Pipelines Service

## Basic info

Pipelines service is used for running and managing pipelines based on their description in Semaphore YAML file.


## Repository content

Here is a list containing brief descriptions of main folders/apps in this repository:

- `block` - Service which runs and manages pipeline's blocks. It is currently started by ppl service as dependency and directly called from code, but it has all needed infrastructure and can be easily deployed as separate service.

- `definition_validator` - App which purpose is to validate received yaml file specification of pipeline against yaml schema of valid yaml files.

- `looper` - Contains configurable macro implementations of frequently needed module functionalities like periodic workers etc.

- `ppl`- Main service which uses and encapsulates all other in this repository and provides Pipelines service defined functionality

- `schema_validator` - App for testing, it ensures that local yaml files used for testing are valid against yaml schema

- `spec` - Contains yaml schemas describing valid yaml files for all supported pipeline versions.
