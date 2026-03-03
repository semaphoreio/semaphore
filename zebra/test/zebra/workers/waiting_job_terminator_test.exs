defmodule Zebra.Workers.WaitingJobTerminatorTest do
  use Zebra.DataCase

  test "jobs in waiting-for-agent state that exceed max scheduled time are terminated" do
    days_ago = DateTime.utc_now() |> DateTime.add(-86_400 * 2, :second)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {:ok, job1} = Support.Factories.Job.create(:"waiting-for-agent", %{scheduled_at: days_ago})
    {:ok, job2} = Support.Factories.Job.create(:"waiting-for-agent", %{scheduled_at: now})
    {:ok, job3} = Support.Factories.Job.create(:started)

    #
    # Job1 exceeded the limit, it should be stopped.
    # Job2 did not exceed the limit, it shouldn't be stopped.
    #
    Zebra.Workers.WaitingJobTerminator.tick()
    assert {:ok, _} = Zebra.Models.JobStopRequest.find_by_job_id(job1.id)
    assert {:error, :not_found} = Zebra.Models.JobStopRequest.find_by_job_id(job2.id)

    #
    # Let's validate that the stop requests were created properly by running the
    # stopper worker.
    #
    Zebra.Workers.JobStopper.init() |> Zebra.Workers.DbWorker.tick()

    #
    # Now, job1 should be stopped. Job2 and Job3 should not be touched.
    #
    job1 = Zebra.Models.Job.reload(job1)
    assert Zebra.Models.Job.finished?(job1)
    assert Zebra.Models.Job.stopped?(job1)

    job2 = Zebra.Models.Job.reload(job2)
    assert Zebra.Models.Job.waiting_for_agent?(job2)
    refute Zebra.Models.Job.stopped?(job2)

    job3 = Zebra.Models.Job.reload(job3)
    assert Zebra.Models.Job.started?(job3)
    refute Zebra.Models.Job.stopped?(job3)
  end

  test "jobs in scheduled state that exceed max scheduled time are terminated" do
    days_ago = DateTime.utc_now() |> DateTime.add(-86_400 * 2, :second)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {:ok, job1} = Support.Factories.Job.create(:scheduled, %{scheduled_at: days_ago})
    {:ok, job2} = Support.Factories.Job.create(:scheduled, %{scheduled_at: now})
    {:ok, job3} = Support.Factories.Job.create(:started)

    #
    # Job1 exceeded the limit, it should be stopped.
    # Job2 did not exceed the limit, it shouldn't be stopped.
    #
    Zebra.Workers.WaitingJobTerminator.tick()
    assert {:ok, _} = Zebra.Models.JobStopRequest.find_by_job_id(job1.id)
    assert {:error, :not_found} = Zebra.Models.JobStopRequest.find_by_job_id(job2.id)

    #
    # Let's validate that the stop requests were created properly by running the
    # stopper worker.
    #
    Zebra.Workers.JobStopper.init() |> Zebra.Workers.DbWorker.tick()

    #
    # Now, job1 should be stopped. Job2 and Job3 should not have been touched.
    #
    job1 = Zebra.Models.Job.reload(job1)
    assert Zebra.Models.Job.finished?(job1)
    assert Zebra.Models.Job.stopped?(job1)

    job2 = Zebra.Models.Job.reload(job2)
    assert Zebra.Models.Job.scheduled?(job2)
    refute Zebra.Models.Job.stopped?(job2)

    job3 = Zebra.Models.Job.reload(job3)
    assert Zebra.Models.Job.started?(job3)
    refute Zebra.Models.Job.stopped?(job3)
  end
end
