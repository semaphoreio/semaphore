defmodule TaskApiReferent.Agent.TaskTest do
  use ExUnit.Case

  alias TaskApiReferent.Agent

  require UUID

  setup_all do

    task = %{state: :FINISHED, result: :FAILED, jobs: [], request_token: "",
             ppl_id: "", wf_id: ""}

    Agent.Task.set(:valid_task, task)
    {:ok, [valid_task: task]}
  end

  test "get - providing valid key, it should return Task Map from the Agent's State Map", context do
    {:ok, task} = Agent.Task.get(:valid_task)
    assert Map.equal?(task, context[:valid_task])
  end

  test "get - providing non-existant key, it should return :error" do
    assert {:error, _} = Agent.Task.get(:non_existant_key)
  end

  test "set - providing key and value, it should add key:value pair in the Agent's State Map", context do
    task_id = UUID.uuid4()
    {:ok, _} = Agent.Task.set(task_id, context[:valid_task])

    {:ok, task} = Agent.Task.get(task_id)
    assert Map.equal?(context[:valid_task], task)
  end
end
