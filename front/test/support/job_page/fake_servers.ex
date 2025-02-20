defmodule JobPage.FakeServers do
  def start_fake_grpc_servers do
    GrpcMock.defmock(OrganizationMock, for: InternalApi.Organization.OrganizationService.Service)

    services = [
      OrganizationMock,
      BranchMock
    ]

    spawn(fn ->
      GRPC.Server.start(services, 50_052)
    end)

    {:ok, _} = FunRegistry.start()

    services = [
      Support.Fake.UserService,
      Support.Fake.RepoProxy,
      Support.Fake.Loghub,
      Support.Fake.Guard,
      Support.Fake.PageHeaderService,
      Support.Fake.PipelineService,
      Support.Fake.WorkflowService
    ]

    # credo:disable-for-next-line
    GRPC.Server.start(services, 50051)
  end

  def setup_responses_for_development do
    repo_proxy_hook =
      InternalApi.RepoProxy.Hook.new(
        hook_id: "21212121-be8a-465a-b9cd-81970fb802c6",
        head_commit_sha: "96e46ddfe9be7656d6799a45e70dee0b1ada2aa4",
        commit_message: "Create eex templates for headers content",
        repo_host_username: "radwo",
        repo_host_url:
          "https://github.com/renderedtext/internal_api/commit/736ce61d50d888e200c75bc50559bb484fbd4b2c"
      )

    repo_proxy_describe_response =
      InternalApi.RepoProxy.DescribeResponse.new(
        status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
        hook: repo_proxy_hook
      )

    repo_proxy_desc =
      InternalApi.RepoProxy.DescribeManyResponse.new(
        hook:
          1..10
          |> Enum.map(fn _ ->
            repo_proxy_hook
          end)
      )

    guard_filter =
      InternalApi.Guard.FilterResponse.new(
        resources: [
          InternalApi.Guard.Resource.new()
        ]
      )

    FunRegistry.set!(Support.Fake.RepoProxy, :describe, repo_proxy_describe_response)
    FunRegistry.set!(Support.Fake.RepoProxy, :describe_many, repo_proxy_desc)
    FunRegistry.set!(Support.Fake.Guard, :filter, guard_filter)
  end
end
