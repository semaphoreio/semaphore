defmodule PublicAPI.Handlers.SelfHostedAgentTypes.Delete do
  @moduledoc """
  Plug which serves for deleting a self-hosted agent type
  """

  use Plug.Builder
  use PublicAPI.SpecHelpers.Operation

  import PublicAPI.Util.PlugContextHelper
  alias InternalClients.SelfHostedHub, as: SelfHostedHubClient
  alias PublicAPI.Schemas

  @operation_id "SelfHostedAgentTypes.Delete"
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
  plug(:delete)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["SelfHostedAgentTypes"],
      summary: "Delete self-hosted agent type",
      description: "Delete a self-hosted agent type",
      operationId: @operation_id,
      parameters: [
        Operation.parameter(
          :agent_type_name,
          :path,
          %Schema{
            type: :string,
            description: "Name of the agent type"
          },
          "Name of the agent type to delete",
          required: true
        )
      ],
      responses:
        Responses.with_errors(%{
          200 =>
            Operation.response(
              "Message containing confirmation for deleted self-hosted agent type",
              "application/json",
              @response_schema
            )
        })
    }
  end

  def delete(conn, _opts) do
    org_id = conn.assigns[:organization_id]

    conn.params
    |> Map.merge(%{organization_id: org_id})
    |> SelfHostedHubClient.delete()
    |> set_response(conn)
  end
end
