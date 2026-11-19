defmodule Zebra.Workers do
  @all [
    %{name: Zebra.Workers.JobDeletionPolicyMarker, flag: "START_JOB_DELETION_POLICY_MARKER"},
    %{name: Zebra.Workers.JobDeletionPolicyWorker, flag: "START_JOB_DELETION_POLICY_WORKER"},
    %{name: Zebra.Workers.JobStartedCallbackWorker, flag: "START_JOB_STARTED_CALLBACK_WORKER"},
    %{name: Zebra.Workers.JobFinishedCallbackWorker, flag: "START_JOB_FINISHED_CALLBACK_WORKER"},
    %{name: Zebra.Workers.JobTeardownCallbackWorker, flag: "START_JOB_TEARDOWN_CALLBACK_WORKER"},
    %{name: Zebra.Workers.TaskFinisher, flag: "START_TASK_FINISHER_WORKER"},
    %{name: Zebra.Workers.TaskFailFast, flag: "START_TASK_FAIL_FAST_WORKER"},
    %{name: Zebra.Workers.Dispatcher, flag: "START_DISPATCHER_WORKER"},
    %{name: Zebra.Workers.JobRequestFactory, flag: "START_JOB_REQUEST_FACTORY"},
    %{name: Zebra.Workers.Scheduler, flag: "START_SCHEDULER_WORKER"},
    %{name: Zebra.Workers.JobStopper, flag: "START_JOB_STOPPER"},
    %{name: Zebra.Workers.JobTerminator, flag: "START_JOB_TERMINATOR"},
    %{name: Zebra.Workers.WaitingJobTerminator, flag: "START_WAITING_JOB_TERMINATOR"},
    %{name: Zebra.UsagePublisher, flag: "START_USAGE_PUBLISHER"},
    %{name: Zebra.QuantumScheduler, flag: "START_MONITOR"}
  ]

  def active do
    @all
    |> Enum.filter(fn s -> System.get_env(s.flag) == "true" end)
    |> Enum.concat(agent_lost_worker())
    |> Enum.concat([
      # Cache invalidator should always be started,
      %{name: Zebra.FeatureProviderInvalidatorWorker}
    ])
    |> Enum.map(fn %{name: name} -> name end)
  end

  # Lost agents are reported only by the secondary agent provider. Unless
  # START_AGENT_LOST_WORKER says otherwise, the worker runs next to the
  # teardown callback worker whenever that provider is configured.
  def agent_lost_worker do
    start? =
      case System.get_env("START_AGENT_LOST_WORKER") do
        "true" ->
          true

        "false" ->
          false

        _ ->
          System.get_env("START_JOB_TEARDOWN_CALLBACK_WORKER") == "true" and
            Zebra.Workers.Agent.HostedAgent.secondary_endpoint_configured?()
      end

    if start?, do: [%{name: Zebra.Workers.AgentLostWorker}], else: []
  end
end
