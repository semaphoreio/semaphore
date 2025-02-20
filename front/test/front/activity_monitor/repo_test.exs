defmodule Front.ActivityMonitor.Repo.Test do
  use ExUnit.Case

  alias Front.ActivityMonitor.Repo

  setup do
    Support.Stubs.init()
    Support.Stubs.build_shared_factories()
  end

  test "describe_organization() returns valid org details" do
    organization_describe_response =
      InternalApi.Organization.DescribeResponse.new(
        status: Support.Factories.status_ok(),
        organization: Support.Factories.organization()
      )

    GrpcMock.stub(OrganizationMock, :describe, organization_describe_response)

    assert {:ok,
            %{
              avatar_url: "https://avatars3.githubusercontent.com/u/0?v=4",
              created_at: _time,
              name: "Rendered Text",
              open_source: false,
              org_id: "78114608-be8a-465a-b9cd-81970fb802c7",
              org_username: "renderedtext",
              owner_id: "78114608-be8a-465a-b9cd-81970fb802c7",
              suspended: false
            }} = Repo.describe_organization("org_1", %{})
  end

  test "list_projects() returns only projects accessable to current user" do
    projects = [
      Support.Factories.listed_project(),
      Support.Factories.listed_project(name: "hello-world", id: "123")
    ]

    project_list_response =
      InternalApi.Projecthub.ListResponse.new(
        metadata: Support.Factories.response_meta(),
        projects: projects,
        pagination: InternalApi.Projecthub.PaginationResponse.new(total_pages: 3)
      )

    GrpcMock.stub(ProjecthubMock, :list, project_list_response)

    GrpcMock.stub(
      RBACMock,
      :list_accessible_projects,
      InternalApi.RBAC.ListAccessibleProjectsResponse.new(
        project_ids: [Support.Factories.listed_project().metadata.id]
      )
    )

    assert Repo.list_projects("78114608-be8a-465a-b9cd-81970fb802c7", "123", %{}) ==
             {:ok,
              [
                %{
                  name: "octocat",
                  description: "The coolest project",
                  id: "78114608-be8a-465a-b9cd-81970fb802c6"
                }
              ]}
  end

  test "list_active_debugs() returns active debug sessions data" do
    debugs_list_resp =
      InternalApi.ServerFarm.Job.ListDebugSessionsResponse.new(
        status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
        debug_sessions: [Support.Factories.debug_session(), Support.Factories.debug_session()],
        next_page_token: "123"
      )

    GrpcMock.stub(InternalJobMock, :list_debug_sessions, debugs_list_resp)

    assert {:ok,
            [
              %{debug_user_id: "user_id", debug_session: %{id: "debug_session_id"}},
              %{debug_user_id: "user_id", debug_session: %{id: "debug_session_id"}}
            ]} = Repo.list_active_debugs("org_1", %{})
  end

  test "list_authors_of() returns users that are requesters or promoters of given pipelines" do
    user_describe_many_response =
      InternalApi.User.DescribeManyResponse.new(
        status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
        users: [
          InternalApi.User.User.new(
            id: "9865c64d-783a-46e1-b659-2194b1d69494",
            name: "octocat",
            avatar_url: "https://avatars3.githubusercontent.com/u/0?v=4"
          )
        ]
      )

    GrpcMock.stub(UserMock, :describe_many, user_describe_many_response)

    ppls = [
      %{requester_id: "user_1", promoter_id: ""},
      %{requester_id: "user_1", promoter_id: "user_2"},
      %{requester_id: "user_3", promoter_id: "user_4"}
    ]

    debugs = [%{debug_user_id: "user_5"}]

    assert {:ok,
            [
              %_{
                id: "9865c64d-783a-46e1-b659-2194b1d69494",
                avatar_url: "https://avatars3.githubusercontent.com/u/0?v=4",
                name: "octocat",
                company: "",
                email: "",
                bitbucket_login: nil,
                bitbucket_scope: :NONE,
                bitbucket_uid: nil,
                github_uid: nil,
                created_at: nil,
                github_login: nil,
                github_scope: :NONE
              }
            ]} = Repo.list_authors_of(ppls, debugs, %{})
  end

  test "describe_many_ppls() returns valid pipelines when the respons from Plumber is valid" do
    GrpcMock.stub(PipelineMock, :describe_many, fn _, _stream ->
      %{response_status: %{code: :OK}, pipelines: [pipeline(1), pipeline(2)]}
      |> Util.Proto.deep_new!(InternalApi.Plumber.DescribeManyResponse)
    end)

    timestamp = DateTime.from_unix!(1_522_754_270_000_000, :microsecond)

    assert {:ok,
            [
              %{ppl_id: "ppl_1", created_at: ^timestamp},
              %{ppl_id: "ppl_2", created_at: ^timestamp}
            ]} = Repo.describe_many_ppls(["ppl_1", "ppl_2"], %{})
  end

  test "list_active_jobs() returns valid jobs when the response from Zebra is valid" do
    job_list_resp =
      InternalApi.ServerFarm.Job.ListResponse.new(
        status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
        jobs: [Support.Factories.job(), Support.Factories.job()],
        next_page_token: "123"
      )

    GrpcMock.stub(InternalJobMock, :list, job_list_resp)

    assert {:ok, [%{name: "RSpec 342/708"}, %{name: "RSpec 342/708"}]} =
             Repo.list_active_jobs(%{}, "org_1", ["ppl_1"])
  end

  test "stop_job() returns response from the server" do
    job_stop_resp =
      InternalApi.ServerFarm.Job.StopResponse.new(
        status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK))
      )

    GrpcMock.stub(InternalJobMock, :stop, job_stop_resp)

    request =
      InternalApi.ServerFarm.Job.StopRequest.new(
        job_id: "job_id 1",
        requester_id: "user_id_1"
      )

    assert {:ok, %{status: %{code: 0, message: ""}}} = Repo.stop_job(request)
  end

  test "list_pipeline_activity() returns details of active pipelines" do
    GrpcMock.stub(PipelineMock, :list_activity, mock_responses())

    timestamp = DateTime.from_unix!(1_522_754_270_000_000, :microsecond)

    assert {:ok,
            [
              %{ppl_id: "ppl_1", created_at: ^timestamp},
              %{ppl_id: "ppl_2", created_at: ^timestamp}
            ]} = Repo.list_pipeline_activity("org_1", %{})
  end

  test "when list_pipeline_activity() returns empty set Repo returns empty Data struct" do
    # Organization

    organization_describe_response =
      InternalApi.Organization.DescribeResponse.new(
        status: Support.Factories.status_ok(),
        organization: Support.Factories.organization()
      )

    GrpcMock.stub(OrganizationMock, :describe, organization_describe_response)

    # Projects

    projects = [
      Support.Factories.listed_project(),
      Support.Factories.listed_project(name: "hello-world", id: "123")
    ]

    project_list_response =
      InternalApi.Projecthub.ListResponse.new(
        metadata: Support.Factories.response_meta(),
        projects: projects,
        pagination: InternalApi.Projecthub.PaginationResponse.new(total_pages: 3)
      )

    GrpcMock.stub(ProjecthubMock, :list, project_list_response)

    GrpcMock.stub(
      RBACMock,
      :list_accessible_projects,
      InternalApi.RBAC.ListAccessibleProjectsResponse.new(
        project_ids: [Support.Factories.listed_project().metadata.id]
      )
    )

    # Pipelines

    GrpcMock.stub(PipelineMock, :list_activity, fn _, _stream ->
      %{next_page_token: "token_1", previous_page_token: "", pipelines: []}
      |> Util.Proto.deep_new!(InternalApi.Plumber.ListActivityResponse)
    end)

    debugs_list_resp =
      InternalApi.ServerFarm.Job.ListDebugSessionsResponse.new(
        status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
        debug_sessions: [],
        next_page_token: "123"
      )

    GrpcMock.stub(InternalJobMock, :list_debug_sessions, debugs_list_resp)

    # Jobs

    job_list_resp =
      InternalApi.ServerFarm.Job.ListResponse.new(
        status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
        jobs: [],
        next_page_token: ""
      )

    GrpcMock.stub(InternalJobMock, :list, job_list_resp)

    assert {:ok, map} = Repo.load("org_1", "usr_1", %{})
    assert [] == map.active_pipelines
    assert [] == map.active_jobs
    assert [] == map.active_debug_sessions
    assert [] == map.users
  end

  defp mock_responses do
    %{next_page_token: "token_1", previous_page_token: "", pipelines: [pipeline(1), pipeline(2)]}
    |> Util.Proto.deep_new!(InternalApi.Plumber.ListActivityResponse)
  end

  test "merge_pipelines() properly merges pipelines with debugged_jobs from debug sessions" do
    pipelines = [pipeline(1), pipeline(2)]
    debugs = [debug("ppl_1", 1), debug("ppl_1", 2), debug("ppl_2", 1)]

    assert {:ok, debugs} = Repo.merge_pipeline_data(debugs, pipelines)

    assert %{
             debug_session: %{id: "-job_1"},
             type: :JOB,
             debug_user_id: "user_1",
             debugged_job: %{id: "ppl_1-job_1", pipeline: %{ppl_id: "ppl_1"}}
           } = Enum.at(debugs, 0)
  end

  test "combine_data() properly merges pipelines and jobs data" do
    pipelines = [pipeline(1), pipeline(2)]
    jobs = [job("ppl_1", 1), job("ppl_1", 2), job("ppl_2", 1), job("ppl_2", 2)]

    assert {:ok, combined} = Repo.combine_data(pipelines, jobs)

    assert %{
             ppl_id: "ppl_1",
             blocks: [
               %{
                 jobs: [
                   %{
                     name: "Job 1",
                     index: 0,
                     state: :RUNNING,
                     project_id: "project_id",
                     result: :PASSED,
                     id: "ppl_1-job_1"
                   },
                   %{
                     name: "Job 2",
                     index: 1,
                     state: :RUNNING,
                     project_id: "project_id",
                     result: :PASSED,
                     id: "ppl_1-job_2"
                   }
                 ]
               },
               %{
                 jobs: [
                   %{name: "Job 1", index: 0, status: "pending"},
                   %{name: "Job 2", index: 1, status: "pending"}
                 ]
               }
             ]
           } = Enum.at(combined, 0)
  end

  defp pipeline(index) do
    %{
      organization_id: "org_#{index}",
      project_id: "pr_#{index}",
      wf_id: "wf_#{index}",
      wf_number: index,
      name: "Pipeline",
      ppl_id: "ppl_#{index}",
      hook_id: "hook_#{index}",
      switch_id: "switch_#{index}",
      definition_file: ".semaphore/semaphore.yml",
      priority: 50,
      wf_triggered_by: 0,
      requester_id: "user_#{index}",
      partial_rerun_of: "",
      promotion_of: "",
      promoter_id: "",
      auto_promoted: false,
      git_ref: "master",
      commit_sha: "12345",
      branch_id: "branch_#{index}",
      created_at: %{seconds: 1_522_754_270, nanos: 0},
      pending_at: %{seconds: 1_522_754_281, nanos: 0},
      queuing_at: %{seconds: 1_522_754_292, nanos: 0},
      running_at: %{seconds: 1_522_754_304, nanos: 0},
      queue: %{
        queue_id: "queue_#{index}",
        name: "prod",
        scope: "project",
        project_id: "pr_#{index}",
        organization_id: "org_#{index}",
        type: 0
      },
      blocks: [
        %{
          block_id: "block_1",
          name: "Block 1",
          priority: 50,
          dependencies: [],
          state: 0,
          result: 0,
          result_reason: 0,
          error_description: "",
          jobs: [
            %{name: "Job 1", index: 0, status: "scheduled"},
            %{name: "Job 2", index: 1, status: "scheduled"}
          ]
        },
        %{
          block_id: "block_2",
          name: "Block 2",
          priority: 50,
          dependencies: [],
          state: 0,
          result: 0,
          result_reason: 0,
          error_description: "",
          jobs: [
            %{name: "Job 1", index: 0, status: "pending"},
            %{name: "Job 2", index: 1, status: "pending"}
          ]
        }
      ]
    }
  end

  defp debug(ppl_id, debug_i) do
    %{
      debug_session: job("", debug_i),
      type: :JOB,
      debug_user_id: "user_1",
      debugged_job: job(ppl_id, debug_i)
    }
  end

  defp job(ppl_id, job_i) do
    %{
      id: "#{ppl_id}-job_#{job_i}",
      project_id: "project_id",
      branch_id: "2cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
      hook_id: "2cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
      name: "Job #{job_i}",
      ppl_id: ppl_id,
      index: job_i - 1,
      timeline: %{
        created_at: DateTime.utc_now(),
        enqueued_at: DateTime.utc_now(),
        started_at: DateTime.utc_now(),
        finished_at: DateTime.utc_now()
      },
      state: :RUNNING,
      result: :PASSED,
      failure_reason: "",
      build_server: "127.0.0.1"
    }
  end
end
