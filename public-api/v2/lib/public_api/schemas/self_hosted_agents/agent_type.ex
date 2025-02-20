defmodule PublicAPI.Schemas.SelfHostedAgents.AgentType do
  @moduledoc """
  Schema for a self-hosted agent type
  """
  use PublicAPI.SpecHelpers.Schema
  use PublicAPI.Schemas.Common.Kind, kind: "SelfHostedAgentType"

  OpenApiSpex.schema(%{
    title: "SelfHostedAgents.AgentType",
    type: :object,
    description: "Self-hosted agent type",
    required: [:apiVersion, :kind, :spec],
    properties: %{
      apiVersion: PublicAPI.Schemas.Common.ApiVersion.schema(),
      kind: ResourceKind.schema(),
      metadata: %Schema{
        type: :object,
        description: "Metadata of the agent type, all fields are read only",
        properties: %{
          name: %Schema{
            type: :string,
            description: "The name of the agent type",
            example: "my-agent-type"
          },
          created_at: PublicAPI.Schemas.Common.timestamp(),
          updated_at: PublicAPI.Schemas.Common.timestamp(),
          status: %Schema{
            type: :object,
            description: "Status of the agent type",
            properties: %{
              total_agent_count: %Schema{
                type: :integer,
                description: "Total number of agents of this type",
                example: 0
              },
              registration_token: %Schema{
                type: :string,
                description: "Registration token for the agent type",
                example: "..."
              }
            }
          }
        },
        readOnly: true,
        required: [:name]
      },
      spec: %Schema{
        type: :object,
        description: "Specification of the agent type",
        required: [:name, :agent_name_settings],
        properties: %{
          name: %Schema{
            type: :string,
            description: "The name of the agent type",
            example: "my-agent-type"
          },
          agent_name_settings: %OpenApiSpex.Reference{
            "$ref": "#/components/schemas/SelfHostedAgents.AgentType.NameSettings"
          }
        }
      }
    }
  })
end
