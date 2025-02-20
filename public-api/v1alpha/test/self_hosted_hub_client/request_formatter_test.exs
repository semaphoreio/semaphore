defmodule PipelinesAPI.SelfHostedHubClient.RequestFormatter.Test do
  use ExUnit.Case
  use Plug.Test

  alias PipelinesAPI.SelfHostedHubClient.RequestFormatter

  alias InternalApi.SelfHosted.{
    CreateRequest,
    UpdateRequest,
    DescribeRequest,
    DescribeAgentRequest,
    DisableAllAgentsRequest,
    DeleteAgentTypeRequest,
    ListRequest,
    ListAgentsRequest
  }

  # Create

  test "form_create_request() returns internal error when it is not called with map as a param" do
    conn = create_conn()

    assert {:error, {:internal, "Internal error"}} ==
             RequestFormatter.form_create_request(nil, conn)
  end

  test "form_create_request() returns {:ok, request} when called with map with all params" do
    conn = create_conn()
    params = %{"metadata" => %{"name" => "my-agent-type"}}
    assert {:ok, request = %CreateRequest{}} = RequestFormatter.form_create_request(params, conn)
    assert request.organization_id == "test_org"
    assert request.name == "my-agent-type"
    assert is_nil(request.agent_name_settings)
  end

  test "form_create_request() returns {:ok, request} with name settings when present" do
    conn = create_conn()

    params = %{
      "metadata" => %{"name" => "my-agent-type"},
      "spec" => %{
        "agent_name_settings" => %{
          "assignment_origin" => "assignment_origin_aws_sts",
          "release_after" => 120
        }
      }
    }

    assert {:ok, request = %CreateRequest{}} = RequestFormatter.form_create_request(params, conn)
    assert request.organization_id == "test_org"
    assert request.name == "my-agent-type"

    assert request.agent_name_settings == %InternalApi.SelfHosted.AgentNameSettings{
             assignment_origin: 2,
             release_after: 120,
             aws: nil
           }
  end

  test "form_create_request() returns default to assignment_origin_agent if missing" do
    conn = create_conn()

    params = %{
      "metadata" => %{"name" => "my-agent-type"},
      "spec" => %{
        "agent_name_settings" => %{
          "release_after" => 0
        }
      }
    }

    assert {:ok, request = %CreateRequest{}} = RequestFormatter.form_create_request(params, conn)
    assert request.organization_id == "test_org"
    assert request.name == "my-agent-type"

    assert request.agent_name_settings == %InternalApi.SelfHosted.AgentNameSettings{
             assignment_origin: 1,
             release_after: 0,
             aws: nil
           }
  end

  test "form_create_request() returns {:error, :user} when called without name" do
    conn = create_conn()

    assert {:error, {:user, "Name must be provided"}} =
             RequestFormatter.form_create_request(%{}, conn)
  end

  test "form_create_request() returns {:error, :user} when called with invalid origin" do
    conn = create_conn()

    params = %{
      "metadata" => %{"name" => "my-agent-type"},
      "spec" => %{
        "agent_name_settings" => %{
          "assignment_origin" => "assignment_origin_invalid"
        }
      }
    }

    assert {:error, {:user, "invalid assignment_origin 'assignment_origin_invalid'"}} =
             RequestFormatter.form_create_request(params, conn)
  end

  # Update

  test "form_update_request() returns internal error when it is not called with map as a param" do
    conn = create_conn()

    assert {:error, {:internal, "Internal error"}} ==
             RequestFormatter.form_update_request(nil, conn)
  end

  test "form_update_request() returns {:ok, request} when called with map with all params" do
    conn = create_conn()
    params = %{"metadata" => %{"name" => "my-agent-type"}}
    assert {:ok, request = %UpdateRequest{}} = RequestFormatter.form_update_request(params, conn)
    assert request.organization_id == "test_org"
    assert request.name == "my-agent-type"
    assert !is_nil(request.agent_type)
    assert request.agent_type.organization_id == "test_org"
    assert request.agent_type.name == "my-agent-type"
    assert is_nil(request.agent_type.agent_name_settings)
  end

  test "form_update_request() returns {:ok, request} with name settings when present" do
    conn = create_conn()

    params = %{
      "metadata" => %{"name" => "my-agent-type"},
      "spec" => %{
        "agent_name_settings" => %{
          "assignment_origin" => "assignment_origin_aws_sts",
          "release_after" => 120
        }
      }
    }

    assert {:ok, request = %UpdateRequest{}} = RequestFormatter.form_update_request(params, conn)
    assert request.organization_id == "test_org"
    assert request.name == "my-agent-type"
    assert !is_nil(request.agent_type)
    assert request.agent_type.organization_id == "test_org"
    assert request.agent_type.name == "my-agent-type"

    assert request.agent_type.agent_name_settings == %InternalApi.SelfHosted.AgentNameSettings{
             assignment_origin: 2,
             release_after: 120,
             aws: nil
           }
  end

  test "form_update_request() returns {:error, :user} when called without name" do
    conn = create_conn()

    assert {:error, {:user, "Name must be provided"}} =
             RequestFormatter.form_update_request(%{}, conn)
  end

  # Describe

  test "form_describe_request() returns internal error when it is not called with map as a param" do
    conn = create_conn()

    assert {:error, {:internal, "Internal error"}} ==
             RequestFormatter.form_describe_request(nil, conn)
  end

  test "form_describe_request() returns {:ok, request} when called with map with all params" do
    conn = create_conn()
    params = %{"agent_type_name" => "my-agent-type"}

    assert {:ok, request = %DescribeRequest{}} =
             RequestFormatter.form_describe_request(params, conn)

    assert request.organization_id == "test_org"
    assert request.name == params["agent_type_name"]
  end

  # Describe agent

  test "form_describe_agent_request() returns internal error when it is not called with map as a param" do
    conn = create_conn()

    assert {:error, {:internal, "Internal error"}} ==
             RequestFormatter.form_describe_agent_request(nil, conn)
  end

  test "form_describe_agent_request() returns {:ok, request} when called with map with all params" do
    conn = create_conn()
    params = %{"agent_name" => "my-agent"}

    assert {:ok, request = %DescribeAgentRequest{}} =
             RequestFormatter.form_describe_agent_request(params, conn)

    assert request.organization_id == "test_org"
    assert request.name == params["agent_name"]
  end

  # Delete

  test "form_delete_request() returns internal error when it is not called with map as a param" do
    conn = create_conn()

    assert {:error, {:internal, "Internal error"}} ==
             RequestFormatter.form_delete_request(nil, conn)
  end

  test "form_delete_request() returns {:ok, request} when called with map with all params" do
    conn = create_conn()
    params = %{"agent_type_name" => "my-agent-type"}

    assert {:ok, request = %DeleteAgentTypeRequest{}} =
             RequestFormatter.form_delete_request(params, conn)

    assert request.organization_id == "test_org"
    assert request.name == params["agent_type_name"]
  end

  describe "disable_all" do
    test "when it is not called with map as a param -> internal error" do
      conn = create_conn()

      assert {:error, {:internal, "Internal error"}} ==
               RequestFormatter.form_disable_all_request(nil, conn)
    end

    test "when called with some params -> :ok with only_idle defaulting to true" do
      conn = create_conn()
      params = %{"agent_type_name" => "my-agent-type"}

      assert {:ok, request = %DisableAllAgentsRequest{}} =
               RequestFormatter.form_disable_all_request(params, conn)

      assert request.organization_id == "test_org"
      assert request.agent_type == params["agent_type_name"]
      assert request.only_idle == true
    end

    test "when called with all params -> :ok" do
      conn = create_conn()
      params = %{"agent_type_name" => "my-agent-type", "only_idle" => "false"}

      assert {:ok, request = %DisableAllAgentsRequest{}} =
               RequestFormatter.form_disable_all_request(params, conn)

      assert request.organization_id == "test_org"
      assert request.agent_type == params["agent_type_name"]
      assert request.only_idle == false
    end

    test "when called with bad param -> user error" do
      conn = create_conn()
      params = %{"agent_type_name" => "my-agent-type", "only_idle" => "this-is-not-a-boolean"}

      assert {:error, {:user, "Invalid 'only_idle': 'this-is-not-a-boolean' is not a boolean."}} =
               RequestFormatter.form_disable_all_request(params, conn)
    end
  end

  # List

  test "form_list_request() returns internal error when it is not called with map as a param" do
    conn = create_conn()

    assert {:error, {:internal, "Internal error"}} ==
             RequestFormatter.form_list_request(nil, conn)
  end

  test "form_list_request() returns user error when one of int params is not integer" do
    conn = create_conn()
    params = %{"page" => "asdf"}
    assert {:error, {:user, msg}} = RequestFormatter.form_list_request(params, conn)
    assert msg == "Invalid value of 'page' param: \"asdf\" - needs to be integer."
  end

  test "form_list_request() returns {:ok, request} when called with map with all params" do
    conn = create_conn()
    params = %{"page" => 4}
    assert {:ok, request = %ListRequest{}} = RequestFormatter.form_list_request(params, conn)
    assert request.organization_id == "test_org"
    assert request.page == params["page"]
  end

  # List agents

  test "form_list_agents_request() returns internal error when it is not called with map as a param" do
    conn = create_conn()

    assert {:error, {:internal, "Internal error"}} ==
             RequestFormatter.form_list_agents_request(nil, conn)
  end

  test "form_list_agents_request() returns user error when one of int params is not integer" do
    conn = create_conn()
    params = %{"page_size" => "asdf"}
    assert {:error, {:user, msg}} = RequestFormatter.form_list_agents_request(params, conn)
    assert msg == "Invalid value of 'page_size' param: \"asdf\" - needs to be integer."
  end

  test "form_list_agents_request() returns {:ok, request} when called with map with all params" do
    conn = create_conn()
    params = %{"page_size" => "100", "cursor" => "", "agent_type" => "s1-my-type"}

    assert {:ok, request = %ListAgentsRequest{}} =
             RequestFormatter.form_list_agents_request(params, conn)

    assert request.organization_id == "test_org"
    assert request.page_size == String.to_integer(params["page_size"])
    assert request.cursor == params["cursor"]
    assert request.agent_type_name == params["agent_type"]
  end

  # Utility

  defp create_conn() do
    init_conn()
    |> put_req_header("x-semaphore-user-id", "test_user")
    |> put_req_header("x-semaphore-org-id", "test_org")
  end

  defp init_conn() do
    conn(:get, "/self_hosted_agent_types/my-agen-type-1")
  end
end
