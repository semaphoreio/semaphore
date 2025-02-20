defmodule PublicAPI.Handlers.DeploymentTargets.Create do
  @moduledoc """
  Plug creates a deployment target.
  """

  alias InternalClients.DeploymentTargets, as: DTClient
  alias PublicAPI.Schemas

  import PublicAPI.Handlers.DeploymentTargets.Plugs.Common,
    only: [has_deployment_targets_enabled: 2, remove_sensitive_params: 2]

  import PublicAPI.Handlers.DeploymentTargets.Util.ErrorHandler

  use PublicAPI.SpecHelpers.Operation
  use Plug.Builder
  require Logger

  plug(:remove_sensitive_params)
  plug(:has_deployment_targets_enabled)

  @operation_id "DeploymentTargets.Create"
  plug(OpenApiSpex.Plug.CastAndValidate,
    json_render_error_v2: true,
    operation_id: @operation_id,
    render_error: PublicAPI.ErrorRenderer
  )

  plug(PublicAPI.Plugs.ProjectIdOrName)

  plug(PublicAPI.Plugs.AuditLogger, operation_id: @operation_id)

  plug(PublicAPI.Plugs.Authorization,
    permissions: ["project.deployment_targets.manage"]
  )

  plug(PublicAPI.Plugs.SecretsKey)

  plug(PublicAPI.Plugs.Metrics, tags: ["create", "deployment_targets"])
  plug(:create)

  def open_api_operation(_) do
    %Operation{
      tags: ["DeploymentTargets"],
      summary: "Create a project deployment targets",
      description: "Create a deployment target for the project.",
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
        )
      ],
      requestBody:
        Operation.request_body(
          "Deployment target to be created and a unique token.",
          "application/json",
          Schemas.DeploymentTargets.CreateRequest,
          required: true
        ),
      responses:
        Responses.with_errors(%{
          200 =>
            Operation.response(
              "Created deployment target",
              "application/json",
              Schemas.DeploymentTargets.DeploymentTarget
            )
        })
    }
  end

  def create(conn, _opts) do
    org_id = conn.assigns[:organization_id]
    user_id = conn.assigns[:user_id]

    conn.body_params
    |> Map.merge(%{
      user_id: user_id,
      organization_id: org_id,
      project_id: conn.assigns[:project_id],
      secrets_encryption_key: conn.private.secrets_key
    })
    |> DTClient.create()
    |> PublicAPI.Util.Response.respond(conn)
  rescue
    error ->
      conn |> handle_error(error, "creating")
  end
end
