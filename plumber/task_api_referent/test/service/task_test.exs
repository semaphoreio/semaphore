defmodule TaskApiReferent.Service.TaskTest do
  use ExUnit.Case

  alias TaskApiReferent.Service

  require UUID

  setup_all do

    task = %{state: :FINISHED, result: :FAILED, jobs: [], request_token: "",
             ppl_id: "", wf_id: ""}

    Service.Task.set(:valid_task, task)
    {:ok, [valid_task: task]}
  end

  test "set_property - providing task_id, property_name and property_value, it should add property_name:property_value pair in TaskAgent" do
    task_id = UUID.uuid4()
    task = %{result: :FAILED, request_token: ""}
    Service.Task.set(task_id, task)

    Service.Task.set_property(task_id, :result, :PASSED)

    {:ok, task} = Service.Task.get(task_id)
    assert :PASSED == Map.get(task, :result)
  end

  test "get_property - providing task_id, property_name, it should return property_value from TaskAgent" do
    task_id = UUID.uuid4()
    task = %{result: :FAILED, request_token: ""}
    Service.Task.set(task_id, task)

    {:ok, property_value} = Service.Task.get_property(task_id, :result)
    assert property_value == :FAILED
  end

  test "add_to_property - providing task_id, property_name and property_value, it should add property_value in List named property_name in TaskAgent" do
    task_id = UUID.uuid4()
    task = %{jobs: [], request_token: ""}
    Service.Task.set(task_id, task)

    job_id = UUID.uuid4()
    {:ok, _} = Service.Task.add_to_property(task_id, :jobs, job_id)

    {:ok, task} = Service.Task.get(task_id)
    assert length(Map.get(task, :jobs)) == 1

    assert Map.get(task, :jobs) == [job_id]
  end
end
