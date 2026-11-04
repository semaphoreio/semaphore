defmodule Zebra.Workers.TaskFinisherTest do
  use Zebra.DataCase

  alias Zebra.Workers.TaskFinisher, as: W

  describe ".tick" do
    test "it calculates the task result for all tasks" do
      tasks =
        1..5
        |> Enum.map(fn _ ->
          create_task_with_finished_jobs()
        end)

      tasks
      |> Enum.each(fn t ->
        assert t.result == nil
      end)

      W.tick()

      tasks
      |> Enum.each(fn t ->
        {:ok, t} = Zebra.Models.Task.find(t.id)

        assert t.result == "passed"
      end)
    end
  end

  describe ".process" do
    test "it calculates the task result and saves into the db" do
      {:ok, task} = Support.Factories.Task.create()

      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, _} =
        Support.Factories.Job.create(:finished, %{
          build_id: task.id,
          result: "passed",
          finished_at: now
        })

      {:ok, _} =
        Support.Factories.Job.create(:finished, %{
          build_id: task.id,
          result: "passed",
          finished_at: now
        })

      assert task.result == nil

      W.process(task)

      {:ok, task} = Zebra.Models.Task.find(task.id)

      assert task.result == "passed"
    end
  end

  describe ".process with unfinished jobs" do
    test "it leaves the task open until the last job finishes" do
      {:ok, task} = Support.Factories.Task.create()

      {:ok, _} = Support.Factories.Job.create(:finished, %{build_id: task.id, result: "passed"})
      {:ok, running} = Support.Factories.Job.create(:started, %{build_id: task.id})

      W.process(task)
      assert {:ok, %{result: nil}} = Zebra.Models.Task.find(task.id)

      {:ok, _} = Zebra.Models.Job.update(running, %{aasm_state: "finished", result: "failed"})

      W.process(task)
      assert {:ok, %{result: "failed"}} = Zebra.Models.Task.find(task.id)
    end
  end

  describe ".job_summary" do
    test "it counts jobs by state and result and returns the last finish time" do
      {:ok, task} = Support.Factories.Task.create()
      {:ok, other_task} = Support.Factories.Task.create()

      for {result, at} <- [{"passed", 100}, {"failed", 300}, {"stopped", 200}, {"passed", 50}] do
        {:ok, _} =
          Support.Factories.Job.create(:finished, %{
            build_id: task.id,
            result: result,
            finished_at: DateTime.from_unix!(at)
          })
      end

      {:ok, _} = Support.Factories.Job.create(:started, %{build_id: task.id})

      {:ok, _} =
        Support.Factories.Job.create(:finished, %{build_id: other_task.id, result: "failed"})

      assert W.job_summary(task.id) == %{
               total: 5,
               unfinished: 1,
               passed: 2,
               failed: 1,
               stopped: 1,
               last_finished_at: DateTime.from_unix!(300)
             }
    end

    test "a task without jobs has an empty summary" do
      {:ok, task} = Support.Factories.Task.create()

      assert W.job_summary(task.id) == %{
               total: 0,
               unfinished: 0,
               passed: 0,
               failed: 0,
               stopped: 0,
               last_finished_at: nil
             }
    end
  end

  describe ".finishable_task_ids" do
    test "it returns only open tasks whose jobs are all finished with a result" do
      done = create_task_with_finished_jobs()

      {:ok, running} = Support.Factories.Task.create()

      {:ok, _} =
        Support.Factories.Job.create(:finished, %{build_id: running.id, result: "passed"})

      {:ok, _} = Support.Factories.Job.create(:started, %{build_id: running.id})

      {:ok, no_result} = Support.Factories.Task.create()
      {:ok, _} = Support.Factories.Job.create(:finished, %{build_id: no_result.id, result: nil})

      {:ok, already_finished} = Support.Factories.Task.create(%{result: "passed"})

      {:ok, _} =
        Support.Factories.Job.create(:finished, %{build_id: already_finished.id, result: "passed"})

      assert W.finishable_task_ids() == [done.id]
    end
  end

  describe ".calculate_task_result" do
    test "when a job has no result => returns an error" do
      {:ok, task} = Support.Factories.Task.create()

      assert {:error, _} = W.calculate_task_result(summary(["passed", nil]), task)
    end

    test "when any of the jobs are stopped => result is stopped" do
      results = ["passed", "failed", "stopped"]
      {:ok, task} = Support.Factories.Task.create()

      assert {:ok, "stopped"} = W.calculate_task_result(summary(results), task)
    end

    test "when any of the jobs are failed => result is failed" do
      results = ["passed", "failed", "passed"]
      {:ok, task} = Support.Factories.Task.create()

      assert {:ok, "failed"} = W.calculate_task_result(summary(results), task)
    end

    test "when all of the jobs are passed => result is passed" do
      results = ["passed", "passed", "passed"]
      {:ok, task} = Support.Factories.Task.create()

      assert {:ok, "passed"} = W.calculate_task_result(summary(results), task)
    end

    test "when fail_fast:stop is active and jobs are stopped due to failure => result is failed" do
      results = ["passed", "failed", "stopped", "stopped"]
      {:ok, task} = Support.Factories.Task.create(%{fail_fast_strategy: "stop"})

      assert {:ok, "failed"} = W.calculate_task_result(summary(results), task)
    end

    test "when fail_fast:stop is active but no jobs failed => result is stopped" do
      results = ["passed", "stopped", "stopped"]
      {:ok, task} = Support.Factories.Task.create(%{fail_fast_strategy: "stop"})

      assert {:ok, "stopped"} = W.calculate_task_result(summary(results), task)
    end

    test "when fail_fast:cancel is active and jobs are stopped due to failure => result is stopped" do
      results = ["passed", "failed", "stopped"]
      {:ok, task} = Support.Factories.Task.create(%{fail_fast_strategy: "cancel"})

      # With cancel strategy, we don't override the normal logic
      assert {:ok, "stopped"} = W.calculate_task_result(summary(results), task)
    end
  end

  describe "roll-up with lightweight copies (D-15, verify-only)" do
    test "a mix of a pre-finished copy and a just-run real job rolls up to passed" do
      {:ok, task} = Support.Factories.Task.create()
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, original} =
        Support.Factories.Job.create(:finished, %{result: "passed", finished_at: now})

      {:ok, _copy} = Zebra.Models.Job.create_copy(original, task.id)

      {:ok, _real} =
        Support.Factories.Job.create(:finished, %{
          build_id: task.id,
          result: "passed",
          finished_at: now
        })

      assert task.result == nil

      W.lock_and_process(task.id)

      {:ok, task} = Zebra.Models.Task.find(task.id)
      assert task.result == "passed"
    end

    test "a passed copy alongside a failed real job rolls up to failed" do
      {:ok, task} = Support.Factories.Task.create()
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, original} =
        Support.Factories.Job.create(:finished, %{result: "passed", finished_at: now})

      {:ok, _copy} = Zebra.Models.Job.create_copy(original, task.id)

      {:ok, _real} =
        Support.Factories.Job.create(:finished, %{
          build_id: task.id,
          result: "failed",
          finished_at: now
        })

      W.lock_and_process(task.id)

      {:ok, task} = Zebra.Models.Task.find(task.id)
      assert task.result == "failed"
    end

    test "an all-copy task (zero run jobs) rolls up to passed and finish/1 does not crash" do
      {:ok, task} = Support.Factories.Task.create()
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, o1} = Support.Factories.Job.create(:finished, %{result: "passed", finished_at: now})

      {:ok, o2} = Support.Factories.Job.create(:finished, %{result: "passed", finished_at: now})

      {:ok, _c1} = Zebra.Models.Job.create_copy(o1, task.id)
      {:ok, _c2} = Zebra.Models.Job.create_copy(o2, task.id)

      W.lock_and_process(task.id)

      {:ok, task} = Zebra.Models.Task.find(task.id)
      assert task.result == "passed"
    end

    test "an all-copy task's finished timestamp is clamped to task creation, not the originals' past" do
      {:ok, task} = Support.Factories.Task.create()

      days_ago =
        DateTime.utc_now()
        |> DateTime.add(-3 * 24 * 60 * 60, :second)
        |> DateTime.truncate(:second)

      {:ok, original} =
        Support.Factories.Job.create(:finished, %{result: "passed", finished_at: days_ago})

      {:ok, _copy} = Zebra.Models.Job.create_copy(original, task.id)

      W.lock_and_process(task.id)

      {:ok, task} = Zebra.Models.Task.find(task.id)
      assert task.result == "passed"

      assert DateTime.compare(Zebra.Models.Task.finished_at(task), task.created_at) == :lt
      assert DateTime.compare(W.task_finished_timestamp(task), task.created_at) != :lt
    end
  end

  def create_task_with_finished_jobs do
    {:ok, task} = Support.Factories.Task.create()

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {:ok, _} =
      Support.Factories.Job.create(:finished, %{
        build_id: task.id,
        result: "passed",
        finished_at: now
      })

    {:ok, _} =
      Support.Factories.Job.create(:finished, %{
        build_id: task.id,
        result: "passed",
        finished_at: now
      })

    task
  end

  defp summary(results) do
    %{
      total: length(results),
      unfinished: 0,
      passed: Enum.count(results, &(&1 == "passed")),
      failed: Enum.count(results, &(&1 == "failed")),
      stopped: Enum.count(results, &(&1 == "stopped")),
      last_finished_at: nil
    }
  end
end
