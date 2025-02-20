defmodule Ppl.Ppls.Model.PplsQueries.Test do
  use Ppl.IntegrationCase
  doctest Ppl.Ppls.Model.PplsQueries

  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.PplSubInits.Model.PplSubInitsQueries
  alias Ppl.PplOrigins.Model.PplOriginsQueries
  alias Ppl.PplTraces.Model.PplTracesQueries
  alias Ppl.Ppls.Model.{Ppls, PplsQueries, Triggerer}
  alias Ppl.EctoRepo, as: Repo
  alias Ppl.Actions

  setup do
    Test.Helpers.truncate_db()

    request_args = Test.Helpers.schedule_request_factory(:local)
    state = create_ppls(request_args)
    {:ok, state}
  end

  defp create_ppls(request_args) do
    job_1 = %{"name" => "job1", "commands" => ["echo foo", "echo bar"]}
    job_2 = %{"name" => "job2", "commands" => ["echo baz"]}
    jobs_list = [job_1, job_2]
    build = %{"jobs" => jobs_list}

    blocks = [%{"build" => build}, %{"build" => build}]
    agent = %{"machine" => %{"type" => "e1-standard-2", "os_image" => "ubuntu1804"}}
    definition_v1 = %{"version" => "v1.0", "agent" => agent, "blocks" => [%{"build" => build}]}
    definition_v3 = %{"version" => "v3.0", "semaphore_image" => "some_image", "blocks" => blocks}

    {:ok, ppl_req} = PplRequestsQueries.insert_request(request_args)
    id = ppl_req.id
    {:ok, ppl_req} = PplRequestsQueries.insert_definition(ppl_req, definition_v1, UUID.uuid4())

    request_args = %{request_args | "request_token" => UUID.uuid4()}
    {:ok, ppl_req_v3} = PplRequestsQueries.insert_request(request_args)
    id_v3 = ppl_req_v3.id

    {:ok, ppl_req_v3} =
      PplRequestsQueries.insert_definition(ppl_req_v3, definition_v3, UUID.uuid4())

    %{ppl_id: id, ppl_req: ppl_req, ppl_v3_id: id_v3, ppl_req_v3: ppl_req_v3}
  end

  test "insert new pipeline event from local pipeline service", ctx do
    insert_pipeline(ctx.ppl_req)
    insert_pipeline(ctx.ppl_req_v3)
  end

  test "insert new pipeline from github pipeline service" do
    state =
      :github
      |> Test.Helpers.schedule_request_factory()
      |> create_ppls()

    insert_pipeline(state.ppl_req)
    insert_pipeline(state.ppl_req_v3)
  end

  test "insert new pipeline from github pipeline service with JustRun" do
    {:ok, ppl_req} =
      %{
        "owner" => "",
        "repo_name" => "",
        "commit_sha" => "",
        "hook_id" => "",
        "branch_id" => "",
        "branch_name" => "master",
        "scheduler_task_id" => UUID.uuid4()
      }
      |> Test.Helpers.schedule_request_factory(:github)
      |> PplRequestsQueries.insert_request(true, true, true)

    {:ok, ppl} = PplsQueries.insert(ppl_req, "", true)

    assert ppl.state == "initializing"
    assert ppl.in_scheduling == false
    assert ppl.recovery_count == 0

    refute ppl.owner
    refute ppl.repo_name
    assert ppl.branch_name == ppl_req.request_args["branch_name"]
    assert ppl.yml_file_path == ".semaphore/semaphore.yml"
  end

  test "insert new pipeline from bitbucket pipeline service" do
    state =
      :bitbucket
      |> Test.Helpers.schedule_request_factory()
      |> create_ppls()

    insert_pipeline(state.ppl_req)
    insert_pipeline(state.ppl_req_v3)
  end

  test "insert new pipeline from git pipeline service" do
    state =
      :git
      |> Test.Helpers.schedule_request_factory()
      |> create_ppls()

    insert_pipeline(state.ppl_req)
    insert_pipeline(state.ppl_req_v3)
  end

  test "insert new pipeline from gitlab pipeline service" do
    state =
      :gitlab
      |> Test.Helpers.schedule_request_factory()
      |> create_ppls()

    insert_pipeline(state.ppl_req)
    insert_pipeline(state.ppl_req_v3)
  end

  test "insert new pipeline for non-existent pipeline service" do
    ctx =
      %{"service" => "non_existent"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> create_ppls()

    assert {:error, {:unknown_service, _}} = PplsQueries.insert(ctx.ppl_req)
  end

  defp insert_pipeline(ppl_req) do
    {:ok, ppl} = PplsQueries.insert(ppl_req)
    assert ppl.state == "initializing"
    assert ppl.in_scheduling == false
    assert ppl.recovery_count == 0
    service = ppl_req |> Map.get(:request_args) |> Map.get("service") |> String.to_atom()
    assert_repo_data_set(ppl, ppl_req, service)
  end

  test "pipeline insert is idempotent operation in regard to ppl_id", ctx do
    assert {:ok, ppl_1} = PplsQueries.insert(ctx.ppl_req)
    assert {:ok, ppl_2} = PplsQueries.insert(ctx.ppl_req)
    assert ppl_1.inserted_at == ppl_2.inserted_at
  end

  defp assert_repo_data_set(ppl, ppl_req, :local) do
    assert ppl.owner == ppl_req.request_args["owner"]
    assert ppl.repo_name == ppl_req.request_args["repo_name"]
    assert ppl.branch_name == ppl_req.request_args["branch_name"]
    assert ppl.yml_file_path == ".semaphore/semaphore.yml"
  end

  defp assert_repo_data_set(ppl, ppl_req, :git_hub) do
    assert ppl.owner == Map.get(ppl_req.request_args, "owner")
    assert ppl.repo_name == Map.get(ppl_req.request_args, "repo_name")
    assert ppl.branch_name == Map.get(ppl_req.request_args, "branch_name")
    assert ppl.yml_file_path == ppl_req.request_args |> get_yml_file_path()
    assert ppl.repository_id ==  Map.get(ppl_req.request_args, "repository_id")
  end

  defp assert_repo_data_set(ppl, ppl_req, :bitbucket) do
    assert ppl.owner == Map.get(ppl_req.request_args, "owner")
    assert ppl.repo_name == Map.get(ppl_req.request_args, "repo_name")
    assert ppl.branch_name == Map.get(ppl_req.request_args, "branch_name")
    assert ppl.yml_file_path == ppl_req.request_args |> get_yml_file_path()
    assert ppl.repository_id ==  Map.get(ppl_req.request_args, "repository_id")
  end

  defp assert_repo_data_set(ppl, ppl_req, :git) do
    assert ppl.owner == Map.get(ppl_req.request_args, "owner")
    assert ppl.repo_name == Map.get(ppl_req.request_args, "repo_name")
    assert ppl.branch_name == Map.get(ppl_req.request_args, "branch_name")
    assert ppl.yml_file_path == ppl_req.request_args |> get_yml_file_path()
    assert ppl.repository_id ==  Map.get(ppl_req.request_args, "repository_id")
  end

  defp assert_repo_data_set(ppl, ppl_req, :gitlab) do
    assert ppl.owner == Map.get(ppl_req.request_args, "owner")
    assert ppl.repo_name == Map.get(ppl_req.request_args, "repo_name")
    assert ppl.branch_name == Map.get(ppl_req.request_args, "branch_name")
    assert ppl.yml_file_path == ppl_req.request_args |> get_yml_file_path()
    assert ppl.repository_id ==  Map.get(ppl_req.request_args, "repository_id")
  end

  defp get_yml_file_path(request_args) do
    filename = Map.get(request_args, "file_name", "semaphore.yml")

    request_args
    |> Map.get("working_dir", ".semaphore")
    |> Path.join(filename)
  end

  test "set termination flags for all pipelines from given branch of given project" do
    ppls = Range.new(0, 4) |> Enum.map(fn index -> insert_new_ppl(index) end)

    # First to done, second to runnning, and every other to queuing
    ppls |> Enum.map(fn ppl -> to_state(ppl, "queuing") end)
    ppls |> Enum.at(0) |> to_state("done")
    ppls |> Enum.at(1) |> to_state("running")

    t_parmas = terminate_params("123", "master")
    assert {:ok, number} = PplsQueries.terminate_all(t_parmas)
    assert number == 4

    assert_ppls_termination_flags_set(ppls, "admin action")
  end

  test "set termination flags for all pipelines from given organization" do
    ppls = Range.new(0, 9) |> Enum.map(fn index -> insert_new_ppl(index) end)

    # First to done, second to runnning, and every other to queuing
    ppls |> Enum.map(fn ppl -> to_state(ppl, "queuing") end)
    ppls |> Enum.at(0) |> to_state("done")
    ppls |> Enum.at(1) |> to_state("running")

    t_parmas = terminate_params("abc")
    assert {:ok, number} = PplsQueries.terminate_all(t_parmas)
    assert number == 9

    assert_ppls_termination_flags_set(ppls, "organization blocked")
  end

  defp terminate_params(project_id, branch_name) do
    %{
      project_id: project_id,
      branch_name: branch_name,
      terminate_request: "stop",
      terminate_request_desc: "admin action",
      terminated_by: "admin"
    }
  end

  defp terminate_params(org_id) do
    %{
      org_id: org_id,
      terminate_request: "stop",
      terminate_request_desc: "organization blocked",
      terminated_by: "admin"
    }
  end

  defp assert_ppls_termination_flags_set(ppls, t_desc) do
    ppls
    |> Enum.slice(1..9)
    |> Enum.map(fn ppl ->
      assert {:ok, from_db} = PplsQueries.get_by_id(ppl.ppl_id)
      assert from_db.terminate_request == "stop"
      assert from_db.terminate_request_desc == t_desc
    end)
  end

  test "get_details() returns correct values" do
    request_args = Test.Helpers.schedule_request_factory(:local)

    state = create_ppls(request_args)
    assert {:ok, ppl} = PplsQueries.insert(state.ppl_req)
    assert {:ok, pt} = PplTracesQueries.insert(ppl)

    assert expected = expected_details_response(state.ppl_req, ppl, pt)

    assert {:ok, expected} == PplsQueries.get_details(state.ppl_id)
  end

  test "get_details() returns environment variable values" do
    request_args = Test.Helpers.schedule_request_factory(:local)
    request_args = Map.put(request_args, "env_vars", [
      %{"name" => "FOO", "value" => "foo"},
      %{"name" => "BAR", "value" => "bar"}
    ])

    state = create_ppls(request_args)
    assert {:ok, ppl} = PplsQueries.insert(state.ppl_req)
    assert {:ok, pt} = PplTracesQueries.insert(ppl)

    assert expected = expected_details_response(state.ppl_req, ppl, pt)
      |> Map.put(:env_vars, [
        %{"name" => "FOO", "value" => "foo"},
        %{"name" => "BAR", "value" => "bar"}
      ])

    assert {:ok, expected} == PplsQueries.get_details(state.ppl_id)
  end

  defp expected_details_response(ppl_req, ppl, pt) do
    %{
      id: ppl.id,
      inserted_at: ppl.inserted_at,
      ppl_id: ppl_req.id,
      name: "Pipeline",
      project_id: ppl_req.request_args["project_id"],
      branch_name: ppl_req.request_args["branch_name"],
      commit_sha: ppl_req.request_args["commit_sha"],
      created_at: pt.created_at,
      pending_at: pt.pending_at,
      queuing_at: pt.queuing_at,
      running_at: pt.running_at,
      stopping_at: pt.stopping_at,
      done_at: pt.done_at,
      state: "initializing",
      result: nil,
      result_reason: nil,
      terminate_request: "",
      hook_id: ppl_req.request_args["hook_id"],
      branch_id: ppl_req.request_args["branch_id"],
      error_description: "",
      switch_id: ppl_req.switch_id,
      working_directory: ppl_req.request_args["working_dir"],
      yaml_file_name: ppl_req.request_args["file_name"],
      terminated_by: "",
      wf_id: ppl_req.wf_id,
      snapshot_id: "",
      partial_rerun_of: "",
      partially_rerun_by: "",
      promotion_of: "",
      commit_message: "",
      compile_task_id: "",
      after_task_id: "",
      with_after_task: false,
      repository_id: "",
      queue: %{
        name: "",
        organization_id: "",
        project_id: "",
        queue_id: "",
        scope: "",
        type: "implicit"
      },
      env_vars: [],
      triggerer: %Triggerer{
        auto_promoted: false,
        initial_request: true,
        promoter_id: "",
        provider_author: "",
        provider_avatar: "",
        provider_uid: "",
        requester_id: ppl_req.request_args["requester_id"],
        scheduler_task_id: "",
        triggered_by: "",
        partial_rerun_of: "",
        partially_rerun_by: "",
        promotion_of: "",
        wf_rebuild_of: "",
        workflow_id: ppl_req.wf_id,
        hook_id: ppl_req.request_args["hook_id"]
      },
      organization_id: ppl_req.request_args["organization_id"]
    }
  end

  test "list pipelines from given branch on given project and receive paginated result" do
    ppls = Range.new(0, 4) |> Enum.map(fn index -> insert_new_ppl(index) end)

    params = %{
      project_id: "123",
      label: :skip,
      yml_file_path: :skip,
      wf_id: :skip,
      created_before: :skip,
      created_after: :skip,
      done_before: :skip,
      done_after: :skip,
      branch_name: "master",
      git_ref_types: :skip,
      queue_id: :skip,
      pr_head_branch: :skip,
      pr_target_branch: :skip
    }

    result = PplsQueries.list_ppls(params, 1, 10)

    assert {:ok,
            %Scrivener.Page{
              entries: list,
              page_number: 1,
              page_size: 10,
              total_entries: 5,
              total_pages: 1
            }} = result

    assert list_result_contains?(list, ppls)

    # check if the result is same when optimized listing is used
    result2 = PplsQueries.list_using_pipelines_only(params, 1, 10)
    assert result == result2
  end

  test "list pipelines result is paginated and orderd by desc creation time" do
    ppls = Range.new(0, 4) |> Enum.map(fn index -> insert_new_ppl(index) end)

    params = %{
      project_id: "123",
      label: :skip,
      yml_file_path: :skip,
      wf_id: :skip,
      created_before: :skip,
      created_after: :skip,
      done_before: :skip,
      done_after: :skip,
      branch_name: "master",
      git_ref_types: :skip,
      queue_id: :skip,
      pr_head_branch: :skip,
      pr_target_branch: :skip
    }

    result = PplsQueries.list_ppls(params, 2, 3)

    assert {:ok,
            %Scrivener.Page{
              entries: list,
              page_number: 2,
              page_size: 3,
              total_entries: 5,
              total_pages: 2
            }} = result

    # oldest two ppl's should be on the second page
    included = ppls |> Enum.slice(0..1)
    excluded = ppls |> Enum.slice(2..4)

    assert list_result_contains?(list, included)
    refute list_result_contains?(list, excluded)

    # check if the result is same when optimized listing is used
    result2 = PplsQueries.list_using_pipelines_only(params, 2, 3)
    assert result == result2
  end

  @tag :integration
  test "list_keyset pipelines by git_ref_types, label and yml_file_path" do
    ppls = Range.new(0, 14) |> Enum.map(fn index -> insert_new_ppl(index) end)

    ppl_id = ppls |> Enum.at(14) |> Map.get(:ppl_id)
    loopers = Test.Helpers.start_all_loopers()
    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 10_000)
    Test.Helpers.stop_all_loopers(loopers)

    params = %{
      project_id: "123",
      label: "master",
      yml_file_path: ".semaphore/deploy.yml",
      wf_id: :skip,
      created_before: :skip,
      created_after: :skip,
      done_before: :skip,
      done_after: :skip,
      branch_name: :skip,
      git_ref_types: ["branch"],
      queue_id: :skip,
      pr_head_branch: :skip,
      pr_target_branch: :skip
    }

    keyset_params = %{
      order: :BY_CREATION_TIME_DESC,
      direction: :NEXT,
      page_size: 10,
      page_token: nil
    }

    result = PplsQueries.list_keyset(params, keyset_params)

    assert {:ok,
            %{
              previous_page_token: "",
              next_page_token: "",
              pipelines: list
             }} = result

    # oldest two ppl's should be on the second page
    included = [Enum.at(ppls, 0), Enum.at(ppls, 2), Enum.at(ppls, 4)]
    excluded = [Enum.at(ppls, 1), Enum.at(ppls, 3)] ++ Enum.slice(ppls, 5..14)

    assert list_result_contains?(list, included)
    refute list_result_contains?(list, excluded)

    # check if the result is same when optimized listing is used
    params = params |> Map.put(:branch_name, "master")

    result2 = PplsQueries.list_keyset_using_pipelines_only(params, keyset_params)
    assert result == result2
  end

  @tag :integration
  test "list pipelines by git_ref_types and label" do
    ppls = Range.new(0, 14) |> Enum.map(fn index -> insert_new_ppl(index) end)

    ppl_id = ppls |> Enum.at(14) |> Map.get(:ppl_id)

    loopers = Test.Helpers.start_all_loopers()
    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 10_000)
    Test.Helpers.stop_all_loopers(loopers)

    # specific branch

    params = %{
      project_id: "123",
      label: "master",
      yml_file_path: :skip,
      wf_id: :skip,
      created_before: :skip,
      created_after: :skip,
      done_before: :skip,
      done_after: :skip,
      branch_name: :skip,
      git_ref_types: ["branch"],
      queue_id: :skip,
      pr_head_branch: :skip,
      pr_target_branch: :skip
    }

    result = PplsQueries.list_ppls(params, 2, 3)

    assert {:ok,
            %Scrivener.Page{
              entries: list,
              page_number: 2,
              page_size: 3,
              total_entries: 5,
              total_pages: 2
            }} = result

    # oldest two ppl's should be on the second page
    included = ppls |> Enum.slice(0..1)
    excluded = ppls |> Enum.slice(2..14)

    assert list_result_contains?(list, included)
    refute list_result_contains?(list, excluded)

    # all tags and prs

    params = %{
      project_id: "123",
      label: :skip,
      yml_file_path: :skip,
      wf_id: :skip,
      created_before: :skip,
      created_after: :skip,
      done_before: :skip,
      done_after: :skip,
      branch_name: :skip,
      git_ref_types: ["tag", "pr"],
      queue_id: :skip,
      pr_head_branch: :skip,
      pr_target_branch: :skip
    }

    result = PplsQueries.list_ppls(params, 2, 3)

    assert {:ok,
            %Scrivener.Page{
              entries: list,
              page_number: 2,
              page_size: 3,
              total_entries: 10,
              total_pages: 4
            }} = result

    included = ppls |> Enum.slice(9..11)
    excluded = Enum.slice(ppls, 0..8) ++ Enum.slice(ppls, 12..14)

    assert list_result_contains?(list, included)
    refute list_result_contains?(list, excluded)
  end

  @tag :integration
  test "list_keyset pipelines by pr_head_branch and pr_target_branch" do
    # last 5 pipelines will be PR triggered which is configured in
    # repo_proxy_ref based on index value passed through hook_id field in request
    ppls = Range.new(0, 14) |> Enum.map(fn index -> insert_new_ppl(index) end)

    ppl_id = ppls |> Enum.at(14) |> Map.get(:ppl_id)

    loopers = Test.Helpers.start_all_loopers()
    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 10_000)
    Test.Helpers.stop_all_loopers(loopers)

    # target branch

    params = %{
      project_id: "123",
      label: :skip,
      yml_file_path: :skip,
      wf_id: :skip,
      created_before: :skip,
      created_after: :skip,
      done_before: :skip,
      done_after: :skip,
      branch_name: :skip,
      git_ref_types: :skip,
      queue_id: :skip,
      pr_head_branch: :skip,
      pr_target_branch: "pr_base"
    }

    keyset_params = %{
      order: :BY_CREATION_TIME_DESC,
      direction: :NEXT,
      page_size: 3,
      page_token: nil
    }

    # we first need to fetch first page to get the token for the second page
    first_page = PplsQueries.list_keyset(params, keyset_params)

    assert {:ok,
            %{
              previous_page_token: "",
              next_page_token: token,
              pipelines: list
             }} = first_page

    included = Enum.slice(ppls, 12..14)
    excluded = Enum.slice(ppls, 0..11)

    assert list_result_contains?(list, included)
    refute list_result_contains?(list, excluded)

    # check if the first page is same when using optimized list keyset
    first_page_optimized = PplsQueries.list_keyset_using_requests_only(params, keyset_params)

    assert {:ok,
            %{
              previous_page_token: "",
              next_page_token: token2,
              pipelines: list2
            }} = first_page_optimized

    assert list == list2

    # second page should contain the older two PR pipelines
    keyset_params2 = %{
      order: :BY_CREATION_TIME_DESC,
      direction: :NEXT,
      page_size: 3,
      page_token: token
    }

    second_page = PplsQueries.list_keyset(params, keyset_params2)

    assert {:ok,
            %{
              next_page_token: _token3,
              pipelines: list3
             }} = second_page

    # oldest two ppl's should be on the second page
    included = Enum.slice(ppls, 10..11)
    excluded = Enum.slice(ppls, 0..9) ++ Enum.slice(ppls, 12..14)

    assert list_result_contains?(list3, included)
    refute list_result_contains?(list3, excluded)

    # check if the result is same when using optimized list keyset
    keyset_params3 = %{
      order: :BY_CREATION_TIME_DESC,
      direction: :NEXT,
      page_size: 3,
      page_token: token2
    }

    second_page_optimized = PplsQueries.list_keyset_using_requests_only(params, keyset_params3)

    assert {:ok,
            %{
              next_page_token: _token4,
              pipelines: list4
            }} = second_page_optimized

    assert list3 == list4

    # head branch

    params = %{
      project_id: "123",
      label: :skip,
      yml_file_path: :skip,
      wf_id: :skip,
      created_before: :skip,
      created_after: :skip,
      done_before: :skip,
      done_after: :skip,
      branch_name: :skip,
      git_ref_types: :skip,
      queue_id: :skip,
      pr_head_branch: "pr_head",
      pr_target_branch: :skip
    }

    keyset_params = %{
      order: :BY_CREATION_TIME_DESC,
      direction: :NEXT,
      page_size: 3,
      page_token: nil
    }

    # we first need to fetch first page to get the token for the second page
    first_page_head = PplsQueries.list_keyset(params, keyset_params)

    assert {:ok,
            %{
              previous_page_token: "",
              next_page_token: token_head,
              pipelines: list_head_1
             }} = first_page_head

    assert list == list_head_1

    # check if the first page is same when using optimized list keyset
    first_page_head_optimized = PplsQueries.list_keyset_using_requests_only(params, keyset_params)

    assert {:ok,
            %{
              previous_page_token: "",
              next_page_token: token_head_2,
              pipelines: list_head_2
            }} = first_page_head_optimized

    assert list_head_1 == list_head_2

    # second page should contain the older two PR pipelines
    keyset_params2 = %{
      order: :BY_CREATION_TIME_DESC,
      direction: :NEXT,
      page_size: 3,
      page_token: token_head
    }

    second_page_head = PplsQueries.list_keyset(params, keyset_params2)

    assert {:ok,
            %{
              next_page_token: _token_head_3,
              pipelines: list_head_3
             }} = second_page_head

    assert list3 == list_head_3

    # check if the result is same when using optimized list keyset
    keyset_params3 = %{
      order: :BY_CREATION_TIME_DESC,
      direction: :NEXT,
      page_size: 3,
      page_token: token_head_2
    }

    second_page_head_optimized = PplsQueries.list_keyset_using_requests_only(params, keyset_params3)

    assert {:ok,
            %{
              next_page_token: _token_head_4,
              pipelines: list_head_4
            }} = second_page_head_optimized

    assert list_head_3 == list_head_4
  end

  @tag :integration
  test "list pipelines by pr_head_branch and pr_target_branch" do
    ppls = Range.new(0, 14) |> Enum.map(fn index -> insert_new_ppl(index) end)

    ppl_id = ppls |> Enum.at(14) |> Map.get(:ppl_id)

    loopers = Test.Helpers.start_all_loopers()
    {:ok, _ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 10_000)
    Test.Helpers.stop_all_loopers(loopers)

    # target branch

    params = %{
      project_id: "123",
      label: :skip,
      yml_file_path: :skip,
      wf_id: :skip,
      created_before: :skip,
      created_after: :skip,
      done_before: :skip,
      done_after: :skip,
      branch_name: :skip,
      git_ref_types: :skip,
      queue_id: :skip,
      pr_head_branch: :skip,
      pr_target_branch: "pr_base"
    }

    result = PplsQueries.list_ppls(params, 2, 3)

    assert {:ok,
            %Scrivener.Page{
              entries: list,
              page_number: 2,
              page_size: 3,
              total_entries: 5,
              total_pages: 2
            }} = result

    # oldest two ppl's should be on the second page
    included = Enum.slice(ppls, 10..11)
    excluded = Enum.slice(ppls, 0..9) ++ Enum.slice(ppls, 12..14)

    assert list_result_contains?(list, included)
    refute list_result_contains?(list, excluded)

    # check if the result is same when optimized listing is used
    result2 = PplsQueries.list_using_requests_only(params, 2, 3)
    assert result == result2

    # head branch

    params = %{
      project_id: "123",
      label: :skip,
      yml_file_path: :skip,
      wf_id: :skip,
      created_before: :skip,
      created_after: :skip,
      done_before: :skip,
      done_after: :skip,
      branch_name: :skip,
      git_ref_types: :skip,
      queue_id: :skip,
      pr_head_branch: "pr_head",
      pr_target_branch: :skip
    }

    result = PplsQueries.list_ppls(params, 2, 3)

    assert {:ok,
            %Scrivener.Page{
              entries: list,
              page_number: 2,
              page_size: 3,
              total_entries: 5,
              total_pages: 2
            }} = result

    # oldest two ppl's should be on the second page
    included = Enum.slice(ppls, 10..11)
    excluded = Enum.slice(ppls, 0..9) ++ Enum.slice(ppls, 12..14)

    assert list_result_contains?(list, included)
    refute list_result_contains?(list, excluded)

    # check if the result is same when optimized listing is used
    result2 = PplsQueries.list_using_requests_only(params, 2, 3)
    assert result == result2
  end

  test "list pipelines correctly handles no ppl found situation " do
    params = %{
      project_id: "123",
      label: :skip,
      yml_file_path: :skip,
      wf_id: :skip,
      created_before: :skip,
      created_after: :skip,
      done_before: :skip,
      done_after: :skip,
      branch_name: "master",
      git_ref_types: :skip,
      queue_id: :skip,
      pr_head_branch: :skip,
      pr_target_branch: :skip
    }

    result = PplsQueries.list_ppls(params, 1, 5)

    assert {:ok,
            %Scrivener.Page{
              entries: [],
              page_number: 1,
              page_size: 5,
              total_entries: 0,
              total_pages: 1
            }} == result

    # check if the result is same when optimized listing is used
    result2 = PplsQueries.list_using_pipelines_only(params, 1, 5)
    assert result == result2
  end

  defp list_result_contains?(results, ppls) do
    Enum.reduce(ppls, true, fn ppl, acc ->
      case acc do
        false -> false
        true -> ppl_id_in_results?(ppl.ppl_id, results)
      end
    end)
  end

  defp ppl_id_in_results?(ppl_id, results),
    do: Enum.find(results, nil, fn %{ppl_id: id} -> id == ppl_id end) != nil

  defp insert_new_ppl(index) do
    request_args =
      %{
        "branch_name" => branch_name(index),
        "commit_sha" => "sha" <> Integer.to_string(index),
        "project_id" => "123",
        "label" => label(index),
        "organization_id" => "abc",
        "pr_branch_name" => "pr_branch",
        "file_name" => file_name(index),
        "working_dir" => ".semaphore",
      }
      |> Test.Helpers.schedule_request_factory(:local)

    job_1 = %{"name" => "job1", "commands" => ["echo foo", "echo bar"]}
    job_2 = %{"name" => "job2", "commands" => ["echo baz"]}
    jobs_list = [job_1, job_2]
    build = %{"jobs" => jobs_list}
    blocks = [%{"build" => build}, %{"build" => build}]
    agent = %{"machine" => %{"type" => "e1-standard-2", "os_image" => "ubuntu1804"}}
    definition = %{"version" => "v1.0", "agent" => agent, "blocks" => blocks}

    request_args = Map.put(request_args, "request_token", UUID.uuid4())
    request_args = Map.put(request_args, "hook_id", hook_id(index))
    request_args = Map.put(request_args, "branch_id", UUID.uuid4())
    assert {:ok, ppl_req} = PplRequestsQueries.insert_request(request_args)
    assert {:ok, ppl_req} = PplRequestsQueries.insert_definition(ppl_req, definition)

    assert {:ok, ppl} = PplsQueries.insert(ppl_req)
    assert {:ok, _ppl_trace} = PplTracesQueries.insert(ppl)
    assert {:ok, _psi} = PplSubInitsQueries.insert(ppl_req, "regular")
    assert {:ok, _ppl_or} = PplOriginsQueries.insert(ppl_req.id, request_args)
    ppl
  end

  defp hook_id(ind) when ind < 5, do: "branch"
  defp hook_id(ind) when ind < 10, do: "tag"
  defp hook_id(_ind), do: "pr"

  defp label(ind) when ind < 5, do: "master"
  defp label(ind) when ind < 10, do: "v1.0.2"
  defp label(_ind), do: "123"

  defp branch_name(ind) when ind < 5, do: "master"
  defp branch_name(ind) when ind < 10, do: "refs/tags/v1.0.2"
  defp branch_name(_ind), do: "pull-request-123"

  defp file_name(ind) when rem(ind, 2) == 1, do: "semaphore.yml"
  defp file_name(_ind), do: "deploy.yml"

  @tag :integration
  test "get running pipeline from same queue" do
    loopers = start_loopers_running()

    {:ok, %{ppl_id: ppl_id_1}} =
      %{"label" => "master", "project_id" => "123"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    assert {:ok, _ppl_1} = Test.Helpers.wait_for_ppl_state(ppl_id_1, "running", 3_000)

    {:ok, %{ppl_id: ppl_id_2}} =
      %{"label" => "master", "project_id" => "123"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    assert {:ok, _ppl_2} = Test.Helpers.wait_for_ppl_state(ppl_id_2, "queuing", 3_000)

    assert {:ok, ppl_2} = PplsQueries.get_by_id(ppl_id_2)

    assert {:ok, [result]} = PplsQueries.ppls_from_same_queue_in_states(ppl_2, ["running"])
    assert {:ok, result} == PplsQueries.get_by_id(ppl_id_1)

    Test.Helpers.stop_all_loopers(loopers)
  end

  defp start_loopers_running() do
    []
    # Ppls loopers
    |> Enum.concat([Ppl.Ppls.STMHandler.InitializingState.start_link()])
    |> Enum.concat([Ppl.Ppls.STMHandler.PendingState.start_link()])
    |> Enum.concat([Ppl.Ppls.STMHandler.QueuingState.start_link()])
    # PplSubInits loopers
    |> Enum.concat([Ppl.PplSubInits.STMHandler.CreatedState.start_link()])
    |> Enum.concat([Ppl.PplSubInits.STMHandler.FetchingState.start_link()])
    |> Enum.concat([Ppl.PplSubInits.STMHandler.CompilationState.start_link()])
    |> Enum.concat([Ppl.PplSubInits.STMHandler.RegularInitState.start_link()])
  end

  @tag :integration
  test "ppls_from_same_queue_in_states() only looks for ppls from same queue" do
    loopers = start_loopers_running()

    {:ok, %{ppl_id: ppl_id_1}} =
      %{"label" => "master", "project_id" => "123"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    assert {:ok, _ppl_1} = Test.Helpers.wait_for_ppl_state(ppl_id_1, "running", 3_000)

    assert {:ok, ppl_1} = PplsQueries.get_by_id(ppl_id_1)

    {:ok, %{ppl_id: ppl_id_2}} =
      %{"label" => "dev", "project_id" => "123"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    assert {:ok, _ppl_2} = Test.Helpers.wait_for_ppl_state(ppl_id_2, "running", 3_000)

    assert {:ok, ppl_2} = PplsQueries.get_by_id(ppl_id_2)
    assert ppl_1.queue_id != ppl_2.queue_id

    assert {:ok, []} = PplsQueries.ppls_from_same_queue_in_states(ppl_2, ["running"])

    {:ok, %{ppl_id: ppl_id_3}} =
      %{"label" => "dev", "project_id" => "123"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    assert {:ok, _ppl_3} = Test.Helpers.wait_for_ppl_state(ppl_id_3, "queuing", 3_000)

    assert {:ok, ppl_3} = PplsQueries.get_by_id(ppl_id_3)
    assert ppl_2.queue_id == ppl_3.queue_id

    assert {:ok, [result]} = PplsQueries.ppls_from_same_queue_in_states(ppl_3, ["running"])
    assert result == ppl_2

    Test.Helpers.stop_all_loopers(loopers)
  end

  test "get pipeline in initializing and move it to scheduling", ctx do
    v1(:to_scheduling_from, ["initializing"], ctx)
    v3(:to_scheduling_from, ["initializing"], ctx)
  end

  test "get pipeline in pending and move it to scheduling", ctx do
    v1(:to_scheduling_from, ["pending"], ctx)
    v3(:to_scheduling_from, ["pending"], ctx)
  end

  test "get pipeline in queuing and move it to scheduling", ctx do
    v1(:to_scheduling_from, ["queuing"], ctx)
    v3(:to_scheduling_from, ["queuing"], ctx)
  end

  test "get pipeline in running and move it to scheduling", ctx do
    v1(:to_scheduling_from, ["running"], ctx)
    v3(:to_scheduling_from, ["running"], ctx)
  end

  test "get pipeline in stopping and move it to scheduling", ctx do
    v1(:to_scheduling_from, ["stopping"], ctx)
    v3(:to_scheduling_from, ["stopping"], ctx)
  end

  test "move pipeline from initializing-scheduling to pending", ctx do
    v1(:from_x_scheduling_to, ["initializing", "pending"], ctx)
    v3(:from_x_scheduling_to, ["initializing", "pending"], ctx)
  end

  test "move pipeline from initializing-scheduling to done", ctx do
    v1(:from_x_scheduling_to, ["initializing", "done"], ctx)
    v3(:from_x_scheduling_to, ["initializing", "done"], ctx)
  end

  test "move pipeline from pending to running", ctx do
    v1(:from_x_scheduling_to, ["pending", "running"], ctx)
    v3(:from_x_scheduling_to, ["pending", "running"], ctx)
  end

  test "move pipeline from pending to queuing", ctx do
    v1(:from_x_scheduling_to, ["pending", "queuing"], ctx)
    v3(:from_x_scheduling_to, ["pending", "queuing"], ctx)
  end

  test "move pipeline from queuing to running", ctx do
    v1(:from_x_scheduling_to, ["queuing", "running"], ctx)
    v3(:from_x_scheduling_to, ["queuing", "running"], ctx)
  end

  test "move pipeline from running to stopping", ctx do
    v1(:from_x_scheduling_to, ["running", "stopping"], ctx)
    v3(:from_x_scheduling_to, ["running", "stopping"], ctx)
  end

  test "move pipeline from running to done", ctx do
    v1(:from_x_scheduling_to, ["running", "done"], ctx)
    v3(:from_x_scheduling_to, ["running", "done"], ctx)
  end

  test "move pipeline from stopping to done", ctx do
    v1(:from_x_scheduling_to, ["stopping", "done"], ctx)
    v3(:from_x_scheduling_to, ["stopping", "done"], ctx)
  end

  test "recover pipelines stuck in scheduling", ctx do
    stuck_ppl = create_event(ctx, "initializing", true)
    id = stuck_ppl.id
    recover_stuck_in_scheduling(stuck_ppl)

    change_state_and_test(id, "pending")
    change_state_and_test(id, "queuing")
    change_state_and_test(id, "running")
    change_state_and_test(id, "stopping")
    change_state_and_test(id, "done")
  end

  defp change_state_and_test(id, state) do
    Ppls
    |> Repo.get(id)
    |> Ppls.changeset(%{in_scheduling: true, state: state})
    |> Repo.update()
    |> elem(1)
    |> recover_stuck_in_scheduling()
  end

  defp beholder_params() do
    %{
      repo: Ppl.EctoRepo,
      query: Ppl.Ppls.Model.Ppls,
      threshold_sec: -2,
      threshold_count: 5,
      terminal_state: "done",
      result_on_abort: "failed",
      result_reason_on_abort: "stuck",
      excluded_states: ["done"]
    }
  end

  # Recover all Ppls stuck in scheduling and check if one of them has passed id value
  defp recover_stuck_in_scheduling(ppl) do
    {_, recovered} = beholder_params() |> Looper.Beholder.Query.recover_stuck()

    Enum.find(recovered, fn recovered_ppl -> recovered_ppl.id == ppl.id end)
    |> recover_stuck_in_scheduling_(ppl.state)
  end

  # Ppls in "done" are not recovered
  defp recover_stuck_in_scheduling_(ppl, "done"), do: assert(ppl == nil)
  # Ppls in other states are recovered - moved out of scheduling
  defp recover_stuck_in_scheduling_(ppl, _state) do
    assert ppl.in_scheduling == false
  end

  test "updated_at change on update_all() call", ctx do
    test_updated_at(ctx.ppl_req.definition)
    test_updated_at(ctx.ppl_req_v3.definition)
  end

  defp test_updated_at(definition) do
    request = Test.Helpers.schedule_request_factory(:local)

    {:ok, ppl_req} = PplRequestsQueries.insert_request(request)
    {:ok, ppl_req} = PplRequestsQueries.insert_definition(ppl_req, definition)

    func = fn ppl_req -> PplsQueries.insert(ppl_req) end
    ppl = assert_ppl_updated_at_set_properly(func, ppl_req)

    func = fn _ -> to_scheduling("initializing") end
    ppl_returned = assert_ppl_updated_at_set_properly(func, ppl)
    assert ppl.id == ppl_returned.id

    func = fn ppl -> to_state(ppl, "done") end
    ppl_returned = assert_ppl_updated_at_set_properly(func, ppl_returned)
    assert ppl.id == ppl_returned.id
  end

  defp assert_ppl_updated_at_set_properly(func, args) do
    before_func = DateTime.utc_now() |> DateTime.to_naive()
    {:ok, ppl} = func.(args)
    after_func = DateTime.utc_now() |> DateTime.to_naive()
    assert NaiveDateTime.compare(before_func, ppl.updated_at) == :lt
    assert NaiveDateTime.compare(after_func, ppl.updated_at) == :gt
    ppl
  end

  defp v1(fun, args, ctx) do
    ctx = Map.delete(ctx, :ppl_v3_id)
    ctx = Map.delete(ctx, :ppl_reql_v3)
    args = args ++ [ctx, "v1.0"]
    apply(__MODULE__, fun, args)
  end

  defp v3(fun, args, ctx) do
    ctx = Map.put(ctx, :ppl_id, Map.get(ctx, :ppl_v3_id))
    ctx = Map.put(ctx, :ppl_req, Map.get(ctx, :ppl_req))
    ctx = Map.delete(ctx, :ppl_req_v3_id)
    ctx = Map.delete(ctx, :ppl_req_v3)
    args = args ++ [ctx, "v3.0"]
    apply(__MODULE__, fun, args)
  end

  def query_params() do
    %{
      initial_query: Ppl.Ppls.Model.Ppls,
      cooling_time_sec: -2,
      repo: Ppl.EctoRepo,
      schema: Ppl.Ppls.Model.Ppls,
      returning: [:id, :ppl_id],
      allowed_states: ~w(initializing pending queuing running stopping done)
    }
  end

  def to_scheduling(state) do
    params = query_params() |> Map.put(:observed_state, state)
    {:ok, %{enter_transition: ppl}} = Looper.STM.Impl.enter_scheduling(params)
    {:ok, ppl}
  end

  def to_state(ppl, state) do
    args = query_params()
    Looper.STM.Impl.exit_scheduling(ppl, fn _, _ -> {:ok, %{state: state}} end, args)
    PplsQueries.get_by_id(ppl.ppl_id)
  end

  def to_scheduling_from(state, ctx, _version) do
    _ppl = create_event(ctx, state, false)
    assert {:ok, ppl} = to_scheduling(state)
    assert ppl.state == state
    assert ppl.in_scheduling == true
  end

  def from_x_scheduling_to(from_state, to_state, ctx, _version) do
    ppl = create_event(ctx, from_state, true)
    to_state(ppl, to_state)
    {:ok, ppl} = to_state(ppl, to_state)
    assert ppl.state == to_state
    assert ppl.in_scheduling == false
  end

  defp create_event(ctx, state, in_scheduling) do
    params = event_params(ctx, state, in_scheduling)
    {:ok, ppl} = %Ppls{} |> Ppls.changeset(params) |> Repo.insert()
    assert ppl.state == state
    assert ppl.in_scheduling == in_scheduling
    ppl
  end

  defp event_params(ctx, state, in_scheduling) do
    ctx
    |> Map.merge(%{state: state, in_scheduling: in_scheduling})
    |> Map.put(:owner, "#{UUID.uuid4()}")
    |> Map.put(:repo_name, "#{UUID.uuid4()}")
    |> Map.put(:branch_name, "#{UUID.uuid4()}")
    |> Map.put(:commit_sha, "#{UUID.uuid4()}")
    |> Map.put(:project_id, "#{UUID.uuid4()}")
    |> Map.put(:yml_file_path, "#{UUID.uuid4()}")
    |> Map.put(:label, "#{UUID.uuid4()}")
  end
end
