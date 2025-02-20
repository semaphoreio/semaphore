# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule PublicAPI.Schemas.Secrets.Secret do
  @moduledoc """
  Schema for a secret

  format:
  apiVersion: (v1)
  kind: Secret
  metadata: (id, org_id, project_id, timestamps)*readonly
  spec: duplication of metadata + resource-specific stuff
  """
  use PublicAPI.SpecHelpers.Schema

  use PublicAPI.Schemas.Common.Kind, kind: "Secret"

  OpenApiSpex.schema(%{
    title: "Secrets.Secret",
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
        required: [:id, :name, :org_id]
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
                description: "Environment variables of the secret",
                items: %OpenApiSpex.Reference{
                  "$ref": "#/components/schemas/Secrets.Secret.EnvVar"
                }
              },
              files: %Schema{
                type: :array,
                description: "Files of the secret",
                items: %OpenApiSpex.Reference{
                  "$ref": "#/components/schemas/Secrets.Secret.File"
                }
              }
            }
          },
          access_config: PublicAPI.Schemas.Secrets.AccessConfig.schema()
        }
      }
    }
  })
end
