defmodule Ppl.Actions do
  @moduledoc """
  Actions:
  - Scheduling incoming pipeline schedule requests from both gRPC server and RabbitMQ.
  - Describe pipelines from gRPC server
  - Terminate pipelines from gRPC server
  - List pipelines for given project from given branch
  - Describe topology for pipeline
  """

  @schedule_metric "Ppl.action_schedule"
  @schedule_def_metric "Ppl.action_schedule_with_definition"
  @partial_rebuild_metric "Ppl.action_partial_rebuild"
  @describe_metric "Ppl.action_describe"
  @describe_many_metric "Ppl.action_describe_many"
  @terminate_metric "Ppl.action_terminate"
  @list_metric "Ppl.action_list"
  @list_keyset_metric "Ppl.action_list_keyset"
  @delete_metric "Ppl.action_delete"
  @list_queues_metric "Ppl.action_list_queues"
  @list_grouped_metric "Ppl.action_list_grouped"
  @list_requesters_metric "Ppl.action_list_requesters"

  @default_ppl_queue_limit "10"

  alias Util.Metrics
  alias Ppl.Actions.{
    ScheduleImpl,
    ScheduleWithDefImpl,
    DescribeImpl,
    TerminateImpl,
    ListImpl,
    DescribeTopologyImpl,
    DescribeManyImpl,
    PartialRebuildImpl,
    Limits.ScheduleLimits,
    DeleteImpl,
    ListQueuesImpl,
    ListGroupedImpl,
    ListKeysetImpl,
    ListRequestersImpl
  }

  # Schedule

  def schedule(request, top_level? \\ true, initial_request? \\ true, task_worfklow? \\ false) do
    Watchman.increment({@schedule_metric, [:request]})
    onprem_metrics(initial_request?, task_worfklow?, :request)

    ppl_queue_limit =
      (System.get_env("PPL_QUEUE_LIMIT") || @default_ppl_queue_limit)
      |> String.to_integer()

    with  {:ok}            <- check_limits(request, ppl_queue_limit),
          {:ok, response}  <- schedule_(request, top_level?, initial_request?, task_worfklow?)
    do
      Watchman.increment({@schedule_metric, [:response, :success]})
      onprem_metrics(initial_request?, task_worfklow?, :success)

      {:ok, response}
    else
      {:limit, msg} ->
        Watchman.increment({@schedule_metric, [:response, :limit_exceeded]})
        onprem_metrics(initial_request?, task_worfklow?, :limit_exceeded)

        {:limit, msg}
      error ->
        Watchman.increment({@schedule_metric, [:response, :failure]})
        onprem_metrics(initial_request?, task_worfklow?, :failure)

        error
    end
  end

  defp check_limits(request, ppl_queue_limit) do
    Metrics.benchmark(@schedule_metric <> ".check_limit", __MODULE__, fn ->
      ScheduleLimits.check_limit(request, ppl_queue_limit)
    end)
  end

  def schedule_(request, top_level?, initial_request?, task_worfklow?) do
    Metrics.benchmark(@schedule_metric <> ".schedule", __MODULE__, fn ->
      ScheduleImpl.schedule(request, top_level?, initial_request?, task_worfklow?)
    end)
  end

  def form_schedule_params(request), do: ScheduleImpl.form_params(request)

  # Schedule with definition

  def schedule_with_definition(request, defintion, initial_definition, top_level? \\ true, initial_request? \\ false) do
    Watchman.increment({@schedule_def_metric, [:request]})

    case ScheduleWithDefImpl.schedule(request, defintion, initial_definition, top_level?, initial_request?) do
      {:ok, response} ->
        Watchman.increment({@schedule_def_metric, [:response, :success]})
        {:ok, response}
      error ->
        Watchman.increment({@schedule_def_metric, [:response, :failure]})
        error
    end
  end

  # Terminate

  def terminate(params) do
    Watchman.increment({@terminate_metric, [:request]})

    case TerminateImpl.terminate(params) do
      {:ok, response} ->
        Watchman.increment({@terminate_metric, [:response, :success]})
        {:ok, response}
      error ->
        Watchman.increment({@terminate_metric, [:response, :failure]})
        error
    end
  end

  # List

  def list_ppls(params) do
    Watchman.increment({@list_metric, [:request]})

    case ListImpl.list_ppls(params) do
      {:ok, response} ->
        Watchman.increment({@list_metric, [:response, :success]})
        {:ok, response}
      error ->
        Watchman.increment({@list_metric, [:response, :failure]})
        error
    end
  end

  # ListKeyset

  def list_keyset(params) do
    Watchman.increment({@list_keyset_metric, [:request]})

    case ListKeysetImpl.list_keyset(params) do
      {:ok, response} ->
        Watchman.increment({@list_keyset_metric, [:response, :success]})
        {:ok, response}
      error ->
        Watchman.increment({@list_keyset_metric, [:response, :failure]})
        error
    end
  end

  # ListQueues

  def list_queues(params) do
    Watchman.increment({@list_queues_metric, [:request]})

    case ListQueuesImpl.list_queues(params) do
      {:ok, response} ->
        Watchman.increment({@list_queues_metric, [:response, :success]})
        {:ok, response}
      error ->
        Watchman.increment({@list_queues_metric, [:response, :failure]})
        error
    end
  end

  # ListGrouped

  def list_grouped(params) do
    Watchman.increment({@list_grouped_metric, [:request]})

    case ListGroupedImpl.list_grouped(params) do
      {:ok, response} ->
        Watchman.increment({@list_grouped_metric, [:response, :success]})
        {:ok, response}
      error ->
        Watchman.increment({@list_grouped_metric, [:response, :failure]})
        error
    end
  end

  # Describe

  def describe(params) do
    Watchman.increment({@describe_metric, [:request]})

    case DescribeImpl.describe(params) do
      {:ok, _ppl, _blocks} = response ->
        Watchman.increment({@describe_metric, [:response, :success]})
        response
      error ->
        Watchman.increment({@describe_metric, [:response, :failure]})
        error
    end
  end

  # DescribeMany

  def describe_many(params) do
    Watchman.increment({@describe_many_metric, [:request]})

    case DescribeManyImpl.describe_many(params) do
      {:ok, _ppls} = response ->
        Watchman.increment({@describe_many_metric, [:response, :success]})
        response
      error ->
        Watchman.increment({@describe_many_metric, [:response, :failure]})
        error
    end
  end

  # DescribeTopology

  def describe_topology(definition),
    do: DescribeTopologyImpl.describe_topology(definition)


  # PartialRebuild

  def partial_rebuild(params) do
    Watchman.increment({@partial_rebuild_metric, [:request]})

    case PartialRebuildImpl.partial_rebuild(params) do
      {:ok, _ppl_id} = response ->
        Watchman.increment({@partial_rebuild_metric, [:response, :success]})
        response
      error ->
        Watchman.increment({@partial_rebuild_metric, [:response, :failure]})
        error
    end
  end

  # Delete

  def delete(params) do
    Watchman.increment({@delete_metric, [:request]})

    case DeleteImpl.delete(params) do
      {:ok, _ppl_id} = response ->
        Watchman.increment({@delete_metric, [:response, :success]})
        response
      error ->
        Watchman.increment({@delete_metric, [:response, :failure]})
        error
    end
  end

  # List requesters

  def list_requesters(params) do
    Watchman.increment({@list_requesters_metric, [:request]})

    case ListRequestersImpl.list_requesters(params) do
      {:ok, _} = response ->
        Watchman.increment({@list_requesters_metric, [:response, :success]})
        response
      error ->
        Watchman.increment({@list_requesters_metric, [:response, :failure]})
        error
    end
  end

  defp onprem_metrics(initial_request?, task_workflow?, state) do
    if System.get_env("ON_PREM") == "true" do
      tags = [task_workflow: to_string(task_workflow?), state: to_string(state)]
      if initial_request? do
        Watchman.increment(external: {"new_workflows", tags})
      end
      Watchman.increment(external: {"new_pipelines", tags})
    end
  end
end
