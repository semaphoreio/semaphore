defmodule PipelinesAPI.Router do
  use Plug.{Router, ErrorHandler}

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
  alias PipelinesAPI.Artifacts.List, as: ListArtifacts
  alias PipelinesAPI.Artifacts.GetSignedURL, as: GetArtifactSignedURL
  alias PipelinesAPI.TestResults.ListFlakyTests
  alias PipelinesAPI.TestResults.FlakyTestDetails
  alias PipelinesAPI.TestResults.FlakyTestDisruptions
  alias PipelinesAPI.TestResults.FlakyHistory
  alias PipelinesAPI.TestResults.DisruptionHistory
  alias PipelinesAPI.Insights.Performance, as: InsightsPerformance
  alias PipelinesAPI.Insights.Reliability, as: InsightsReliability
  alias PipelinesAPI.Insights.Frequency, as: InsightsFrequency
  alias PipelinesAPI.Members.List, as: ListMembers
  alias PipelinesAPI.Members.ListProject, as: ListProjectMembers
  alias PipelinesAPI.Roles.List, as: ListRoles
  alias PipelinesAPI.Roles.Describe, as: DescribeRole
  alias PipelinesAPI.Roles.Create, as: CreateRole
  alias PipelinesAPI.Roles.Update, as: UpdateRole
  alias PipelinesAPI.Roles.Destroy, as: DestroyRole
  alias PipelinesAPI.Permissions.List, as: ListPermissions
  alias PipelinesAPI.RoleAssignments.AssignOrg, as: AssignOrgRole
  alias PipelinesAPI.RoleAssignments.RetractOrg, as: RetractOrgRole
  alias PipelinesAPI.RoleAssignments.AssignProject, as: AssignProjectRole
  alias PipelinesAPI.RoleAssignments.RetractProject, as: RetractProjectRole
  alias PipelinesAPI.Groups.List, as: ListGroups
  alias PipelinesAPI.Groups.Create, as: CreateGroup
  alias PipelinesAPI.Groups.Modify, as: ModifyGroup
  alias PipelinesAPI.Groups.Destroy, as: DestroyGroup
  alias PipelinesAPI.ServiceAccounts.List, as: ListServiceAccounts
  alias PipelinesAPI.ServiceAccounts.Create, as: CreateServiceAccount
  alias PipelinesAPI.ServiceAccounts.Describe, as: DescribeServiceAccount
  alias PipelinesAPI.ServiceAccounts.Update, as: UpdateServiceAccount
  alias PipelinesAPI.ServiceAccounts.Destroy, as: DestroyServiceAccount
  alias PipelinesAPI.ServiceAccounts.Deactivate, as: DeactivateServiceAccount
  alias PipelinesAPI.ServiceAccounts.Reactivate, as: ReactivateServiceAccount
  alias PipelinesAPI.ServiceAccounts.RegenerateToken, as: RegenerateTokenServiceAccount

  plug(PipelinesAPI.Plug.Logger)
  plug(PipelinesAPI.Plug.ClientMetrics)

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

  match("/artifacts", via: :get, to: ListArtifacts)
  match("/artifacts/signed_url", via: :get, to: GetArtifactSignedURL)

  match("/projects/:project_id/test_results/flaky_tests", via: :get, to: ListFlakyTests)

  match("/projects/:project_id/test_results/flaky_tests/:test_id/disruptions",
    via: :get,
    to: FlakyTestDisruptions
  )

  match("/projects/:project_id/test_results/flaky_tests/:test_id",
    via: :get,
    to: FlakyTestDetails
  )

  match("/projects/:project_id/test_results/flaky_history", via: :get, to: FlakyHistory)

  match("/projects/:project_id/test_results/disruption_history",
    via: :get,
    to: DisruptionHistory
  )

  match("/projects/:project_id/insights/performance", via: :get, to: InsightsPerformance)
  match("/projects/:project_id/insights/reliability", via: :get, to: InsightsReliability)
  match("/projects/:project_id/insights/frequency", via: :get, to: InsightsFrequency)

  match("/members", via: :get, to: ListMembers)
  match("/members/:subject_id/roles", via: :post, to: AssignOrgRole)
  match("/members/:subject_id/roles", via: :delete, to: RetractOrgRole)
  match("/members/:subject_id/roles/:role_id", via: :delete, to: RetractOrgRole)

  match("/projects/:project_id/members", via: :get, to: ListProjectMembers)
  match("/projects/:project_id/members/:subject_id/roles", via: :post, to: AssignProjectRole)
  match("/projects/:project_id/members/:subject_id/roles", via: :delete, to: RetractProjectRole)

  match("/projects/:project_id/members/:subject_id/roles/:role_id",
    via: :delete,
    to: RetractProjectRole
  )

  match("/roles", via: :get, to: ListRoles)
  match("/roles", via: :post, to: CreateRole)
  match("/roles/:id", via: :get, to: DescribeRole)
  match("/roles/:id", via: :patch, to: UpdateRole)
  match("/roles/:id", via: :delete, to: DestroyRole)

  match("/permissions", via: :get, to: ListPermissions)

  match("/groups", via: :get, to: ListGroups)
  match("/groups", via: :post, to: CreateGroup)
  match("/groups/:id", via: :patch, to: ModifyGroup)
  match("/groups/:id", via: :delete, to: DestroyGroup)

  match("/service_accounts", via: :get, to: ListServiceAccounts)
  match("/service_accounts", via: :post, to: CreateServiceAccount)
  match("/service_accounts/:id", via: :get, to: DescribeServiceAccount)
  match("/service_accounts/:id", via: :patch, to: UpdateServiceAccount)
  match("/service_accounts/:id", via: :delete, to: DestroyServiceAccount)
  match("/service_accounts/:id/deactivate", via: :post, to: DeactivateServiceAccount)
  match("/service_accounts/:id/reactivate", via: :post, to: ReactivateServiceAccount)
  match("/service_accounts/:id/regenerate_token", via: :post, to: RegenerateTokenServiceAccount)

  match("/logs/:job_id", via: :get, to: PipelinesAPI.Logs.Get)

  get "/health_check/ping" do
    send_resp(conn, 200, "pong")
  end

  # sobelow_skip ["XSS.SendResp"]
  def handle_errors(conn, %{kind: _kind, reason: reason, stack: stack}) do
    require Logger
    Logger.error(inspect(stack))

    case reason.__struct__ do
      Plug.Parsers.ParseError ->
        %{exception: %{message: message}} = reason
        send_resp(conn, conn.status, "Malformed request: " <> Plug.HTML.html_escape(message))

      _ ->
        send_resp(conn, conn.status, "Something went wrong")
    end
  end

  # Root path has to return 200 OK in order to pass health checks made by ingress
  # on Kubernets
  get "/" do
    send_resp(conn, 200, "pong")
  end

  match _ do
    send_resp(conn, 404, "oops")
  end
end
