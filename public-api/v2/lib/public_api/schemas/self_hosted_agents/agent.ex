defmodule PublicAPI.Schemas.SelfHostedAgents.Agent do
  @moduledoc """
  Schema for a self-hosted agent type
  """
  use PublicAPI.SpecHelpers.Schema
  use PublicAPI.Schemas.Common.Kind, kind: "SelfHostedAgent"

  OpenApiSpex.schema(%{
    title: "SelfHostedAgents.Agent",
    type: :object,
    description: "Self-hosted agent",
    required: [:apiVersion, :kind],
    properties: %{
      apiVersion: PublicAPI.Schemas.Common.ApiVersion.schema(),
      kind: ResourceKind.schema(),
      metadata: %Schema{
        type: :object,
        description: "Metadata of the agent, all fields are read only",
        properties: %{
          version: %Schema{
            type: :string,
            description: "Version of the agent",
            example: "v2.2.6"
          },
          type: %Schema{
            type: :string,
            description: "Self-hosted agent type of the agent",
            example: "s1-my-type"
          },
          pid: %Schema{
            type: :integer,
            description: ""
          },
          os: %Schema{
            type: :string,
            description: "OS the agent is running on",
            example: "Ubuntu 20.04.6 LTS"
          },
          name: %Schema{
            type: :string,
            description: "Unique name of the agent"
          },
          org_id: PublicAPI.Schemas.Common.id("Organization"),
          ip_address: %Schema{
            type: :string,
            description: "The public IP address of the agent"
          },
          hostname: %Schema{
            type: :string,
            description: "Hostname the agent is running on"
          },
          connected_at: PublicAPI.Schemas.Common.timestamp(),
          disabled_at: PublicAPI.Schemas.Common.timestamp(),
          arch: %Schema{
            type: :string,
            description: "Architecture the agent is built for"
          },
          status: %Schema{
            type: :string,
            enum: ["WAITING_FOR_JOB", "RUNNING_JOB"]
          }
        }
      }
    }
  })
end
