defmodule Zebra.Workers.JobDeletionPolicyWorkerTest do
  use ExUnit.Case

  import Mock

  alias Zebra.Models.Job
  alias Zebra.Workers.JobDeletionPolicyWorker, as: Worker

  describe "tick/1" do
    test "returns false when no expired jobs found" do
      worker = %Worker{limit: 10, naptime: 1000, longnaptime: 5000}

      with_mock Job, expired_job_ids: fn _limit -> {:ok, []} end do
        result = Worker.tick(worker)

        assert result == false
        assert_called(Job.expired_job_ids(10))
      end
    end

    test "returns true when jobs are deleted successfully" do
      worker = %Worker{limit: 10, naptime: 1000, longnaptime: 5000}

      job_id_1 = Ecto.UUID.generate()
      job_id_2 = Ecto.UUID.generate()
      org_id = Ecto.UUID.generate()
      project_id = Ecto.UUID.generate()
      artifact_store_id = Ecto.UUID.generate()

      expired_jobs = [
        {job_id_1, org_id, project_id, artifact_store_id},
        {job_id_2, org_id, project_id, artifact_store_id}
      ]

      with_mocks [
        {Job, [],
         [
           expired_job_ids: fn _limit -> {:ok, expired_jobs} end,
           publish_job_deletion_events: fn _jobs -> :ok end,
           delete_job_stop_requests: fn _job_ids -> {:ok, 2} end,
           delete_jobs: fn _job_ids -> {:ok, 2} end
         ]},
        {Watchman, [], [submit: fn _metric, _value, _type -> :ok end]}
      ] do
        result = Worker.tick(worker)

        assert result == true
        assert_called(Job.expired_job_ids(10))
        assert_called(Job.publish_job_deletion_events(expired_jobs))
        assert_called(Job.delete_job_stop_requests([job_id_1, job_id_2]))
        assert_called(Job.delete_jobs([job_id_1, job_id_2]))
        assert_called(Watchman.submit({"retention.deleted", []}, 2, :count))
      end
    end

    test "returns false when error occurs during deletion" do
      worker = %Worker{limit: 10, naptime: 1000, longnaptime: 5000}

      with_mock Job, expired_job_ids: fn _limit -> {:error, "database error"} end do
        result = Worker.tick(worker)

        assert result == false
        assert_called(Job.expired_job_ids(10))
      end
    end

    test "returns false when publish_job_deletion_events fails" do
      worker = %Worker{limit: 10, naptime: 1000, longnaptime: 5000}

      job_id = Ecto.UUID.generate()
      org_id = Ecto.UUID.generate()
      project_id = Ecto.UUID.generate()
      artifact_store_id = Ecto.UUID.generate()

      expired_jobs = [{job_id, org_id, project_id, artifact_store_id}]

      with_mock Job,
        expired_job_ids: fn _limit -> {:ok, expired_jobs} end,
        publish_job_deletion_events: fn _jobs -> {:error, "amqp error"} end do
        result = Worker.tick(worker)

        assert result == false
        assert_called(Job.expired_job_ids(10))
        assert_called(Job.publish_job_deletion_events(expired_jobs))
      end
    end

    test "handles jobs with nil artifact_store_id (orphaned projects)" do
      worker = %Worker{limit: 10, naptime: 1000, longnaptime: 5000}

      job_id_1 = Ecto.UUID.generate()
      job_id_2 = Ecto.UUID.generate()
      org_id = Ecto.UUID.generate()
      project_id = Ecto.UUID.generate()
      orphan_project_id = Ecto.UUID.generate()
      artifact_store_id = Ecto.UUID.generate()

      expired_jobs = [
        {job_id_1, org_id, project_id, artifact_store_id},
        {job_id_2, org_id, orphan_project_id, nil}
      ]

      with_mocks [
        {Job, [],
         [
           expired_job_ids: fn _limit -> {:ok, expired_jobs} end,
           publish_job_deletion_events: fn _jobs -> :ok end,
           delete_job_stop_requests: fn _job_ids -> {:ok, 2} end,
           delete_jobs: fn _job_ids -> {:ok, 2} end
         ]},
        {Watchman, [], [submit: fn _metric, _value, _type -> :ok end]}
      ] do
        result = Worker.tick(worker)

        assert result == true
        assert_called(Job.expired_job_ids(10))
        assert_called(Job.publish_job_deletion_events(expired_jobs))
        assert_called(Job.delete_job_stop_requests([job_id_1, job_id_2]))
        assert_called(Job.delete_jobs([job_id_1, job_id_2]))
      end
    end
  end
end
