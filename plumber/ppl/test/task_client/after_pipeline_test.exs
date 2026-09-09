defmodule Ppl.TaskClient.AfterPipelineTest do
  use ExUnit.Case, async: false

  import Mock

  alias Block.TaskApiClient.GrpcClient, as: TaskApiClient
  alias Ppl.TaskClient.AfterPipeline
  alias Test.Support.RequestFactory

  # The task API formatter rebuilds the jobs from the task DEFINITION it is handed
  # (the first argument to schedule/3), not from request_params["jobs"]. So the
  # inherited limit must be present on the definition's jobs, in the YAML shape
  # the formatter converts (%{"minutes" => n}). These tests assert on that layer.

  describe "start/4 execution_time_limit on the scheduled definition" do
    test "a job without its own limit inherits the pipeline's limit" do
      [job] = scheduled_definition_jobs([job_def("Submit Reports")], 45)

      assert job["execution_time_limit"] == %{"minutes" => 45}
    end

    test "a job with its own limit keeps it untouched" do
      raw_job =
        "Process Reports"
        |> job_def()
        |> Map.put("execution_time_limit", %{"minutes" => 20})

      [job] = scheduled_definition_jobs([raw_job], 45)

      assert job["execution_time_limit"] == %{"minutes" => 20}
    end

    test "the pipeline's limit is inherited by every job that lacks one" do
      raw_jobs = [
        job_def("Submit Reports"),
        "Process Reports" |> job_def() |> Map.put("execution_time_limit", %{"hours" => 1})
      ]

      assert [first, second] = scheduled_definition_jobs(raw_jobs, 30)
      assert first["execution_time_limit"] == %{"minutes" => 30}
      assert second["execution_time_limit"] == %{"hours" => 1}
    end

    test "no limit is added when the pipeline has no limit of its own" do
      [job] = scheduled_definition_jobs([job_def("Submit Reports")], nil)

      refute Map.has_key?(job, "execution_time_limit")
    end
  end

  defp job_def(name), do: %{"name" => name, "commands" => ["echo #{name}"]}

  defp scheduled_definition_jobs(raw_jobs, ppl_limit) do
    test_pid = self()

    ppl_req = %{
      id: UUID.uuid4(),
      wf_id: UUID.uuid4(),
      source_args: %{},
      request_args: RequestFactory.schedule_args(%{}, :local),
      definition: %{"after_pipeline" => [%{"build" => %{"jobs" => raw_jobs}}]}
    }

    after_ppl = %{id: 1, ppl_id: ppl_req.id}
    ppl = %{result: "passed", result_reason: nil, exec_time_limit_min: ppl_limit}

    with_mock TaskApiClient,
      schedule: fn definition, _request_params, _url ->
        send(test_pid, {:scheduled_definition, definition})
        {:ok, %{id: UUID.uuid4()}}
      end do
      assert {:ok, _task_id} = AfterPipeline.start(ppl_req, after_ppl, ppl_trace(), ppl)
    end

    assert_received {:scheduled_definition, definition}

    definition["jobs"]
  end

  defp ppl_trace do
    now = DateTime.utc_now()

    %{
      created_at: now,
      pending_at: now,
      queuing_at: now,
      running_at: now,
      done_at: now
    }
  end
end
