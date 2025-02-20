defmodule PublicAPI.Handlers.DeploymentTargets.Update do
  @moduledoc """
  Plug updates a deployment target.
  """

  alias InternalClients.DeploymentTargets, as: DTClient
  alias PublicAPI.Schemas

  import PublicAPI.Handlers.DeploymentTargets.Plugs.Common,
    only: [has_deployment_targets_enabled: 2, remove_sensitive_params: 2]

  import PublicAPI.Handlers.DeploymentTargets.Util.ErrorHandler

  import PublicAPI.Util.PlugContextHelper

  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder
  require Logger

  plug(:remove_sensitive_params)
  plug(:has_deployment_targets_enabled)

  @operation_id "DeploymentTargets.Update"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  @response_schema Schemas.DeploymentTargets.DeploymentTarget

  plug(PublicAPI.Plugs.ProjectIdOrName)

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["project.deployment_targets.manage"]
  )

  plug(PublicAPI.Plugs.SecretsKey)

  plug(PublicAPI.Plugs.Metrics, tags: ["update", "deployment_targets"])
  plug(PublicAPI.Handlers.DeploymentTargets.Plugs.Loader)
  plug(PublicAPI.Plugs.ObjectFilter)
  plug(:update)

  plug(PublicAPI.Plugs.Respond,
    schema: @response_schema
  )

  def open_api_operation(_) do
    %Operation{
      tags: ["DeploymentTargets"],
      summary: "Update a project deployment target",
      description:
        "Update a deployment target for the project. Fields that are not provided will not be updated.",
      operationId: @operation_id,
      parameters: [
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
          :id_or_name,
          :path,
          %Schema{
            type: :string,
            description: "Id or name of the deployment target"
          },
          "Id or name of the deployment target",
          required: true
        )
      ],
      requestBody:
        Operation.request_body(
          "Deployment target to be updated and a unique token.",
          "application/json",
          Schemas.DeploymentTargets.UpdateRequest,
          required: true
        ),
      responses:
        Responses.with_errors(%{
          200 =>
            Operation.response(
              "Updated deployment target",
              "application/json",
              @response_schema
            )
        })
    }
  end

  def update(conn, _opts) do
    org_id = conn.assigns[:organization_id]
    user_id = conn.assigns[:user_id]

    conn
    |> get_resource()
    |> case do
      {:ok, old_target} ->
        %{
          new_target: conn.body_params.deployment_target,
          unique_token: conn.body_params.unique_token,
          old_target: old_target,
          deployment_target_id: old_target.metadata.id,
          user_id: user_id,
          organization_id: org_id,
          project_id: conn.assigns[:project_id],
          secrets_encryption_key: conn.private.secrets_key
        }
        |> DTClient.update()
        |> set_response(conn)

      error ->
        Logger.debug("Error updating deployment target: #{inspect(error)}")

        error
        |> PublicAPI.Util.Response.respond(conn)
        |> Plug.Conn.halt()
    end
  rescue
    error ->
      conn |> handle_error(error, "updating")
  end
end
