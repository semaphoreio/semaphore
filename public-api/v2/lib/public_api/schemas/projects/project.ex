defmodule PublicAPI.Schemas.Projects.Project do
  @moduledoc """
  Schema for a secret

  format:
  apiVersion: (v1)
  kind: Project
  metadata: (id, org_id, timestamps)*readonly
  spec: duplication of metadata + resource-specific stuff
  """
  use PublicAPI.SpecHelpers.Schema

  use PublicAPI.Schemas.Common.Kind, kind: "Project"

  OpenApiSpex.schema(%{
    title: "Projects.Project",
    type: :object,
    required: [:apiVersion, :kind, :metadata, :spec],
    properties: %{
      apiVersion: PublicAPI.Schemas.Common.ApiVersion.schema(),
      kind: ResourceKind.schema(),
      metadata: %Schema{
        type: :object,
        description: "Metadata of the project, all fields are read only",
        properties: %{
          id: PublicAPI.Schemas.Common.id("Project"),
          name: PublicAPI.Schemas.Secrets.Name.schema(),
          created_at: PublicAPI.Schemas.Common.timestamp(),
          org_id: PublicAPI.Schemas.Common.id("Organization"),
          created_by: PublicAPI.Schemas.Common.User.schema(),
          description: %Schema{
            type: :string,
            description: "Description of the project"
          },
          connected: %Schema{
            type: :boolean,
            description: "Connection status between Semaphore and repository."
          }
        },
        readOnly: true,
        required: [:id, :name]
      },
      spec: %Schema{
        type: :object,
        description: "Specification of the project",
        required: [:repository, :name],
        properties: %{
          name: PublicAPI.Schemas.Projects.Name.schema(),
          description: %Schema{
            type: :string,
            description: "Description of the project"
          },
          visibility: %Schema{
            type: :string,
            enum: ~w(PUBLIC PRIVATE),
            description: "Visibility of the project"
          },
          repository: %Schema{
            type: :object,
            description: "Repository settings for the project",
            required: [:url, :integration_type, :run_on],
            properties: %{
              url: %Schema{
                type: :string,
                example: "git@github.com:semaphoreci/toolbox.git",
                description: "URL of the repository"
              },
              integration_type: %Schema{
                type: :string,
                description: "Provider of the repository and authentication method",
                enum: ~w(GITHUB_APP GITHUB_OAUTH_TOKEN BITBUCKET)
              },
              forked_pull_requests: %Schema{
                description:
                  "Whether to include forked pull requests in the project, read more [here](https://docs.semaphoreci.com/essentials/project-workflow-trigger-options/#exposing-secrets-in-forked-pull-requests).",
                type: :object,
                properties: %{
                  allowed_secrets: %Schema{
                    type: :array,
                    items: PublicAPI.Schemas.Secrets.Name.schema(),
                    description:
                      "The allowed_secrets property specifies the array of secrets names that are allowed to be exported into jobs triggered by forked-pull-requests. If the array is empty, no secrets will be exported."
                  },
                  allowed_contributors: %Schema{
                    type: :array,
                    items: PublicAPI.Schemas.Common.Contributor.schema(),
                    example: [],
                    description:
                      "List of contributors that can create workflows from forked PRs. Empty list means that everyone can."
                  }
                }
              },
              whitelist: %Schema{
                type: :object,
                description:
                  "Whitelist of branches and tags that can be built using this project",
                properties: %{
                  branches: %Schema{
                    type: :array,
                    items: %Schema{type: :string},
                    description:
                      "List of branches that can be build. Regular expressions allowed. Empty list means that all branches can. Used only when RunType BRANCHES is included."
                  },
                  tags: %Schema{
                    type: :array,
                    items: %Schema{type: :string},
                    description:
                      "List of tags that can be build. Regular expressions allowed. Empty list means that all tags can. Used only when RunType TAGS is included."
                  }
                }
              },
              run_on: %Schema{
                type: :array,
                items: PublicAPI.Schemas.Projects.RunType.schema(),
                description:
                  "Which event will trigger the pipelines for this project. In most cases it is useful set to [\"BRANCHES\"]"
              },
              pipeline_file: %Schema{
                type: :string,
                description: "Path to the pipeline file to run the projec pipelines with",
                default: ".semaphore/semaphore.yml"
              },
              status: %Schema{
                type: :object,
                description:
                  "The status property is used to specify which Semaphore pipeline(s) will submit a status check on GitHub pull requests.
                A pipeline can create a single status check as a result of a whole pipeline. Or each block in a pipeline can create its own status check.
                For most of the projects `path: \".semaphore/semaphore.yml\", level: \"PIPELINE\"` will be suitable. **If left empty default value assumed.** ",
                properties: %{
                  pipeline_files: %Schema{
                    type: :array,
                    default: [%{path: ".semaphore/semaphore.yml", level: "PIPELINE"}],
                    items: %Schema{
                      type: :object,
                      required: [:path, :level],
                      properties: %{
                        level: %Schema{
                          type: :string,
                          enum: ~w(BLOCK PIPELINE),
                          description: "Level of the status check"
                        },
                        path: %Schema{
                          type: :string,
                          description: "Path to the pipeline file",
                          default: ".semaphore/semaphore.yml"
                        }
                      },
                      description:
                        "List of pipeline files that will submit a status check on GitHub pull requests"
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  })
end
