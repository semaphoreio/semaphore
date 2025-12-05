defmodule Zebra.Workers.JobDeletionPolicyWorkerTest do
  use Zebra.DataCase

  alias Zebra.Models.{Job, JobStopRequest}
  alias Zebra.Workers.JobDeletionPolicyWorker, as: Worker

  describe ".start_link" do
    setup do
      original_config = Application.get_env(:zebra, Worker)

      on_exit(fn ->
        if original_config do
          Application.put_env(:zebra, Worker, original_config)
        else
          Application.delete_env(:zebra, Worker)
        end
      end)

      {:ok, original_config: original_config || []}
    end

    test "starts successfully with valid configuration", %{original_config: _original_config} do
      Application.put_env(:zebra, Worker, naptime: 1000, longnaptime: 5000, limit: 100)

      assert {:ok, pid} = Worker.start_link()
      assert Process.alive?(pid)

      Process.exit(pid, :kill)
    end

    test "starts successfully with nil longnaptime", %{original_config: _original_config} do
      Application.put_env(:zebra, Worker, naptime: 1000, longnaptime: nil, limit: 100)

      assert {:ok, pid} = Worker.start_link()
      assert Process.alive?(pid)

      Process.exit(pid, :kill)
    end

    test "starts successfully without longnaptime key", %{original_config: _original_config} do
      Application.put_env(:zebra, Worker, naptime: 1000, limit: 100)

      assert {:ok, pid} = Worker.start_link()
      assert Process.alive?(pid)

      Process.exit(pid, :kill)
    end

    test "returns error when configuration is missing" do
      Application.delete_env(:zebra, Worker)

      assert {:error, "Worker configuration is missing"} = Worker.start_link()
    end

    test "returns error when naptime is missing", %{original_config: _original_config} do
      Application.put_env(:zebra, Worker, limit: 100)

      assert {:error, "naptime configuration is missing"} = Worker.start_link()
    end

    test "returns error when naptime is not a positive integer", %{
      original_config: _original_config
    } do
      Application.put_env(:zebra, Worker, naptime: 0, limit: 100)

      assert {:error, error} = Worker.start_link()
      assert error =~ "Invalid naptime"
    end

    test "returns error when naptime is negative", %{original_config: _original_config} do
      Application.put_env(:zebra, Worker, naptime: -100, limit: 100)

      assert {:error, error} = Worker.start_link()
      assert error =~ "Invalid naptime"
    end

    test "returns error when limit is missing", %{original_config: _original_config} do
      Application.put_env(:zebra, Worker, naptime: 1000)

      assert {:error, "limit configuration is missing"} = Worker.start_link()
    end

    test "returns error when limit is not a positive integer", %{
      original_config: _original_config
    } do
      Application.put_env(:zebra, Worker, naptime: 1000, limit: 0)

      assert {:error, error} = Worker.start_link()
      assert error =~ "Invalid limit"
    end

    test "returns error when limit is negative", %{original_config: _original_config} do
      Application.put_env(:zebra, Worker, naptime: 1000, limit: -10)

      assert {:error, error} = Worker.start_link()
      assert error =~ "Invalid limit"
    end

    test "returns error when longnaptime is invalid (not integer or nil)", %{
      original_config: _original_config
    } do
      Application.put_env(:zebra, Worker, naptime: 1000, longnaptime: "invalid", limit: 100)

      assert {:error, error} = Worker.start_link()
      assert error =~ "Invalid longnaptime"
    end

    test "returns error when longnaptime is zero", %{original_config: _original_config} do
      Application.put_env(:zebra, Worker, naptime: 1000, longnaptime: 0, limit: 100)

      assert {:error, error} = Worker.start_link()
      assert error =~ "Invalid longnaptime"
    end
  end

  describe ".tick" do
    test "deletes expired jobs and related stop requests" do
      worker = %Worker{limit: 10, naptime: 1000, longnaptime: 5000}

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
      worker = %Worker{limit: 10, naptime: 1000, longnaptime: 5000}

      {:ok, job} = Support.Factories.Job.create(:finished)

      future_expiration =
        DateTime.utc_now()
        |> DateTime.add(3600, :second)

      {:ok, _} = Job.update(job, %{expires_at: future_expiration})

      refute Worker.tick(worker)

      assert {:ok, _} = Job.find(job.id)
    end

    test "respects the batch limit" do
      worker = %Worker{limit: 2, naptime: 1000, longnaptime: 5000}

      expired_at =
        DateTime.utc_now()
        |> DateTime.add(-3600, :second)

      {:ok, job1} = Support.Factories.Job.create(:finished)
      {:ok, _} = Job.update(job1, %{expires_at: expired_at})

      {:ok, job2} = Support.Factories.Job.create(:finished)
      {:ok, _} = Job.update(job2, %{expires_at: expired_at})

      {:ok, job3} = Support.Factories.Job.create(:finished)
      {:ok, _} = Job.update(job3, %{expires_at: expired_at})

      assert Worker.tick(worker)

      deleted_count =
        [job1, job2, job3]
        |> Enum.count(fn job ->
          match?({:error, :not_found}, Job.find(job.id))
        end)

      assert deleted_count == 2
    end

    test "returns true when only stop requests are deleted" do
      worker = %Worker{limit: 10, naptime: 1000, longnaptime: 5000}

      {:ok, job} = Support.Factories.Job.create(:finished)
      {:ok, _} = JobStopRequest.create(job.build_id, job.id)

      expired_at =
        DateTime.utc_now()
        |> DateTime.add(-3600, :second)

      {:ok, _} = Job.update(job, %{expires_at: expired_at})

      assert Worker.tick(worker)
    end

    test "returns false when no jobs have expired" do
      worker = %Worker{limit: 10, naptime: 1000, longnaptime: 5000}

      {:ok, _job} = Support.Factories.Job.create(:finished)

      refute Worker.tick(worker)
    end
  end
end
