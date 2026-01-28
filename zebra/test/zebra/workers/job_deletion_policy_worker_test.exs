defmodule Zebra.Workers.JobDeletionPolicyWorkerTest do
  use ExUnit.Case

  import Mock

  alias Zebra.Models.Job
  alias Zebra.Workers.JobDeletionPolicyWorker, as: Worker

  describe "tick/1" do
    test "returns false when no expired jobs found" do
      worker = %Worker{limit: 10, naptime: 1000, longnaptime: 5000}

      with_mock Job, claim_and_delete_expired_jobs: fn _limit -> {:ok, 0, 0} end do
        result = Worker.tick(worker)

        assert result == false
        assert_called(Job.claim_and_delete_expired_jobs(10))
      end
    end

    test "returns true when jobs are deleted successfully" do
      worker = %Worker{limit: 10, naptime: 1000, longnaptime: 5000}

      with_mocks [
        {Job, [], [claim_and_delete_expired_jobs: fn _limit -> {:ok, 2, 2} end]},
        {Watchman, [], [submit: fn _metric, _value, _type -> :ok end]}
      ] do
        result = Worker.tick(worker)

        assert result == true
        assert_called(Job.claim_and_delete_expired_jobs(10))
        assert_called(Watchman.submit({"retention.deleted", []}, 2, :count))
      end
    end

    test "returns false when error occurs during deletion" do
      worker = %Worker{limit: 10, naptime: 1000, longnaptime: 5000}

      with_mock Job, claim_and_delete_expired_jobs: fn _limit -> {:error, "database error"} end do
        result = Worker.tick(worker)

        assert result == false
        assert_called(Job.claim_and_delete_expired_jobs(10))
      end
    end

    test "returns false when publish_job_deletion_events fails" do
      worker = %Worker{limit: 10, naptime: 1000, longnaptime: 5000}

      with_mock Job, claim_and_delete_expired_jobs: fn _limit -> {:error, {:error, "amqp error"}} end do
        result = Worker.tick(worker)

        assert result == false
        assert_called(Job.claim_and_delete_expired_jobs(10))
      end
    end

    test "handles partial deletions (stop requests vs jobs count differs)" do
      worker = %Worker{limit: 10, naptime: 1000, longnaptime: 5000}

      with_mocks [
        {Job, [], [claim_and_delete_expired_jobs: fn _limit -> {:ok, 1, 2} end]},
        {Watchman, [], [submit: fn _metric, _value, _type -> :ok end]}
      ] do
        result = Worker.tick(worker)

        assert result == true
        assert_called(Job.claim_and_delete_expired_jobs(10))
        # Watchman should report the number of deleted jobs
        assert_called(Watchman.submit({"retention.deleted", []}, 2, :count))
      end
    end
  end
end
