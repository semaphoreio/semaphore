# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule PublicAPI.Schemas.ProjectSecrets.Secret do
  @moduledoc """
  Schema for a secret

  format:
  apiVersion: (v1)
  kind: ProjectSecret
  metadata: (id, org_id, project_id, timestamps)*readonly
  spec: duplication of metadata + resource-specific stuff
  """
  use PublicAPI.SpecHelpers.Schema

  use PublicAPI.Schemas.Common.Kind, kind: "ProjectSecret"

  OpenApiSpex.schema(%{
    title: "ProjectSecrets.Secret",
    type: :object,
    required: [:apiVersion, :kind, :metadata, :spec],
    properties: %{
      apiVersion: PublicAPI.Schemas.Common.ApiVersion.schema(),
      kind: ResourceKind.schema(),
      metadata: %Schema{
        type: :object,
        description: "Metadata of the secret, all fields are read only",
        properties: %{
          id: PublicAPI.Schemas.Common.id("Secret"),
          org_id: PublicAPI.Schemas.Common.id("Organization"),
          project_id: PublicAPI.Schemas.Common.id("Project"),
          name: PublicAPI.Schemas.Secrets.Name.schema(),
          created_at: PublicAPI.Schemas.Common.timestamp(),
          updated_at: PublicAPI.Schemas.Common.timestamp(),
          last_used_at: %{
            PublicAPI.Schemas.Common.timestamp()
            | nullable: true,
              description: "Last time the secret was used in a job"
          },
          created_by: PublicAPI.Schemas.Common.User.schema(),
          updated_by: PublicAPI.Schemas.Common.User.schema(),
          description: %Schema{
            type: :string,
            description: "Description of the secret"
          },
          last_used_by: PublicAPI.Schemas.Secrets.Checkout.schema()
        },
        readOnly: true,
        required: [:id, :name, :org_id, :project_id]
      },
      spec: %Schema{
        type: :object,
        description: "Specification of the secret",
        required: [:name, :data],
        properties: %{
          name: PublicAPI.Schemas.Secrets.Name.schema(),
          description: %Schema{
            type: :string,
            description: "Description of the secret"
          },
          data: %Schema{
            type: :object,
            description:
              "Data of the secret, both env_vars and files are required but can be empty",
            required: [:env_vars, :files],
            properties: %{
              env_vars: %Schema{
                type: :array,
                description: "Value of the secret",
                items: %Schema{
                  type: :object,
                  description: "Environment variable",
                  properties: %{
                    name: %Schema{
                      type: :string,
                      minLength: 1,
                      example: "ENV_VAR_NAME",
                      description: "Name of the environment variable"
                    },
                    value: %Schema{
                      type: :string,
                      description: "Value of the environment variable, or a md5 checksum"
                    }
                  },
                  required: [:name, :value]
                }
              },
              files: %Schema{
                type: :array,
                description: "Files of the secret",
                items: %Schema{
                  type: :object,
                  description: "File",
                  properties: %{
                    path: %Schema{
                      type: :string,
                      minLength: 1,
                      example: "/path/to/file",
                      description:
                        "Name of the file. Both absolute and relative paths are allowed."
                    },
                    content: %Schema{
                      type: :string,
                      description: "base64 encoded content of the file or a md5 checksum"
                    }
                  },
                  required: [:path, :content]
                }
              }
            }
          }
        }
      }
    }
  })
end
