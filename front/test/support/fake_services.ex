defmodule Support.FakeServices do
  @moduledoc false

  alias InternalApi.Plumber.DescribeTopologyResponse
  alias Support.Factories
  alias Support.FakeServices, as: FS

  def start_fake_grpc_servers do
    init()
    stub_responses()
  end

  def init do
    GrpcMock.defmock(ArtifacthubMock, for: InternalApi.Artifacthub.ArtifactService.Service)
    GrpcMock.defmock(AuditMock, for: InternalApi.Audit.AuditService.Service)
    GrpcMock.defmock(BillingMock, for: InternalApi.Billing.BillingService.Service)
    GrpcMock.defmock(GoferMock, for: InternalApi.Gofer.Switch.Service)
    GrpcMock.defmock(InternalJobMock, for: InternalApi.ServerFarm.Job.JobService.Service)
    GrpcMock.defmock(PipelineMock, for: InternalApi.Plumber.PipelineService.Service)
    GrpcMock.defmock(PublicJobMock, for: Semaphore.Jobs.V1alpha.JobsApi.Service)
    GrpcMock.defmock(SchedulerMock, for: InternalApi.PeriodicScheduler.PeriodicService.Service)
    GrpcMock.defmock(RepositoryMock, for: InternalApi.Repository.RepositoryService.Service)
    GrpcMock.defmock(SelfHostedAgentsMock, for: InternalApi.SelfHosted.SelfHostedAgents.Service)
    GrpcMock.defmock(GuardMock, for: InternalApi.Guard.Guard.Service)
    GrpcMock.defmock(RBACMock, for: InternalApi.RBAC.RBAC.Service)
    GrpcMock.defmock(GroupsMock, for: InternalApi.Groups.Groups.Service)

    GrpcMock.defmock(PermissionPatrolMock,
      for: InternalApi.PermissionPatrol.PermissionPatrol.Service
    )

    GrpcMock.defmock(RepositoryIntegratorMock,
      for: InternalApi.RepositoryIntegrator.RepositoryIntegratorService.Service
    )

    GrpcMock.defmock(TaskMock, for: InternalApi.Task.TaskService.Service)
    GrpcMock.defmock(WorkflowMock, for: InternalApi.PlumberWF.WorkflowService.Service)
    GrpcMock.defmock(OrganizationMock, for: InternalApi.Organization.OrganizationService.Service)
    GrpcMock.defmock(BranchMock, for: InternalApi.Branch.BranchService.Service)
    GrpcMock.defmock(ProjecthubMock, for: InternalApi.Projecthub.ProjectService.Service)
    GrpcMock.defmock(UserMock, for: InternalApi.User.UserService.Service)
    GrpcMock.defmock(SecretMock, for: InternalApi.Secrethub.SecretService.Service)

    GrpcMock.defmock(InstanceConfigMock,
      for: InternalApi.InstanceConfig.InstanceConfigService.Service
    )

    GrpcMock.defmock(NotificationMock,
      for: Semaphore.Notifications.V1alpha.NotificationsApi.Service
    )

    GrpcMock.defmock(DashboardMock,
      for: Semaphore.Dashboards.V1alpha.DashboardsApi.Service
    )

    GrpcMock.defmock(PipelineMetricsMock,
      for: InternalApi.Velocity.PipelineMetricsService.Service
    )

    GrpcMock.defmock(SuperjerryMock,
      for: InternalApi.Superjerry.Superjerry.Service
    )

    GrpcMock.defmock(ScouterMock,
      for: InternalApi.Scouter.ScouterService.Service
    )

    GrpcMock.defmock(PreFlightChecksMock,
      for: InternalApi.PreFlightChecksHub.PreFlightChecksService.Service
    )

    GrpcMock.defmock(DeploymentsMock,
      for: InternalApi.Gofer.DeploymentTargets.DeploymentTargets.Service
    )

    GrpcMock.defmock(OktaMock,
      for: InternalApi.Okta.Okta.Service
    )

    GrpcMock.defmock(FeatureMock, for: InternalApi.Feature.FeatureService.Service)
    GrpcMock.defmock(UsageMock, for: InternalApi.Usage.UsageService.Service)

    excluded_stubs =
      System.get_env("EXCLUDE_STUBS", "")
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(&String.to_atom/1)

    services =
      [
        ArtifacthubMock,
        AuditMock,
        BillingMock,
        GoferMock,
        InternalJobMock,
        PipelineMock,
        PublicJobMock,
        SchedulerMock,
        RepositoryIntegratorMock,
        RepositoryMock,
        TaskMock,
        WorkflowMock,
        OrganizationMock,
        BranchMock,
        ProjecthubMock,
        UserMock,
        SelfHostedAgentsMock,
        GuardMock,
        RBACMock,
        GroupsMock,
        PermissionPatrolMock,
        SecretMock,
        NotificationMock,
        DashboardMock,
        PipelineMetricsMock,
        PreFlightChecksMock,
        OktaMock,
        FeatureMock,
        DeploymentsMock,
        UsageMock,
        InstanceConfigMock,
        SuperjerryMock,
        ScouterMock
      ]
      |> Enum.reject(&Enum.member?(excluded_stubs, &1))

    spawn(fn ->
      GRPC.Server.start(services, 50_052)
    end)

    {:ok, _} = FunRegistry.start()

    services = [
      FS.RepoProxyService,
      FS.Loghub
    ]

    spawn(fn ->
      GRPC.Server.start(services, 50_051)
    end)
  end

  defp project_destroy_response do
    InternalApi.Projecthub.DestroyResponse.new(
      metadata:
        InternalApi.Projecthub.ResponseMeta.new(
          status:
            InternalApi.Projecthub.ResponseMeta.Status.new(
              code: InternalApi.Projecthub.ResponseMeta.Code.value(:OK)
            )
        )
    )
  end

  def stub_responses do
    organization_update_response =
      InternalApi.Organization.UpdateResponse.new(
        status: Google.Rpc.Status.new(code: Google.Rpc.Code.value(:OK)),
        organization: Support.Factories.organization()
      )

    organization_destroy_response = Google.Protobuf.Empty.new()

    guard_refresh_response =
      InternalApi.Guard.RefreshResponse.new(status: Support.Factories.status_ok())

    projecthub_check_webhook_ok_response =
      InternalApi.Projecthub.CheckWebhookResponse.new(
        metadata: Support.Factories.response_meta(),
        webhook:
          InternalApi.Projecthub.Webhook.new(
            url: "https://semaphoreci.com/f7dbf4bd-91f0-47ab-93ee-b27d5994dcf2"
          )
      )

    projecthub_regenerate_webhook_ok_response =
      InternalApi.Projecthub.RegenerateWebhookResponse.new(
        metadata: Support.Factories.response_meta(),
        webhook:
          InternalApi.Projecthub.Webhook.new(
            url: "https://semaphoreci.com/f7dbf4bd-91f0-47ab-93ee-b27d5994dcf2"
          )
      )

    projecthub_check_deploy_key_ok_response =
      InternalApi.Projecthub.CheckDeployKeyResponse.new(
        metadata: Support.Factories.response_meta(),
        deploy_key:
          InternalApi.Projecthub.CheckDeployKeyResponse.DeployKey.new(
            title: "semaphore-renderedtext-guard",
            fingerprint: "SHA256:OpCrpdiCJsjelCRPNnb0oo9EXEGbluYP9c1bUVMBUo0",
            created_at: Google.Protobuf.Timestamp.new(seconds: 1_522_495_543)
          )
      )

    projecthub_regenerate_deploy_key_ok_response =
      InternalApi.Projecthub.RegenerateDeployKeyResponse.new(
        metadata: Support.Factories.response_meta(),
        deploy_key:
          InternalApi.Projecthub.RegenerateDeployKeyResponse.DeployKey.new(
            title: "semaphore-renderedtext-guard",
            fingerprint: "SHA256:OpCrpdiCJsjelCRPNnb0oo9EXEGbluYP9c1bUVMBUo0",
            created_at: Google.Protobuf.Timestamp.new(seconds: 1_522_495_543)
          )
      )

    projects =
      Enum.map(1..300, fn i ->
        Support.Factories.listed_project(id: Ecto.UUID.generate(), name: "Project #{i}")
      end)

    project_list_response =
      InternalApi.Projecthub.ListResponse.new(
        metadata: Support.Factories.response_meta(:OK),
        projects: projects,
        pagination:
          InternalApi.Projecthub.PaginationResponse.new(
            total_pages: 1,
            total_entries: 300
          )
      )

    project_users = [
      Support.Factories.user(id: "1"),
      Support.Factories.user(id: "2", name: "Sim One", github_login: "simone"),
      Support.Factories.user(id: "3", name: "Bob", github_login: "bob"),
      Support.Factories.user(id: "4", name: "Alice", github_login: "alice"),
      Support.Factories.user(id: "78114608-be8a-465a-b9cd-81970fb802c7")
    ]

    project_users_response =
      InternalApi.Projecthub.UsersResponse.new(
        metadata: Support.Factories.response_meta(:OK),
        users: project_users
      )

    project_create_response =
      InternalApi.Projecthub.CreateResponse.new(
        project: Support.Factories.projecthub_api_described_project(),
        metadata:
          InternalApi.Projecthub.ResponseMeta.new(
            status:
              InternalApi.Projecthub.ResponseMeta.Status.new(
                code: InternalApi.Projecthub.ResponseMeta.Code.value(:OK)
              )
          )
      )

    project_fork_and_create_response =
      InternalApi.Projecthub.ForkAndCreateResponse.new(
        project: Support.Factories.projecthub_api_described_project(),
        metadata:
          InternalApi.Projecthub.ResponseMeta.new(
            status:
              InternalApi.Projecthub.ResponseMeta.Status.new(
                code: InternalApi.Projecthub.ResponseMeta.Code.value(:OK)
              )
          )
      )

    project_update_response =
      InternalApi.Projecthub.UpdateResponse.new(
        project: Support.Factories.projecthub_api_described_project(),
        metadata:
          InternalApi.Projecthub.ResponseMeta.new(
            status:
              InternalApi.Projecthub.ResponseMeta.Status.new(
                code: InternalApi.Projecthub.ResponseMeta.Code.value(:OK)
              )
          )
      )

    organization_describe_response =
      InternalApi.Organization.DescribeResponse.new(
        status: Support.Factories.status_ok(),
        organization: Support.Factories.organization()
      )

    list_suspensions_response =
      InternalApi.Organization.ListSuspensionsResponse.new(
        status: Google.Rpc.Status.new(code: Google.Rpc.Code.value(:OK)),
        suspensions: []
      )

    organization_members_response =
      InternalApi.Organization.MembersResponse.new(
        status: Support.Factories.status_ok(),
        members: [
          Support.Factories.member(
            invited_at: Google.Protobuf.Timestamp.new(seconds: 1_522_754_266),
            user_id: "391db4f5-1661-49f7-a4d8-d31da77c2f33"
          ),
          Support.Factories.member(
            user_id: "454614ec-5b5f-47b7-b3b0-4553584e305a",
            screen_name: "pera",
            github_username: "pera",
            avatar_url: "https://avatars0.githubusercontent.com/u/338659?s=460&v=4",
            invited_at: Google.Protobuf.Timestamp.new(seconds: 1_522_754_270)
          ),
          Support.Factories.member(
            user_id: "e65c4c48-2bb8-4d20-8000-3cbee1e58d89",
            screen_name: "mika",
            github_username: "mika",
            avatar_url: "https://avatars2.githubusercontent.com/u/115592?s=460&v=4",
            role: InternalApi.Organization.Member.Role.value(:OWNER)
          )
        ],
        not_logged_in_members: [
          Support.Factories.member(
            github_uid: "9396752",
            github_username: "bmarkons",
            screen_name: "bmarkons",
            avatar_url: "https://avatars2.githubusercontent.com/u/9396752?s=460&v=4"
          ),
          Support.Factories.member(
            github_uid: "184065",
            github_username: "radwo",
            screen_name: "radwo",
            avatar_url: "https://avatars2.githubusercontent.com/u/184065?s=460&v=4"
          ),
          Support.Factories.member(
            github_uid: "20469",
            github_username: "darkofabijan",
            screen_name: "darkofabijan",
            avatar_url: "https://avatars2.githubusercontent.com/u/20469?s=460&v=4"
          ),
          Support.Factories.member(
            github_uid: "8651",
            github_username: "markoa",
            screen_name: "markoa",
            avatar_url: "https://avatars2.githubusercontent.com/u/8651?s=460&v=4"
          )
        ]
      )

    organization_list_response =
      InternalApi.Organization.ListResponse.new(
        status: Support.Factories.status_ok(),
        organizations: Support.Factories.organizations()
      )

    add_members_response =
      InternalApi.Organization.AddMembersResponse.new(members: [Support.Factories.member()])

    add_member_response =
      InternalApi.Organization.AddMemberResponse.new(
        status: Google.Rpc.Status.new(code: Google.Rpc.Code.value(:OK)),
        member: Support.Factories.member()
      )

    delete_member_response =
      InternalApi.Organization.DeleteMemberResponse.new(
        status: Google.Rpc.Status.new(code: Google.Rpc.Code.value(:OK))
      )

    branch_response =
      InternalApi.Branch.DescribeResponse.new(
        status: Support.Factories.status_ok(),
        branch_id: "06278ef7-dcde-4d87-b405-ca39fb5f9827",
        branch_name: "master",
        project_id: "342841b2-11ff-4380-a215-2b038e07d8d7",
        repo_host_url: "https://github.com/renderedtext/front",
        tag_name: "v1.2.3",
        type: InternalApi.Branch.Branch.Type.value(:TAG),
        display_name: "v1.2.3"
      )

    branches = Enum.map(1..6, fn _ -> Support.Factories.branch() end)

    branch_list_response =
      InternalApi.Branch.ListResponse.new(
        status: Support.Factories.status_ok(),
        branches: branches,
        page_number: 1,
        page_size: 10,
        total_entries: 12,
        total_pages: 30
      )

    branch_filter_response =
      InternalApi.Branch.FilterResponse.new(
        branches: [Support.Factories.branch()],
        pull_requests: [
          Support.Factories.branch(
            id: "78114608-be8a-465a-b9cd-81970fb802c7",
            name: "master PR"
          ),
          Support.Factories.branch(
            id: "78114608-be8a-465a-b9cd-81970fb802c7",
            name: "new-design-2020-01-backup-13.07"
          )
        ],
        page_number: 1,
        page_size: 10,
        total_entries: 12,
        total_pages: 30
      )

    repo_proxy_describe_many_response =
      InternalApi.RepoProxy.DescribeManyResponse.new(
        status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
        hooks: [
          InternalApi.RepoProxy.Hook.new(
            hook_id: "2cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
            head_commit_sha: "474488cb82e4784b8de8a91d3e58ed188fea4dbd",
            commit_message: "Pull new workflows on the branch page",
            repo_host_url: "",
            semaphore_email: "",
            repo_host_username: "jane",
            repo_host_email: "",
            user_id: "",
            repo_host_avatar_url: "https://avatars3.githubusercontent.com/u/0?v=4",
            branch_name: "master",
            tag_name: "v1.2.3",
            pr_name: "Update README.md",
            pr_branch_name: "master",
            pr_number: "5",
            git_ref_type: InternalApi.RepoProxy.Hook.Type.value(:TAG)
          ),
          InternalApi.RepoProxy.Hook.new(
            hook_id: "4ab71575-2bcb-4fdb-9248-d922d1670719",
            head_commit_sha: "0b9995d5de71603dc2793d07914f0de16873159c",
            commit_message: "dummy pr",
            repo_host_url: "https://github.com/renderedtext/vampyri-bot",
            repo_host_username: "octocat",
            repo_host_avatar_url: "https://avatars3.githubusercontent.com/u/0?v=4",
            pr_name: "dummy pr",
            pr_number: "8",
            git_ref_type: :PR,
            branch_name: "master",
            repo_slug: "renderedtext/vampyri-bot",
            pr_slug: "renderedtext/vampyri-bot",
            pr_sha: "6b962d30e851eeaaa344c08ab5fc1a849d4fa892",
            git_ref: "refs/semaphoreci/0b9995d5de71603dc2793d07914f0de16873159c",
            pr_mergeable: true,
            pr_branch_name: "ms/branch-with-pr",
            commit_author: "octocat",
            git_ref_type: InternalApi.RepoProxy.Hook.Type.value(:PR)
          )
        ]
      )

    repo_proxy_describe_response =
      InternalApi.RepoProxy.DescribeResponse.new(
        status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
        hook:
          InternalApi.RepoProxy.Hook.new(
            hook_id: "2cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
            head_commit_sha: "garbble",
            commit_message: "Fix indentation",
            repo_host_url: "url",
            semaphore_email: "",
            repo_host_username: "jane",
            repo_host_email: "",
            user_id: "",
            repo_host_avatar_url: "https://avatars3.githubusercontent.com/u/0?v=4",
            branch_name: "master",
            tag_name: "v1.2.3",
            pr_name: "Update README.md",
            pr_number: "5",
            pr_branch_name: "master",
            git_ref_type: InternalApi.RepoProxy.Hook.Type.value(:TAG)
          )
      )

    repo_proxy_create_response =
      InternalApi.RepoProxy.CreateResponse.new(
        hook_id: "2cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
        workflow_id: "2cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
        pipeline_id: "2cb61a21-c759-4d50-a45a-1e1eaba8c1bf"
      )

    repo_proxy_schedule_blocked_hook_response =
      InternalApi.RepoProxy.ScheduleBlockedHookResponse.new(
        status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
        wf_id: "2cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
        ppl_id: "2cb61a21-c759-4d50-a45a-1e1eaba8c1bf"
      )

    workflow1 =
      Support.Factories.workflow(
        wf_id: "3cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
        hook_id: Enum.at(repo_proxy_describe_many_response.hooks, 0).hook_id
      )

    workflow2 =
      Support.Factories.workflow(
        wf_id: "4cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
        hook_id: Enum.at(repo_proxy_describe_many_response.hooks, 1).hook_id
      )

    workflow_describe_response =
      InternalApi.PlumberWF.DescribeResponse.new(
        workflow: workflow1,
        status: Support.Factories.internal_api_status_ok()
      )

    workflow_list_response =
      InternalApi.PlumberWF.ListResponse.new(
        workflows: [workflow1, workflow2],
        status: Support.Factories.internal_api_status_ok(),
        page_number: 1,
        total_pages: 1
      )

    workflow_list_grouped_response =
      InternalApi.PlumberWF.ListGroupedResponse.new(
        workflows: [workflow1],
        status: Support.Factories.internal_api_status_ok(),
        page_number: 1,
        total_pages: 1
      )

    workflow_get_path_response =
      InternalApi.PlumberWF.GetPathResponse.new(
        wf_id: "3cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
        wf_created_at: Google.Protobuf.Timestamp.new(seconds: 1_580_654_045),
        path: [
          InternalApi.PlumberWF.GetPathResponse.PathElement.new(
            ppl_id: "3cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
            switch_id: "3cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
            rebuild_partition: [""]
          )
        ],
        status: Support.Factories.internal_api_status_ok()
      )

    pipeline =
      Support.Factories.Pipeline.pipeline(
        wf_id: workflow1.wf_id,
        hook_id: Enum.at(repo_proxy_describe_many_response.hooks, 0).hook_id
      )

    pipeline2 = Support.Factories.Pipeline.finished_pipeline()

    end_date = Timex.today()
    start_date = Timex.shift(end_date, days: -10)

    pipelines =
      if System.get_env("RANDOM_PIPELINES") == "true" do
        Date.range(start_date, end_date)
        |> Enum.map(fn date ->
          start_time = date |> Timex.to_datetime() |> Timex.to_unix()
          end_time = date |> Timex.to_datetime() |> Timex.end_of_day() |> Timex.to_unix()

          Enum.take_random(start_time..end_time, Enum.random(0..3))
          |> Enum.map(fn d ->
            [
              done_at: Google.Protobuf.Timestamp.new(seconds: d + Enum.random(69..220)),
              running_at: Google.Protobuf.Timestamp.new(seconds: d),
              state: InternalApi.Plumber.Pipeline.State.value(:DONE)
            ]
            |> Support.Factories.Pipeline.pipeline()
          end)
        end)
        |> List.flatten()
      else
        [pipeline, pipeline2]
      end

    pipeline_describe_many_response =
      InternalApi.Plumber.DescribeManyResponse.new(
        response_status:
          InternalApi.Plumber.ResponseStatus.new(
            code: InternalApi.Plumber.ResponseStatus.ResponseCode.value(:OK)
          ),
        pipelines: [pipeline, pipeline2]
      )

    pipeline_list_response =
      InternalApi.Plumber.ListResponse.new(
        response_status:
          InternalApi.Plumber.ResponseStatus.new(
            code: InternalApi.Plumber.ResponseStatus.ResponseCode.value(:OK)
          ),
        pipelines: pipelines,
        page_number: 1,
        total_pages: 1
      )

    pipeline_list_keyset =
      InternalApi.Plumber.ListKeysetResponse.new(
        pipelines: pipelines,
        next_page_token: "next_page_token",
        previous_page_token: "previous_page_token"
      )

    pipeline_list_grouped =
      InternalApi.Plumber.ListGroupedResponse.new(
        response_status:
          InternalApi.Plumber.ResponseStatus.new(
            code: InternalApi.Plumber.ResponseStatus.ResponseCode.value(:OK)
          ),
        pipelines: [
          Support.Factories.pipeline(
            hook_id: Enum.at(repo_proxy_describe_many_response.hooks, 0).hook_id,
            queue: Support.Factories.queue()
          )
        ],
        page_number: 1,
        total_pages: 1
      )

    notification_list_response = %Semaphore.Notifications.V1alpha.ListNotificationsResponse{
      notifications: [
        Support.Factories.notification("zebra"),
        Support.Factories.notification("launchpad")
      ],
      next_page_token: ""
    }

    notification = Support.Factories.notification("zebra")
    delete_notification_response = Semaphore.Notifications.V1alpha.Empty.new()

    GrpcMock.stub(BranchMock, :list, branch_list_response)
    GrpcMock.stub(BranchMock, :filter, branch_filter_response)
    GrpcMock.stub(BranchMock, :describe, branch_response)
    GrpcMock.stub(GuardMock, :refresh, guard_refresh_response)

    FunRegistry.set!(FS.NotificationService, :list_notifications, notification_list_response)
    FunRegistry.set!(FS.NotificationService, :get_notification, notification)
    FunRegistry.set!(FS.NotificationService, :delete_notification, delete_notification_response)
    FunRegistry.set!(FS.NotificationService, :update_notification, notification)
    FunRegistry.set!(FS.NotificationService, :create_notification, notification)

    GrpcMock.stub(OrganizationMock, :describe, organization_describe_response)
    GrpcMock.stub(OrganizationMock, :list_suspensions, list_suspensions_response)

    GrpcMock.stub(OrganizationMock, :create, fn req, _stream ->
      InternalApi.Organization.CreateResponse.new(
        status: Support.Factories.status_ok(),
        organization: Support.Factories.organization(org_username: req.organization_username)
      )
    end)

    GrpcMock.stub(OrganizationMock, :update, organization_update_response)
    GrpcMock.stub(OrganizationMock, :destroy, organization_destroy_response)
    GrpcMock.stub(OrganizationMock, :members, organization_members_response)
    GrpcMock.stub(OrganizationMock, :list, organization_list_response)
    GrpcMock.stub(OrganizationMock, :add_member, add_member_response)
    GrpcMock.stub(OrganizationMock, :add_members, add_members_response)
    GrpcMock.stub(OrganizationMock, :delete_member, delete_member_response)
    FunRegistry.set!(FS.WorkflowService, :describe, workflow_describe_response)
    FunRegistry.set!(FS.WorkflowService, :list, workflow_list_response)
    FunRegistry.set!(FS.WorkflowService, :list_grouped, workflow_list_grouped_response)
    FunRegistry.set!(FS.WorkflowService, :get_path, workflow_get_path_response)

    GrpcMock.stub(
      ProjecthubMock,
      :check_webhook,
      projecthub_check_webhook_ok_response
    )

    GrpcMock.stub(
      ProjecthubMock,
      :regenerate_webhook,
      projecthub_regenerate_webhook_ok_response
    )

    GrpcMock.stub(
      ProjecthubMock,
      :check_deploy_key,
      projecthub_check_deploy_key_ok_response
    )

    GrpcMock.stub(
      ProjecthubMock,
      :regenerate_deploy_key,
      projecthub_regenerate_deploy_key_ok_response
    )

    GrpcMock.stub(ProjecthubMock, :destroy, project_destroy_response())
    GrpcMock.stub(ProjecthubMock, :list, project_list_response)
    GrpcMock.stub(ProjecthubMock, :users, project_users_response)
    GrpcMock.stub(ProjecthubMock, :create, project_create_response)
    GrpcMock.stub(ProjecthubMock, :fork_and_create, project_fork_and_create_response)
    GrpcMock.stub(ProjecthubMock, :update, project_update_response)

    FunRegistry.set!(FS.RepoProxyService, :describe_many, repo_proxy_describe_many_response)
    FunRegistry.set!(FS.RepoProxyService, :describe, repo_proxy_describe_response)

    FunRegistry.set!(FS.RepoProxyService, :list_blocked_hooks, fn req, _s ->
      if req.git_ref != "" do
        InternalApi.RepoProxy.ListBlockedHooksResponse.new(
          status:
            InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
          hooks: [
            Support.Factories.RepoProxy.hook(req.git_ref),
            Support.Factories.RepoProxy.hook("master2"),
            Support.Factories.RepoProxy.hook("master3")
          ]
        )
      else
        InternalApi.RepoProxy.ListBlockedHooksResponse.new(
          status:
            InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
          hooks: [
            Support.Factories.RepoProxy.hook("master"),
            Support.Factories.RepoProxy.hook("master2"),
            Support.Factories.RepoProxy.hook("master3")
          ]
        )
      end
    end)

    FunRegistry.set!(
      FS.RepoProxyService,
      :schedule_blocked_hook,
      repo_proxy_schedule_blocked_hook_response
    )

    FunRegistry.set!(
      FS.RepoProxyService,
      :create,
      repo_proxy_create_response
    )

    FunRegistry.set!(FS.WorkflowService, :describe, workflow_describe_response)
    FunRegistry.set!(FS.WorkflowService, :list, workflow_list_response)

    FunRegistry.set!(FS.SwitchService, :describe, Support.Factories.switch_describe_response())

    alias InternalApi.Plumber.DescribeTopologyResponse
    alias InternalApi.Plumber.ResponseStatus

    GrpcMock.stub(PipelineMock, :describe_topology, fn _, _ ->
      %DescribeTopologyResponse{
        blocks: [
          %DescribeTopologyResponse.Block{
            name: "block 1",
            jobs: [
              "job 1",
              "job 2",
              "job 3",
              "job 4",
              "job 5",
              "job 6",
              "job 7",
              "job 8",
              "job 9"
            ],
            dependencies: []
          }
        ],
        after_pipeline: %DescribeTopologyResponse.AfterPipeline{jobs: []},
        status: %ResponseStatus{code: 0, message: ""}
      }
    end)

    GrpcMock.stub(PipelineMock, :describe_many, pipeline_describe_many_response)
    GrpcMock.stub(PipelineMock, :list, pipeline_list_response)
    GrpcMock.stub(PipelineMock, :list_grouped, pipeline_list_grouped)

    GrpcMock.stub(PipelineMock, :list_keyset, pipeline_list_keyset)

    GrpcMock.stub(TaskMock, :describe_many, fn _, _ ->
      InternalApi.Task.DescribeManyResponse.new(
        tasks: [
          InternalApi.Task.Task.new(),
          InternalApi.Task.Task.new()
        ]
      )
    end)

    switches = [
      %{
        id: "43e929b5-06de-451c-8e52-829cd252d7f9",
        ppl_id: "7e5ea0ae-3477-4d15-b3e9-768db905b9a2",
        targets: [
          %{
            name: "Deploy to Prod",
            events: [
              %{processed: false, result: :FAILED, ppl_id: ""},
              %{processed: true, result: :FAILED, ppl_id: ""},
              %{processed: true, result: :PASSED, ppl_id: "7e5ea0ae-3477-4d15-b3e9-768db905b9a2"}
            ]
          },
          %{
            name: "Deploy to Stg",
            events: []
          }
        ]
      }
    ]

    GrpcMock.stub(GoferMock, :describe, fn req, _ ->
      Enum.find(switches, fn switch -> switch.id == req.switch_id end)
      |> Factories.Gofer.describe_response()
    end)

    GrpcMock.stub(
      BillingMock,
      :organization_status,
      %InternalApi.Billing.OrganizationStatusResponse{
        plan_type_slug: "free"
      }
    )

    workflow_list_keyset_response =
      InternalApi.PlumberWF.ListKeysetResponse.new(
        workflows: [workflow1, workflow2],
        next_page_token: "next_token",
        previous_page_token: "previous_token",
        status: Support.Factories.internal_api_status_ok()
      )

    workflow_list_grouped_keyset_response =
      InternalApi.PlumberWF.ListGroupedKSResponse.new(
        workflows: [workflow1, workflow2],
        next_page_token: "next_token",
        previous_page_token: "previous_token"
      )

    workflow_list_latest_workflows_response =
      InternalApi.PlumberWF.ListLatestWorkflowsResponse.new(
        workflows: [workflow1, workflow2],
        next_page_token: "next_token",
        previous_page_token: "previous_token"
      )

    GrpcMock.stub(WorkflowMock, :list_keyset, workflow_list_keyset_response)
    FunRegistry.set!(FS.WorkflowService, :list_keyset, workflow_list_keyset_response)
    FunRegistry.set!(FS.WorkflowService, :list_grouped_ks, workflow_list_grouped_keyset_response)

    FunRegistry.set!(
      FS.WorkflowService,
      :list_latest_workflows,
      workflow_list_latest_workflows_response
    )

    workflow_get_path_response =
      InternalApi.PlumberWF.GetPathResponse.new(
        wf_id: "3cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
        wf_created_at: Google.Protobuf.Timestamp.new(seconds: 1_580_654_045),
        path: [
          InternalApi.PlumberWF.GetPathResponse.PathElement.new(
            ppl_id: "3cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
            switch_id: "3cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
            rebuild_partition: [""]
          )
        ],
        status: Support.Factories.internal_api_status_ok()
      )

    FunRegistry.set!(FS.WorkflowService, :get_path, workflow_get_path_response)

    stop_job_response = Semaphore.Jobs.V1alpha.Empty.new()
    GrpcMock.stub(PublicJobMock, :stop_job, stop_job_response)

    :ok
  end
end
