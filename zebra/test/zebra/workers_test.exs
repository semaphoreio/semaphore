defmodule Zebra.Workers.Test do
  use ExUnit.Case, async: false

  test "no environment variables set => only default workers start" do
    assert Zebra.Workers.active() == [
             Zebra.FeatureProviderInvalidatorWorker
           ]
  end

  describe "with environment variables set" do
    setup do
      System.put_env("START_JOB_STOPPER", "true")
      System.put_env("START_TASK_FAIL_FAST_WORKER", "true")
      System.put_env("START_TASK_FINISHER_WORKER", "true")
      System.put_env("START_JOB_DELETION_POLICY_MARKER", "true")
      System.put_env("START_JOB_DELETION_POLICY_WORKER", "true")

      on_exit(fn ->
        System.put_env("START_JOB_STOPPER", "false")
        System.put_env("START_TASK_FAIL_FAST_WORKER", "false")
        System.put_env("START_TASK_FINISHER_WORKER", "false")
        System.put_env("START_JOB_DELETION_POLICY_MARKER", "false")
        System.put_env("START_JOB_DELETION_POLICY_WORKER", "false")
      end)
    end

    test "active workers are returned" do
      assert Zebra.Workers.active() == [
               Zebra.Workers.JobDeletionPolicyMarker,
               Zebra.Workers.JobDeletionPolicyWorker,
               Zebra.Workers.TaskFinisher,
               Zebra.Workers.TaskFailFast,
               Zebra.Workers.JobStopper,
               Zebra.FeatureProviderInvalidatorWorker
             ]
    end
  end
end
