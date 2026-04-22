defmodule PipelinesAPI.AuditTest do
  use ExUnit.Case
  use Plug.Test
  import ExUnit.CaptureLog

  alias PipelinesAPI.Audit

  setup do
    Application.put_env(:pipelines_api, :audit_logging, false)
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

    log =
      capture_log(fn ->
        audit = Audit.log_artifact_download(conn, params)

        assert Keyword.fetch!(audit, :user_id) == user_id
        assert Keyword.fetch!(audit, :org_id) == org_id
        assert Keyword.fetch!(audit, :operation_id) == ""

        metadata = Keyword.fetch!(audit, :metadata)
        assert metadata.source_kind == "jobs"
        assert metadata.request_method == "GET"
      end)

    assert log =~ "AuditLog"
    assert log =~ user_id
    assert log =~ org_id
  end
end
