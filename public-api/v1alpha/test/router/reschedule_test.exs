defmodule Router.RescheduleTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  import Test.PipelinesClient, only: [post_reschedule: 3, post_reschedule: 4, post_reschedule: 5]

  setup do
    Support.Stubs.grant_all_permissions()
    :ok
  end

  test "POST /workflows/:wf_id/reschedule - project ID mismatch" do
    org = Support.Stubs.Organization.create(name: "RT2", org_username: "rt2")
    user = Support.Stubs.User.create_default()
    user_id = user.id
    project = Support.Stubs.Project.create(org, user)

    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, user_id, organization_id: org.id)
    _ = Support.Stubs.Pipeline.create_initial(workflow)

    response = post_reschedule(workflow.id, %{"request_token" => UUID.uuid4()}, 404, false)
    assert response == "Not Found"
  end

  test "POST /workflows/:wf_id/reschedule - no permission" do
    GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
      InternalApi.RBAC.ListUserPermissionsResponse.new(
        permissions: Support.Stubs.all_permissions_except("project.job.rerun")
      )
    end)

    org = Support.Stubs.Organization.create(name: "RT2", org_username: "rt2-#{UUID.uuid4()}")
    user = Support.Stubs.User.create_default()
    user_id = user.id
    project = Support.Stubs.Project.create(org, user)

    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, user_id, organization_id: org.id)
    _ = Support.Stubs.Pipeline.create_initial(workflow)

    response = post_reschedule(workflow.id, %{"request_token" => UUID.uuid4()}, 404, false)
    assert response == "Not Found"
  end

  test "POST /workflows/:wf_id/reschedule - valid args" do
    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    user_id = user.id
    project = Support.Stubs.Project.create(org, user)

    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, user_id, organization_id: org.id)
    _ = Support.Stubs.Pipeline.create_initial(workflow)

    response = post_reschedule(workflow.id, %{"request_token" => UUID.uuid4()}, 200)
    assert %{"wf_id" => wf_id, "ppl_id" => ppl_id} = response
    assert {:ok, _} = UUID.info(ppl_id)
    assert {:ok, _} = UUID.info(wf_id)
  end

  test "POST /workflows/:wf_id/reschedule - emits workflow rebuild audit log" do
    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    user_id = user.id
    project = Support.Stubs.Project.create(org, user)

    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, user_id, organization_id: org.id)
    _ = Support.Stubs.Pipeline.create_initial(workflow)

    log =
      capture_log(fn ->
        response = post_reschedule(workflow.id, %{"request_token" => UUID.uuid4()}, 200)
        assert %{"wf_id" => _wf_id, "ppl_id" => _ppl_id} = response
      end)

    assert log =~ "AuditLog"
    assert log =~ user_id
    assert log =~ org.id
    assert log =~ workflow.id
    assert log =~ "workflow_operation"
  end

  test "POST /workflows/:wf_id/reschedule - emits workflow rebuild audit log even when reschedule fails" do
    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    user_id = user.id
    project = Support.Stubs.Project.create(org, user)

    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, user_id, organization_id: org.id)
    _ = Support.Stubs.Pipeline.create_initial(workflow)

    GrpcMock.stub(WorkflowMock, :reschedule, fn _req, _stream ->
      InternalApi.PlumberWF.ScheduleResponse.new(
        status:
          InternalApi.Status.new(
            code: Google.Rpc.Code.value(:FAILED_PRECONDITION),
            message: "Failed precondition"
          )
      )
    end)

    on_exit(fn ->
      GrpcMock.stub(WorkflowMock, :reschedule, &Support.Stubs.Workflow.Grpc.reschedule/2)
    end)

    log =
      capture_log(fn ->
        _response = post_reschedule(workflow.id, %{"request_token" => UUID.uuid4()}, 400, false)
      end)

    assert log =~ "workflow_operation"
    assert log =~ "operation: \"Rebuild\""
    assert log =~ workflow.id
  end

  test "POST /workflows/:wf_id/reschedule - returns 500 and skips reschedule when audit publish fails" do
    Application.put_env(:pipelines_api, :audit_logging, true)

    org = Support.Stubs.Organization.create(name: "RT2", org_username: "rt2-#{UUID.uuid4()}")
    Support.Stubs.Feature.set_org_defaults(org.id)
    Support.Stubs.Feature.enable_feature(org.id, :audit_logs)
    clear_feature_provider_cache()
    user = Support.Stubs.User.create_default()
    user_id = user.id
    project = Support.Stubs.Project.create(org, user)

    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, user_id, organization_id: org.id)
    _ = Support.Stubs.Pipeline.create_initial(workflow)

    parent = self()

    GrpcMock.stub(WorkflowMock, :reschedule, fn req, stream ->
      send(parent, :workflow_reschedule_called)
      Support.Stubs.Workflow.Grpc.reschedule(req, stream)
    end)

    on_exit(fn ->
      GrpcMock.stub(WorkflowMock, :reschedule, &Support.Stubs.Workflow.Grpc.reschedule/2)
    end)

    with_broken_audit_channel(fn ->
      response =
        post_reschedule(
          workflow.id,
          %{"request_token" => UUID.uuid4()},
          500,
          false,
          headers(user_id, org.id)
        )

      assert response in ["Internal error", "\"Internal error\""]
      refute_received :workflow_reschedule_called
    end)
  end

  test "POST /workflows/:wf_id/reschedule - wrong wf_id" do
    response = post_reschedule("123", %{"request_token" => UUID.uuid4()}, 404, false)
    assert response == "Not Found"
  end

  test "POST /workflows/:wf_id/reschedule - request token missing" do
    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    user_id = user.id
    project = Support.Stubs.Project.create(org, user)

    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, user_id, organization_id: org.id)
    _ = Support.Stubs.Pipeline.create_initial(workflow)

    response = post_reschedule(workflow.id, %{"request_token" => ""}, 400)
    assert response == "Missing required post parameter request_token."
  end

  defp headers(user_id, org_id),
    do: [
      {"Content-type", "application/json"},
      {"x-semaphore-org-id", org_id},
      {"x-semaphore-user-id", user_id}
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

  defp clear_feature_provider_cache do
    case Cachex.clear(:feature_provider_cache) do
      {:ok, _count} -> :ok
      {:error, _reason} -> :ok
    end
  end
end
