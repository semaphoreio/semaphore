defmodule PublicAPI.Handlers.SelfHostedAgents.List do
  @moduledoc """
  Plug which serves for listing registered self-hosted agents
  """

  use Plug.Builder
  use PublicAPI.SpecHelpers.Operation

  import PublicAPI.Util.PlugContextHelper
  alias InternalClients.SelfHostedHub, as: SelfHostedHubClient
  alias PublicAPI.Schemas

  @operation_id "SelfHostedAgents.List"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.SelfHostedAgents.ListAgentsResponse

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["organization.self_hosted_agents.view"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["self_hosted_agents", "list"])

  plug(:list)
  plug(PublicAPI.Plugs.ObjectFilter)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["SelfHostedAgents"],
      summary: "List registered self-hosted agents",
      description: "List all registered self-hosted agents. Optionally filter by agent type.",
      operationId: @operation_id,
      parameters:
        [
          Operation.parameter(
            :agent_type,
            :query,
            %Schema{
              type: :string,
              description: "Name of the agent type"
            },
            "The name of the agent type to filter for. If not specified, agents for all agent types will be returned."
          )
        ] ++ Pagination.token_params(),
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

  def list(conn, _opts) do
    org_id = conn.assigns[:organization_id]

    conn.params
    |> Map.merge(%{organization_id: org_id})
    |> SelfHostedHubClient.list_agents()
    |> add_page_size(conn.params.page_size)
    |> set_response(conn)
  end

  defp add_page_size({:ok, resp}, page_size) do
    {:ok, Map.put(resp, :page_size, page_size)}
  end

  defp add_page_size(error = _, _page_size), do: error
end
