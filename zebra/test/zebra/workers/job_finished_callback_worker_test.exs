defmodule Zebra.Workers.JobFinishedCallbackWorkerTest do
  use Zebra.DataCase

  alias Zebra.Models.Job
  alias Zebra.Workers.JobFinishedCallbackWorker, as: W

  describe ".handle_message" do
    test "when the job is started => handles a started callback message" do
      {:ok, job} = Support.Factories.Job.create(:started)

      payload = %{"result" => "passed"} |> Poison.encode!()
      callback_message = %{"job_hash_id" => job.id, "payload" => payload} |> Poison.encode!()

      assert Job.started?(job)
      assert is_nil(job.finished_at)

      W.handle_message(callback_message)

      {:ok, job} = Job.find(job.id)

      assert Job.finished?(job)
      refute is_nil(job.finished_at)
    end

    test "when the payload result is nil => saves false" do
      {:ok, job} = Support.Factories.Job.create(:started)

      payload = %{"result" => nil} |> Poison.encode!()
      callback_message = %{"job_hash_id" => job.id, "payload" => payload} |> Poison.encode!()

      assert Job.started?(job)
      assert is_nil(job.finished_at)

      W.handle_message(callback_message)

      {:ok, job} = Job.find(job.id)

      assert Job.finished?(job)
      assert Job.failed?(job)
      refute is_nil(job.finished_at)
    end

    test "when the job is stopped => it doesn't raise an error and publishes a finished message" do
      {:ok, job} = Support.Factories.Job.create(:finished, %{result: "stopped"})

      payload = %{"result" => "passed"} |> Poison.encode!()
      callback_message = %{"job_hash_id" => job.id, "payload" => payload} |> Poison.encode!()

      W.handle_message(callback_message)

      assert Job.finished?(job)
      assert Job.stopped?(job)
      refute Job.failed?(job)
      refute Job.passed?(job)
      refute is_nil(job.finished_at)
    end

    test "when the job is passed => it doesn't raise an error" do
      {:ok, job} = Support.Factories.Job.create(:finished, %{result: "passed"})

      payload = %{"result" => "failed"} |> Poison.encode!()
      callback_message = %{"job_hash_id" => job.id, "payload" => payload} |> Poison.encode!()

      W.handle_message(callback_message)

      assert Job.finished?(job)
      assert Job.passed?(job)
      refute Job.failed?(job)
      refute Job.stopped?(job)
      refute is_nil(job.finished_at)
    end

    test "when the job is failed => it doesn't raise an error" do
      {:ok, job} = Support.Factories.Job.create(:finished, %{result: "failed"})

      payload = %{"result" => "passed"} |> Poison.encode!()
      callback_message = %{"job_hash_id" => job.id, "payload" => payload} |> Poison.encode!()

      W.handle_message(callback_message)

      assert Job.finished?(job)
      assert Job.failed?(job)
      refute Job.passed?(job)
      refute Job.stopped?(job)
      refute is_nil(job.finished_at)
    end

    test "when the job is not started => process message" do
      {:ok, job} = Support.Factories.Job.create(:scheduled)

      payload = %{"result" => "passed"} |> Poison.encode!()
      callback_message = %{"job_hash_id" => job.id, "payload" => payload} |> Poison.encode!()

      W.handle_message(callback_message)

      {:ok, job} = Job.find(job.id)

      assert Job.finished?(job)
      refute is_nil(job.finished_at)
    end

    test "when job is not found => raise error" do
      payload = %{"result" => "passed"} |> Poison.encode!()

      callback_message =
        %{
          "job_hash_id" => Ecto.UUID.generate(),
          "payload" => payload
        }
        |> Poison.encode!()

      assert_raise MatchError, fn ->
        W.handle_message(callback_message)
      end
    end
  end
end
