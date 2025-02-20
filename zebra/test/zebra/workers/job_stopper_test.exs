defmodule Zebra.Workers.JobStopperTest do
  use Zebra.DataCase

  alias Zebra.LegacyRepo, as: Repo
  alias Zebra.Models.Job
  alias Zebra.Models.JobStopRequest
  alias Zebra.Workers.JobStopper, as: Worker

  import Ecto.Query

  describe ".request_stop_async" do
    test "it schedules a job stop request" do
      {:ok, job} = Support.Factories.Job.create(:started)
      assert {:ok, _} = Zebra.Workers.JobStopper.request_stop_async(job)
    end

    test "it doesn't store duplicate requests" do
      {:ok, job} = Support.Factories.Job.create(:started)

      # Try to stop 5 times
      1..5
      |> Enum.each(fn _ ->
        assert {:ok, _} = Zebra.Workers.JobStopper.request_stop_async(job)
      end)

      request_count =
        Zebra.Models.JobStopRequest
        |> where([r], r.job_id == ^job.id)
        |> Zebra.LegacyRepo.aggregate(:count, :id)

      assert request_count == 1
    end
  end

  describe ".request_stop_for_all_jobs_in_task_async" do
    test "it schedules multiple job stop requests" do
      {:ok, task} = Support.Factories.Task.create()

      {:ok, j1} = Support.Factories.Job.create(:pending, %{build_id: task.id})
      {:ok, j2} = Support.Factories.Job.create(:pending, %{build_id: task.id})

      assert :ok = Zebra.Workers.JobStopper.request_stop_for_all_jobs_in_task_async(task)

      stop_requests =
        Zebra.Models.JobStopRequest
        |> where([r], r.build_id == ^task.id)
        |> Zebra.LegacyRepo.all()

      assert length(stop_requests) == 2

      request_ids = Enum.map(stop_requests, fn r -> r.job_id end) |> Enum.sort()
      job_ids = [j1.id, j2.id] |> Enum.sort()

      assert request_ids == job_ids
    end

    test "it is idempotent" do
      {:ok, task} = Support.Factories.Task.create()

      {:ok, j1} = Support.Factories.Job.create(:pending, %{build_id: task.id})
      {:ok, j2} = Support.Factories.Job.create(:pending, %{build_id: task.id})

      1..5
      |> Enum.each(fn _ ->
        assert :ok = Zebra.Workers.JobStopper.request_stop_for_all_jobs_in_task_async(task)
      end)

      stop_requests =
        Zebra.Models.JobStopRequest
        |> where([r], r.build_id == ^task.id)
        |> Zebra.LegacyRepo.all()

      assert length(stop_requests) == 2

      request_ids = Enum.map(stop_requests, fn r -> r.job_id end) |> Enum.sort()
      job_ids = [j1.id, j2.id] |> Enum.sort()

      assert request_ids == job_ids
    end
  end

  describe ".process" do
    test "when job is running" do
      {:ok, job} = Support.Factories.Job.create(:started)
      {:ok, req} = Zebra.Workers.JobStopper.request_stop_async(job)

      Worker.init() |> Zebra.Workers.DbWorker.tick()

      req = JobStopRequest |> where([r], r.id == ^req.id) |> Repo.one()

      job = Job.reload(job)

      assert Job.stopped?(job)
      assert req.state == JobStopRequest.state_done()
      assert req.result == JobStopRequest.result_success()
      assert req.result_reason == JobStopRequest.result_reason_job_transitioned_to_stopping()
    end
  end
end
