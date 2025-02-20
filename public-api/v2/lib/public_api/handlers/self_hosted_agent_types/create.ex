defmodule PublicAPI.Handlers.SelfHostedAgentTypes.Create do
  @moduledoc """
  Plug which serves for creating a self-hosted agent type
  """

  use Plug.Builder
  use PublicAPI.SpecHelpers.Operation

  alias InternalClients.SelfHostedHub, as: SelfHostedHubClient
  alias PublicAPI.Schemas

  @operation_id "SelfHostedAgentTypes.Create"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["organization.self_hosted_agents.manage"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["self_hosted_agent_type", "create"])

  plug(:create)

  def open_api_operation(_) do
    %Operation{
      tags: ["SelfHostedAgentTypes"],
      summary: "Create self-hosted agent type",
      description: "Create a self-hosted agent type",
      operationId: @operation_id,
      parameters: [],
      requestBody:
        Operation.request_body(
          "Self-hosted-agent type to be created",
          "application/json",
          Schemas.SelfHostedAgents.AgentType
        ),
      responses:
        Responses.with_errors(%{
          200 =>
            Operation.response(
              "Created self-hosted agent type",
              "application/json",
              Schemas.SelfHostedAgents.Agent
            )
        })
    }
  end

  def create(conn, _opts) do
    org_id = conn.assigns[:organization_id]
    user_id = conn.assigns[:user_id]

    conn.body_params
    |> Map.merge(%{organization_id: org_id, requester_id: user_id})
    |> SelfHostedHubClient.create()
    |> PublicAPI.Util.Response.respond(conn)
  end
end
