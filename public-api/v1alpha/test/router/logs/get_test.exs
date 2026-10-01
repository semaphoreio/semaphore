defmodule PipelinesAPI.Logs.Get.Test do
  use ExUnit.Case
  import ExUnit.CaptureLog

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
    previous_audit_logging = Application.get_env(:pipelines_api, :audit_logging)
    Application.put_env(:pipelines_api, :audit_logging, false)

    on_exit(fn ->
      Application.put_env(:pipelines_api, :audit_logging, previous_audit_logging)
    end)

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
      stub_loghub(fn _, _ ->
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

    test "returns 404 when loghub reports the logs cannot be found", ctx do
      stub_loghub(fn _, _ ->
        %InternalApi.Loghub.GetLogEventsResponse{
          final: false,
          events: [],
          status: %InternalApi.ResponseStatus{
            code: InternalApi.ResponseStatus.Code.value(:BAD_PARAM),
            message: "Log not found neither in the archive nor in the virtual machine"
          }
        }
      end)

      assert {404, _, response} = get_logs(ctx.cloud_job.id, ctx.user_id)
      assert response == "Log not found neither in the archive nor in the virtual machine"
    end

    test "returns 404 with the job's failure reason when the job never ran", ctx do
      failure_reason = "Selected machine type is not available in this organization"

      job =
        create_finished_without_execution_job(ctx,
          result: "failed",
          failure_reason: failure_reason
        )

      stub_loghub_not_found()

      assert {404, _, response} = get_logs(job.api_model.id, ctx.user_id)
      assert response == failure_reason
    end

    test "returns 404 explaining the job never started when it finished without running", ctx do
      job = create_finished_without_execution_job(ctx, result: "failed")
      stub_loghub_not_found()

      assert {404, _, response} = get_logs(job.api_model.id, ctx.user_id)
      assert response == "This job never started, so no logs were produced."
    end

    test "returns 404 explaining the job was stopped before it started", ctx do
      job = create_finished_without_execution_job(ctx, result: "stopped")
      stub_loghub_not_found()

      assert {404, _, response} = get_logs(job.api_model.id, ctx.user_id)
      assert response == "This job was stopped before it started, so no logs were produced."
    end

    test "reads the logs of the original job when the job is a reused copy", ctx do
      reused =
        Job.create(ctx.ppl.ppl_id, ctx.block.build_req_id,
          project_id: ctx.cloud_job.project_id,
          original_job_id: ctx.cloud_job.id
        )

      test_pid = self()

      stub_loghub(fn req, _ ->
        send(test_pid, {:loghub_job_id, req.job_id})

        %InternalApi.Loghub.GetLogEventsResponse{
          final: true,
          events: [~s({"event":"cmd_output","timestamp":1624541916,"output":"from the original"})],
          status: %InternalApi.ResponseStatus{
            code: InternalApi.ResponseStatus.Code.value(:OK),
            message: ""
          }
        }
      end)

      assert {200, _, response} = get_logs(reused.api_model.id, ctx.user_id)
      assert_receive {:loghub_job_id, requested_id}

      assert requested_id == ctx.cloud_job.id
      assert response["events"] |> hd() |> Map.get("output") == "from the original"
    end

    test "points a reused self-hosted job at the original job's log stream", ctx do
      reused =
        Job.create(ctx.ppl.ppl_id, ctx.block.build_req_id,
          project_id: ctx.self_hosted_job.project_id,
          machine_type: "s1-test",
          machine_os_image: "",
          self_hosted: true,
          original_job_id: ctx.self_hosted_job.id
        )

      test_pid = self()

      GrpcMock.stub(Loghub2Mock, :generate_token, fn req, _ ->
        send(test_pid, {:loghub2_job_id, req.job_id})

        %InternalApi.Loghub2.GenerateTokenResponse{
          type: InternalApi.Loghub2.TokenType.value(:PULL),
          token: @token
        }
      end)

      assert {302, headers, _} = get_logs(reused.api_model.id, ctx.user_id, false)
      assert_receive {:loghub2_job_id, requested_id}
      assert requested_id == ctx.self_hosted_job.id

      location = "https://localhost/api/v1/logs/#{ctx.self_hosted_job.id}?jwt=#{@token}"

      assert Enum.find(headers, fn {name, _} -> name == "location" end) ==
               {"location", location}
    end

    test "returns 503 when loghub reports the logs are temporarily unavailable", ctx do
      GrpcMock.stub(LoghubMock, :stream_log_events, fn _, stream ->
        GRPC.Server.send_headers(stream, %{})
        raise GRPC.RPCError, status: GRPC.Status.unavailable(), message: "unavailable"
      end)

      capture_log(fn ->
        assert {503, _, response} = get_logs(ctx.cloud_job.id, ctx.user_id)
        assert response == "Logs are temporarily unavailable, please retry"
      end)
    end

    test "returns 500 when the log stream fails after some events", ctx do
      GrpcMock.stub(LoghubMock, :stream_log_events, fn _, stream ->
        GRPC.Server.send_reply(stream, %InternalApi.Loghub.GetLogEventsResponse{
          final: true,
          events: Enum.take(@events, 2),
          status: %InternalApi.ResponseStatus{code: InternalApi.ResponseStatus.Code.value(:OK)}
        })

        raise GRPC.RPCError, status: GRPC.Status.data_loss(), message: "corrupt"
      end)

      capture_log(fn ->
        assert {500, _, "Internal error"} = get_logs(ctx.cloud_job.id, ctx.user_id)
      end)
    end

    test "returns 500 when loghub throws", ctx do
      stub_loghub(fn _, _ ->
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

    test "returns 302 and location for artifact job logs when compressed artifact exists", ctx do
      Support.Stubs.Artifacthub.create(ctx.cloud_job.id,
        scope: "jobs",
        path: "agent/job_logs.txt.gz",
        url: @full_logs_url
      )

      assert {302, headers, _response} =
               get_logs(ctx.cloud_job.id, ctx.user_id, false, %{"artifact_job_logs" => "true"})

      assert Enum.find(headers, fn {name, _} -> name == "location" end) ==
               {"location", @full_logs_url}
    end

    test "emits audit log for artifact job logs with full artifact resource path", ctx do
      Support.Stubs.Artifacthub.create(ctx.cloud_job.id,
        scope: "jobs",
        path: "agent/job_logs.txt.gz",
        url: @full_logs_url
      )

      expected_resource_name = "artifacts/jobs/#{ctx.cloud_job.id}/agent/job_logs.txt.gz"

      log =
        capture_log(fn ->
          assert {302, _headers, _response} =
                   get_logs(ctx.cloud_job.id, ctx.user_id, false, %{"artifact_job_logs" => "true"})
        end)

      assert log =~ "AuditLog"
      assert log =~ ctx.user_id
      assert log =~ ctx.org.id
      assert log =~ expected_resource_name
    end

    test "returns 500 and does not call signed_url backend when artifact job logs audit publish fails",
         ctx do
      Application.put_env(:pipelines_api, :audit_logging, true)
      Support.Stubs.Feature.enable_feature(ctx.org.id, :audit_logs)

      Support.Stubs.Artifacthub.create(ctx.cloud_job.id,
        scope: "jobs",
        path: "agent/job_logs.txt.gz",
        url: @full_logs_url
      )

      parent = self()

      GrpcMock.stub(ArtifacthubMock, :get_signed_url, fn req, _ ->
        send(parent, {:signed_path, req.path})

        InternalApi.Artifacthub.GetSignedURLResponse.new(
          url: "https://localhost:9000/" <> req.path
        )
      end)

      with_broken_audit_channel(fn ->
        assert {500, _headers, body} =
                 get_logs(ctx.cloud_job.id, ctx.user_id, false, %{"artifact_job_logs" => "true"})

        assert body in ["Internal error", "\"Internal error\""]

        refute_received {:signed_path, _}
      end)
    end

    test "prefers uncompressed artifact job logs when both variants exist", ctx do
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
               get_logs(ctx.cloud_job.id, ctx.user_id, false, %{"artifact_job_logs" => "true"})

      assert Enum.find(headers, fn {name, _} -> name == "location" end) ==
               {"location", txt_url}
    end

    test "signs and audits a reused job's artifact logs under the original job", ctx do
      parent = self()

      reused =
        Job.create(ctx.ppl.ppl_id, ctx.block.build_req_id,
          project_id: ctx.cloud_job.project_id,
          original_job_id: ctx.cloud_job.id
        )

      Support.Stubs.Artifacthub.create(ctx.cloud_job.id,
        scope: "jobs",
        path: "agent/job_logs.txt",
        url: @full_logs_url
      )

      GrpcMock.stub(ArtifacthubMock, :get_signed_url, fn req, _ ->
        send(parent, {:signed_path, req.path})

        InternalApi.Artifacthub.GetSignedURLResponse.new(
          url: "https://localhost:9000/" <> req.path
        )
      end)

      log =
        capture_log(fn ->
          assert {302, _headers, _response} =
                   get_logs(reused.api_model.id, ctx.user_id, false, %{
                     "artifact_job_logs" => "true"
                   })
        end)

      assert_receive {:signed_path, signed_path}
      assert signed_path == "artifacts/jobs/#{ctx.cloud_job.id}/agent/job_logs.txt"

      assert log =~ "artifacts/jobs/#{ctx.cloud_job.id}/agent/job_logs.txt"
      refute log =~ "artifacts/jobs/#{reused.api_model.id}"
    end

    test "returns 400 when artifact job logs listing fails with hard limit", ctx do
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
               get_logs(ctx.cloud_job.id, ctx.user_id, true, %{"artifact_job_logs" => "true"})

      assert response == "path resolves to too many files; narrow the path"
      assert_received :list_path_called
    end

    test "uses listed file path when signing artifact job logs (prevents guessed txt fallback for gz-only)",
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
               get_logs(ctx.cloud_job.id, ctx.user_id, false, %{"artifact_job_logs" => "true"})

      assert_received {:signed_path, signed_path}
      assert signed_path == "artifacts/jobs/#{ctx.cloud_job.id}/agent/job_logs.txt.gz"

      assert Enum.find(headers, fn {name, _} -> name == "location" end) ==
               {"location",
                "https://localhost:9000/artifacts/jobs/#{ctx.cloud_job.id}/agent/job_logs.txt.gz"}
    end

    test "returns 404 when artifact job logs are requested and artifact is missing", ctx do
      assert {404, _, response} =
               get_logs(ctx.cloud_job.id, ctx.user_id, true, %{"artifact_job_logs" => "1"})

      assert response == "Artifact job logs not found"
    end

    test "returns 401 when artifact job logs are requested without artifact permission", ctx do
      GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          permissions: Support.Stubs.all_permissions_except("project.artifacts.view")
        )
      end)

      assert {401, _, _} =
               get_logs(ctx.cloud_job.id, ctx.user_id, false, %{"artifact_job_logs" => "true"})
    end

    test "returns 401 when artifact job logs are requested for self-hosted job without artifact permission",
         ctx do
      GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          permissions: Support.Stubs.all_permissions_except("project.artifacts.view")
        )
      end)

      assert {401, _, _} =
               get_logs(ctx.self_hosted_job.id, ctx.user_id, false, %{
                 "artifact_job_logs" => "true"
               })
    end

    test "returns 401 when artifact job logs are requested without project.view permission",
         ctx do
      GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          permissions: Support.Stubs.all_permissions_except("project.view")
        )
      end)

      assert {401, _, _} =
               get_logs(ctx.cloud_job.id, ctx.user_id, false, %{"artifact_job_logs" => "true"})
    end

    test "returns 401 when artifact job logs are requested for self-hosted job without project.view permission",
         ctx do
      GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          permissions: Support.Stubs.all_permissions_except("project.view")
        )
      end)

      assert {401, _, _} =
               get_logs(ctx.self_hosted_job.id, ctx.user_id, false, %{
                 "artifact_job_logs" => "true"
               })
    end

    test "returns 403 when artifact job logs are requested and neither feature is enabled", ctx do
      Support.Stubs.Feature.disable_feature(ctx.org.id, :artifacts_api)
      Support.Stubs.Feature.disable_feature(ctx.org.id, :artifacts_job_logs)

      assert {403, _, response} =
               get_logs(ctx.cloud_job.id, ctx.user_id, false, %{"artifact_job_logs" => "true"})

      assert response ==
               "The artifacts api feature is not enabled for your organization. Please contact support"
    end

    test "returns 302 when artifact job logs are requested and only artifacts_job_logs feature is enabled",
         ctx do
      Support.Stubs.Feature.disable_feature(ctx.org.id, :artifacts_api)
      Support.Stubs.Feature.enable_feature(ctx.org.id, :artifacts_job_logs)

      Support.Stubs.Artifacthub.create(ctx.cloud_job.id,
        scope: "jobs",
        path: "agent/job_logs.txt.gz",
        url: @full_logs_url
      )

      assert {302, headers, _response} =
               get_logs(ctx.cloud_job.id, ctx.user_id, false, %{"artifact_job_logs" => "true"})

      assert Enum.find(headers, fn {name, _} -> name == "location" end) ==
               {"location", @full_logs_url}
    end

    test "returns 302 when artifact job logs are requested and artifacts feature is disabled",
         ctx do
      Support.Stubs.Feature.disable_feature(ctx.org.id, :artifacts)

      Support.Stubs.Artifacthub.create(ctx.cloud_job.id,
        scope: "jobs",
        path: "agent/job_logs.txt.gz",
        url: @full_logs_url
      )

      assert {302, headers, _response} =
               get_logs(ctx.cloud_job.id, ctx.user_id, false, %{"artifact_job_logs" => "true"})

      assert Enum.find(headers, fn {name, _} -> name == "location" end) ==
               {"location", @full_logs_url}
    end

    test "returns artifact job logs artifact URL for self-hosted jobs when available", ctx do
      self_hosted_full_logs_url = "https://localhost:9000/agent/job_logs.txt"

      Support.Stubs.Artifacthub.create(ctx.self_hosted_job.id,
        scope: "jobs",
        path: "agent/job_logs.txt",
        url: self_hosted_full_logs_url
      )

      assert {302, headers, _response} =
               get_logs(ctx.self_hosted_job.id, ctx.user_id, false, %{
                 "artifact_job_logs" => "true"
               })

      assert Enum.find(headers, fn {name, _} -> name == "location" end) ==
               {"location", self_hosted_full_logs_url}
    end

    test "ignores malformed artifact_job_logs query value type", ctx do
      stub_loghub(fn _, _ ->
        %InternalApi.Loghub.GetLogEventsResponse{
          final: true,
          events: @events,
          status: %InternalApi.ResponseStatus{
            code: InternalApi.ResponseStatus.Code.value(:OK),
            message: ""
          }
        }
      end)

      assert {200, _, response} =
               get_logs_raw_query(ctx.cloud_job.id, ctx.user_id, "artifact_job_logs[]=true")

      assert response["events"] |> length() == length(@events)
    end

    test "returns 404 for job that does not exist", ctx do
      non_existing_job_id = UUID.uuid4()
      assert {404, _, _} = get_logs(non_existing_job_id, ctx.user_id, false)
    end
  end

  describe "GET /logs/:job_id streaming" do
    # GrpcMock stubs outlive the test, and other tests rely on GetLogEvents
    # having none (a fallback must fail there).
    setup do
      on_exit(fn ->
        GrpcMock.stub(LoghubMock, :get_log_events, fn _, _ -> raise "no GetLogEvents stub" end)
      end)
    end

    # What the endpoint has always returned: the events, as loghub stores
    # them, joined into one JSON document.
    defp expected_body(events), do: ~s({ "events": [) <> Enum.join(events, ",") <> "] }"

    defp ok_status,
      do: %InternalApi.ResponseStatus{
        code: InternalApi.ResponseStatus.Code.value(:OK),
        message: ""
      }

    defp stub_batches(batches) do
      GrpcMock.stub(LoghubMock, :stream_log_events, fn _, stream ->
        for events <- batches do
          GRPC.Server.send_reply(stream, %InternalApi.Loghub.GetLogEventsResponse{
            status: ok_status(),
            events: events,
            final: true
          })
        end
      end)
    end

    defp put_commit_bytes(bytes) do
      previous = Application.get_env(:pipelines_api, :logs_commit_bytes)
      Application.put_env(:pipelines_api, :logs_commit_bytes, bytes)

      on_exit(fn ->
        if previous,
          do: Application.put_env(:pipelines_api, :logs_commit_bytes, previous),
          else: Application.delete_env(:pipelines_api, :logs_commit_bytes)
      end)
    end

    defp put_loghub_timeout(ms) do
      previous = Application.get_env(:pipelines_api, :loghub_stream_timeout)
      Application.put_env(:pipelines_api, :loghub_stream_timeout, ms)
      on_exit(fn -> Application.put_env(:pipelines_api, :loghub_stream_timeout, previous) end)
    end

    @batches [[], [~s({"event":"job_started"}), ~s({"n":1})], [], [~s({"n":2})], [~s({"n":3})]]

    test "a log under the commit size is one response with a Content-Length, same bytes", ctx do
      stub_batches(@batches)

      assert {200, headers, body} = get_logs(ctx.cloud_job.id, ctx.user_id, false)
      assert body == expected_body(List.flatten(@batches))
      assert header(headers, "content-length") == "#{byte_size(body)}"
      assert header(headers, "transfer-encoding") == nil
      assert header(headers, "content-type") =~ "application/json"
    end

    test "a log over the commit size is sent in chunks, same bytes", ctx do
      put_commit_bytes(1)
      stub_batches(@batches)

      assert {200, headers, body} = get_logs(ctx.cloud_job.id, ctx.user_id, false)
      assert body == expected_body(List.flatten(@batches))
      assert header(headers, "transfer-encoding") == "chunked"
      assert header(headers, "content-type") =~ "application/json"

      # And as more than one chunk: the batches went out as they arrived.
      assert {:ok, %{chunks: chunks, complete?: true}} = raw_get(ctx.cloud_job.id, ctx.user_id)
      assert length(chunks) > 1
      assert Enum.join(chunks) == expected_body(List.flatten(@batches))
    end

    test "an empty log is the same body either way", ctx do
      stub_batches([[]])
      assert {200, _, body} = get_logs(ctx.cloud_job.id, ctx.user_id, false)
      assert body == expected_body([])

      put_commit_bytes(1)
      assert {200, _, ^body} = get_logs(ctx.cloud_job.id, ctx.user_id, false)
    end

    test "a failure after the response started aborts it, so no client gets a partial log",
         ctx do
      put_commit_bytes(1)

      GrpcMock.stub(LoghubMock, :stream_log_events, fn _, stream ->
        GRPC.Server.send_reply(stream, %InternalApi.Loghub.GetLogEventsResponse{
          status: ok_status(),
          events: [~s({"n":1})],
          final: true
        })

        raise GRPC.RPCError, status: GRPC.Status.data_loss(), message: "corrupt"
      end)

      capture_log(fn ->
        assert {:ok, %{status: 200, chunks: chunks, complete?: false}} =
                 raw_get(ctx.cloud_job.id, ctx.user_id)

        assert Enum.join(chunks) == ~s({ "events": [{"n":1})
      end)
    end

    test "over HTTP/2, a failure after the response started resets the stream", ctx do
      put_commit_bytes(1)

      GrpcMock.stub(LoghubMock, :stream_log_events, fn _, stream ->
        GRPC.Server.send_reply(stream, %InternalApi.Loghub.GetLogEventsResponse{
          status: ok_status(),
          events: [~s({"n":1})],
          final: true
        })

        raise GRPC.RPCError, status: GRPC.Status.data_loss(), message: "corrupt"
      end)

      capture_log(fn ->
        {:ok, conn} = :gun.open(~c"localhost", 4004, %{protocols: [:http2]})
        {:ok, :http2} = :gun.await_up(conn)

        ref =
          :gun.get(conn, "/logs/#{ctx.cloud_job.id}", [
            {"x-semaphore-user-id", ctx.user_id},
            {"x-semaphore-org-id", Support.Stubs.Organization.default_org_id()}
          ])

        assert {:response, :nofin, 200, _headers} = :gun.await(conn, ref, 5_000)
        assert {:error, {:stream_error, _}} = :gun.await_body(conn, ref, 5_000)
        :gun.close(conn)
      end)
    end

    test "a status change after the response started aborts it", ctx do
      put_commit_bytes(1)

      GrpcMock.stub(LoghubMock, :stream_log_events, fn _, stream ->
        GRPC.Server.send_reply(stream, %InternalApi.Loghub.GetLogEventsResponse{
          status: ok_status(),
          events: [~s({"n":1})],
          final: true
        })

        GRPC.Server.send_reply(stream, %InternalApi.Loghub.GetLogEventsResponse{
          status: %InternalApi.ResponseStatus{
            code: InternalApi.ResponseStatus.Code.value(:BAD_PARAM),
            message: "gone"
          },
          events: [],
          final: true
        })
      end)

      capture_log(fn ->
        assert {:ok, %{status: 200, complete?: false}} = raw_get(ctx.cloud_job.id, ctx.user_id)
      end)
    end

    test "a failure before the commit size still gets its own status", ctx do
      GrpcMock.stub(LoghubMock, :stream_log_events, fn _, stream ->
        GRPC.Server.send_reply(stream, %InternalApi.Loghub.GetLogEventsResponse{
          status: ok_status(),
          events: [~s({"n":1})],
          final: true
        })

        raise GRPC.RPCError, status: GRPC.Status.unavailable(), message: "busy"
      end)

      capture_log(fn ->
        assert {503, _, "Logs are temporarily unavailable, please retry"} =
                 get_logs(ctx.cloud_job.id, ctx.user_id)
      end)
    end

    test "a loghub that is too slow to start is a 503, not a fallback", ctx do
      GrpcMock.stub(LoghubMock, :stream_log_events, fn _, _ ->
        # The test deadline is 1s (config/test.exs).
        Process.sleep(3_000)
      end)

      GrpcMock.stub(LoghubMock, :get_log_events, fn _, _ -> flunk("must not fall back") end)

      log =
        capture_log(fn ->
          assert {503, _, _} = get_logs(ctx.cloud_job.id, ctx.user_id)
        end)

      refute log =~ "falling back"
    end

    test "a stream that outlives the deadline after the response started is aborted", ctx do
      put_commit_bytes(1)

      GrpcMock.stub(LoghubMock, :stream_log_events, fn _, stream ->
        GRPC.Server.send_reply(stream, %InternalApi.Loghub.GetLogEventsResponse{
          status: ok_status(),
          events: [~s({"n":1})],
          final: true
        })

        Process.sleep(3_000)
      end)

      capture_log(fn ->
        {elapsed, result} = :timer.tc(fn -> raw_get(ctx.cloud_job.id, ctx.user_id) end)
        assert {:ok, %{status: 200, complete?: false}} = result
        # The 1s test deadline, not the 3s the handler sleeps.
        assert elapsed < 2_500_000
      end)
    end

    test "the GetLogEvents fallback is streamed the same way", ctx do
      put_commit_bytes(1)

      GrpcMock.stub(LoghubMock, :stream_log_events, fn _, _ ->
        raise GRPC.RPCError, status: GRPC.Status.unimplemented(), message: "unimplemented"
      end)

      GrpcMock.stub(LoghubMock, :get_log_events, fn _, _ ->
        %InternalApi.Loghub.GetLogEventsResponse{
          status: ok_status(),
          events: [~s({"n":1}), ~s({"n":2})],
          final: true
        }
      end)

      capture_log(fn ->
        assert {200, headers, body} = get_logs(ctx.cloud_job.id, ctx.user_id, false)
        assert body == expected_body([~s({"n":1}), ~s({"n":2})])
        assert header(headers, "transfer-encoding") == "chunked"
      end)
    end

    # The leak behind the OOM: a client that gives up must not leave loghub
    # (and this service) working on a log nobody reads.
    test "a client hanging up mid-stream cancels the loghub stream within about a second",
         ctx do
      put_commit_bytes(1)
      put_loghub_timeout(60_000)
      test = self()

      GrpcMock.stub(LoghubMock, :stream_log_events, fn _, stream ->
        GRPC.Server.send_reply(stream, %InternalApi.Loghub.GetLogEventsResponse{
          status: ok_status(),
          events: [~s({"n":1})],
          final: true
        })

        send(test, {:first_batch_sent, self()})
        Process.sleep(60_000)
      end)

      {:ok, socket} = raw_request(ctx.cloud_job.id, ctx.user_id)
      assert_receive {:first_batch_sent, handler}, 5_000
      ref = Process.monitor(handler)

      # Wait for the start of the body, then hang up.
      {:ok, _} = :gen_tcp.recv(socket, 0, 5_000)
      :gen_tcp.close(socket)

      assert_receive {:DOWN, ^ref, :process, ^handler, _}, 2_000
    end
  end

  defp header(headers, name) do
    Enum.find_value(headers, fn {key, value} ->
      if String.downcase(key) == name, do: value
    end)
  end

  defp raw_request(job_id, user_id) do
    {:ok, socket} = :gen_tcp.connect(~c"localhost", 4004, [:binary, active: false])

    request =
      "GET /logs/#{job_id} HTTP/1.1\r\nhost: localhost\r\nconnection: close\r\n" <>
        "x-semaphore-user-id: #{user_id}\r\n" <>
        "x-semaphore-org-id: #{Support.Stubs.Organization.default_org_id()}\r\n\r\n"

    :ok = :gen_tcp.send(socket, request)
    {:ok, socket}
  end

  # Reads a whole response off the socket and decodes its chunks. complete?
  # is whether the body ended with the last (empty) chunk.
  defp raw_get(job_id, user_id) do
    {:ok, socket} = raw_request(job_id, user_id)
    data = read_all(socket, "")
    [head, body] = String.split(data, "\r\n\r\n", parts: 2)
    [status_line | _] = String.split(head, "\r\n")
    [_, status | _] = String.split(status_line, " ")
    {chunks, complete?} = decode_chunks(body, [])
    {:ok, %{status: String.to_integer(status), chunks: chunks, complete?: complete?}}
  end

  defp read_all(socket, acc) do
    case :gen_tcp.recv(socket, 0, 10_000) do
      {:ok, data} -> read_all(socket, acc <> data)
      {:error, :closed} -> acc
    end
  end

  defp decode_chunks(data, chunks) do
    with [size_line, rest] <- String.split(data, "\r\n", parts: 2),
         {size, ""} <- Integer.parse(size_line, 16) do
      case {size, rest} do
        {0, "\r\n"} ->
          {Enum.reverse(chunks), true}

        {size, rest} when byte_size(rest) >= size + 2 ->
          <<chunk::binary-size(size), "\r\n", rest::binary>> = rest
          decode_chunks(rest, [chunk | chunks])

        _ ->
          {Enum.reverse(chunks), false}
      end
    else
      _ -> {Enum.reverse(chunks), false}
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

  # A cloud job that reached a terminal state without ever starting: started_at
  # is nil (rendered as "") and the job is FINISHED.
  defp create_finished_without_execution_job(ctx, opts) do
    Job.create(UUID.uuid4(), UUID.uuid4(),
      project_id: ctx.cloud_job.project_id,
      state: "finished",
      result: Keyword.fetch!(opts, :result),
      failure_reason: Keyword.get(opts, :failure_reason, ""),
      timeline: %{
        created_at: DateTime.utc_now(),
        started_at: nil,
        finished_at: DateTime.utc_now()
      }
    )
  end

  defp stub_loghub_not_found do
    stub_loghub(fn _, _ ->
      %InternalApi.Loghub.GetLogEventsResponse{
        final: false,
        events: [],
        status: %InternalApi.ResponseStatus{
          code: InternalApi.ResponseStatus.Code.value(:BAD_PARAM),
          message: "Log not found neither in the archive nor in the virtual machine"
        }
      }
    end)
  end

  # Serves the given response through StreamLogEvents, one event per message,
  # the way loghub splits a log into batches.
  defp stub_loghub(fun) do
    GrpcMock.stub(LoghubMock, :stream_log_events, fn req, stream ->
      response = fun.(req, stream)

      case response.events do
        [] ->
          GRPC.Server.send_reply(stream, response)

        events ->
          Enum.each(events, &GRPC.Server.send_reply(stream, %{response | events: [&1]}))
      end
    end)
  end

  defp headers(user_id),
    do: [
      {"Content-type", "application/json"},
      {"x-semaphore-user-id", user_id},
      {"x-semaphore-org-id", Support.Stubs.Organization.default_org_id()}
    ]

  defp with_broken_audit_channel(fun) when is_function(fun, 0) do
    previous_publish_fun = Application.get_env(:pipelines_api, :audit_publish_fun)

    Application.put_env(:pipelines_api, :audit_publish_fun, fn _message ->
      {:error, :forced_failure}
    end)

    try do
      fun.()
    after
      Application.put_env(:pipelines_api, :audit_publish_fun, previous_publish_fun)
    end
  end
end
