defmodule PublicAPI.Handlers.SelfHostedAgentTypes.Describe do
  @moduledoc """
  Plug which serves for describing a self-hosted agent type
  """

  use Plug.Builder
  use PublicAPI.SpecHelpers.Operation

  alias PublicAPI.Schemas

  @operation_id "SelfHostedAgentTypes.Describe"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.SelfHostedAgents.AgentType

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["organization.self_hosted_agents.view"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["self_hosted_agent_type", "describe"])
  plug(PublicAPI.Handlers.SelfHostedAgentTypes.Loader)
  plug(PublicAPI.Plugs.ObjectFilter)
  plug(:describe)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["SelfHostedAgentTypes"],
      summary: "Describe self-hosted agent type",
      description: "Describe a self-hosted agent type",
      operationId: @operation_id,
      parameters: [
        Operation.parameter(
          :agent_type_name,
          :path,
          %Schema{
            type: :string,
            description: "Name of the agent type"
          },
          "Name of the agent type",
          required: true
        )
      ],
      responses:
        Responses.with_errors(%{
          200 =>
            Operation.response(
              "Self-hosted agent type",
              "application/json",
              @response_schema
            )
        })
    }
  end

  # The self hosted agent type is already loaded in the connection and respond plug will take care of the response
  def describe(conn, _opts), do: conn
end
