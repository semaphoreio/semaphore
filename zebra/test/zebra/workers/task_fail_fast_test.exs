defmodule Zebra.Workers.TaskFailFastTest do
  use Zebra.DataCase

  alias Zebra.LegacyRepo, as: Repo

  setup do
    {:ok, org_id: Ecto.UUID.generate()}
  end

  describe ".query" do
    test "it ignores tasks without fail-fast strategies", %{org_id: org_id} do
      {:ok, task} = Support.Factories.Task.create()

      {:ok, job1} = create_job(org_id, :pending, %{build_id: task.id})

      {:ok, _} =
        create_job(org_id, :finished, %{
          build_id: task.id,
          result: "failed"
        })

      #
      # The task satisfies the "has at least one failed job" but it has no
      # fail_fast_strategy.
      #
      tuples = Zebra.Workers.TaskFailFast.query("stop") |> Repo.all()

      assert tuples == []

      #
      # Let's check if the strategy is the only thing that prevented the lookup
      #
      assert {:ok, _} =
               Zebra.Models.Task.update(task, %{
                 fail_fast_strategy: "stop"
               })

      tuples = Zebra.Workers.TaskFailFast.query("stop") |> Repo.all()

      assert tuples == [{task.id, job1.id}]
    end

    test "it returns only jobs that have no job_stop_requests", %{org_id: org_id} do
      {:ok, task} =
        Support.Factories.Task.create(%{
          fail_fast_strategy: "stop"
        })

      {:ok, job1} = create_job(org_id, :pending, %{build_id: task.id})

      {:ok, _} =
        create_job(org_id, :finished, %{
          build_id: task.id,
          result: "failed"
        })

      # returns the job because it has no stop request
      tuples = Zebra.Workers.TaskFailFast.query("stop") |> Repo.all()
      assert tuples == [{task.id, job1.id}]

      assert {:ok, _} = Zebra.Models.JobStopRequest.create(job1.build_id, job1.id)

      # returns nothing, because the job already has a stop request
      tuples = Zebra.Workers.TaskFailFast.query("stop") |> Repo.all()
      assert tuples == []
    end

    test "it returns only jobs that have tasks with a failed job", %{org_id: org_id} do
      {:ok, task} =
        Support.Factories.Task.create(%{
          fail_fast_strategy: "stop"
        })

      {:ok, job1} = create_job(org_id, :pending, %{build_id: task.id})
      {:ok, job2} = create_job(org_id, :pending, %{build_id: task.id})

      # returns nothing, as the task has no failed jobs
      tuples = Zebra.Workers.TaskFailFast.query("stop") |> Repo.all()
      assert tuples == []

      {:ok, _} =
        Zebra.Models.Job.update(job1, %{
          aasm_state: "finished",
          result: "failed"
        })

      # task now has at least one failed job
      tuples = Zebra.Workers.TaskFailFast.query("stop") |> Repo.all()
      assert tuples == [{task.id, job2.id}]
    end

    test "when the strategy is stop => return all non-finished jobs", %{org_id: org_id} do
      {:ok, task} =
        Support.Factories.Task.create(%{
          fail_fast_strategy: "stop"
        })

      {:ok, job1} = create_job(org_id, :pending, %{build_id: task.id})
      {:ok, job2} = create_job(org_id, :enqueued, %{build_id: task.id})
      {:ok, job3} = create_job(org_id, :scheduled, %{build_id: task.id})
      {:ok, job4} = create_job(org_id, :started, %{build_id: task.id})

      # task needs to have at least one failed job
      {:ok, _} =
        create_job(org_id, :finished, %{
          build_id: task.id,
          result: "failed"
        })

      # returns every non-finished job
      tuples = Zebra.Workers.TaskFailFast.query("stop") |> Repo.all()
      assert length(tuples) == 4
      assert {task.id, job1.id} in tuples
      assert {task.id, job2.id} in tuples
      assert {task.id, job3.id} in tuples
      assert {task.id, job4.id} in tuples
    end

    test "when the strategy is cancel => return all non-started jobs", %{org_id: org_id} do
      {:ok, task} =
        Support.Factories.Task.create(%{
          fail_fast_strategy: "cancel"
        })

      {:ok, job1} = create_job(org_id, :pending, %{build_id: task.id})
      {:ok, job2} = create_job(org_id, :enqueued, %{build_id: task.id})
      {:ok, job3} = create_job(org_id, :scheduled, %{build_id: task.id})
      {:ok, _} = create_job(org_id, :started, %{build_id: task.id})

      # task needs to have at least one failed job
      {:ok, _} =
        create_job(org_id, :finished, %{
          build_id: task.id,
          result: "failed"
        })

      # returns every non-started job
      tuples = Zebra.Workers.TaskFailFast.query("cancel") |> Repo.all()

      # mocked jobs are not always properly order because timestamps are the same
      # so we should only assert which jobs are returned
      assert length(tuples) == 3
      assert {task.id, job1.id} in tuples
      assert {task.id, job2.id} in tuples
      assert {task.id, job3.id} in tuples
    end
  end

  describe ".tick" do
    alias Support.Factories, as: F
    alias Zebra.Models.JobStopRequest

    test "when the task has a cancel strategy", %{org_id: org_id} do
      {:ok, task} = F.Task.create(%{fail_fast_strategy: "cancel"})
      {:ok, job1} = create_job(org_id, :pending, %{build_id: task.id})
      {:ok, job2} = create_job(org_id, :enqueued, %{build_id: task.id})
      {:ok, job3} = create_job(org_id, :scheduled, %{build_id: task.id})
      {:ok, job4} = create_job(org_id, :started, %{build_id: task.id})
      {:ok, job5} = create_job(org_id, :finished, %{build_id: task.id})

      {:ok, job6} =
        create_job(org_id, :finished, %{
          build_id: task.id,
          result: "failed"
        })

      Zebra.Workers.TaskFailFast.tick()

      assert {:ok, _} = JobStopRequest.find_by_job_id(job1.id)
      assert {:ok, _} = JobStopRequest.find_by_job_id(job2.id)
      assert {:ok, _} = JobStopRequest.find_by_job_id(job3.id)
      assert {:error, :not_found} = JobStopRequest.find_by_job_id(job4.id)
      assert {:error, :not_found} = JobStopRequest.find_by_job_id(job5.id)
      assert {:error, :not_found} = JobStopRequest.find_by_job_id(job6.id)
    end

    test "when the task has a stop strategy", %{org_id: org_id} do
      {:ok, task} = F.Task.create(%{fail_fast_strategy: "stop"})
      {:ok, job1} = create_job(org_id, :pending, %{build_id: task.id})
      {:ok, job2} = create_job(org_id, :enqueued, %{build_id: task.id})
      {:ok, job3} = create_job(org_id, :scheduled, %{build_id: task.id})
      {:ok, job4} = create_job(org_id, :started, %{build_id: task.id})
      {:ok, job5} = create_job(org_id, :finished, %{build_id: task.id})

      {:ok, job6} =
        create_job(org_id, :finished, %{
          build_id: task.id,
          result: "failed"
        })

      Zebra.Workers.TaskFailFast.tick()

      assert {:ok, _} = JobStopRequest.find_by_job_id(job1.id)
      assert {:ok, _} = JobStopRequest.find_by_job_id(job2.id)
      assert {:ok, _} = JobStopRequest.find_by_job_id(job3.id)
      assert {:ok, _} = JobStopRequest.find_by_job_id(job4.id)
      assert {:error, :not_found} = JobStopRequest.find_by_job_id(job5.id)
      assert {:error, :not_found} = JobStopRequest.find_by_job_id(job6.id)
    end

    test "when the task has no strategy", %{org_id: org_id} do
      {:ok, task} = F.Task.create()
      {:ok, job1} = create_job(org_id, :pending, %{build_id: task.id})
      {:ok, job2} = create_job(org_id, :enqueued, %{build_id: task.id})
      {:ok, job3} = create_job(org_id, :scheduled, %{build_id: task.id})
      {:ok, job4} = create_job(org_id, :started, %{build_id: task.id})
      {:ok, job5} = create_job(org_id, :finished, %{build_id: task.id})

      {:ok, job6} =
        create_job(org_id, :finished, %{
          build_id: task.id,
          result: "failed"
        })

      Zebra.Workers.TaskFailFast.tick()

      assert {:error, :not_found} = JobStopRequest.find_by_job_id(job1.id)
      assert {:error, :not_found} = JobStopRequest.find_by_job_id(job2.id)
      assert {:error, :not_found} = JobStopRequest.find_by_job_id(job3.id)
      assert {:error, :not_found} = JobStopRequest.find_by_job_id(job4.id)
      assert {:error, :not_found} = JobStopRequest.find_by_job_id(job5.id)
      assert {:error, :not_found} = JobStopRequest.find_by_job_id(job6.id)
    end

    test "when the task has stop strategy but no failed jobs", %{org_id: org_id} do
      {:ok, task} = F.Task.create(%{fail_fast_strategy: "stop"})
      {:ok, job1} = create_job(org_id, :pending, %{build_id: task.id})
      {:ok, job2} = create_job(org_id, :enqueued, %{build_id: task.id})
      {:ok, job3} = create_job(org_id, :scheduled, %{build_id: task.id})
      {:ok, job4} = create_job(org_id, :started, %{build_id: task.id})
      {:ok, job5} = create_job(org_id, :finished, %{build_id: task.id})

      Zebra.Workers.TaskFailFast.tick()

      assert {:error, :not_found} = JobStopRequest.find_by_job_id(job1.id)
      assert {:error, :not_found} = JobStopRequest.find_by_job_id(job2.id)
      assert {:error, :not_found} = JobStopRequest.find_by_job_id(job3.id)
      assert {:error, :not_found} = JobStopRequest.find_by_job_id(job4.id)
      assert {:error, :not_found} = JobStopRequest.find_by_job_id(job5.id)
    end

    test "when the task has cancel strategy but no failed jobs", %{org_id: org_id} do
      {:ok, task} = F.Task.create(%{fail_fast_strategy: "cancel"})
      {:ok, job1} = create_job(org_id, :pending, %{build_id: task.id})
      {:ok, job2} = create_job(org_id, :enqueued, %{build_id: task.id})
      {:ok, job3} = create_job(org_id, :scheduled, %{build_id: task.id})
      {:ok, job4} = create_job(org_id, :started, %{build_id: task.id})
      {:ok, job5} = create_job(org_id, :finished, %{build_id: task.id})

      Zebra.Workers.TaskFailFast.tick()

      assert {:error, :not_found} = JobStopRequest.find_by_job_id(job1.id)
      assert {:error, :not_found} = JobStopRequest.find_by_job_id(job2.id)
      assert {:error, :not_found} = JobStopRequest.find_by_job_id(job3.id)
      assert {:error, :not_found} = JobStopRequest.find_by_job_id(job4.id)
      assert {:error, :not_found} = JobStopRequest.find_by_job_id(job5.id)
    end
  end

  defp create_job(org_id, state, params) do
    Support.Factories.Job.create(state, Map.put(params, :organization_id, org_id))
  end
end
