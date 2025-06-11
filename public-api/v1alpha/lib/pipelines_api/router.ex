defmodule PipelinesAPI.Router do
  use Plug.{Router, ErrorHandler}

  import PipelinesAPI.Util.APIResponse

  alias PipelinesAPI.Pipelines.Terminate
  alias PipelinesAPI.Pipelines.DescribeTopology
  alias PipelinesAPI.Pipelines.PartialRebuild
  alias PipelinesAPI.Pipelines.ValidateYaml
  alias PipelinesAPI.Pipelines.Describe
  alias PipelinesAPI.Pipelines.List, as: PplList
  alias PipelinesAPI.Workflows.List, as: WfList
  alias PipelinesAPI.Workflows.Schedule, as: WfSchedule
  alias PipelinesAPI.Workflows.Terminate, as: WfTerminate
  alias PipelinesAPI.Workflows.Reschedule, as: WfReschedule
  alias PipelinesAPI.Workflows.Describe, as: WfDescribe
  alias PipelinesAPI.Promotions.Trigger, as: TriggerPromotion
  alias PipelinesAPI.Promotions.List, as: ListPromotions
  alias PipelinesAPI.Deployments.List, as: ListDeploymentTargets
  alias PipelinesAPI.Deployments.Create, as: CreateDeploymentTarget
  alias PipelinesAPI.Deployments.Update, as: UpdateDeploymentTarget
  alias PipelinesAPI.Deployments.Delete, as: DeleteDeploymentTarget
  alias PipelinesAPI.Deployments.Describe, as: DescribeDeploymentTarget
  alias PipelinesAPI.Deployments.History, as: HistoryDeployments
  alias PipelinesAPI.Deployments.Cordon, as: CordonDeploymentTarget
  alias PipelinesAPI.Deployments.Uncordon, as: UnCordonDeploymentTarget
  alias PipelinesAPI.RoleBindings.Delete, as: DeleteRoleBindings
  alias PipelinesAPI.Schedules.Apply, as: ApplySchedule
  alias PipelinesAPI.Schedules.Describe, as: DescribeSchedule
  alias PipelinesAPI.Schedules.Delete, as: DeleteSchedule
  alias PipelinesAPI.Schedules.List, as: ListSchedules
  alias PipelinesAPI.Schedules.RunNow, as: RunNowSchedule
  alias PipelinesAPI.SelfHostedAgentTypes.Create, as: CreateSHAgentType
  alias PipelinesAPI.SelfHostedAgentTypes.Update, as: UpdateSHAgentType
  alias PipelinesAPI.SelfHostedAgentTypes.Describe, as: DescribeSHAgentType
  alias PipelinesAPI.SelfHostedAgentTypes.DescribeAgent, as: DescribeSHAgent
  alias PipelinesAPI.SelfHostedAgentTypes.List, as: ListSHAgentTypes
  alias PipelinesAPI.SelfHostedAgentTypes.ListAgents, as: ListSHAgents
  alias PipelinesAPI.SelfHostedAgentTypes.Delete, as: DeleteSHAgentType
  alias PipelinesAPI.SelfHostedAgentTypes.DisableAll, as: DisableAllSHAgentType
  alias PipelinesAPI.Troubleshoot.Workflow, as: TroubleshootWorkflow
  alias PipelinesAPI.Troubleshoot.Pipeline, as: TroubleshootPipeline
  alias PipelinesAPI.Troubleshoot.Job, as: TroubleshootJob
  alias PipelinesAPI.ArtifactsRetentionPolicy.Update, as: UpdateArtifactsRetentionPolicy
  alias PipelinesAPI.ArtifactsRetentionPolicy.Describe, as: DescribeArtifactsRetentionPolicy

  plug(PipelinesAPI.Plug.Logger)

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

  match("/workflows", via: :get, to: WfList)

  match("/workflows", via: :post, to: WfSchedule)

  match("/workflows/:wf_id/terminate", via: :post, to: WfTerminate)

  match("/workflows/:wf_id/reschedule", via: :post, to: WfReschedule)

  match("/workflows/:wf_id", via: :get, to: WfDescribe)

  match("/pipelines", via: :get, to: PplList)

  match("/pipelines/:pipeline_id", via: :get, to: Describe)

  match("/pipelines/:pipeline_id", via: :patch, to: Terminate)

  match("/pipelines/:pipeline_id/describe_topology", via: :get, to: DescribeTopology)

  match("/pipelines/:pipeline_id/partial_rebuild", via: :post, to: PartialRebuild)

  match("/yaml", via: :post, to: ValidateYaml)

  match("/promotions", via: :post, to: TriggerPromotion)

  match("/promotions", via: :get, to: ListPromotions)

  match("/deployment_targets", via: :get, to: ListDeploymentTargets)

  match("/deployment_targets", via: :post, to: CreateDeploymentTarget)

  match("/deployment_targets/:target_id/history", via: :get, to: HistoryDeployments)

  match("/deployment_targets/:target_id/deactivate", via: :patch, to: CordonDeploymentTarget)

  match("/deployment_targets/:target_id/activate", via: :patch, to: UnCordonDeploymentTarget)

  match("/deployment_targets/:target_id", via: :get, to: DescribeDeploymentTarget)

  match("/deployment_targets/:target_id", via: :patch, to: UpdateDeploymentTarget)

  match("/deployment_targets/:target_id", via: :delete, to: DeleteDeploymentTarget)

  match("/role_bindings", via: :delete, to: DeleteRoleBindings)

  match("/schedules", via: :post, to: ApplySchedule)

  match("/schedules", via: :get, to: ListSchedules)

  match("/schedules/:identifier", via: :get, to: DescribeSchedule)

  match("/schedules/:identifier", via: :delete, to: DeleteSchedule)

  match("/schedules/:identifier/run_now", via: :post, to: RunNowSchedule)

  match("/tasks", via: :post, to: ApplySchedule)

  match("/tasks", via: :get, to: ListSchedules)

  match("/tasks/:identifier", via: :get, to: DescribeSchedule)

  match("/tasks/:identifier", via: :delete, to: DeleteSchedule)

  match("/tasks/:identifier/run_now", via: :post, to: RunNowSchedule)

  match("/self_hosted_agent_types", via: :post, to: CreateSHAgentType)

  match("/self_hosted_agent_types/:agent_type_name", via: :patch, to: UpdateSHAgentType)

  match("/self_hosted_agent_types", via: :get, to: ListSHAgentTypes)

  match("/self_hosted_agent_types/:agent_type_name", via: :get, to: DescribeSHAgentType)

  match("/self_hosted_agent_types/:agent_type_name", via: :delete, to: DeleteSHAgentType)

  match("/self_hosted_agent_types/:agent_type_name/disable_all",
    via: :post,
    to: DisableAllSHAgentType
  )

  match("/agents", via: :get, to: ListSHAgents)

  match("/agents/:agent_name", via: :get, to: DescribeSHAgent)

  match("/troubleshoot/workflow/:wf_id", via: :get, to: TroubleshootWorkflow)

  match("/troubleshoot/pipeline/:pipeline_id", via: :get, to: TroubleshootPipeline)

  match("/troubleshoot/job/:job_id", via: :get, to: TroubleshootJob)

  match("/artifacts_retention_policies", via: :post, to: UpdateArtifactsRetentionPolicy)

  match("/artifacts_retention_policies/:project_id",
    via: :get,
    to: DescribeArtifactsRetentionPolicy
  )

  match("/logs/:job_id", via: :get, to: PipelinesAPI.Logs.Get)

  get "/health_check/ping" do
    text(conn, "pong")
  end

  # sobelow_skip ["XSS.SendResp"]
  def handle_errors(conn, %{kind: _kind, reason: reason, stack: stack}) do
    require Logger
    Logger.error(inspect(stack))

    case reason.__struct__ do
      Plug.Parsers.ParseError ->
        %{exception: %{message: message}} = reason

        conn
        |> put_status(conn.status)
        |> text("Malformed request: " <> Plug.HTML.html_escape(message))

      _ ->
        conn
        |> put_status(conn.status)
        |> text("Something went wrong")
    end
  end

  # Root path has to return 200 OK in order to pass health checks made by ingress
  # on Kubernets
  get "/" do
    text(conn, "pong")
  end

  match _ do
    conn
    |> put_status(404)
    |> text("oops")
  end
end
