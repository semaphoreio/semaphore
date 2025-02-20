defmodule PublicAPI.Schemas.Dashboards.Dashboard do
  @moduledoc """
  Schema for a dashboard

  format:
  apiVersion: (v2)
  kind: Dashboard
  metadata: (id, org_id, timestamps)*readonly
  spec: duplication of metadata + resource-specific stuff
  """
  use PublicAPI.SpecHelpers.Schema

  use PublicAPI.Schemas.Common.Kind, kind: "Dashboard"

  OpenApiSpex.schema(%{
    title: "Dashboard",
    type: :object,
    required: [:apiVersion, :kind, :metadata, :spec],
    properties: %{
      apiVersion: PublicAPI.Schemas.Common.ApiVersion.schema(),
      kind: ResourceKind.schema(),
      metadata: %Schema{
        type: :object,
        description: "Metadata of the dashboard, all fields are read only",
        properties: %{
          id: PublicAPI.Schemas.Common.ResourceId.schema(),
          organization: PublicAPI.Schemas.Common.SimpleOrganization.schema(),
          name: PublicAPI.Schemas.Common.Name.schema(),
          timeline: %Schema{
            type: :object,
            properties: %{
              created_at: PublicAPI.Schemas.Common.timestamp(),
              created_by: PublicAPI.Schemas.Common.Requester.schema(),
              updated_at: PublicAPI.Schemas.Common.timestamp(),
              updated_by: PublicAPI.Schemas.Common.Requester.schema()
            }
          }
        },
        readOnly: true,
        required: [:id, :organization, :name, :timeline]
      },
      spec: %Schema{
        type: :object,
        description: "Specification of the dashboard",
        required: [:display_name, :widgets],
        properties: %{
          display_name: PublicAPI.Schemas.Common.DisplayName.schema(),
          widgets: %Schema{
            type: :array,
            description: "List of widgets on the dashboard",
            items: %Schema{
              type: :object,
              description: "Widget on the dashboard",
              required: [:name, :type, :filters],
              properties: %{
                name: %Schema{
                  type: :string,
                  description: "Name of the widget",
                  example: "Deployment Pipelines"
                },
                type: %Schema{
                  type: :string,
                  description: "Type of the widget",
                  example: "PIPELINES",
                  enum: ["PIPELINES", "WORKFLOWS"]
                },
                filters: %Schema{
                  type: :object,
                  description: "Object with filters for the widget",
                  properties: %{
                    project: PublicAPI.Schemas.Common.NullableSimpleProject.schema(),
                    reference: %Schema{
                      type: :string,
                      description: "git reference",
                      example: "refs/heads/master"
                    },
                    pipeline_file: %Schema{
                      type: :string,
                      description: "Path to the pipelie file",
                      example: ".semaphore/semaphore.yml"
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
