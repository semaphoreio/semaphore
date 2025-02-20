defmodule TaskApiReferent.Agent.JobTest do
  use ExUnit.Case

  alias TaskApiReferent.Agent

  setup_all do
    job = %{state: :FINISHED, result: :PASSED, id: "123", name: "asdf", index: 0,
            commands: ["cmd1", "cmd2"], prologue_commands: [], epilogue_commands: [],
            env_vars: [], stopped: false
           }
    Agent.Job.set(:test_job, job)

    {:ok, [job: job]}
  end

  test "get - providing valid job_id it should return existing job's status", context do
    {:ok, job} = Agent.Job.get(:test_job)
    assert Map.equal?(job, context[:job])
  end

  test "get - providing invalid job_id should return :error with error message" do
    job_id = :invalid_job_id
    assert {:error, _} = Agent.Job.get(job_id)
  end

  test "set - providing job_id should set a new value in Agent's state map", ctx do
    job_id = UUID.uuid4()
    job = %{ctx.job | result: :PASSED}

    assert {:ok, _} = Agent.Job.set(job_id, job)

    {:ok, result} = Agent.Job.get(job_id)
    assert Map.equal?(result, job)
  end
end
