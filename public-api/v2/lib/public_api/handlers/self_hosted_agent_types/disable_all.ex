defmodule PublicAPI.Handlers.SelfHostedAgentTypes.DisableAll do
  @moduledoc """
  Plug which serves for disabling a self-hosted agent type
  """

  use Plug.Builder
  use PublicAPI.SpecHelpers.Operation

  import PublicAPI.Util.PlugContextHelper
  alias InternalClients.SelfHostedHub, as: SelfHostedHubClient
  alias PublicAPI.Schemas

  @operation_id "SelfHostedAgentTypes.DisableAll"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.SelfHostedAgents.DeleteResponse

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["organization.self_hosted_agents.manage"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["self_hosted_agent_type", "delete"])
  plug(PublicAPI.Handlers.SelfHostedAgentTypes.Loader)
  plug(PublicAPI.Plugs.ObjectFilter)
  plug(:disable_all)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["SelfHostedAgentTypes"],
      summary: "Disable agents for an agent type",
      description: "Disable agents for an agent type",
      operationId: @operation_id,
      parameters: [
        Operation.parameter(
          :agent_type_name,
          :path,
          %Schema{
            type: :string,
            description: "Name of the agent type"
          },
          "Name of the agent type to disable",
          required: true
        )
      ],
      requestBody:
        Operation.request_body(
          "Disable all or only idle agents for an agent type",
          "application/json",
          %Schema{
            title: "SelfHostedAgents.DisableAllRequest",
            type: :object,
            description: "Disable all self-hosted agents request",
            required: [],
            properties: %{
              only_idle: %Schema{
                type: :boolean,
                default: true,
                description:
                  "A boolean flag that controls whether all agents will be disabled or only idle agents. If set to `true` only idle agents are disabled.
                   By default, this is set to `true`"
              }
            }
          }
        ),
      responses:
        Responses.with_errors(%{
          200 =>
            Operation.response(
              "Self-hosted agents of the given type were disabled.",
              "application/json",
              @response_schema
            )
        })
    }
  end

  def disable_all(conn, _opts) do
    org_id = conn.assigns[:organization_id]

    conn.params
    |> Map.merge(%{organization_id: org_id, only_idle: Map.get(conn.body_params, :only_idle)})
    |> SelfHostedHubClient.disable_all()
    |> set_response(conn)
  end
end
