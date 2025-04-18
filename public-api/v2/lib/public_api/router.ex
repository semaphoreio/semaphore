defmodule PublicAPI.Router do
  use Plug.{Router, ErrorHandler}

  alias PublicAPI.Handlers.Workflows, as: Wfs
  alias PublicAPI.Handlers.Pipelines, as: Ppl
  alias PublicAPI.Handlers.Tasks, as: Tasks
  alias PublicAPI.Handlers.Secrets, as: Scr
  alias PublicAPI.Handlers.ProjectSecrets, as: PrScr
  alias PublicAPI.Handlers.SelfHostedAgentTypes, as: SHAgentTypes
  alias PublicAPI.Handlers.SelfHostedAgents, as: SHAgents
  alias PublicAPI.Handlers.Notifications, as: Ntf
  alias PublicAPI.Handlers.Projects, as: Projects
  alias PublicAPI.Handlers.Dashboards, as: Dash
  alias PublicAPI.Handlers.DeploymentTargets, as: DeploymentTargets
  alias PublicAPI.Handlers.Canvases, as: Canvases
  alias PublicAPI.Handlers.EventSources, as: EventSources
  alias PublicAPI.Handlers.Stages, as: Stages
  alias PublicAPI.Handlers.Spec

  plug(Plug.Logger)

  if Enum.member?([:dev, :test], Application.compile_env(:public_api, :environment)) do
    plug(Support.Plugs.DevelopmentHeaders)
  end

  plug(PublicAPI.Plugs.RequestAssigns)

  @no_feature_flag ["/health_check/ping", "/api-spec/openapi.json"]
  plug(PublicAPI.Plugs.FeatureFlag,
    feature: "public_api_v1",
    except: @no_feature_flag,
    message:
      "APIv2 is not enabled for your organization. Please contact support for more information."
  )

  plug(OpenApiSpex.Plug.PutApiSpec, module: PublicAPI.ApiSpec)

  plug(Plug.Parsers,
    parsers: [
      {:urlencoded, length: 8_000_000},
      {:multipart, length: 150_000_000},
      :json
    ],
    pass: ["*/*"],
    json_decoder: Poison
  )

  plug(:match)
  plug(:dispatch)

  # 200 OK in order to pass health checks made by Kubernetes
  get "/health_check/ping" do
    send_resp(conn, 200, "pong")
  end

  match("/api-spec/openapi.json", via: :get, to: Spec)

  match("/workflows", via: :get, to: Wfs.List)
  match("/workflows", via: :post, to: Wfs.Schedule)
  match("/workflows/:wf_id/terminate", via: :post, to: Wfs.Terminate)
  match("/workflows/:wf_id/reschedule", via: :post, to: Wfs.Reschedule)
  match("/workflows/:wf_id", via: :get, to: Wfs.Describe)

  match("/pipelines", via: :get, to: Ppl.List)
  match("/pipelines/:pipeline_id", via: :get, to: Ppl.Describe)
  match("/pipelines/:pipeline_id/terminate", via: :post, to: Ppl.Terminate)
  match("/pipelines/:pipeline_id/describe_topology", via: :get, to: Ppl.DescribeTopology)
  match("/pipelines/:pipeline_id/partial_rebuild", via: :post, to: Ppl.PartialRebuild)

  match("/projects/:project_id_or_name/tasks", via: :get, to: Tasks.List)
  match("/projects/:project_id_or_name/tasks", via: :post, to: Tasks.Create)
  match("/projects/:project_id_or_name/tasks/:task_id", via: :get, to: Tasks.Describe)
  match("/projects/:project_id_or_name/tasks/:task_id", via: :put, to: Tasks.Replace)
  match("/projects/:project_id_or_name/tasks/:task_id", via: :patch, to: Tasks.Update)
  match("/projects/:project_id_or_name/tasks/:task_id", via: :delete, to: Tasks.Delete)
  match("/projects/:project_id_or_name/tasks/:task_id/triggers", via: :post, to: Tasks.Trigger)

  match("/yaml", via: :post, to: Ppl.ValidateYaml)

  match("/secrets", via: :get, to: Scr.List)
  match("/secrets", via: :post, to: Scr.Create)
  match("/secrets/:id_or_name", via: :get, to: Scr.Describe)
  match("/secrets/:id_or_name", via: :delete, to: Scr.Delete)
  match("/secrets/:id_or_name", via: :put, to: Scr.Update)

  match("/projects/:project_id_or_name/secrets", via: :get, to: PrScr.List)
  match("/projects/:project_id_or_name/secrets", via: :post, to: PrScr.Create)
  match("/projects/:project_id_or_name/secrets/:id_or_name", via: :get, to: PrScr.Describe)
  match("/projects/:project_id_or_name/secrets/:id_or_name", via: :delete, to: PrScr.Delete)
  match("/projects/:project_id_or_name/secrets/:id_or_name", via: :put, to: PrScr.Update)

  match("/self_hosted_agent_types", via: :get, to: SHAgentTypes.List)
  match("/self_hosted_agent_types", via: :post, to: SHAgentTypes.Create)
  match("/self_hosted_agent_types/:agent_type_name", via: :put, to: SHAgentTypes.Update)
  match("/self_hosted_agent_types/:agent_type_name", via: :get, to: SHAgentTypes.Describe)
  match("/self_hosted_agent_types/:agent_type_name", via: :delete, to: SHAgentTypes.Delete)

  match("/self_hosted_agent_types/:agent_type_name/disable_all",
    via: :post,
    to: SHAgentTypes.DisableAll
  )

  match("/agents", via: :get, to: SHAgents.List)
  match("/agents/:agent_name", via: :get, to: SHAgents.Describe)

  match("/notifications", via: :get, to: Ntf.List)
  match("/notifications", via: :post, to: Ntf.Create)
  match("/notifications/:id_or_name", via: :get, to: Ntf.Describe)
  match("/notifications/:id_or_name", via: :delete, to: Ntf.Delete)
  match("/notifications/:id_or_name", via: :put, to: Ntf.Update)

  match("/projects", via: :get, to: Projects.List)
  match("/projects", via: :post, to: Projects.Create)
  match("/projects/:project_id_or_name", via: :get, to: Projects.Describe)
  match("/projects/:project_id_or_name", via: :put, to: Projects.Update)
  match("/projects/:project_id_or_name", via: :delete, to: Projects.Delete)

  match("dashboards", via: :get, to: Dash.List)
  match("dashboards", via: :post, to: Dash.Create)
  match("dashboards/:id_or_name", via: :get, to: Dash.Describe)
  match("dashboards/:id_or_name", via: :delete, to: Dash.Delete)
  match("dashboards/:id_or_name", via: :post, to: Dash.Update)

  match("/projects/:project_id_or_name/deployment_targets", via: :get, to: DeploymentTargets.List)

  match("/projects/:project_id_or_name/deployment_targets",
    via: :post,
    to: DeploymentTargets.Create
  )

  match("/projects/:project_id_or_name/deployment_targets/:id_or_name",
    via: :get,
    to: DeploymentTargets.Describe
  )

  match("/projects/:project_id_or_name/deployment_targets/:id_or_name",
    via: :delete,
    to: DeploymentTargets.Delete
  )

  match("/projects/:project_id_or_name/deployment_targets/:id_or_name",
    via: :patch,
    to: DeploymentTargets.Update
  )

  match("/projects/:project_id_or_name/deployment_targets/:id_or_name/history",
    via: :get,
    to: DeploymentTargets.History
  )

  match("/projects/:project_id_or_name/deployment_targets/:id_or_name/deactivate",
    via: :patch,
    to: DeploymentTargets.Cordon
  )

  match("/projects/:project_id_or_name/deployment_targets/:id_or_name/activate",
    via: :patch,
    to: DeploymentTargets.Uncordon
  )

  match("/canvases", via: :post, to: Canvases.Create)
  match("/canvases/:id_or_name", via: :get, to: Canvases.Describe)

  match("/canvases/:canvas_id_or_name/sources", via: :get, to: EventSources.List)
  # match("/canvases/:canvas_id_or_name/sources", via: :post, to: EventSources.Create)
  match("/canvases/:canvas_id_or_name/sources/:id_or_name", via: :get, to: EventSources.Describe)

  match("/canvases/:canvas_id_or_name/stages", via: :get, to: Stages.List)
  # match("/canvases/:canvas_id_or_name/stages", via: :post, to: Stages.Create)
  match("/canvases/:canvas_id_or_name/stages/:id_or_name", via: :get, to: Stages.Describe)

  match("/canvases/:canvas_id_or_name/stages/:id_or_name/events", via: :get, to: Stages.ListEvents)

  match("/canvases/:canvas_id_or_name/stages/:id_or_name/events/:id/approve",
    via: :get,
    to: Stages.ApproveEvent
  )

  # sobelow_skip ["XSS.SendResp"]
  def handle_errors(conn, %{kind: _kind, reason: reason, stack: _stack}) do
    case reason.__struct__ do
      Plug.Parsers.ParseError ->
        %{exception: %{message: message}} = reason
        send_resp(conn, conn.status, "Malformed request: " <> Plug.HTML.html_escape(message))

      ArgumentError ->
        send_resp(
          conn,
          conn.status,
          "Malformed request: " <> Plug.HTML.html_escape(reason.message)
        )

      _ ->
        require Logger
        Logger.warning("Error in handle_errors: #{inspect(reason)}")
        send_resp(conn, conn.status, "Something went wrong")
    end
  end

  match _ do
    body =
      %{message: "The requested path could not be found."}
      |> Jason.encode!()

    send_resp(conn, 404, body)
  end
end
