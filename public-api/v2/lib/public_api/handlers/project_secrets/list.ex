defmodule PublicAPI.Handlers.ProjectSecrets.List do
  @moduledoc false
  require Logger

  alias InternalClients.Secrets, as: SecretsClient
  alias PublicAPI.Schemas

  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder
  import PublicAPI.Util.PlugContextHelper

  plug(PublicAPI.Plugs.FeatureFlag, feature: "project_level_secrets")

  @operation_id "ProjectSecrets.List"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.ProjectSecrets.ListResponse

  plug(PublicAPI.Plugs.ProjectIdOrName)

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["project.secrets.view"]
  )

  plug(PublicAPI.Plugs.Metrics, tags: ["list", "project_secrets"])
  plug(:list)
  plug(PublicAPI.Plugs.ObjectFilter)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["ProjectSecrets"],
      summary: "List project level secrets",
      description:
        "List all project level secrets in a project.
      If the response does not fit all the secrets refer to the link header to get next page url.",
      operationId: @operation_id,
      parameters:
        [
          Operation.parameter(
            :project_id_or_name,
            :path,
            %Schema{
              anyOf: [
                PublicAPI.Schemas.Common.id("Project"),
                PublicAPI.Schemas.Projects.Name.schema()
              ]
            },
            "Id or name of the project",
            required: true
          ),
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
      project_id: conn.assigns[:project_id],
      secret_level: :PROJECT
    })
    |> SecretsClient.list()
    |> add_field(:page_size, conn.params.page_size)
    |> set_response(conn)
  end

  defp add_field({:ok, map}, field, value), do: {:ok, Map.put(map, field, value)}
  defp add_field(err, _, _), do: err
end
