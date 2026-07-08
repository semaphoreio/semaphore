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

  describe ".calculate_task_result" do
    test "when any of the jobs are stopped => result is stopped" do
      results = ["passed", "failed", "stopped"]
      {:ok, task} = Support.Factories.Task.create()

      assert {:ok, "stopped"} = W.calculate_task_result(results, task)
    end

    test "when any of the jobs are failed => result is failed" do
      results = ["passed", "failed", "passed"]
      {:ok, task} = Support.Factories.Task.create()

      assert {:ok, "failed"} = W.calculate_task_result(results, task)
    end

    test "when all of the jobs are passed => result is passed" do
      results = ["passed", "passed", "passed"]
      {:ok, task} = Support.Factories.Task.create()

      assert {:ok, "passed"} = W.calculate_task_result(results, task)
    end

    test "when fail_fast:stop is active and jobs are stopped due to failure => result is failed" do
      results = ["passed", "failed", "stopped", "stopped"]
      {:ok, task} = Support.Factories.Task.create(%{fail_fast_strategy: "stop"})

      assert {:ok, "failed"} = W.calculate_task_result(results, task)
    end

    test "when fail_fast:stop is active but no jobs failed => result is stopped" do
      results = ["passed", "stopped", "stopped"]
      {:ok, task} = Support.Factories.Task.create(%{fail_fast_strategy: "stop"})

      assert {:ok, "stopped"} = W.calculate_task_result(results, task)
    end

    test "when fail_fast:cancel is active and jobs are stopped due to failure => result is stopped" do
      results = ["passed", "failed", "stopped"]
      {:ok, task} = Support.Factories.Task.create(%{fail_fast_strategy: "cancel"})

      # With cancel strategy, we don't override the normal logic
      assert {:ok, "stopped"} = W.calculate_task_result(results, task)
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
end
