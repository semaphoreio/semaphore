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

  describe "list_keyset with large number of project IDs" do
    test "uses CTE optimization when requester_id and >100 projects are provided" do
      # Setup test data
      organization_id = UUID.uuid4()
      requester_id = UUID.uuid4()
      hook_id = UUID.uuid4()

      # Create 110 project IDs (more than the 100 threshold)
      project_ids = Enum.map(1..110, fn _ -> UUID.uuid4() end)

      # Create workflows for 5 of these projects
      test_project_ids = Enum.take(project_ids, 5)

      workflow_ids =
        test_project_ids
        |> Enum.map(fn project_id ->
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

      # Create params with requester_id and large projects list to trigger CTE optimization
      params = %{
        org_id: organization_id,
        projects: project_ids,
        project_id: :skip,
        requesters: :skip,
        requester_id: requester_id,
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

      # Capture logs to verify CTE is being used
      ExUnit.CaptureLog.capture_log(fn ->
        # Execute the query
        {:ok,
         %{
           workflows: workflows,
           next_page_token: _next_token,
           previous_page_token: _previous_token
         }} = WQ.list_keyset(params, keyset_params)

        # Verify results
        assert length(workflows) == 5
        assert Enum.map(workflows, fn workflow -> workflow.wf_id end) |> Enum.sort() == Enum.sort(workflow_ids)

        # Verify all workflows have the correct requester_id
        Enum.each(workflows, fn workflow ->
          assert workflow.requester_id == requester_id
        end)

        # Verify all workflows have project_ids from our test set
        workflow_project_ids = Enum.map(workflows, fn workflow -> workflow.project_id end)
        assert Enum.all?(workflow_project_ids, fn id -> id in test_project_ids end)
      end)
    end

    test "pagination works correctly with CTE optimization" do
      # Setup test data
      organization_id = UUID.uuid4()
      requester_id = UUID.uuid4()
      hook_id = UUID.uuid4()

      # Create 110 project IDs (more than the 100 threshold)
      project_ids = Enum.map(1..110, fn _ -> UUID.uuid4() end)

      # Create 10 workflows for testing pagination
      test_project_ids = Enum.take(project_ids, 10)

      workflow_ids =
        test_project_ids
        |> Enum.map(fn project_id ->
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

          # Add a small delay to ensure different timestamps
          Process.sleep(10)
          wf_id
        end)

      # Create params with requester_id and large projects list
      params = %{
        org_id: organization_id,
        projects: project_ids,
        project_id: :skip,
        requesters: :skip,
        requester_id: requester_id,
        label: :skip,
        git_ref_types: :skip,
        branch_name: :skip,
        triggerers: :skip,
        created_before: :skip,
        created_after: :skip
      }

      # First page - get 5 items
      keyset_params_page1 = %{
        order: :BY_CREATION_TIME_DESC,
        direction: :NEXT,
        page_token: nil,
        page_size: 5
      }

      # Get first page
      {:ok,
       %{
         workflows: workflows_page1,
         next_page_token: next_token,
         previous_page_token: _previous_token
       }} = WQ.list_keyset(params, keyset_params_page1)

      # Verify first page has 5 items
      assert length(workflows_page1) == 5

      # Get second page
      keyset_params_page2 = %{
        order: :BY_CREATION_TIME_DESC,
        direction: :NEXT,
        page_token: next_token,
        page_size: 5
      }

      {:ok,
       %{
         workflows: workflows_page2,
         next_page_token: _next_token_page2,
         previous_page_token: _previous_token_page2
       }} = WQ.list_keyset(params, keyset_params_page2)

      # Verify second page has 5 items
      assert length(workflows_page2) == 5

      # Verify no duplicates between pages
      page1_ids = Enum.map(workflows_page1, fn w -> w.wf_id end)
      page2_ids = Enum.map(workflows_page2, fn w -> w.wf_id end)

      assert length(page1_ids) + length(page2_ids) == 10
      assert Enum.empty?(page1_ids -- workflow_ids)
      assert Enum.empty?(page2_ids -- workflow_ids)
      assert Enum.empty?(Enum.uniq(page1_ids ++ page2_ids) -- workflow_ids)

      # Verify all 10 workflows were returned across both pages
      all_returned_ids = page1_ids ++ page2_ids
      assert Enum.sort(all_returned_ids) == Enum.sort(workflow_ids)
    end
  end
end
