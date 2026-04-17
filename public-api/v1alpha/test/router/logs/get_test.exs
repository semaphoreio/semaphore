defmodule PipelinesAPI.Logs.Get.Test do
  use ExUnit.Case

  alias Support.Stubs.{Job, Pipeline, Workflow}

  @token "asdasdas"
  @full_logs_url "https://localhost:9000/agent/job_logs.txt.gz"
  @events [
    "{\"event\": \"job_started\", \"timestamp\": 1624541916}",
    "{\"event\": \"cmd_started\", \"timestamp\": 1624541916, \"directive\": \"Exporting environment variables\"}",
    "{\"event\": \"cmd_output\", \"timestamp\": 1624541916, \"output\": \"Exporting VAR1\"}",
    "{\"event\": \"cmd_output\", \"timestamp\": 1624541916, \"output\": \"Exporting VAR2\"}",
    "{\"event\": \"job_finished\", \"timestamp\": 1624541916, \"result\": \"passed\"}"
  ]

  setup do
    Support.Stubs.reset()
    Support.Stubs.grant_all_permissions()

    org = Support.Stubs.Organization.create_default()
    Support.Stubs.Feature.set_org_defaults(org.id)
    Support.Stubs.Feature.enable_feature(org.id, :artifacts_api)
    user = Support.Stubs.User.create_default()
    project = Support.Stubs.Project.create(org, user)
    user_id = user.id
    build_req_id = UUID.uuid4()
    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}
    workflow = Workflow.create(hook, user_id, organization_id: org.id)
    pipeline = Pipeline.create_initial(workflow)

    block =
      Pipeline.add_block(pipeline, %{
        name: "Block #1",
        dependencies: [],
        job_names: ["First job"],
        build_req_id: build_req_id
      })

    cloud_job = Job.create(pipeline.id, build_req_id, project_id: project.id)

    self_hosted_job =
      Job.create(pipeline.id, build_req_id,
        project_id: project.id,
        machine_type: "s1-test",
        machine_os_image: "",
        self_hosted: true
      )

    %{
      org: org,
      user: user,
      user_id: user_id,
      cloud_job: cloud_job.api_model,
      self_hosted_job: self_hosted_job.api_model,
      ppl: pipeline.api_model,
      wf: workflow.api_model,
      block: block.api_model
    }
  end

  describe "GET /logs/:job_id" do
    test "unauthorized user", ctx do
      GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          permissions: Support.Stubs.all_permissions_except("project.view")
        )
      end)

      assert {401, _, _} = get_logs(ctx.cloud_job.id, ctx.user_id, false)
    end

    test "project ID mismatch", ctx do
      org = Support.Stubs.Organization.create(name: "RT2", org_username: "rt2")
      project = Support.Stubs.Project.create(org, ctx.user)
      hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}
      build_req_id = UUID.uuid4()

      workflow = Support.Stubs.Workflow.create(hook, ctx.user.id, organization_id: org.id)
      pipeline = Pipeline.create_initial(workflow)

      Pipeline.add_block(pipeline, %{
        name: "Block #1",
        dependencies: [],
        job_names: ["First job"],
        build_req_id: build_req_id
      })

      cloud_job = Job.create(pipeline.id, build_req_id, project_id: project.id)

      self_hosted_job =
        Job.create(pipeline.id, build_req_id,
          project_id: project.id,
          machine_type: "s1-test",
          machine_os_image: "",
          self_hosted: true
        )

      assert {404, _, _} = get_logs(cloud_job.id, ctx.user_id, false)
      assert {404, _, _} = get_logs(self_hosted_job.id, ctx.user_id, false)
    end

    test "returns 200 and logs for existing cloud job", ctx do
      GrpcMock.stub(LoghubMock, :get_log_events, fn _, _ ->
        %InternalApi.Loghub.GetLogEventsResponse{
          final: true,
          events: @events,
          status: %InternalApi.ResponseStatus{
            code: InternalApi.ResponseStatus.Code.value(:OK),
            message: ""
          }
        }
      end)

      assert {200, _, response} = get_logs(ctx.cloud_job.id, ctx.user_id)

      assert response == %{
               "events" => [
                 %{"event" => "job_started", "timestamp" => 1_624_541_916},
                 %{
                   "event" => "cmd_started",
                   "timestamp" => 1_624_541_916,
                   "directive" => "Exporting environment variables"
                 },
                 %{
                   "event" => "cmd_output",
                   "timestamp" => 1_624_541_916,
                   "output" => "Exporting VAR1"
                 },
                 %{
                   "event" => "cmd_output",
                   "timestamp" => 1_624_541_916,
                   "output" => "Exporting VAR2"
                 },
                 %{"event" => "job_finished", "timestamp" => 1_624_541_916, "result" => "passed"}
               ]
             }
    end

    test "returns 500 when loghub returns bad status", ctx do
      GrpcMock.stub(LoghubMock, :get_log_events, fn _, _ ->
        %InternalApi.Loghub.GetLogEventsResponse{
          final: false,
          events: [],
          status: %InternalApi.ResponseStatus{
            code: InternalApi.ResponseStatus.Code.value(:BAD_PARAM),
            message: ""
          }
        }
      end)

      assert {500, _, response} = get_logs(ctx.cloud_job.id, ctx.user_id)
      assert response == "Internal error"
    end

    test "returns 500 when loghub throws", ctx do
      GrpcMock.stub(LoghubMock, :get_log_events, fn _, _ ->
        throw("oops")
      end)

      assert {500, _, response} = get_logs(ctx.cloud_job.id, ctx.user_id)
      assert response == "Internal error"
    end

    test "returns 302 and location for existing self-hosted job", ctx do
      GrpcMock.stub(Loghub2Mock, :generate_token, fn _, _ ->
        %InternalApi.Loghub2.GenerateTokenResponse{
          type: InternalApi.Loghub2.TokenType.value(:PULL),
          token: @token
        }
      end)

      assert {302, headers, _} = get_logs(ctx.self_hosted_job.id, ctx.user_id, false)
      location = "https://localhost/api/v1/logs/#{ctx.self_hosted_job.id}?jwt=#{@token}"

      assert Enum.find(headers, fn {name, _} -> name == "location" end) ==
               {"location", location}
    end

    test "returns 500 when loghub2 throws", ctx do
      GrpcMock.stub(Loghub2Mock, :generate_token, fn _, _ ->
        throw("oops")
      end)

      assert {500, _headers, "Internal error"} = get_logs(ctx.self_hosted_job.id, ctx.user_id)
    end

    test "returns 302 and location for full logs when compressed artifact exists", ctx do
      Support.Stubs.Artifacthub.create(ctx.cloud_job.id,
        scope: "jobs",
        path: "agent/job_logs.txt.gz",
        url: @full_logs_url
      )

      assert {302, headers, _response} =
               get_logs(ctx.cloud_job.id, ctx.user_id, false, %{"full" => "true"})

      assert Enum.find(headers, fn {name, _} -> name == "location" end) ==
               {"location", @full_logs_url}
    end

    test "prefers uncompressed full logs when both variants exist", ctx do
      txt_url = "https://localhost:9000/agent/job_logs.txt"
      gz_url = "https://localhost:9000/agent/job_logs.txt.gz"

      Support.Stubs.Artifacthub.create(ctx.cloud_job.id,
        scope: "jobs",
        path: "agent/job_logs.txt",
        url: txt_url
      )

      Support.Stubs.Artifacthub.create(ctx.cloud_job.id,
        scope: "jobs",
        path: "agent/job_logs.txt.gz",
        url: gz_url
      )

      assert {302, headers, _response} =
               get_logs(ctx.cloud_job.id, ctx.user_id, false, %{"full" => "true"})

      assert Enum.find(headers, fn {name, _} -> name == "location" end) ==
               {"location", txt_url}
    end

    test "returns 400 when full logs listing fails with hard limit", ctx do
      parent = self()

      Support.Stubs.Artifacthub.create(ctx.cloud_job.id,
        scope: "jobs",
        path: "agent/job_logs.txt",
        url: "https://localhost:9000/agent/job_logs.txt"
      )

      GrpcMock.stub(ArtifacthubMock, :list_path, fn _req, _ ->
        send(parent, :list_path_called)

        raise GRPC.RPCError,
          status: :failed_precondition,
          message: "path resolves to too many files; narrow the path"
      end)

      assert {400, _, response} =
               get_logs(ctx.cloud_job.id, ctx.user_id, true, %{"full" => "true"})

      assert response == "path resolves to too many files; narrow the path"
      assert_received :list_path_called
    end

    test "uses listed file path when signing full logs (prevents guessed txt fallback for gz-only)",
         ctx do
      parent = self()

      Support.Stubs.Artifacthub.create(ctx.cloud_job.id,
        scope: "jobs",
        path: "agent/job_logs.txt.gz",
        url: @full_logs_url
      )

      GrpcMock.stub(ArtifacthubMock, :get_signed_url, fn req, _ ->
        send(parent, {:signed_path, req.path})

        InternalApi.Artifacthub.GetSignedURLResponse.new(
          url: "https://localhost:9000/" <> req.path
        )
      end)

      assert {302, headers, _response} =
               get_logs(ctx.cloud_job.id, ctx.user_id, false, %{"full" => "true"})

      assert_received {:signed_path, signed_path}
      assert signed_path == "artifacts/jobs/#{ctx.cloud_job.id}/agent/job_logs.txt.gz"

      assert Enum.find(headers, fn {name, _} -> name == "location" end) ==
               {"location",
                "https://localhost:9000/artifacts/jobs/#{ctx.cloud_job.id}/agent/job_logs.txt.gz"}
    end

    test "returns 404 when full logs are requested and artifact is missing", ctx do
      assert {404, _, response} = get_logs(ctx.cloud_job.id, ctx.user_id, true, %{"full" => "1"})
      assert response == "Full log artifact not found"
    end

    test "returns 401 when full logs are requested without artifact permission", ctx do
      GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          permissions: Support.Stubs.all_permissions_except("project.artifacts.view")
        )
      end)

      assert {401, _, _} = get_logs(ctx.cloud_job.id, ctx.user_id, false, %{"full" => "true"})
    end

    test "returns 401 when full logs are requested for self-hosted job without artifact permission",
         ctx do
      GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          permissions: Support.Stubs.all_permissions_except("project.artifacts.view")
        )
      end)

      assert {401, _, _} =
               get_logs(ctx.self_hosted_job.id, ctx.user_id, false, %{"full" => "true"})
    end

    test "returns 401 when full logs are requested without project.view permission", ctx do
      GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          permissions: Support.Stubs.all_permissions_except("project.view")
        )
      end)

      assert {401, _, _} = get_logs(ctx.cloud_job.id, ctx.user_id, false, %{"full" => "true"})
    end

    test "returns 401 when full logs are requested for self-hosted job without project.view permission",
         ctx do
      GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          permissions: Support.Stubs.all_permissions_except("project.view")
        )
      end)

      assert {401, _, _} =
               get_logs(ctx.self_hosted_job.id, ctx.user_id, false, %{"full" => "true"})
    end

    test "returns 403 when full logs are requested and neither feature is enabled", ctx do
      Support.Stubs.Feature.disable_feature(ctx.org.id, :artifacts_api)
      Support.Stubs.Feature.disable_feature(ctx.org.id, :artifacts_job_logs)

      assert {403, _, response} =
               get_logs(ctx.cloud_job.id, ctx.user_id, false, %{"full" => "true"})

      assert response ==
               "The artifacts api feature is not enabled for your organization. Please contact support"
    end

    test "returns 302 when full logs are requested and only artifacts_job_logs feature is enabled",
         ctx do
      Support.Stubs.Feature.disable_feature(ctx.org.id, :artifacts_api)
      Support.Stubs.Feature.enable_feature(ctx.org.id, :artifacts_job_logs)

      Support.Stubs.Artifacthub.create(ctx.cloud_job.id,
        scope: "jobs",
        path: "agent/job_logs.txt.gz",
        url: @full_logs_url
      )

      assert {302, headers, _response} =
               get_logs(ctx.cloud_job.id, ctx.user_id, false, %{"full" => "true"})

      assert Enum.find(headers, fn {name, _} -> name == "location" end) ==
               {"location", @full_logs_url}
    end

    test "returns 302 when full logs are requested and artifacts feature is disabled", ctx do
      Support.Stubs.Feature.disable_feature(ctx.org.id, :artifacts)

      Support.Stubs.Artifacthub.create(ctx.cloud_job.id,
        scope: "jobs",
        path: "agent/job_logs.txt.gz",
        url: @full_logs_url
      )

      assert {302, headers, _response} =
               get_logs(ctx.cloud_job.id, ctx.user_id, false, %{"full" => "true"})

      assert Enum.find(headers, fn {name, _} -> name == "location" end) ==
               {"location", @full_logs_url}
    end

    test "returns full logs artifact URL for self-hosted jobs when available", ctx do
      self_hosted_full_logs_url = "https://localhost:9000/agent/job_logs.txt"

      Support.Stubs.Artifacthub.create(ctx.self_hosted_job.id,
        scope: "jobs",
        path: "agent/job_logs.txt",
        url: self_hosted_full_logs_url
      )

      assert {302, headers, _response} =
               get_logs(ctx.self_hosted_job.id, ctx.user_id, false, %{"full" => "true"})

      assert Enum.find(headers, fn {name, _} -> name == "location" end) ==
               {"location", self_hosted_full_logs_url}
    end

    test "ignores malformed full query value type", ctx do
      GrpcMock.stub(LoghubMock, :get_log_events, fn _, _ ->
        %InternalApi.Loghub.GetLogEventsResponse{
          final: true,
          events: @events,
          status: %InternalApi.ResponseStatus{
            code: InternalApi.ResponseStatus.Code.value(:OK),
            message: ""
          }
        }
      end)

      assert {200, _, response} = get_logs_raw_query(ctx.cloud_job.id, ctx.user_id, "full[]=true")
      assert response["events"] |> length() == length(@events)
    end

    test "returns 404 for job that does not exist", ctx do
      non_existing_job_id = UUID.uuid4()
      assert {404, _, _} = get_logs(non_existing_job_id, ctx.user_id, false)
    end
  end

  defp get_logs(job_id, user_id, decode? \\ true, query_params \\ %{}) do
    query =
      if map_size(query_params) == 0 do
        ""
      else
        "?" <> URI.encode_query(query_params)
      end

    url = "localhost:4004/logs/" <> job_id <> query

    {:ok,
     %{
       :body => body,
       :status_code => status_code,
       :headers => response_headers
     }} = HTTPoison.get(url, headers(user_id))

    body =
      case decode? do
        true -> Poison.decode!(body)
        false -> body
      end

    {status_code, response_headers, body}
  end

  defp get_logs_raw_query(job_id, user_id, raw_query, decode? \\ true) do
    url = "localhost:4004/logs/" <> job_id <> "?" <> raw_query

    {:ok,
     %{
       :body => body,
       :status_code => status_code,
       :headers => response_headers
     }} = HTTPoison.get(url, headers(user_id))

    body =
      case decode? do
        true -> Poison.decode!(body)
        false -> body
      end

    {status_code, response_headers, body}
  end

  defp headers(user_id),
    do: [
      {"Content-type", "application/json"},
      {"x-semaphore-user-id", user_id},
      {"x-semaphore-org-id", Support.Stubs.Organization.default_org_id()}
    ]
end
