defmodule PipelinesAPI.GoferClient.RequestFormatter.Test do
  use ExUnit.Case

  alias PipelinesAPI.GoferClient.RequestFormatter

  alias InternalApi.Gofer.{
    TriggerRequest,
    EnvVariable
  }

  test "form_trigger_request() returns internal error when it is not called with map as a param" do
    assert {:error, {:internal, "Internal error"}} == RequestFormatter.form_trigger_request(nil)
  end

  test "form_trigger_request() returns {:ok, request} when called with map with all params" do
    params = %{
      "switch_id" => "sw1",
      "name" => "tg1",
      "override" => true,
      "request_token" => "rt1",
      "user_id" => "us1",
      "env1" => "1",
      "env2" => "2"
    }

    assert {:ok, request} = RequestFormatter.form_trigger_request(params)

    assert %TriggerRequest{
             switch_id: "sw1",
             target_name: "tg1",
             override: true,
             request_token: "rt1",
             triggered_by: "us1",
             env_variables: env_vars
           } = request

    assert [%EnvVariable{name: "env1", value: "1"}, %EnvVariable{name: "env2", value: "2"}] ==
             env_vars
  end

  test "form_trigger_request() rerurns user error when override params is not bool" do
    params = %{
      "switch_id" => "sw1",
      "name" => "tg1",
      "override" => "not-a-bool-val",
      "request_token" => "rt1",
      "user_id" => "us1",
      "env1" => "1",
      "env2" => "2"
    }

    assert {:error, {:user, msg}} = RequestFormatter.form_trigger_request(params)
    assert msg == "Invalid value of 'override' param: \"not-a-bool-val\" - needs to be boolean."
  end
end
