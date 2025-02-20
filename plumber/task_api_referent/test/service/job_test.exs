defmodule TaskApiReferent.Service.JobTest do
  use ExUnit.Case

  alias TaskApiReferent.Service
  
  setup_all do

    job = %{state: :FINISHED, result: :PASSED, commands: []}

    Service.Job.set(:valid_job, job)
    {:ok, [valid_job: job]}
  end

  test "set_property - providing job_id, property_name and property_value, it should add property_name:property_value pair in JobAgent" do
    job_id = UUID.uuid4()
    job = %{result: :FAILED}
    Service.Job.set(job_id, job)

    Service.Job.set_property(job_id, :result, :PASSED)

    {:ok, job} = Service.Job.get(job_id)
    assert :PASSED == Map.get(job, :result)
  end

  test "get_property - providing job_id, property_name, it should return property_value from JobAgent" do
    job_id = UUID.uuid4()
    job = %{result: :FAILED}
    Service.Job.set(job_id, job)

    {:ok, property_value} = Service.Job.get_property(job_id, :result)
    assert property_value == :FAILED
  end

  test "add_to_property - providing job_id, property_name and property_value, it should add property_value in List named property_name in JobAgent" do
    job_id = UUID.uuid4()
    job = %{commands: []}
    Service.Job.set(job_id, job)

    command_id = UUID.uuid4()
    {:ok, _} = Service.Job.add_to_property(job_id, :commands, command_id)

    {:ok, job} = Service.Job.get(job_id)
    assert length(Map.get(job, :commands)) == 1

    assert Map.get(job, :commands) == [command_id]
  end
end
