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

  describe "agent lost worker" do
    setup do
      on_exit(fn ->
        System.delete_env("START_AGENT_LOST_WORKER")
        System.delete_env("START_JOB_TEARDOWN_CALLBACK_WORKER")
        Application.delete_env(:zebra, :chmura_secondary_endpoint)
      end)
    end

    test "starts next to the teardown callback worker when the secondary provider is configured" do
      System.put_env("START_JOB_TEARDOWN_CALLBACK_WORKER", "true")
      Application.put_env(:zebra, :chmura_secondary_endpoint, "localhost:50051")

      assert Zebra.Workers.AgentLostWorker in Zebra.Workers.active()
      assert Zebra.Workers.JobTeardownCallbackWorker in Zebra.Workers.active()
    end

    test "does not start without a secondary provider" do
      System.put_env("START_JOB_TEARDOWN_CALLBACK_WORKER", "true")

      refute Zebra.Workers.AgentLostWorker in Zebra.Workers.active()

      Application.put_env(:zebra, :chmura_secondary_endpoint, "")

      refute Zebra.Workers.AgentLostWorker in Zebra.Workers.active()
    end

    test "does not start where the teardown callback worker does not run" do
      Application.put_env(:zebra, :chmura_secondary_endpoint, "localhost:50051")

      refute Zebra.Workers.AgentLostWorker in Zebra.Workers.active()
    end

    test "START_AGENT_LOST_WORKER overrides the default" do
      System.put_env("START_AGENT_LOST_WORKER", "true")

      assert Zebra.Workers.AgentLostWorker in Zebra.Workers.active()

      System.put_env("START_AGENT_LOST_WORKER", "false")
      System.put_env("START_JOB_TEARDOWN_CALLBACK_WORKER", "true")
      Application.put_env(:zebra, :chmura_secondary_endpoint, "localhost:50051")

      refute Zebra.Workers.AgentLostWorker in Zebra.Workers.active()
    end
  end
end
