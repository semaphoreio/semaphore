defmodule Zebra.Workers.JobTerminatorTest do
  use Zebra.DataCase

  test "terminating jobs that exceeded execution time limit" do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    five_mis_ago = now |> Timex.shift(seconds: -300)
    four_minutes = 4 * 60
    six_minutes = 6 * 60

    {:ok, job1} =
      Support.Factories.Job.create(:started, %{
        started_at: five_mis_ago,
        execution_time_limit: four_minutes
      })

    {:ok, job2} =
      Support.Factories.Job.create(:started, %{
        started_at: five_mis_ago,
        execution_time_limit: six_minutes
      })

    #
    # Job1 exceeded its execution_time_limit, it should be stopped.
    # Job2 did not exceeded its execution_time_limit, it shouldn't be stopped.
    #
    Zebra.Workers.JobTerminator.tick()

    #
    # The worker creates stop requests. Let's assert their existance.
    #
    assert {:ok, _} = Zebra.Models.JobStopRequest.find_by_job_id(job1.id)
    assert {:error, :not_found} = Zebra.Models.JobStopRequest.find_by_job_id(job2.id)

    #
    # Let's validate that the stop requests were created properly by running the
    # stopper worker.
    #
    worker = Zebra.Workers.JobStopper.init()
    Zebra.Workers.DbWorker.tick(worker)

    #
    # Now, the job1 should be stopped. Job2 should still be running.
    #
    job1 = Zebra.Models.Job.reload(job1)
    assert job1.aasm_state == "finished"
    assert job1.result == "stopped"

    job2 = Zebra.Models.Job.reload(job2)
    assert job2.aasm_state == "started"
    assert job2.result == nil
  end
end
