defmodule Ppl.DefinitionReviser.BlocksReviser.Test do
  use ExUnit.Case

  alias Ppl.DefinitionReviser.BlocksReviser
  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias InternalApi.User.DescribeResponse
  alias InternalApi.User.RepositoryProvider
  alias Ppl.Actions
  alias Util.Proto

  @url_env_name "INTERNAL_API_URL_USER"

  setup_all do
    Test.Support.GrpcServerHelper.start_server_with_cleanup(UserServiceMock)
  end

  setup %{port: port} do
    Test.Support.GrpcServerHelper.setup_service_url(@url_env_name, port)
    :ok
  end

  setup do
    assert {:ok, %{ppl_id: ppl_id}} =
      Test.Helpers.schedule_request_factory(%{}, :local)
      |> Actions.schedule()

    assert {:ok, real_ppl_req} = PplRequestsQueries.get_by_id(ppl_id)

    agent = %{"machine" => %{"type" => "e1-standard-2", "os_image" => "ubuntu1804"}}
    blocks = [%{"build" => %{}, "name" => "blk 0"}, %{"build" => %{}, "name" => "blk 1"}]
    ppl_def = %{"agent" => agent, "blocks" => blocks, "name" => "Test Pipeline"}
    args = %{"service" => "local", "repo_name" => "4_cmd_file", "branch_name" => "master",
            "commit_sha" => "sha_1", "working_dir" => ".semaphore", "file_name" => "semaphore.yml",
            "organization_id" => "test-org-id-123"}
    source_args = %{"repo_host_username" => "gh_username_1", "commit_author" => "gh_username_2"}
    ppl_req = %{id: ppl_id, request_args: args, source_args: source_args, wf_id: real_ppl_req.wf_id, top_level: true,
                prev_ppl_artefact_ids: [], ppl_artefact_id: "A1", initial_request: true}
    {:ok, %{ppl_req: ppl_req, ppl_def: ppl_def, agent: agent, req_args: args}}
  end

  @ppl_id_env_var_name "SEMAPHORE_PIPELINE_ID"
  @ppl_name_env_var_name "SEMAPHORE_PIPELINE_NAME"
  @artefact_id_env_var_name "SEMAPHORE_PIPELINE_ARTEFACT_ID"
  @block_name "SEMAPHORE_BLOCK_NAME"
  @pipeline_rerun "SEMAPHORE_PIPELINE_RERUN"
  @pipeline_promotion "SEMAPHORE_PIPELINE_PROMOTION"
  @pipeline_promoted_by "SEMAPHORE_PIPELINE_PROMOTED_BY"
  @workflow_id_env_var_name "SEMAPHORE_WORKFLOW_ID"
  @workflow_number_env_var_name "SEMAPHORE_WORKFLOW_NUMBER"
  @workflow_rerun "SEMAPHORE_WORKFLOW_RERUN"
  @workflow_triggered_by_hook "SEMAPHORE_WORKFLOW_TRIGGERED_BY_HOOK"
  @workflow_hook_source "SEMAPHORE_WORKFLOW_HOOK_SOURCE"
  @workflow_triggered_by_schedule "SEMAPHORE_WORKFLOW_TRIGGERED_BY_SCHEDULE"
  @workflow_triggered_by_api "SEMAPHORE_WORKFLOW_TRIGGERED_BY_API"
  @workflow_triggered_by_manual_run "SEMAPHORE_WORKFLOW_TRIGGERED_BY_MANUAL_RUN"
  @workflow_triggered_by "SEMAPHORE_WORKFLOW_TRIGGERED_BY"
  @git_commit_author "SEMAPHORE_GIT_COMMIT_AUTHOR"
  @git_committer "SEMAPHORE_GIT_COMMITTER"
  @organization_id "SEMAPHORE_ORGANIZATION_ID"

  test "BlocksReviser correctly sets agent", ctx do
    agent = %{"machine" => %{"type" => "e1-standard-4", "os_image" => "ubuntu1804"}}
    blks = [%{"build" => %{}}, %{"build" => %{"agent" => agent}}]
    ppl_def = %{ctx.ppl_def | "blocks" => blks}

    assert {:ok, revised_def} = BlocksReviser.revise_blocks_definition(ppl_def, ctx.ppl_req)
    assert %{"blocks" => blocks} = revised_def
    assert is_list(blocks)

    assert block_one = Enum.at(blocks, 0)
    assert is_map(block_one)
    assert get_in(block_one, ["build", "agent"]) == ctx.agent

    assert block_two = Enum.at(blocks, 1)
    assert is_map(block_two)
    assert get_in(block_two, ["build", "agent"]) == agent
  end

  test "BlocksReviser correctly sets ppl_env_vars", ctx do
    assert {:ok, revised_def} = BlocksReviser.revise_blocks_definition(ctx.ppl_def, ctx.ppl_req)
    assert %{"blocks" => blocks} = revised_def
    assert is_list(blocks)

    blocks |> Enum.map(fn block ->
      expected_env_vars = [%{"name" => @workflow_id_env_var_name, "value" => ctx.ppl_req.wf_id},
        %{"name" => @workflow_number_env_var_name, "value" => "1"},
        %{"name" => @workflow_rerun, "value" => "false"},
        %{"name" => @workflow_triggered_by_hook, "value" => "true"},
        %{"name" => @workflow_hook_source, "value" => "github"},
        %{"name" => @workflow_triggered_by_schedule, "value" => "false"},
        %{"name" => @workflow_triggered_by_api, "value" => "false"},
        %{"name" => @workflow_triggered_by_manual_run, "value" => "false"},
        %{"name" => @artefact_id_env_var_name, "value" => "A1"},
        %{"name" => @ppl_id_env_var_name, "value" => ctx.ppl_req.id},
        %{"name" => @ppl_name_env_var_name, "value" => ctx.ppl_def["name"]},
        %{"name" => @block_name, "value" => block["name"]},
        %{"name" => @pipeline_rerun, "value" => "false"},
        %{"name" => @pipeline_promotion, "value" => "false"},
        %{"name" => @pipeline_promoted_by, "value" => ""},
        %{"name" => @workflow_triggered_by, "value" => "gh_username_1"},
        %{"name" => @git_commit_author, "value" => "gh_username_2"},
        %{"name" => @git_committer, "value" => "gh_username_1"},
        %{"name" => @organization_id, "value" => "test-org-id-123"},
        %{"name" => "SEMAPHORE_PIPELINE_0_ARTEFACT_ID", "value" => "A1"}]

      assert is_map(block)
      assert get_in(block, ["build", "ppl_env_variables"]) == expected_env_vars
    end)
  end

  test "BlocksReviser correctly sets ppl_env_vars when there are env vars in request", ctx do
    request_args = ctx.ppl_req.request_args
                   |> Map.merge(%{"env_vars" => [%{"name" => "TEST", "value" => "VALUE"}]})
    request = ctx.ppl_req |> Map.put(:request_args, request_args)
    assert {:ok, revised_def} = BlocksReviser.revise_blocks_definition(ctx.ppl_def, request)
    assert %{"blocks" => blocks} = revised_def
    assert is_list(blocks)

    blocks |> Enum.map(fn block ->
      expected_env_vars = [%{"name" => @workflow_id_env_var_name, "value" => ctx.ppl_req.wf_id},
        %{"name" => @workflow_number_env_var_name, "value" => "1"},
        %{"name" => @workflow_rerun, "value" => "false"},
        %{"name" => @workflow_triggered_by_hook, "value" => "true"},
        %{"name" => @workflow_hook_source, "value" => "github"},
        %{"name" => @workflow_triggered_by_schedule, "value" => "false"},
        %{"name" => @workflow_triggered_by_api, "value" => "false"},
        %{"name" => @workflow_triggered_by_manual_run, "value" => "false"},
        %{"name" => @artefact_id_env_var_name, "value" => "A1"},
        %{"name" => @ppl_id_env_var_name, "value" => ctx.ppl_req.id},
        %{"name" => @ppl_name_env_var_name, "value" => ctx.ppl_def["name"]},
        %{"name" => @block_name, "value" => block["name"]},
        %{"name" => @pipeline_rerun, "value" => "false"},
        %{"name" => @pipeline_promotion, "value" => "false"},
        %{"name" => @pipeline_promoted_by, "value" => ""},
        %{"name" => @workflow_triggered_by, "value" => "gh_username_1"},
        %{"name" => @git_commit_author, "value" => "gh_username_2"},
        %{"name" => @git_committer, "value" => "gh_username_1"},
        %{"name" => @organization_id, "value" => "test-org-id-123"},
        %{"name" => "SEMAPHORE_PIPELINE_0_ARTEFACT_ID", "value" => "A1"},
        %{"name" => "TEST", "value" => "VALUE"}]

      assert is_map(block)
      assert get_in(block, ["build", "ppl_env_variables"]) == expected_env_vars
    end)
  end

  test "BlocksReviser correctly sets ppl_env_vars when prev_ppl_artefact_ids is not empty", ctx do
    ppl_req = ctx.ppl_req |> Map.put(:prev_ppl_artefact_ids, ["Previous id value"])
    assert {:ok, revised_def} = BlocksReviser.revise_blocks_definition(ctx.ppl_def, ppl_req)
    assert %{"blocks" => blocks} = revised_def
    assert is_list(blocks)
    blocks |> Enum.map(fn block ->
      expected_env_vars = [%{"name" => @workflow_id_env_var_name, "value" => ctx.ppl_req.wf_id},
        %{"name" => @workflow_number_env_var_name, "value" => "1"},
        %{"name" => @workflow_rerun, "value" => "false"},
        %{"name" => @workflow_triggered_by_hook, "value" => "true"},
        %{"name" => @workflow_hook_source, "value" => "github"},
        %{"name" => @workflow_triggered_by_schedule, "value" => "false"},
        %{"name" => @workflow_triggered_by_api, "value" => "false"},
        %{"name" => @workflow_triggered_by_manual_run, "value" => "false"},
        %{"name" => @artefact_id_env_var_name, "value" => "A1"},
        %{"name" => @ppl_id_env_var_name, "value" => ctx.ppl_req.id},
        %{"name" => @ppl_name_env_var_name, "value" => ctx.ppl_def["name"]},
        %{"name" => @block_name, "value" => block["name"]},
        %{"name" => @pipeline_rerun, "value" => "false"},
        %{"name" => @pipeline_promotion, "value" => "false"},
        %{"name" => @pipeline_promoted_by, "value" => ""},
        %{"name" => @workflow_triggered_by, "value" => "gh_username_1"},
        %{"name" => @git_commit_author, "value" => "gh_username_2"},
        %{"name" => @git_committer, "value" => "gh_username_1"},
        %{"name" => @organization_id, "value" => "test-org-id-123"},
        %{"name" => "SEMAPHORE_PIPELINE_0_ARTEFACT_ID", "value" => "Previous id value"},
        %{"name" => "SEMAPHORE_PIPELINE_1_ARTEFACT_ID", "value" => "A1"}]

      assert is_map(block)
      assert get_in(block, ["build", "ppl_env_variables"]) == expected_env_vars
    end)
  end

  test "BlocksReviser correctly sets secrets in global job config when there are secrets in request", ctx do
    ppl_def = Map.update(ctx.ppl_def, "global_job_config",
                %{"secrets" => [%{"name" => "secret789"}]},
                &Map.put(&1, "secrets", [%{"name" => "secret789"}]))
    request_args = ctx.ppl_req.request_args
                   |> Map.merge(%{"request_secrets" => [%{"name" => "secret123"}, %{"name" => "secret456"}]})
    request = ctx.ppl_req |> Map.put(:request_args, request_args)
    assert {:ok, revised_def} = BlocksReviser.revise_blocks_definition(ppl_def, request)
    assert %{"blocks" => blocks} = revised_def
    assert is_list(blocks)

    expected_secrets = [%{"name" => "secret123"}, %{"name" => "secret456"}, %{"name" => "secret789"}]

    blocks |> Enum.map(fn block ->
      assert is_map(block)
      assert get_in(block, ["build", "secrets"]) == expected_secrets
    end)
  end

  test "BlocksReviser sets promoted_by from the promoter and triggered_by from the webhook in promotions", ctx do
    req_args = ctx.req_args |> Map.put("promoter_id", "user_id_1") |> Map.put("requester_id", "user_id_2")
    ppl_req = ctx.ppl_req |> Map.put(:request_args, req_args)

    UserServiceMock
    |> GrpcMock.expect(:describe, 2, fn
      %{user_id: "user_id_1"}, _ ->
        %{github_login: "github_username_1", status: %{code: 0}}
        |> Proto.deep_new!(DescribeResponse)
      %{user_id: "user_id_2"}, _ ->
        %{github_login: "github_username_2", status: %{code: 0}}
        |> Proto.deep_new!(DescribeResponse)
    end)

    assert {:ok, revised_def} = BlocksReviser.revise_blocks_definition(ctx.ppl_def, ppl_req)
    assert %{"blocks" => blocks} = revised_def
    assert is_list(blocks)

    blocks |> Enum.map(fn block ->
      expected_env_vars = [%{"name" => @workflow_id_env_var_name, "value" => ctx.ppl_req.wf_id},
        %{"name" => @workflow_number_env_var_name, "value" => "1"},
        %{"name" => @workflow_rerun, "value" => "false"},
        %{"name" => @workflow_triggered_by_hook, "value" => "true"},
        %{"name" => @workflow_hook_source, "value" => "github"},
        %{"name" => @workflow_triggered_by_schedule, "value" => "false"},
        %{"name" => @workflow_triggered_by_api, "value" => "false"},
        %{"name" => @workflow_triggered_by_manual_run, "value" => "false"},
        %{"name" => @artefact_id_env_var_name, "value" => "A1"},
        %{"name" => @ppl_id_env_var_name, "value" => ctx.ppl_req.id},
        %{"name" => @ppl_name_env_var_name, "value" => ctx.ppl_def["name"]},
        %{"name" => @block_name, "value" => block["name"]},
        %{"name" => @pipeline_rerun, "value" => "false"},
        %{"name" => @pipeline_promotion, "value" => "false"},
        %{"name" => @pipeline_promoted_by, "value" => "github_username_1"},
        %{"name" => @workflow_triggered_by, "value" => "gh_username_1"},
        %{"name" => @git_commit_author, "value" => "gh_username_2"},
        %{"name" => @git_committer, "value" => "gh_username_1"},
        %{"name" => @organization_id, "value" => "test-org-id-123"},
        %{"name" => "SEMAPHORE_PIPELINE_0_ARTEFACT_ID", "value" => "A1"}]
      assert is_map(block)
      assert get_in(block, ["build", "ppl_env_variables"]) == expected_env_vars
    end)

    GrpcMock.verify!(UserServiceMock)
  end

  describe "SEMAPHORE_WORKFLOW_TRIGGERED_BY" do
    test "hook pushes name the webhook's pusher, not the requester's stored login", ctx do
      stub_requester([provider(:GITHUB, "github-login"), provider(:GITLAB, "gitlab-login")])

      for service <- ["git_hub", "gitlab", "bitbucket"] do
        ppl_req = with_request_args(ctx.ppl_req, %{"service" => service, "triggered_by" => "hook",
                                                    "requester_id" => "user_id_1"})

        assert triggered_by_env(ctx.ppl_def, ppl_req) == "gh_username_1"
      end
    end

    test "promotions name the workflow triggerer, not the promoter", ctx do
      stub_requester([provider(:GITHUB, "promoter-login")])
      ppl_req = with_request_args(ctx.ppl_req, %{"service" => "git_hub", "triggered_by" => "hook",
                                                  "promoter_id" => "user_id_1"})

      assert triggered_by_env(ctx.ppl_def, ppl_req) == "gh_username_1"
    end

    test "API, scheduled and manual runs name the requester's login on the repo's provider", ctx do
      stub_requester([provider(:GITHUB, "github-login"), provider(:GITLAB, "gitlab-login"),
                      provider(:BITBUCKET, "bitbucket-login")])

      for {service, login} <- [{"git_hub", "github-login"}, {"gitlab", "gitlab-login"},
                               {"bitbucket", "bitbucket-login"}],
          trigger <- ["api", "schedule", "manual_run"] do
        ppl_req = with_request_args(ctx.ppl_req, %{"service" => service, "triggered_by" => trigger,
                                                    "requester_id" => "user_id_1"})

        assert triggered_by_env(ctx.ppl_def, ppl_req) == login
      end
    end

    test "is empty when the requester has no account on the repo's provider", ctx do
      stub_requester([provider(:GITHUB, "github-login")])
      ppl_req = with_request_args(ctx.ppl_req, %{"service" => "bitbucket", "triggered_by" => "api",
                                                  "requester_id" => "user_id_1"})

      assert triggered_by_env(ctx.ppl_def, ppl_req) == ""
    end

    test "is empty for API, scheduled and manual runs without a requester", ctx do
      ppl_req = with_request_args(ctx.ppl_req, %{"service" => "git_hub", "triggered_by" => "schedule"})

      assert triggered_by_env(ctx.ppl_def, ppl_req) == ""
    end

    test "generic Git names the requester's GitHub login, or the hook's author without one", ctx do
      stub_requester([provider(:GITHUB, "github-login")])
      with_requester = with_request_args(ctx.ppl_req, %{"service" => "git", "triggered_by" => "hook",
                                                         "requester_id" => "user_id_1"})
      without_requester = with_request_args(ctx.ppl_req, %{"service" => "git", "triggered_by" => "hook"})

      assert triggered_by_env(ctx.ppl_def, with_requester) == "stored-login"
      assert triggered_by_env(ctx.ppl_def, without_requester) == "gh_username_1"
    end
  end

  defp stub_requester(providers) do
    UserServiceMock
    |> GrpcMock.stub(:describe, fn _, _ ->
      %{github_login: "stored-login", repository_providers: providers, status: %{code: 0}}
      |> Proto.deep_new!(DescribeResponse)
    end)
  end

  defp provider(type, login),
    do: %{type: RepositoryProvider.Type.value(type), login: login, uid: "uid-#{login}"}

  defp with_request_args(ppl_req, args),
    do: Map.update!(ppl_req, :request_args, &Map.merge(&1, args))

  defp triggered_by_env(ppl_def, ppl_req) do
    assert {:ok, %{"blocks" => [block | _]}} = BlocksReviser.revise_blocks_definition(ppl_def, ppl_req)

    block
    |> get_in(["build", "ppl_env_variables"])
    |> Enum.find(fn env_var -> env_var["name"] == @workflow_triggered_by end)
    |> Map.get("value")
  end

  test "old style epilogue commands both in blocks and global are transformed into always commands", ctx do
    global_cfg = %{"epilogue" => %{"commands" => ["echo epilogue"]}}
    blks = [%{"build" => %{}}, %{"build" => %{"epilogue" => %{"commands_file" => "cmd_file_1.sh"}}}]
    ppl_def = %{ctx.ppl_def | "blocks" => blks} |> Map.put("global_job_config", global_cfg)

    assert {:ok, revised_def} = BlocksReviser.revise_blocks_definition(ppl_def, ctx.ppl_req)
    assert %{"blocks" => blocks} = revised_def
    assert is_list(blocks)

    assert block_one = Enum.at(blocks, 0)
    assert is_map(block_one)
    assert get_in(block_one, ["build", "epilogue", "always"]) == %{"commands" => ["echo epilogue"]}

    assert block_two = Enum.at(blocks, 1)
    assert is_map(block_two)
    assert get_in(block_two, ["build", "epilogue", "always"])
           == %{"commands" => ["echo epilogue"], "commands_file" => "cmd_file_1.sh"}
  end

  test "global always, on_pass and on_fail commands are read from cmd_files and merged with ones in block", ctx do
    file = %{"commands_file" => "cmd_file_1.sh"}
    global_cfg = %{"epilogue" => %{"always" => file, "on_pass" => file, "on_fail" => file}}
    blks = [%{"build" => %{"epilogue" => %{"on_pass" => %{"commands" => ["echo first"]}}}},
            %{"build" => %{"epilogue" => %{"commands" => ["echo first"]}}}]
    ppl_def = %{ctx.ppl_def | "blocks" => blks} |> Map.put("global_job_config", global_cfg)

    assert {:ok, revised_def} = BlocksReviser.revise_blocks_definition(ppl_def, ctx.ppl_req)
    assert %{"blocks" => blocks} = revised_def
    assert is_list(blocks)

    assert block_one = Enum.at(blocks, 0)
    assert is_map(block_one)
    assert get_in(block_one, ["build", "epilogue", "always"])
            == %{"commands" => ["echo foo", "echo bar", "echo baz"]}
    assert get_in(block_one, ["build", "epilogue", "on_pass"])
            == %{"commands" => ["echo first", "echo foo", "echo bar", "echo baz"]}
    assert get_in(block_one, ["build", "epilogue", "on_fail"])
            == %{"commands" => ["echo foo", "echo bar", "echo baz"]}

    assert block_two = Enum.at(blocks, 1)
    assert is_map(block_two)
    assert get_in(block_two, ["build", "epilogue", "always"])
            == %{"commands" => ["echo first", "echo foo", "echo bar", "echo baz"]}
    assert get_in(block_two, ["build", "epilogue", "on_pass"])
            == %{"commands" => ["echo foo", "echo bar", "echo baz"]}
    assert get_in(block_two, ["build", "epilogue", "on_fail"])
            == %{"commands" => ["echo foo", "echo bar", "echo baz"]}
  end

  test "priorities in global_job_config are properly merged with the ones on job level", ctx do
    job_1 = %{"name" => "Job 1", "priority" => [%{"value" => 20, "when" => true}]}
    job_2 = %{"name" => "Job 2", "priority" => [%{"value" => 32, "when" => true}]}
    job_3 = %{"name" => "Job 3", "priority" => [%{"value" => 42, "when" => true}]}

    blks = [%{"build" => %{"jobs" => [job_1, job_2]}}, %{"build" => %{"jobs" => [job_3]}}]

    global_cfg = %{"priority" => [%{"value" => 75, "when" => "branch = 'master'"},
                                  %{"value" => 56, "when" => "branch = 'dev'"}]}

    ppl_def = %{ctx.ppl_def | "blocks" => blks} |> Map.put("global_job_config", global_cfg)

    assert {:ok, revised_def} = BlocksReviser.revise_blocks_definition(ppl_def, ctx.ppl_req)
    assert %{"blocks" => blocks} = revised_def

    assert jobs_b1 = Enum.at(blocks, 0) |> get_in(["build", "jobs"])
    assert Enum.at(jobs_b1, 0) |> Map.get("priority")
          == [%{"value" => 20, "when" => true},
              %{"value" => 75, "when" => "branch = 'master'"},
              %{"value" => 56, "when" => "branch = 'dev'"}]

    assert Enum.at(jobs_b1, 1) |> Map.get("priority")
          == [%{"value" => 32, "when" => true},
              %{"value" => 75, "when" => "branch = 'master'"},
              %{"value" => 56, "when" => "branch = 'dev'"}]

    assert jobs_b2 = Enum.at(blocks, 1) |> get_in(["build", "jobs"])
    assert Enum.at(jobs_b2, 0) |> Map.get("priority")
          == [%{"value" => 42, "when" => true},
              %{"value" => 75, "when" => "branch = 'master'"},
              %{"value" => 56, "when" => "branch = 'dev'"}]
  end

  test "priorities only on job level => nothing is changed", ctx do
    job_1 = %{"name" => "Job 1", "priority" => [%{"value" => 20, "when" => true}]}
    job_2 = %{"name" => "Job 2", "priority" => [%{"value" => 32, "when" => true}]}
    job_3 = %{"name" => "Job 3", "priority" => [%{"value" => 42, "when" => true}]}

    global_cfg = %{"epilogue" => %{"always" => %{"commands_file" => "cmd_file_1.sh"}}}

    blks = [%{"build" => %{"jobs" => [job_1, job_2]}}, %{"build" => %{"jobs" => [job_3]}}]

    ppl_def = %{ctx.ppl_def | "blocks" => blks} |> Map.put("global_job_config", global_cfg)

    assert {:ok, revised_def} = BlocksReviser.revise_blocks_definition(ppl_def, ctx.ppl_req)
    assert %{"blocks" => blocks} = revised_def

    assert jobs_b1 = Enum.at(blocks, 0) |> get_in(["build", "jobs"])
    assert Enum.at(jobs_b1, 0) |> Map.get("priority")
          == [%{"value" => 20, "when" => true}]

    assert Enum.at(jobs_b1, 1) |> Map.get("priority")
          == [%{"value" => 32, "when" => true}]

    assert jobs_b2 = Enum.at(blocks, 1) |> get_in(["build", "jobs"])
    assert Enum.at(jobs_b2, 0) |> Map.get("priority")
          == [%{"value" => 42, "when" => true}]
  end

  test "priorities only in global_job_config are exported into each job", ctx do
    blks = [%{"build" => %{"jobs" => [%{"name" => "Job 1"}, %{"name" => "Job 2"}]}},
            %{"build" => %{"jobs" => [%{"name" => "Job 3"}]}}]

    global_cfg = %{"priority" => [%{"value" => 75, "when" => "branch = 'master'"},
                                  %{"value" => 56, "when" => "branch = 'dev'"}]}

    ppl_def = %{ctx.ppl_def | "blocks" => blks} |> Map.put("global_job_config", global_cfg)

    assert {:ok, revised_def} = BlocksReviser.revise_blocks_definition(ppl_def, ctx.ppl_req)
    assert %{"blocks" => blocks} = revised_def

    assert jobs_b1 = Enum.at(blocks, 0) |> get_in(["build", "jobs"])
    assert Enum.at(jobs_b1, 0) |> Map.get("priority")
          == [%{"value" => 75, "when" => "branch = 'master'"},
              %{"value" => 56, "when" => "branch = 'dev'"}]

    assert Enum.at(jobs_b1, 1) |> Map.get("priority")
          == [%{"value" => 75, "when" => "branch = 'master'"},
              %{"value" => 56, "when" => "branch = 'dev'"}]

    assert jobs_b2 = Enum.at(blocks, 1) |> get_in(["build", "jobs"])
    assert Enum.at(jobs_b2, 0) |> Map.get("priority")
          == [%{"value" => 75, "when" => "branch = 'master'"},
              %{"value" => 56, "when" => "branch = 'dev'"}]
  end
end
