defmodule Zebra.Models.TaskTest do
  use Zebra.DataCase

  alias Zebra.Models

  describe ".create" do
    test "it sets created_at and updated_at" do
      {:ok, task} = Zebra.Models.Task.create(%{})

      assert task.created_at != nil
      assert task.updated_at != nil

      assert task.created_at == task.updated_at
    end
  end

  describe ".update" do
    test "it updates updated_at" do
      {:ok, task} = Support.Factories.Task.create()

      :timer.sleep(1000)

      old_updated_at = task.updated_at

      {:ok, task} = task |> Zebra.Models.Task.update()

      new_updated_at = task.updated_at

      assert old_updated_at < new_updated_at
    end

    test "it updates the fields" do
      {:ok, task} = Support.Factories.Task.create()
      assert task.result != "passed"

      {:ok, task} = task |> Zebra.Models.Task.update(%{result: "passed"})

      assert task.result == "passed"
    end
  end

  describe ".finish" do
    test "it sets the result" do
      {:ok, task} = Support.Factories.Task.create()
      assert task.result != "passed"

      {:ok, task} = Zebra.Models.Task.finish(task, "passed")

      assert task.result == "passed"
    end
  end

  describe ".finished_at" do
    test "returns datetime when the last job was finished" do
      {:ok, task} = Support.Factories.Task.create(%{result: "passed"})

      {:ok, _first_job} =
        Support.Factories.Job.create(:finished, %{
          build_id: task.id,
          finished_at: DateTime.from_unix!(100)
        })

      {:ok, second_job} =
        Support.Factories.Job.create(:finished, %{
          build_id: task.id,
          finished_at: DateTime.from_unix!(500)
        })

      {:ok, _third_job} =
        Support.Factories.Job.create(:finished, %{
          build_id: task.id,
          finished_at: DateTime.from_unix!(250)
        })

      assert Models.Task.finished_at(task) == second_job.finished_at
    end
  end

  describe ".find_by_id_or_request_token" do
    test "when the task can be found by id" do
      {:ok, t} = Support.Factories.Task.create(%{result: "passed"})

      assert {:ok, ^t} = Models.Task.find_by_id_or_request_token(t.id)
    end

    test "when the task can be found by request token" do
      {:ok, t} = Support.Factories.Task.create(%{result: "passed"})

      assert Models.Task.find_by_id_or_request_token(t.build_request_id) == {:ok, t}
    end

    test "when the task can't be fount by either approches" do
      id = Ecto.UUID.generate()

      assert Models.Task.find_by_id_or_request_token(id) == {:error, :not_found}
    end
  end

  describe ".find_many_by_id_or_request_token" do
    test "it looks up by either id or request token" do
      {:ok, t1} = Support.Factories.Task.create(%{result: "passed"})
      {:ok, t2} = Support.Factories.Task.create(%{result: "passed"})

      assert Zebra.Models.Task.find_many_by_id_or_request_token([
               t1.id,
               t2.build_request_id
             ]) == {:ok, [t1, t2]}
    end
  end
end
