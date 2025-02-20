defmodule PipelinesAPI.RepoProxyClient.Test do
  use ExUnit.Case

  alias PipelinesAPI.RepoProxyClient

  test "call Create API and get :ok response" do
    params = %{
      "project_id" => "project_1",
      "reference" => "master",
      "commit_sha" => "1234",
      "requester_id" => "user_1",
      "pipeline_file" => ".semaphore/semaphore.yml"
    }

    assert {:ok, response} = RepoProxyClient.create(params)

    assert {:ok, _} = UUID.info(response.workflow_id)
    assert {:ok, _} = UUID.info(response.pipeline_id)
    assert {:ok, _} = UUID.info(response.hook_id)
  end

  test "call Create API and get :invalid_argument response" do
    params = %{
      "project_id" => "invalid_arg",
      "reference" => "master",
      "commit_sha" => "1234",
      "requester_id" => "user_1",
      "pipeline_file" => ".semaphore/semaphore.yml"
    }

    assert {:error, {:user, message}} = RepoProxyClient.create(params)
    assert message == "Invalid argument"
  end

  test "call Create API and get :not_found response" do
    params = %{
      "project_id" => "not_found",
      "reference" => "master",
      "commit_sha" => "1234",
      "requester_id" => "user_1",
      "pipeline_file" => ".semaphore/semaphore.yml"
    }

    assert {:error, {:user, message}} = RepoProxyClient.create(params)
    assert message == "Not found"
  end

  test "call Create API and get :aborted response" do
    params = %{
      "project_id" => "aborted",
      "reference" => "master",
      "commit_sha" => "1234",
      "requester_id" => "user_1",
      "pipeline_file" => ".semaphore/semaphore.yml"
    }

    assert {:error, {:user, message}} = RepoProxyClient.create(params)
    assert message == "Aborted"
  end

  test "create rpc call returns internal error when it can't connect to RepoProxy service" do
    System.put_env("REPO_PROXY_URL", "something:12345")

    params = %{
      "project_id" => "project_1",
      "reference" => "master",
      "commit_sha" => "1234",
      "requester_id" => "user_1",
      "pipeline_file" => ".semaphore/semaphore.yml"
    }

    assert {:error, {:internal, message}} = RepoProxyClient.create(params)
    assert message == "Internal error"

    System.put_env("REPO_PROXY_URL", "127.0.0.1:50052")
  end
end
