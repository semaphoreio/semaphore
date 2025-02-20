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

      assert {:ok, "stopped"} = W.calculate_task_result(results)
    end

    test "when any of the jobs are failed => result is failed" do
      results = ["passed", "failed", "passed"]

      assert {:ok, "failed"} = W.calculate_task_result(results)
    end

    test "when all of the jobs are passed => result is passed" do
      results = ["passed", "failed", "passed"]

      assert {:ok, "failed"} = W.calculate_task_result(results)
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
