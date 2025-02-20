defmodule PublicAPI.Handlers.SelfHostedAgentTypes.Update do
  @moduledoc """
  Plug which serves for updating a self-hosted agent type
  """

  use Plug.Builder
  use PublicAPI.SpecHelpers.Operation

  import PublicAPI.Util.PlugContextHelper
  alias InternalClients.SelfHostedHub, as: SelfHostedHubClient
  alias PublicAPI.Schemas

  @operation_id "SelfHostedAgentTypes.Update"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.SelfHostedAgents.AgentType

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["organization.self_hosted_agents.manage"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["self_hosted_agent_type", "update"])
  plug(PublicAPI.Handlers.SelfHostedAgentTypes.Loader)
  plug(PublicAPI.Plugs.ObjectFilter)

  plug(:update)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["SelfHostedAgentTypes"],
      summary: "Update a self-hosted agent type",
      description: "Update a self-hosted agent type",
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
      requestBody:
        Operation.request_body(
          "Updated details of the self-hosted agent type.",
          "application/json",
          Schemas.SelfHostedAgents.AgentType
        ),
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

  def update(conn, _opts) do
    org_id = conn.assigns[:organization_id]
    user_id = conn.assigns[:user_id]

    conn.body_params
    |> Map.merge(%{
      organization_id: org_id,
      requester_id: user_id,
      agent_type_name: conn.params.agent_type_name
    })
    |> SelfHostedHubClient.update()
    |> set_response(conn)
  end
end
