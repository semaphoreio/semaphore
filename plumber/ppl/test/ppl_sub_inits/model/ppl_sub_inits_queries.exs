defmodule Ppl.PplSubInits.Model.PplSubInitsQueries.Test do
  use ExUnit.Case

  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.PplSubInits.Model.PplSubInitsQueries

  setup do
    Test.Helpers.truncate_db()

    {:ok, ppl_req} = request_args() |> PplRequestsQueries.insert_request()
    {:ok, %{ppl_req: ppl_req}}
  end

  defp request_args() do
    %{"service" => "git_hub", "repo_name" => "test", "owner" => "user",
      "branch_name"=> "master", "commit_sha" => "sha", "client_id" => "id",
      "client_secret" => "secret", "access_token" => "token", "project_id" => "123",
      "file_name" => "semaphore.yml", "working_dir" => ".semaphore", "wf_id" => "123",
      "request_token" =>  UUID.uuid4(), "hook_id" => UUID.uuid4(), "branch_id" => UUID.uuid4()}
  end

  test "insert ppl_sub_init", ctx do
    assert {:ok, psi} = PplSubInitsQueries.insert(ctx.ppl_req, "regular")
    assert psi.state == "created"
    assert psi.in_scheduling == false
    assert psi.recovery_count == 0
  end

  test "insert ppl_sub_init from task", ctx do
    assert {:ok, psi} = PplSubInitsQueries.insert(ctx.ppl_req, "regular", true)
    assert psi.state == "conceived"
    assert psi.in_scheduling == false
    assert psi.recovery_count == 0
  end

  test "get_by_id retruns ppl_sub_int for valid ppl_id", ctx do
    assert {:ok, psi} = PplSubInitsQueries.insert(ctx.ppl_req, "regular")

    assert {:ok, psi_2} = PplSubInitsQueries.get_by_id(ctx.ppl_req.id)
    # error_description is nil before db insert (not returning field), and empty string after
    assert psi |> Map.delete(:error_description) == psi_2 |> Map.delete(:error_description)
  end
end
