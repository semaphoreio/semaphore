defmodule PublicAPI.Handlers.Dashboards.List do
  @moduledoc false
  require Logger

  require OpenApiSpex
  alias InternalClients.Dashboards, as: DashboardsClient
  alias PublicAPI.Schemas

  import PublicAPI.Util.PlugContextHelper
  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder

  @operation_id "Dashboards.List"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema %OpenApiSpex.Schema{
    title: "Dashboards.ListResponse",
    type: :array,
    items: Schemas.Dashboards.Dashboard.schema()
  }

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["organization.dashboards.view"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["dashboards_list"])
  plug(:list)
  plug(PublicAPI.Plugs.ObjectFilter)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["Dashboards"],
      summary: "List organization level dashboards",
      description:
        "List all organization level dashboards.
      If the response does not fit all the dashboards refer to the link header to get next page url.",
      operationId: @operation_id,
      parameters:
        [
          Operation.parameter(
            :order,
            :query,
            %Schema{
              type: :string,
              enum: ~w(BY_NAME_ASC BY_CREATE_TIME_ASC),
              default: "BY_NAME_ASC"
            },
            "Ordering of the dashboards"
          )
        ] ++ Pagination.token_params(),
      responses:
        Responses.with_errors(%{
          200 =>
            Operation.response(
              "List of dashboards",
              "application/json",
              @response_schema,
              links: Pagination.token_links(@operation_id)
            )
        })
    }
  end

  def list(conn, _opts) do
    org_id = conn.assigns[:organization_id]
    org_name = conn.assigns[:organization_username]
    user_id = conn.assigns[:user_id]

    ctx = %{
      organization: %{
        id: org_id,
        name: org_name
      }
    }

    Map.merge(conn.params, %{
      organization_id: org_id,
      user_id: user_id
    })
    |> DashboardsClient.list()
    |> case do
      {:ok, response} ->
        response
        |> PublicAPI.Handlers.Dashboards.Formatter.list(ctx)
        |> add_field(:page_size, conn.params.page_size)
        |> set_response(conn)

      err ->
        Logger.error("Error listing dashboards: #{inspect(err)}")

        err
        |> set_response(conn)
    end
  end

  defp add_field({:ok, map}, field, value), do: {:ok, Map.put(map, field, value)}
end
