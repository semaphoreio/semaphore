defmodule PublicAPI.Schemas.SelfHostedAgents.AgentType.NameSettings do
  @moduledoc """
  Schema for a self-hosted agent type name settings
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "SelfHostedAgents.AgentType.NameSettings",
    type: :object,
    description: "Settings for the agent name",
    required: [],
    properties: %{
      assignment_origin: %Schema{
        type: :string,
        description: "The origin of the agent name assignment during its registration",
        enum: [
          "ASSIGNMENT_ORIGIN_UNSPECIFIED",
          "ASSIGNMENT_ORIGIN_AGENT",
          "ASSIGNMENT_ORIGIN_AWS_STS"
        ],
        default: "ASSIGNMENT_ORIGIN_AGENT"
      },
      release_after: %Schema{
        type: :integer,
        description:
          "How long to hold the agent name after its disconnection, not allowing other agents to register with its name",
        default: 0
      },
      aws: %Schema{
        type: :object,
        nullable: true,
        description:
          "AWS settings, required if `assignment_origin` `ASSIGNMENT_ORIGIN_AWS_STS` is used",
        required: [:account_id, :role_name_patterns],
        properties: %{
          account_id: %Schema{
            type: :string,
            description: "The AWS account ID",
            example: "123456789012"
          },
          role_name_patterns: %Schema{
            type: :string,
            description: "Comma-separated list of AWS role names. Wildcards (*) can be used too",
            example: "my-role-name"
          }
        }
      }
    }
  })
end
