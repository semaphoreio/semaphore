defmodule PublicAPI.Handlers.Projects.List do
  @moduledoc false
  require Logger

  alias InternalClients.Projecthub, as: ProjectsClient
  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder
  import PublicAPI.Util.PlugContextHelper

  @operation_id "Projects.List"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.Projects.ListResponse

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["organization.view"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["projects_list"])
  plug(:list)
  plug(PublicAPI.Plugs.ObjectFilter)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["Projects"],
      summary: "List projects",
      description: "List projects in organization.",
      operationId: @operation_id,
      parameters:
        [
          Operation.parameter(
            :owner_uuid,
            :query,
            %Schema{type: :string, format: :uuid},
            "UUID of the project owner",
            example: UUID.uuid4()
          ),
          Operation.parameter(
            :repo_url,
            :query,
            %Schema{type: :string},
            "URL of the repository the project is associated with",
            example: "git@github.com:semaphoreci/toolbox.git"
          ),
          Operation.parameter(
            :direction,
            :query,
            %Schema{type: :string, enum: ~w(NEXT PREVIOUS), default: "NEXT"},
            "Direction of the pagination.
            `NEXT` will fetch projects after the provided token, `PREVIOUS` will fetch projects before the provided token"
          )
        ] ++ Pagination.token_params(),
      responses:
        Responses.with_errors(%{
          200 =>
            Operation.response(
              "List of projects in organization",
              "application/json",
              @response_schema,
              links: Pagination.token_links(@operation_id)
            )
        })
    }
  end

  def list(conn, _opts) do
    org_id = conn.assigns[:organization_id]
    user_id = conn.assigns[:user_id]

    Map.merge(conn.params, %{
      organization_id: org_id,
      user_id: user_id
    })
    |> ProjectsClient.list()
    |> add_page_size(conn.params.page_size)
    |> set_response(conn)
  end

  defp add_page_size({:ok, response}, page_size),
    do: {:ok, Map.put(response, :page_size, page_size)}

  defp add_page_size(e, _), do: e
end
