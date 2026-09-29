defmodule PipelinesAPI.AuditTest do
  use ExUnit.Case
  use Plug.Test
  import ExUnit.CaptureLog

  alias PipelinesAPI.Audit

  setup do
    previous_audit_logging = Application.get_env(:pipelines_api, :audit_logging)
    previous_audit_publish_fun = Application.get_env(:pipelines_api, :audit_publish_fun)
    Application.put_env(:pipelines_api, :audit_logging, false)

    Support.Stubs.reset()

    on_exit(fn ->
      Application.put_env(:pipelines_api, :audit_logging, previous_audit_logging)
      Application.put_env(:pipelines_api, :audit_publish_fun, previous_audit_publish_fun)
    end)

    :ok
  end

  test "logs artifact download with user_id and org_id from headers" do
    user_id = UUID.uuid4()
    org_id = UUID.uuid4()

    conn =
      conn(:get, "/artifacts/signed_url")
      |> put_req_header("x-semaphore-user-id", user_id)
      |> put_req_header("x-semaphore-org-id", org_id)
      |> put_req_header("user-agent", "SemaphoreCLI/1.0.0")

    params = %{
      "scope" => "jobs",
      "scope_id" => UUID.uuid4(),
      "path" => "agent/job_logs.txt.gz",
      "project_id" => UUID.uuid4(),
      "method" => "GET"
    }

    expected_resource_name = "artifacts/jobs/#{params["scope_id"]}/agent/job_logs.txt.gz"

    log =
      capture_log(fn ->
        assert {:ok, audit} = Audit.log_artifact_download(conn, params)

        assert Keyword.fetch!(audit, :user_id) == user_id
        assert Keyword.fetch!(audit, :org_id) == org_id
        assert Keyword.fetch!(audit, :operation_id) == ""
        assert Keyword.fetch!(audit, :resource_name) == expected_resource_name

        metadata = Keyword.fetch!(audit, :metadata)
        assert metadata.source_kind == "jobs"
        assert metadata.request_method == "GET"
      end)

    assert log =~ "AuditLog"
    assert log =~ user_id
    assert log =~ org_id
    assert log =~ expected_resource_name
  end

  test "logs workflow rebuild with front-compatible metadata" do
    user_id = UUID.uuid4()
    org_id = UUID.uuid4()
    wf_id = UUID.uuid4()
    project_id = UUID.uuid4()
    branch_name = "main"
    commit_sha = UUID.uuid4()

    conn =
      conn(:post, "/workflows/#{wf_id}/reschedule")
      |> put_req_header("x-semaphore-user-id", user_id)
      |> put_req_header("x-semaphore-org-id", org_id)

    log =
      capture_log(fn ->
        assert {:ok, audit} =
                 Audit.log_workflow_rebuild(conn, %{
                   "wf_id" => wf_id,
                   "project_id" => project_id,
                   "branch_name" => branch_name,
                   "commit_sha" => commit_sha
                 })

        assert Keyword.fetch!(audit, :user_id) == user_id
        assert Keyword.fetch!(audit, :org_id) == org_id
        assert Keyword.fetch!(audit, :resource_name) == wf_id

        metadata = Keyword.fetch!(audit, :metadata)
        assert metadata.project_id == project_id
        assert metadata.branch_name == branch_name
        assert metadata.workflow_id == wf_id
        assert metadata.commit_sha == commit_sha
      end)

    assert log =~ "AuditLog"
    assert log =~ user_id
    assert log =~ org_id
    assert log =~ wf_id
  end

  test "does not publish AMQP event when audit_logs feature is disabled" do
    user_id = UUID.uuid4()
    org_id = UUID.uuid4()
    parent = self()
    Support.Stubs.Feature.set_org_defaults(org_id)
    Support.Stubs.Feature.disable_feature(org_id, :audit_logs)
    Application.put_env(:pipelines_api, :audit_logging, true)

    Application.put_env(:pipelines_api, :audit_publish_fun, fn _message ->
      send(parent, :audit_publish_attempted)
      :ok
    end)

    conn = conn_with_headers(user_id, org_id)
    params = artifact_download_params()
    expected_resource_name = "artifacts/jobs/#{params["scope_id"]}/agent/job_logs.txt.gz"

    log =
      capture_log(fn ->
        assert {:ok, _audit} = Audit.log_artifact_download(conn, params)
      end)

    assert log =~ "AuditLog"
    assert log =~ user_id
    assert log =~ org_id
    assert log =~ expected_resource_name
    refute_received :audit_publish_attempted
  end

  test "publishes AMQP event only when audit_logs feature is enabled" do
    user_id = UUID.uuid4()
    org_id = UUID.uuid4()
    parent = self()
    Support.Stubs.Feature.set_org_defaults(org_id)
    Support.Stubs.Feature.enable_feature(org_id, :audit_logs)
    Application.put_env(:pipelines_api, :audit_logging, true)

    Application.put_env(:pipelines_api, :audit_publish_fun, fn _message ->
      send(parent, :audit_publish_attempted)
      :ok
    end)

    log =
      capture_log(fn ->
        assert {:ok, _audit} =
                 Audit.log_artifact_download(
                   conn_with_headers(user_id, org_id),
                   artifact_download_params()
                 )
      end)

    assert_received :audit_publish_attempted
    assert log =~ "AuditLog"
    assert log =~ user_id
    assert log =~ org_id
  end

  defp conn_with_headers(user_id, org_id) do
    conn(:get, "/artifacts/signed_url")
    |> put_req_header("x-semaphore-user-id", user_id)
    |> put_req_header("x-semaphore-org-id", org_id)
  end

  defp artifact_download_params do
    %{
      "scope" => "jobs",
      "scope_id" => UUID.uuid4(),
      "path" => "agent/job_logs.txt.gz",
      "project_id" => UUID.uuid4(),
      "method" => "GET"
    }
  end
end
