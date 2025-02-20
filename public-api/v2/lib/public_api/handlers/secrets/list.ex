defmodule PublicAPI.Handlers.Secrets.List do
  @moduledoc false
  require Logger

  alias InternalClients.Secrets, as: SecretsClient
  alias PublicAPI.Schemas

  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder
  import PublicAPI.Util.PlugContextHelper

  @operation_id "Secrets.List"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.Secrets.ListResponse

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["organization.secrets.view"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["secrets_list"])
  plug(:list)
  plug(PublicAPI.Plugs.ObjectFilter)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["Secrets"],
      summary: "List organization level secrets",
      description:
        "List all organization level secrets.
      If the response does not fit all the secrets refer to the link header to get next page url.",
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
            "Ordering of the secrets"
          )
        ] ++ Pagination.token_params(),
      responses:
        Responses.with_errors(%{
          200 =>
            Operation.response(
              "List of secrets",
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
      user_id: user_id,
      secret_level: :ORGANIZATION
    })
    |> SecretsClient.list()
    |> add_field(:page_size, conn.params.page_size)
    |> set_response(conn)
  end

  defp add_field({:ok, map}, field, value), do: {:ok, Map.put(map, field, value)}
  defp add_field(err, _, _), do: err
end
