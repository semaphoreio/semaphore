defmodule Front.ActivityMonitor.RepoLoadTest do
  use ExUnit.Case

  alias Front.ActivityMonitor.Repo
  alias InternalApi.ServerFarm.Job.Job

  @org_id "org_1"

  setup do
    Cachex.clear(Repo.cache_name())
    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    counters = :counters.new(3, [])
    test_pid = self()

    stub_organization()
    stub_projects()
    stub_accessible_projects(counters)
    stub_pipeline_pages(counters, [[pipeline(1)], [pipeline(2)]])
    stub_jobs(test_pid)
    stub_no_debugs()
    stub_users()

    {:ok, counters: counters}
  end

  describe "load/3 with the per-org cache" do
    test "fetches org data once and applies project visibility per user", ctx do
      assert {:ok, admin_data} = Repo.load(@org_id, "admin", %{})
      assert {:ok, restricted_data} = Repo.load(@org_id, "restricted", %{})

      assert ids(admin_data.accessable_projects) == ["pr_1", "pr_2"]
      assert ids(restricted_data.accessable_projects) == ["pr_1"]

      # Org-wide data is shared, visibility is not.
      assert admin_data.active_pipelines == restricted_data.active_pipelines
      assert admin_data.active_jobs == restricted_data.active_jobs
      assert admin_data.users == restricted_data.users

      assert pipeline_first_page_calls(ctx) == 1
      assert rbac_calls(ctx) == 2
    end

    test "a user without RBAC access sees no projects even when the org data is cached", ctx do
      assert {:ok, _} = Repo.load(@org_id, "admin", %{})
      assert {:ok, data} = Repo.load(@org_id, "nobody", %{})

      assert data.accessable_projects == []
      assert pipeline_first_page_calls(ctx) == 1
    end

    test "concurrent loads for the same org share one fetch", ctx do
      stub_pipeline_pages(ctx.counters, [[pipeline(1)], [pipeline(2)]], delay: 300)

      results =
        1..5
        |> Enum.map(fn _ -> Task.async(fn -> Repo.load(@org_id, "admin", %{}) end) end)
        |> Task.await_many(10_000)

      assert Enum.all?(results, &match?({:ok, _}, &1))
      assert pipeline_first_page_calls(ctx) == 1
    end

    test "refetches after the cache entry is gone", ctx do
      assert {:ok, _} = Repo.load(@org_id, "admin", %{})
      Cachex.clear(Repo.cache_name())
      assert {:ok, _} = Repo.load(@org_id, "admin", %{})

      assert pipeline_first_page_calls(ctx) == 2
    end

    test "different orgs are cached separately", ctx do
      assert {:ok, _} = Repo.load(@org_id, "admin", %{})
      assert {:ok, _} = Repo.load("org_2", "admin", %{})

      assert pipeline_first_page_calls(ctx) == 2
    end

    test "plumber errors are returned as error tuples and are not cached", ctx do
      GrpcMock.stub(PipelineMock, :list_activity, fn _req, _stream ->
        :counters.add(ctx.counters, 1, 1)
        raise GRPC.RPCError, status: 4, message: "deadline exceeded"
      end)

      assert {:error, %GRPC.RPCError{}} = Repo.load(@org_id, "admin", %{})

      stub_pipeline_pages(ctx.counters, [[pipeline(1)]])

      assert {:ok, data} = Repo.load(@org_id, "admin", %{})
      assert ids_of_pipelines(data) == ["ppl_1"]
      assert pipeline_first_page_calls(ctx) == 2
    end

    test "zebra errors are returned as error tuples" do
      GrpcMock.stub(InternalJobMock, :list, fn _req, _stream ->
        raise GRPC.RPCError, status: 14, message: "unavailable"
      end)

      assert {:error, %GRPC.RPCError{}} = Repo.load(@org_id, "admin", %{})
    end
  end

  describe "list_pipelines_and_jobs/2" do
    test "asks zebra for the jobs of each pipeline page separately" do
      assert {:ok, {pipelines, jobs}} = Repo.list_pipelines_and_jobs(@org_id, %{})

      assert Enum.map(pipelines, & &1.ppl_id) == ["ppl_1", "ppl_2"]

      assert_received {:jobs_request, ["ppl_1"]}
      assert_received {:jobs_request, ["ppl_2"]}
      refute_received {:jobs_request, _}

      assert jobs |> Enum.map(& &1.id) |> Enum.sort() ==
               ["ppl_1-job_0", "ppl_1-job_1", "ppl_2-job_0", "ppl_2-job_1"]
    end

    test "without active pipelines it asks zebra once without a pipeline filter", ctx do
      stub_pipeline_pages(ctx.counters, [[]])

      assert {:ok, {[], []}} = Repo.list_pipelines_and_jobs(@org_id, %{})

      assert_received {:jobs_request, []}
      refute_received {:jobs_request, _}
    end

    test "does not duplicate jobs when a pipeline shows up on two pages", ctx do
      stub_pipeline_pages(ctx.counters, [[pipeline(1)], [pipeline(1), pipeline(2)]])

      assert {:ok, {_pipelines, jobs}} = Repo.list_pipelines_and_jobs(@org_id, %{})

      assert length(jobs) == 4
      assert jobs |> Enum.map(& &1.id) |> Enum.uniq() |> length() == 4
    end

    test "fills scheduled jobs of every page with zebra data" do
      assert {:ok, data} = Repo.load(@org_id, "admin", %{})

      for ppl <- data.active_pipelines do
        [scheduled_block, pending_block] = ppl.blocks

        assert Enum.map(scheduled_block.jobs, & &1.state) == [:STARTED, :STARTED]

        assert Enum.map(scheduled_block.jobs, & &1.machine_type) == [
                 "e1-standard-2",
                 "e1-standard-2"
               ]

        assert Enum.map(pending_block.jobs, & &1.status) == ["pending", "pending"]
      end
    end
  end

  describe "cached activity" do
    test "keeps only the fields the page and the agent stats read" do
      assert {:ok, _} = Repo.load(@org_id, "admin", %{})
      assert {:ok, {:ok, cached}} = Cachex.get(Repo.cache_name(), @org_id)

      assert cached.active_jobs != []

      for job <- cached.active_jobs do
        assert job |> Map.keys() |> Enum.sort() == [:machine_type, :self_hosted, :state]
      end

      for ppl <- cached.active_pipelines do
        refute Map.has_key?(ppl, :organization_id)

        for block <- ppl.blocks, job <- block.jobs do
          assert Map.keys(job) -- [:machine_type, :state, :status] == []
        end
      end
    end

    test "renders the same activity and agent stats from the cached shape" do
      GrpcMock.stub(InternalJobMock, :list, fn req, _stream ->
        jobs =
          Enum.flat_map(req.ppl_ids, fn ppl_id ->
            [
              job(ppl_id, "Job 1", 0),
              Job.new(
                id: "#{ppl_id}-job_1",
                ppl_id: ppl_id,
                name: "Job 2",
                index: 1,
                machine_type: "s1-own",
                self_hosted: true,
                state: Job.State.value(:SCHEDULED)
              )
            ]
          end)

        InternalApi.ServerFarm.Job.ListResponse.new(
          status:
            InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
          jobs: jobs,
          next_page_token: ""
        )
      end)

      assert {:ok, data} = Repo.load(@org_id, "admin", %{})

      agents = %Front.ActivityMonitor.AgentStats{
        agent_types: [
          %{name: "e1-standard-2", occupied_count: 0, waiting_count: 0, total_count: 8}
        ],
        self_hosted_agent_types: [
          %{name: "s1-own", occupied_count: 0, waiting_count: 0, total_count: 2}
        ],
        max_parallelism: 10,
        max_agents: 2
      }

      stats = Front.ActivityMonitor.AgentStats.load_activity(agents, data)

      assert [%{occupied_count: 2, waiting_count: 0}] = stats.agent_types
      assert [%{occupied_count: 0, waiting_count: 2}] = stats.self_hosted_agent_types

      activity = Front.ActivityMonitor.load(@org_id, "admin")

      items =
        activity.items.lobby.items ++ activity.items.waiting.items ++ activity.items.running.items

      assert length(items) == 2

      for item <- items do
        assert item.job_stats.left == 2
        assert item.job_stats.running.machine_types == %{"e1-standard-2" => 1}
        assert item.job_stats.waiting.machine_types == %{"s1-own" => 1}
      end
    end
  end

  describe "zebra page budget" do
    test "the job lookups of one load share a single page budget", ctx do
      stub_pipeline_pages(ctx.counters, Enum.map(1..10, &[pipeline(&1)]))
      zebra_calls = :counters.new(1, [])

      GrpcMock.stub(InternalJobMock, :list, fn req, _stream ->
        :counters.add(zebra_calls, 1, 1)

        InternalApi.ServerFarm.Job.ListResponse.new(
          status:
            InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
          jobs: [job(hd(req.ppl_ids), "Job 1", 0)],
          next_page_token: "next-#{System.unique_integer([:positive])}"
        )
      end)

      assert {:ok, _} = Repo.load(@org_id, "admin", %{})
      assert :counters.get(zebra_calls, 1) == 10
    end
  end

  describe "cancelling a fetch" do
    setup do
      on_exit(fn -> Application.delete_env(:front, :activity_monitor_fetch_timeout_ms) end)
    end

    test "an organization failure requests nothing from plumber or zebra" do
      GrpcMock.stub(OrganizationMock, :describe, fn _req, _stream ->
        raise GRPC.RPCError, status: 14, message: "unavailable"
      end)

      record_backend_calls(self(), pipeline_delay: 50, zebra_delay: 50)

      assert {:error, _} = Repo.load(@org_id, "admin", %{})
      assert_no_backend_calls_after_return()
    end

    test "a failed pipeline page stops the job lookups already started" do
      test_pid = self()

      GrpcMock.stub(PipelineMock, :list_activity, fn req, _stream ->
        send(test_pid, {:backend_call, :plumber})

        case req.page_token do
          "" ->
            %{next_page_token: "page_2", previous_page_token: "", pipelines: [pipeline(1)]}
            |> Util.Proto.deep_new!(InternalApi.Plumber.ListActivityResponse)

          _ ->
            :timer.sleep(100)
            raise GRPC.RPCError, status: 14, message: "unavailable"
        end
      end)

      stub_slow_paging_zebra(test_pid, 50)

      assert {:error, %GRPC.RPCError{}} = Repo.load(@org_id, "admin", %{})
      assert_no_backend_calls_after_return()
    end

    test "the fetch cap stops every lookup the fetch started" do
      Application.put_env(:front, :activity_monitor_fetch_timeout_ms, 300)
      record_backend_calls(self(), pipeline_delay: 100, zebra_delay: 50)

      assert {:error, :timeout} = Repo.load(@org_id, "admin", %{})
      assert_no_backend_calls_after_return()
    end
  end

  describe "users lookup" do
    test "starts before the job lookups finish" do
      users_requested = :atomics.new(1, [])
      test_pid = self()

      GrpcMock.stub(UserMock, :describe_many, fn _req, _stream ->
        :atomics.put(users_requested, 1, 1)

        InternalApi.User.DescribeManyResponse.new(
          status:
            InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
          users: [InternalApi.User.User.new(id: "user_1", name: "octocat")]
        )
      end)

      GrpcMock.stub(InternalJobMock, :list, fn req, _stream ->
        send(test_pid, {:users_seen_by_zebra, wait_for_flag(users_requested, 40)})

        InternalApi.ServerFarm.Job.ListResponse.new(
          status:
            InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
          jobs: [job(hd(req.ppl_ids), "Job 1", 0)],
          next_page_token: ""
        )
      end)

      assert {:ok, _} = Repo.load(@org_id, "admin", %{})
      assert_received {:users_seen_by_zebra, true}
    end
  end

  defp wait_for_flag(_flag, 0), do: false

  defp wait_for_flag(flag, tries) do
    if :atomics.get(flag, 1) == 1 do
      true
    else
      :timer.sleep(25)
      wait_for_flag(flag, tries - 1)
    end
  end

  # Plumber pages forever and zebra pages forever, both slowly, and every call
  # is reported to the test process.
  defp record_backend_calls(test_pid, opts) do
    pipeline_delay = Keyword.fetch!(opts, :pipeline_delay)

    GrpcMock.stub(PipelineMock, :list_activity, fn req, _stream ->
      send(test_pid, {:backend_call, :plumber})
      :timer.sleep(pipeline_delay)
      n = System.unique_integer([:positive])

      %{
        next_page_token: "page_#{req.page_token}#{n}",
        previous_page_token: "",
        pipelines: [pipeline(n)]
      }
      |> Util.Proto.deep_new!(InternalApi.Plumber.ListActivityResponse)
    end)

    stub_slow_paging_zebra(test_pid, Keyword.fetch!(opts, :zebra_delay))
  end

  defp stub_slow_paging_zebra(test_pid, delay) do
    GrpcMock.stub(InternalJobMock, :list, fn req, _stream ->
      send(test_pid, {:backend_call, :zebra})
      :timer.sleep(delay)

      InternalApi.ServerFarm.Job.ListResponse.new(
        status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
        jobs: [job(hd(req.ppl_ids ++ ["none"]), "Job 1", 0)],
        next_page_token: "next-#{System.unique_integer([:positive])}"
      )
    end)
  end

  defp assert_no_backend_calls_after_return do
    flush_backend_calls()
    refute_receive {:backend_call, _}, 500
  end

  defp flush_backend_calls do
    receive do
      {:backend_call, _} -> flush_backend_calls()
    after
      0 -> :ok
    end
  end

  describe "combine_data/2" do
    test "matches the previous list-scanning implementation" do
      pipelines = [
        pipeline(1),
        pipeline(2),
        # same job names in two blocks of one pipeline
        Map.update!(pipeline(3), :blocks, fn [b1, _b2] ->
          [b1, %{b1 | block_id: "block_2"}]
        end),
        # scheduled jobs that zebra does not know about
        pipeline(4)
      ]

      jobs =
        [
          job("ppl_1", "Job 1", 0),
          job("ppl_1", "Job 2", 1),
          job("ppl_2", "Job 2", 1),
          job("ppl_3", "Job 1", 0),
          job("ppl_3", "Job 2", 1),
          # duplicate key, different job: the first one must win
          %{job("ppl_2", "Job 2", 1) | id: "ppl_2-job_1-retry"},
          # unrelated job
          job("ppl_9", "Job 1", 0)
        ]
        |> Enum.map(&to_map/1)

      ppls = Enum.map(pipelines, &to_ppl_map/1)

      assert Repo.combine_data(ppls, jobs) == {:ok, legacy_combine_data(ppls, jobs)}
    end

    test "matches the previous implementation when a block repeats a job" do
      ppl =
        pipeline(1)
        |> Map.update!(:blocks, fn [b1, b2] ->
          [%{b1 | jobs: b1.jobs ++ [%{name: "Job 1", index: 0, status: "scheduled"}]}, b2]
        end)
        |> to_ppl_map()

      jobs =
        [job("ppl_1", "Job 1", 0), %{job("ppl_1", "Job 1", 0) | id: "second"}]
        |> Enum.map(&to_map/1)

      assert {:ok, [combined]} = Repo.combine_data([ppl], jobs)
      assert {:ok, [combined]} == {:ok, legacy_combine_data([ppl], jobs)}

      assert combined.blocks |> hd() |> Map.get(:jobs) |> Enum.map(&Map.get(&1, :id)) ==
               ["ppl_1-job_0", nil, "second"]
    end
  end

  # The pre-index implementation, kept here as the reference behaviour.
  defp legacy_combine_data(active_pipelines, active_jobs) do
    Enum.map(active_pipelines, fn pipeline ->
      blocks =
        Enum.map(pipeline.blocks, fn block ->
          {jobs, _} =
            Enum.reduce(block.jobs, {[], active_jobs}, fn job, {block_jobs, full_jobs} ->
              legacy_replace_job(pipeline.ppl_id, job, block_jobs, full_jobs)
            end)

          Map.put(block, :jobs, jobs)
        end)

      Map.put(pipeline, :blocks, blocks)
    end)
  end

  defp legacy_replace_job(ppl_id, p_job = %{status: "scheduled"}, block_jobs, full_jobs) do
    full_job =
      Enum.find(full_jobs, p_job, fn job ->
        job.ppl_id == ppl_id and job.name == p_job.name and job.index == p_job.index
      end)

    full_jobs =
      Enum.reject(full_jobs, fn job -> Map.get(job, :id, "") == Map.get(full_job, :id) end)

    {block_jobs ++ [full_job], full_jobs}
  end

  defp legacy_replace_job(_ppl_id, job = %{status: "pending"}, block_jobs, full_jobs),
    do: {block_jobs ++ [job], full_jobs}

  # Helpers

  defp ids(projects), do: Enum.map(projects, & &1.id)
  defp ids_of_pipelines(data), do: Enum.map(data.active_pipelines, & &1.ppl_id)

  defp pipeline_first_page_calls(ctx), do: :counters.get(ctx.counters, 1)
  defp rbac_calls(ctx), do: :counters.get(ctx.counters, 2)

  defp to_map(job), do: job |> Map.from_struct() |> Map.take([:id, :ppl_id, :name, :index])

  defp to_ppl_map(ppl) do
    %{
      ppl_id: ppl.ppl_id,
      blocks: Enum.map(ppl.blocks, fn b -> %{block_id: b.block_id, jobs: b.jobs} end)
    }
  end

  defp stub_organization do
    GrpcMock.stub(
      OrganizationMock,
      :describe,
      InternalApi.Organization.DescribeResponse.new(
        status: Support.Factories.status_ok(),
        organization: Support.Factories.organization()
      )
    )
  end

  defp stub_projects do
    GrpcMock.stub(
      ProjecthubMock,
      :list,
      InternalApi.Projecthub.ListResponse.new(
        metadata: Support.Factories.response_meta(),
        projects: [
          Support.Factories.listed_project(name: "front", id: "pr_1"),
          Support.Factories.listed_project(name: "zebra", id: "pr_2")
        ],
        pagination: InternalApi.Projecthub.PaginationResponse.new(total_pages: 1)
      )
    )
  end

  defp stub_accessible_projects(counters) do
    GrpcMock.stub(RBACMock, :list_accessible_projects, fn req, _stream ->
      :counters.add(counters, 2, 1)

      project_ids =
        case req.user_id do
          "admin" -> ["pr_1", "pr_2"]
          "restricted" -> ["pr_1"]
          _ -> []
        end

      InternalApi.RBAC.ListAccessibleProjectsResponse.new(project_ids: project_ids)
    end)
  end

  defp stub_pipeline_pages(counters, pages, opts \\ []) do
    delay = Keyword.get(opts, :delay, 0)
    last = length(pages)

    GrpcMock.stub(PipelineMock, :list_activity, fn req, _stream ->
      page_number =
        case req.page_token do
          "" ->
            :counters.add(counters, 1, 1)
            1

          "page_" <> n ->
            String.to_integer(n)
        end

      if delay > 0, do: :timer.sleep(delay)

      next = if page_number < last, do: "page_#{page_number + 1}", else: ""

      %{
        next_page_token: next,
        previous_page_token: "",
        pipelines: Enum.at(pages, page_number - 1)
      }
      |> Util.Proto.deep_new!(InternalApi.Plumber.ListActivityResponse)
    end)
  end

  defp stub_jobs(test_pid) do
    GrpcMock.stub(InternalJobMock, :list, fn req, _stream ->
      send(test_pid, {:jobs_request, req.ppl_ids})

      jobs =
        Enum.flat_map(req.ppl_ids, fn ppl_id ->
          [job(ppl_id, "Job 1", 0), job(ppl_id, "Job 2", 1)]
        end)

      InternalApi.ServerFarm.Job.ListResponse.new(
        status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
        jobs: jobs,
        next_page_token: ""
      )
    end)
  end

  defp stub_no_debugs do
    GrpcMock.stub(
      InternalJobMock,
      :list_debug_sessions,
      InternalApi.ServerFarm.Job.ListDebugSessionsResponse.new(
        status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
        debug_sessions: [],
        next_page_token: ""
      )
    )
  end

  defp stub_users do
    GrpcMock.stub(
      UserMock,
      :describe_many,
      InternalApi.User.DescribeManyResponse.new(
        status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
        users: [InternalApi.User.User.new(id: "user_1", name: "octocat")]
      )
    )
  end

  defp job(ppl_id, name, index) do
    Job.new(
      id: "#{ppl_id}-job_#{index}",
      ppl_id: ppl_id,
      project_id: "pr_1",
      name: name,
      index: index,
      machine_type: "e1-standard-2",
      state: Job.State.value(:STARTED)
    )
  end

  defp pipeline(index) do
    %{
      organization_id: @org_id,
      project_id: "pr_#{index}",
      wf_id: "wf_#{index}",
      name: "Pipeline",
      ppl_id: "ppl_#{index}",
      requester_id: "user_1",
      promoter_id: "",
      git_ref: "master",
      branch_id: "branch_#{index}",
      created_at: %{seconds: 1_522_754_270, nanos: 0},
      blocks: [
        %{
          block_id: "block_1",
          name: "Block 1",
          jobs: [
            %{name: "Job 1", index: 0, status: "scheduled"},
            %{name: "Job 2", index: 1, status: "scheduled"}
          ]
        },
        %{
          block_id: "block_2",
          name: "Block 2",
          jobs: [
            %{name: "Job 1", index: 0, status: "pending"},
            %{name: "Job 2", index: 1, status: "pending"}
          ]
        }
      ]
    }
  end
end
