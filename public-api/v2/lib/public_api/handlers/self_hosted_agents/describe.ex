defmodule PublicAPI.Handlers.SelfHostedAgents.Describe do
  @moduledoc """
  Plug which serves for describing registered self-hosted agent
  """

  use Plug.Builder
  use PublicAPI.SpecHelpers.Operation

  import PublicAPI.Util.PlugContextHelper
  alias InternalClients.SelfHostedHub, as: SelfHostedHubClient
  alias PublicAPI.Schemas

  @operation_id "SelfHostedAgents.Describe"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.SelfHostedAgents.Agent

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["organization.self_hosted_agents.view"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["self_hosted_agents", "describe"])

  plug(:describe)
  plug(PublicAPI.Plugs.ObjectFilter)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["SelfHostedAgents"],
      summary: "Describe registered self-hosted agent",
      description: "Describe a single registered self-hosted agent by agent name.",
      operationId: @operation_id,
      parameters: [
        Operation.parameter(
          :agent_name,
          :path,
          %Schema{
            type: :string,
            description: "Unique name of the self-hosted agent"
          },
          "Unique name of the self-hosted agent."
        )
      ],
      responses:
        Responses.with_errors(%{
          200 =>
            Operation.response(
              "Self-hosted agents",
              "application/json",
              @response_schema
            )
        })
    }
  end

  def describe(conn, _opts) do
    org_id = conn.assigns[:organization_id]

    conn.params
    |> Map.merge(%{organization_id: org_id})
    |> SelfHostedHubClient.describe_agent()
    |> set_response(conn)
  end
end
