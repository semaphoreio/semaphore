defmodule Ppl.WorkflowQueries.Test do
  use ExUnit.Case

  import Ecto.Query

  alias Ppl.WorkflowQueries, as: WQ
  alias Test.Support.WorkflowBuilder
  alias Ppl.EctoRepo, as: Repo
  alias Ppl.Ppls.Model.Ppls
  alias Ppl.PplRequests.Model.PplRequests
  alias Ppl.LatestWfs.Model.LatestWfs

  setup do
    Test.Helpers.truncate_db()

    urls = %{workflow_service: "localhost:50053", plumber_service: "localhost:50053"}
    start_supervised!({WorkflowBuilder.Impl, urls})
    :ok
  end

  @branches ["patch-1", "patch-2", "patch-3"]
  @requester_id UUID.uuid4()

  describe "list_keyset" do
    test "returns workflows for the branch page" do
      project_id = UUID.uuid4()
      hook_id = UUID.uuid4()
      label = "master"
      branch_name = "master"

      workflow_ids =
        [1, 2, 3]
        |> Enum.map(fn _ ->
          {:ok, wf_id, _ppl_id} =
            %{
              "label" => label,
              "branch_name" => branch_name,
              "hook_id" => hook_id,
              "project_id" => project_id,
              "repo_name" => "semaphore"
            }
            |> WorkflowBuilder.schedule()

          wf_id
        end)

      params = %{
        org_id: :skip,
        projects: :skip,
        project_id: project_id,
        requesters: :skip,
        requester_id: :skip,
        label: "master",
        git_ref_types: ["branch"],
        branch_name: :skip,
        triggerers: :skip,
        created_before: :skip,
        created_after: :skip
      }

      keyset_params = %{
        order: :BY_CREATION_TIME_DESC,
        direction: :NEXT,
        page_token: nil,
        page_size: 10
      }

      {:ok,
       %{
         workflows: workflows,
         next_page_token: next_token,
         previous_page_token: previous_token
       }} = WQ.list_keyset(params, keyset_params)

      assert Enum.map(workflows, fn workflow -> workflow.wf_id end) == Enum.reverse(workflow_ids)
    end

    test "returns workflows for everyone's activity in organization" do
      organization_id = UUID.uuid4()

      project_ids = [
        UUID.uuid4(),
        UUID.uuid4(),
        UUID.uuid4()
      ]

      hook_id = UUID.uuid4()

      workflow_ids =
        (project_ids ++ [UUID.uuid4(), UUID.uuid4()])
        |> Enum.map(fn project_id ->
          {:ok, wf_id, _ppl_id} =
            %{
              "organization_id" => organization_id,
              "label" => "master",
              "branch_name" => "master",
              "hook_id" => hook_id,
              "repo_name" => "semaphore",
              "project_id" => project_id
            }
            |> WorkflowBuilder.schedule()

          wf_id
        end)
        |> Enum.drop(-2)

      params = %{
        org_id: :skip,
        projects: project_ids,
        project_id: :skip,
        requesters: :skip,
        requester_id: :skip,
        label: :skip,
        git_ref_types: :skip,
        branch_name: :skip,
        triggerers: :skip,
        created_before: :skip,
        created_after: :skip
      }

      keyset_params = %{
        order: :BY_CREATION_TIME_DESC,
        direction: :NEXT,
        page_token: nil,
        page_size: 10
      }

      {:ok,
       %{
         workflows: workflows,
         next_page_token: next_token,
         previous_page_token: previous_token
       }} = WQ.list_keyset(params, keyset_params)

      assert Enum.map(workflows, fn workflow -> workflow.wf_id end) == Enum.reverse(workflow_ids)
    end

    test "returns workflows for my work in organization" do
      organization_id = UUID.uuid4()
      project_ids = [UUID.uuid4(), UUID.uuid4(), UUID.uuid4()]
      requester_ids = [UUID.uuid4(), UUID.uuid4(), UUID.uuid4()]
      hook_id = UUID.uuid4()

      workflow_ids =
        Enum.zip([project_ids, requester_ids])
        |> Enum.map(fn {project_id, requester_id} ->
          {:ok, wf_id, _ppl_id} =
            %{
              "organization_id" => organization_id,
              "label" => "master",
              "branch_name" => "master",
              "hook_id" => hook_id,
              "repo_name" => "semaphore",
              "project_id" => project_id,
              "requester_id" => requester_id
            }
            |> WorkflowBuilder.schedule()

          wf_id
        end)

      params = %{
        org_id: :skip,
        projects: project_ids |> Enum.drop(1),
        project_id: :skip,
        requesters: :skip,
        requester_id: requester_ids |> Enum.at(2),
        label: :skip,
        git_ref_types: :skip,
        branch_name: :skip,
        triggerers: :skip,
        created_before: :skip,
        created_after: :skip
      }

      keyset_params = %{
        order: :BY_CREATION_TIME_DESC,
        direction: :NEXT,
        page_token: nil,
        page_size: 10
      }

      {:ok,
       %{
         workflows: workflows,
         next_page_token: next_token,
         previous_page_token: previous_token
       }} = WQ.list_keyset(params, keyset_params)

      assert Enum.map(workflows, fn workflow -> workflow.wf_id end) == [Enum.at(workflow_ids, -1)]
    end

    test "returns workflows for my work in organization - with multiple requesters" do
      organization_id = UUID.uuid4()
      project_ids = [UUID.uuid4(), UUID.uuid4(), UUID.uuid4()]
      requester_ids = [UUID.uuid4(), UUID.uuid4(), UUID.uuid4()]
      hook_id = UUID.uuid4()

      workflow_ids =
        Enum.zip([project_ids, requester_ids])
        |> Enum.map(fn {project_id, requester_id} ->
          {:ok, wf_id, _ppl_id} =
            %{
              "organization_id" => organization_id,
              "label" => "master",
              "branch_name" => "master",
              "hook_id" => hook_id,
              "repo_name" => "semaphore",
              "project_id" => project_id,
              "requester_id" => requester_id
            }
            |> WorkflowBuilder.schedule()

          wf_id
        end)

      params = %{
        org_id: :skip,
        projects: project_ids |> Enum.drop(1),
        project_id: :skip,
        requester_id: :skip,
        requesters: requester_ids |> Enum.drop(2),
        label: :skip,
        git_ref_types: :skip,
        branch_name: :skip,
        triggerers: :skip,
        created_before: :skip,
        created_after: :skip
      }

      keyset_params = %{
        order: :BY_CREATION_TIME_DESC,
        direction: :NEXT,
        page_token: nil,
        page_size: 10
      }

      {:ok,
       %{
         workflows: workflows,
         next_page_token: next_token,
         previous_page_token: previous_token
       }} = WQ.list_keyset(params, keyset_params)

      assert Enum.map(workflows, fn workflow -> workflow.wf_id end) == [Enum.at(workflow_ids, -1)]
    end

    test "returns workflows when project list exceeds JOIN threshold (>100)" do
      organization_id = UUID.uuid4()
      hook_id = UUID.uuid4()

      # Create 3 workflows with known project IDs
      known_project_ids =
        [1, 2, 3]
        |> Enum.map(fn _ -> UUID.uuid4() end)

      workflow_ids =
        known_project_ids
        |> Enum.map(fn project_id ->
          {:ok, wf_id, _ppl_id} =
            %{
              "organization_id" => organization_id,
              "label" => "master",
              "branch_name" => "master",
              "hook_id" => hook_id,
              "repo_name" => "semaphore",
              "project_id" => project_id
            }
            |> WorkflowBuilder.schedule()

          wf_id
        end)

      # Build a large project list (>100) that includes our known project IDs
      # This triggers the JOIN with unnest code path
      large_project_list = Enum.map(1..150, fn _ -> UUID.uuid4() end) ++ known_project_ids

      params = %{
        org_id: :skip,
        projects: large_project_list,
        project_id: :skip,
        requesters: :skip,
        requester_id: :skip,
        label: :skip,
        git_ref_types: :skip,
        branch_name: :skip,
        triggerers: :skip,
        created_before: :skip,
        created_after: :skip
      }

      keyset_params = %{
        order: :BY_CREATION_TIME_DESC,
        direction: :NEXT,
        page_token: nil,
        page_size: 10
      }

      {:ok,
       %{
         workflows: workflows,
         next_page_token: _next_token,
         previous_page_token: _previous_token
       }} = WQ.list_keyset(params, keyset_params)

      # Should return all 3 workflows that match the known project IDs
      assert Enum.count(workflows) == 3
      assert Enum.map(workflows, fn workflow -> workflow.wf_id end) == Enum.reverse(workflow_ids)
    end

    @tag timeout: :infinity
    test "handles 1000 workflows across different projects and uses index" do
      organization_id = UUID.uuid4()
      hook_id = UUID.uuid4()

      # Create 1000 workflows, each with a unique project_id
      project_ids =
        1..1000
        |> Enum.map(fn _ -> UUID.uuid4() end)

      # Schedule workflows in parallel batches to speed up test
      workflow_ids =
        project_ids
        |> Enum.chunk_every(100)
        |> Enum.flat_map(fn chunk ->
          chunk
          |> Task.async_stream(
            fn project_id ->
              {:ok, wf_id, _ppl_id} =
                %{
                  "organization_id" => organization_id,
                  "label" => "master",
                  "branch_name" => "master",
                  "hook_id" => hook_id,
                  "repo_name" => "semaphore",
                  "project_id" => project_id
                }
                |> WorkflowBuilder.schedule()

              wf_id
            end,
            max_concurrency: 10,
            timeout: 60_000
          )
          |> Enum.map(fn {:ok, wf_id} -> wf_id end)
        end)

      assert length(workflow_ids) == 1000

      # Query with all 1000 project_ids - this triggers the JOIN unnest path
      params = %{
        org_id: :skip,
        projects: project_ids,
        project_id: :skip,
        requesters: :skip,
        requester_id: :skip,
        label: :skip,
        git_ref_types: :skip,
        branch_name: :skip,
        triggerers: :skip,
        created_before: :skip,
        created_after: :skip
      }

      keyset_params = %{
        order: :BY_CREATION_TIME_DESC,
        direction: :NEXT,
        page_token: nil,
        page_size: 20
      }

      {:ok,
       %{
         workflows: workflows,
         next_page_token: next_token,
         previous_page_token: _previous_token
       }} = WQ.list_keyset(params, keyset_params)

      # Should return first page of 20 workflows
      assert Enum.count(workflows) == 20
      # Should have a next page token for pagination
      assert next_token != ""

      # Verify that production code uses planner hints (SET LOCAL) for large project lists.
      # The execute_paginated_query function disables hash/merge joins for >100 projects,
      # which forces nested loop + index usage. We verify this by running EXPLAIN ANALYZE
      # with the same settings that production uses.
      query = WQ.build_list_keyset_query(params) |> limit(20)
      {sql, params_list} = Repo.to_sql(:all, query)

      # Run EXPLAIN with the same planner hints as production (execute_paginated_query)
      {:ok, explain_result} =
        Repo.transaction(fn ->
          Repo.query!("SET LOCAL enable_hashjoin = off")
          Repo.query!("SET LOCAL enable_mergejoin = off")
          %{rows: rows} = Repo.query!("EXPLAIN ANALYZE " <> sql, params_list)
          rows |> Enum.map(&hd/1) |> Enum.join("\n")
        end)

      IO.puts("\n=== Query Execution Plan ===\n#{explain_result}\n===========================\n")

      # With hash/merge joins disabled (as in production for >100 projects),
      # PostgreSQL should use Nested Loop + Index Scan
      assert explain_result =~ "Nested Loop",
             "Expected Nested Loop join. Got plan:\n#{explain_result}"

      assert explain_result =~ "Index Scan" or explain_result =~ "Index Only Scan" or
               explain_result =~ "pipeline_requests_project_id",
             "Expected query to use project_id index. Got plan:\n#{explain_result}"

      # Verify the query completes quickly (should be under 5 seconds even with 1000 projects)
      {time_microseconds, {:ok, _result}} =
        :timer.tc(fn -> WQ.list_keyset(params, keyset_params) end)

      assert time_microseconds < 5_000_000,
             "Query took too long: #{time_microseconds / 1_000}ms"
    end
  end

  describe "get_workflows" do
    test "returns workflows for provided IDs ordered in desc by inserted_at" do
      organization_id = UUID.uuid4()
      project_id = UUID.uuid4()
      requester_id = UUID.uuid4()
      hook_id = UUID.uuid4()

      workflow_ids =
        [1, 2, 3]
        |> Enum.map(fn _ ->
          {:ok, wf_id, _ppl_id} =
            %{
              "label" => "master",
              "branch_name" => "master",
              "hook_id" => hook_id,
              "project_id" => project_id,
              "organization_id" => organization_id,
              "repo_name" => "semaphore"
            }
            |> WorkflowBuilder.schedule()

          wf_id
        end)
        |> Enum.reverse()

      assert Ppls |> Repo.aggregate(:count, :id) == 3
      assert PplRequests |> Repo.aggregate(:count, :id) == 3

      workflows = WQ.get_workflows(workflow_ids)

      workflows
      |> Enum.each(fn workflow ->
        assert {:ok, workflow} == WQ.get_details(workflow.wf_id)
      end)

      assert workflow_ids == Enum.map(workflows, fn workflow -> workflow.wf_id end)
    end
  end

  describe "list_latest_workflows" do
    setup do
      @branches
      |> Enum.each(fn branch ->
        insert_workflows(branch)
      end)

      assert PplRequests |> Repo.aggregate(:count, :id) == 6
      assert Ppls |> Repo.aggregate(:count, :id) == 6
      assert LatestWfs |> Repo.aggregate(:count, :id) == 3

      :ok
    end

    test "returns latest workflows for project per each branch" do
      params = %{
        order: :BY_CREATION_TIME_DESC,
        direction: :NEXT,
        page_token: nil,
        page_size: 10,
        project_id: "list_latest_wfs",
        org_id: "semaphore"
      }

      {:ok, result} = WQ.list_latest_workflows(params)

      assert result.workflows |> Enum.count() == 3
      assert result.workflows |> from_different_branches?(@branches)
      assert result.workflows |> latest?()
    end

    test "returns paginated workflows" do
      params = %{
        order: :BY_CREATION_TIME_DESC,
        direction: :NEXT,
        page_token: nil,
        page_size: 1,
        project_id: "list_latest_wfs"
      }

      {:ok, result} = WQ.list_latest_workflows(params)
      assert result.workflows |> Enum.count() == 1
    end

    test "returns paginated workflows by requester" do
      # three workflows are scheduled by @requester_id
      # we will go through all of them in 3 pages
      params = %{
        order: :BY_CREATION_TIME_DESC,
        direction: :NEXT,
        page_token: nil,
        page_size: 1,
        project_id: "list_latest_wfs",
        requester_id: @requester_id
      }

      {:ok,
       %{
         workflows: workflows,
         next_page_token: next_token,
         previous_page_token: previous_token
       }} = WQ.list_latest_workflows(params)

      assert Enum.count(workflows) == 1

      params_pg_2 = %{
        order: :BY_CREATION_TIME_DESC,
        direction: :NEXT,
        page_token: next_token,
        page_size: 1,
        project_id: "list_latest_wfs",
        requester_id: @requester_id
      }

      {:ok,
       %{
         workflows: workflows_pg_2,
         next_page_token: next_token_pg_2,
         previous_page_token: previous_token_pg_2
       }} = WQ.list_latest_workflows(params_pg_2)

      assert Enum.count(workflows_pg_2) == 1

      params_pg_3 = %{
        order: :BY_CREATION_TIME_DESC,
        direction: :NEXT,
        page_token: next_token_pg_2,
        page_size: 1,
        project_id: "list_latest_wfs",
        requester_id: @requester_id
      }

      {:ok,
       %{
         workflows: workflows_pg_3,
         next_page_token: next_token_pg_3,
         previous_page_token: previous_token_pg_3
       }} = WQ.list_latest_workflows(params_pg_3)

      assert Enum.count(workflows_pg_3) == 1
      assert next_token_pg_3 == ""
    end
  end

  defp from_different_branches?(workflows, expected_branches) do
    actual_branches = workflows |> Enum.map(fn workflow -> workflow.branch_name end)
    Enum.sort(actual_branches) == Enum.sort(expected_branches)
  end

  defp latest?(workflows) do
    ppl_ids =
      workflows
      |> Enum.map(fn workflow ->
        last_record =
          Ppls
          |> where([p], p.branch_name == ^workflow.branch_name)
          |> order_by([p], desc: p.inserted_at)
          |> limit(1)
          |> Repo.one()

        last_record.ppl_id
      end)

    ppl_ids == workflows |> Enum.map(fn workflow -> workflow.initial_ppl_id end)
  end

  defp insert_workflows(branch) do
    Range.new(0, 1)
    |> Enum.map(fn i ->
      %{
        "label" => branch,
        "branch_name" => branch,
        "hook_id" => "#{i}",
        "project_id" => "list_latest_wfs",
        "organization_id" => "semaphore",
        "repo_name" => "2_basic",
        "requester_id" => @requester_id
      }
      |> WorkflowBuilder.schedule()
    end)
  end
end
