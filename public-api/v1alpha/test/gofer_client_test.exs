defmodule PipelinesAPI.GoferClient.Test do
  use ExUnit.Case

  alias PipelinesAPI.GoferClient

  test "trigger promotion on Gofer and get :ok response" do
    user_id = UUID.uuid4()
    hook = %{id: UUID.uuid4(), project_id: UUID.uuid4(), branch_id: UUID.uuid4()}

    workflow = Support.Stubs.Workflow.create(hook, user_id)
    pipeline = Support.Stubs.Pipeline.create_initial(workflow, name: "Build & Test")
    switch = Support.Stubs.Pipeline.add_switch(pipeline)
    _ = Support.Stubs.Switch.add_target(switch, name: "Foo promotion")

    params = %{
      "switch_id" => switch.id,
      "name" => "Foo promotion",
      "override" => true,
      "request_token" => UUID.uuid4(),
      "user_id" => "us1"
    }

    assert {:ok, message} = GoferClient.trigger(params)
    assert message == "Promotion successfully triggered."
  end

  test "trigger rpc call returns internal error when it cann't connect to Gofer service" do
    System.put_env("GOFER_GRPC_URL", "something:12345")

    params = %{
      "switch_id" => "sw1",
      "name" => "tg1",
      "override" => true,
      "request_token" => "rt1",
      "user_id" => "us1",
      "env1" => "1",
      "env2" => "2"
    }

    assert {:error, {:internal, message}} = GoferClient.trigger(params)
    assert message == "Internal error"

    System.put_env("GOFER_GRPC_URL", "127.0.0.1:50052")
  end
end
