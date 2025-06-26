defmodule Ppl.RepoProxyClient.Test do
  use ExUnit.Case

  alias Ppl.RepoProxyClient


  @tag :integration
  test "describe correctly timeouts if repo proxy service takes to long to respond" do
    assert {:error, _} = RepoProxyClient.describe("timeout")
  end

  test "describe returns error when it is not possible to connect to repo proxy service" do
    use_non_existing_repo_proxy_service()

    assert {:error, _} = RepoProxyClient.describe(UUID.uuid4())

    use_test_repo_proxy_service()
  end

  @tag :integration
  test "send invalid describe request and receive bad param responsed" do
    assert {:error, message} = RepoProxyClient.describe("bad_param")
    assert message == "Error"
  end

  @tag :integration
  test "send valid describe request and receive and unpach Hook properly" do
    hook_id = UUID.uuid4()
    assert {:ok, hook} = RepoProxyClient.describe(hook_id)

    assert hook.hook_id == hook_id
    assert hook.git_ref_type == "branch"
    assert hook.branch_name == "master"
  end

  describe "create_blank/1" do
    test "returns error when repo proxy service is unreachable" do
      use_non_existing_repo_proxy_service()

      params = ppl_req_params()
      assert {:error, _} = RepoProxyClient.create_blank(params)

      use_test_repo_proxy_service()
    end

    @tag :integration
    test "correctly times out when repo proxy service takes to long to respond" do
      params = ppl_req_params() |> Map.put(:request_token, "timeout")
      assert {:error, _} = RepoProxyClient.create_blank(params)
    end

    @tag :integration
    test "correctly parses raised errors" do
      params = ppl_req_params() |> Map.put(:request_token, "bad_param")
      assert {:error, %GRPC.RPCError{message: "Bad parameter"}} =
                RepoProxyClient.create_blank(params)
    end

    @tag :integration
    test "creates a blank hook and processes response" do
      params = ppl_req_params()
      assert {:ok, response} = RepoProxyClient.create_blank(params)

      assert response.hook_id == "hook_id"
      assert response.wf_id == params.wf_id
      assert response.pipeline_id == params.id
    end
  end

  # Utility

  defp use_test_repo_proxy_service() do
     System.put_env("INTERNAL_API_URL_REPO_PROXY", "localhost:51000")
     System.put_env("REPO_PROXY_NEW_GRPC_URL", "localhost:51000")
  end

  defp use_non_existing_repo_proxy_service() do
    System.put_env("INTERNAL_API_URL_REPO_PROXY", "something:12345")
    System.put_env("REPO_PROXY_NEW_GRPC_URL", "something:12345")
  end

  defp ppl_req_params() do
    %{
      id: UUID.uuid4(),
      wf_id: UUID.uuid4(),
      request_token: UUID.uuid4(),
      request_args: %{
        "service" => "git_hub",
        "project_id" => UUID.uuid4(),
        "requester_id" => UUID.uuid4(),
        "file_name" => "semaphore.yml",
        "triggered_by" => "schedule",
        "branch_name" => "master",
        "commit_sha" => "",
        "git_reference" => "refs/heads/master"
      }
    }
  end
end
