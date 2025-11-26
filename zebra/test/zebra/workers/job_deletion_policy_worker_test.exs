defmodule Zebra.Workers.JobDeletionPolicyWorkerTest do
  use Zebra.DataCase

  alias Zebra.Models.{Job, JobStopRequest}
  alias Zebra.Workers.JobDeletionPolicyWorker, as: Worker

  describe ".tick" do
    test "deletes expired jobs and related stop requests" do
      worker = %Worker{limit: 10, naptime: 0, longnaptime: 0}

      {:ok, job} = Support.Factories.Job.create(:finished)
      {:ok, _} = JobStopRequest.create(job.build_id, job.id)

      expired_at =
        DateTime.utc_now()
        |> DateTime.add(-3600, :second)

      {:ok, _} = Job.update(job, %{expires_at: expired_at})

      assert Worker.tick(worker)

      assert {:error, :not_found} = Job.find(job.id)
      assert {:error, :not_found} = JobStopRequest.find_by_job_id(job.id)
    end

    test "returns false when nothing is eligible for deletion" do
      worker = %Worker{limit: 10, naptime: 0, longnaptime: 0}

      {:ok, job} = Support.Factories.Job.create(:finished)

      future_expiration =
        DateTime.utc_now()
        |> DateTime.add(3600, :second)

      {:ok, _} = Job.update(job, %{expires_at: future_expiration})

      refute Worker.tick(worker)

      assert {:ok, _} = Job.find(job.id)
    end
  end
end
