defmodule Zebra.Workers.JobRequestFactory.OpenIDConnectTest do
  use Zebra.DataCase

  alias Zebra.Workers.JobRequestFactory.{JobRequest, OpenIDConnect}

  describe "load/6" do
    setup do
      {:ok, task} = Support.Factories.Task.create()
      {:ok, job} = Support.Factories.Job.create(:pending, %{build_id: task.id})

      test_pid = self()

      GrpcMock.stub(Support.FakeServers.SecretsApi, :generate_open_id_connect_token, fn req, _ ->
        send(test_pid, {:oidc_request, req})
        InternalApi.Secrethub.GenerateOpenIDConnectTokenResponse.new(token: "token")
      end)

      spec_env_vars = [JobRequest.env_var("SEMAPHORE_WORKFLOW_TRIGGERED_BY_HOOK", "true")]

      {:ok,
       job: job,
       org: %{org_username: "testorg"},
       project: %{name: "test-project"},
       spec_env_vars: spec_env_vars}
    end

    test "sends the tag name as git_tag for tag builds", ctx do
      repo_env_vars = [
        JobRequest.env_var("SEMAPHORE_GIT_REF_TYPE", "tag"),
        JobRequest.env_var("SEMAPHORE_GIT_REF", "refs/tags/v1.2.3"),
        JobRequest.env_var("SEMAPHORE_GIT_BRANCH", "refs/tags/v1.2.3"),
        JobRequest.env_var("SEMAPHORE_GIT_TAG_NAME", "v1.2.3")
      ]

      assert {:ok, [%{"name" => "SEMAPHORE_OIDC_TOKEN"}]} =
               OpenIDConnect.load(
                 ctx.job,
                 repo_env_vars,
                 ctx.org,
                 ctx.project,
                 :pipeline_job,
                 ctx.spec_env_vars
               )

      assert_receive {:oidc_request, req}
      assert req.git_tag == "v1.2.3"
      assert req.git_ref_type == "tag"
    end

    test "sends an empty git_tag for branch builds", ctx do
      repo_env_vars = [
        JobRequest.env_var("SEMAPHORE_GIT_REF_TYPE", "branch"),
        JobRequest.env_var("SEMAPHORE_GIT_REF", "refs/heads/main"),
        JobRequest.env_var("SEMAPHORE_GIT_BRANCH", "main")
      ]

      assert {:ok, [%{"name" => "SEMAPHORE_OIDC_TOKEN"}]} =
               OpenIDConnect.load(
                 ctx.job,
                 repo_env_vars,
                 ctx.org,
                 ctx.project,
                 :pipeline_job,
                 ctx.spec_env_vars
               )

      assert_receive {:oidc_request, req}
      assert req.git_tag == ""
      assert req.git_branch_name == "main"
    end

    test "sends the workflow triggerer's provider login as user_id", ctx do
      spec_env_vars =
        ctx.spec_env_vars ++
          [
            JobRequest.env_var("SEMAPHORE_WORKFLOW_TRIGGERED_BY", "stored-login"),
            JobRequest.env_var("SEMAPHORE_WORKFLOW_TRIGGERED_BY_PROVIDER_LOGIN", "pusher")
          ]

      assert load_user_id(ctx, spec_env_vars) == "pusher"
    end

    test "sends the workflow triggerer, not the promoter, for promotions", ctx do
      for promoted_by <- ["promoter", "auto-promotion"] do
        spec_env_vars =
          ctx.spec_env_vars ++
            [
              JobRequest.env_var("SEMAPHORE_WORKFLOW_TRIGGERED_BY_PROVIDER_LOGIN", "pusher"),
              JobRequest.env_var("SEMAPHORE_PIPELINE_PROMOTION", "true"),
              JobRequest.env_var("SEMAPHORE_PIPELINE_PROMOTED_BY", promoted_by)
            ]

        assert load_user_id(ctx, spec_env_vars) == "pusher"
      end
    end

    test "sends an empty user_id when the provider login is missing", ctx do
      spec_env_vars =
        ctx.spec_env_vars ++
          [JobRequest.env_var("SEMAPHORE_WORKFLOW_TRIGGERED_BY", "stored-login")]

      assert load_user_id(ctx, spec_env_vars) == ""
    end

    test "sends an empty user_id for debug jobs", ctx do
      spec_env_vars =
        ctx.spec_env_vars ++
          [JobRequest.env_var("SEMAPHORE_WORKFLOW_TRIGGERED_BY_PROVIDER_LOGIN", "pusher")]

      assert load_user_id(ctx, spec_env_vars, :debug_job) == ""
      assert load_user_id(ctx, spec_env_vars, :project_debug_job) == ""
    end

    test "ignores user-supplied duplicates appended after the platform env vars", ctx do
      spec_env_vars =
        ctx.spec_env_vars ++
          [
            JobRequest.env_var("SEMAPHORE_WORKFLOW_TRIGGERED_BY_PROVIDER_LOGIN", "pusher"),
            JobRequest.env_var("SEMAPHORE_WORKFLOW_TRIGGERED_BY_PROVIDER_LOGIN", "spoofed")
          ]

      assert load_user_id(ctx, spec_env_vars) == "pusher"
    end
  end

  defp load_user_id(ctx, spec_env_vars, job_type \\ :pipeline_job) do
    assert {:ok, [%{"name" => "SEMAPHORE_OIDC_TOKEN"}]} =
             OpenIDConnect.load(ctx.job, [], ctx.org, ctx.project, job_type, spec_env_vars)

    assert_receive {:oidc_request, req}
    req.user_id
  end

  describe "construct_triggerer/1" do
    test "constructs triggerer with API workflow trigger" do
      env_vars = [
        %{"name" => "SEMAPHORE_WORKFLOW_TRIGGERED_BY_API", "value" => Base.encode64("true")},
        %{"name" => "SEMAPHORE_WORKFLOW_RERUN", "value" => Base.encode64("false")},
        %{"name" => "SEMAPHORE_PIPELINE_PROMOTED_BY", "value" => Base.encode64("")},
        %{"name" => "SEMAPHORE_PIPELINE_PROMOTION", "value" => Base.encode64("false")},
        %{"name" => "SEMAPHORE_PIPELINE_RERUN", "value" => Base.encode64("false")}
      ]

      result = OpenIDConnect.construct_triggerer("", "", "", env_vars, :pipeline_job)
      assert result == "a:f-i:f"
    end

    test "constructs triggerer with SCHEDULE workflow trigger" do
      env_vars = [
        %{"name" => "SEMAPHORE_WORKFLOW_TRIGGERED_BY_SCHEDULE", "value" => Base.encode64("true")},
        %{"name" => "SEMAPHORE_WORKFLOW_RERUN", "value" => Base.encode64("true")},
        %{"name" => "SEMAPHORE_PIPELINE_PROMOTED_BY", "value" => Base.encode64("gh-user")},
        %{"name" => "SEMAPHORE_PIPELINE_PROMOTION", "value" => Base.encode64("true")},
        %{"name" => "SEMAPHORE_PIPELINE_RERUN", "value" => Base.encode64("true")}
      ]

      result = OpenIDConnect.construct_triggerer("", "", "", env_vars, :pipeline_job)

      assert result ==
               "s:t-n:t"
    end

    test "constructs triggerer with MANUAL_RUN workflow trigger" do
      env_vars = [
        %{
          "name" => "SEMAPHORE_WORKFLOW_TRIGGERED_BY_MANUAL_RUN",
          "value" => Base.encode64("true")
        },
        %{"name" => "SEMAPHORE_WORKFLOW_RERUN", "value" => Base.encode64("false")},
        %{"name" => "SEMAPHORE_PIPELINE_PROMOTED_BY", "value" => Base.encode64("user")},
        %{"name" => "SEMAPHORE_PIPELINE_PROMOTION", "value" => Base.encode64("false")},
        %{"name" => "SEMAPHORE_PIPELINE_RERUN", "value" => Base.encode64("false")}
      ]

      result = OpenIDConnect.construct_triggerer("", "", "", env_vars, :pipeline_job)
      assert result == "m:f-i:f"
    end

    test "constructs triggerer with HOOK workflow trigger" do
      env_vars = [
        %{"name" => "SEMAPHORE_WORKFLOW_TRIGGERED_BY_HOOK", "value" => Base.encode64("true")},
        %{"name" => "SEMAPHORE_WORKFLOW_RERUN", "value" => Base.encode64("true")},
        %{"name" => "SEMAPHORE_PIPELINE_PROMOTED_BY", "value" => Base.encode64("auto-promotion")},
        %{"name" => "SEMAPHORE_PIPELINE_PROMOTION", "value" => Base.encode64("true")},
        %{"name" => "SEMAPHORE_PIPELINE_RERUN", "value" => Base.encode64("true")}
      ]

      result = OpenIDConnect.construct_triggerer("", "", "", env_vars, :pipeline_job)
      assert result == "h:t-u:t"
    end

    test "constructs triggerer with manual promotion" do
      env_vars = [
        %{"name" => "SEMAPHORE_WORKFLOW_TRIGGERED_BY_API", "value" => Base.encode64("false")},
        %{
          "name" => "SEMAPHORE_WORKFLOW_TRIGGERED_BY_MANUAL_RUN",
          "value" => Base.encode64("true")
        },
        %{"name" => "SEMAPHORE_PIPELINE_PROMOTED_BY", "value" => Base.encode64("user")},
        %{"name" => "SEMAPHORE_PIPELINE_PROMOTION", "value" => Base.encode64("true")},
        %{"name" => "SEMAPHORE_PIPELINE_RERUN", "value" => Base.encode64("false")}
      ]

      result = OpenIDConnect.construct_triggerer("", "", "", env_vars, :pipeline_job)

      assert result ==
               "m:f-n:f"
    end

    test "constructs triggerer with manual promotion for debug job" do
      env_vars = [
        %{"name" => "SEMAPHORE_WORKFLOW_TRIGGERED_BY_API", "value" => Base.encode64("false")},
        %{
          "name" => "SEMAPHORE_WORKFLOW_TRIGGERED_BY_MANUAL_RUN",
          "value" => Base.encode64("true")
        },
        %{"name" => "SEMAPHORE_PIPELINE_PROMOTED_BY", "value" => Base.encode64("user")},
        %{"name" => "SEMAPHORE_PIPELINE_PROMOTION", "value" => Base.encode64("true")},
        %{"name" => "SEMAPHORE_PIPELINE_RERUN", "value" => Base.encode64("false")}
      ]

      result = OpenIDConnect.construct_triggerer("", "", "", env_vars, :debug_job)

      assert result ==
               "m:f-n:f"
    end

    test "returns empty string for project debug job" do
      assert "" == OpenIDConnect.construct_triggerer("", "", "", [], :project_debug_job)
    end

    test "returns empty string for debug job with no triggerer environment variables" do
      assert "" ==
               OpenIDConnect.construct_triggerer("wf-123", "ppl-456", "job-789", [], :debug_job)
    end
  end
end
