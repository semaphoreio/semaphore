defmodule Gofer.Actions do
  @moduledoc """
  Module implements various actions performed by Gofer servise on some API call.
  """

  alias Gofer.Actions.{
    CreateImpl,
    PipelineDoneImpl,
    TriggerImpl,
    DescribeImpl,
    ListTriggersImpl,
    DescribeManyImpl
  }

  @create_metric "Gofer.action_create"
  @pipeline_done_metric "Gofer.action_pipeline_done"
  @trigger_metric "Gofer.action_trigger"
  @describe_metric "Gofer.action_describe"
  @describe_many_metric "Gofer.action_describe_many"
  @list_triggers_metric "Gofer.action_list_triggers"

  # Create related fucntions

  @doc """
  Initiates SwitchProcess which will validate and persist switch and targets
  definitions into DB in it's init block.
  """
  def create_switch(switch_def, targets_defs) do
    Watchman.increment({@create_metric, [:request]})

    case CreateImpl.create_switch(switch_def, targets_defs) do
      {:ok, response} ->
        Watchman.increment({@create_metric, [:response, :success]})
        {:ok, response}

      error ->
        Watchman.increment({@create_metric, [:response, :failure]})
        error
    end
  end

  @doc """
  Callback for inserting switch and targets into DB called from init of SwitchProcess
  """
  def persist_switch_and_targets_def(switch_def, raw_targets_defs),
    do: CreateImpl.persist_switch_and_targets_def(switch_def, raw_targets_defs)

  # Pipeline Done related fucntions

  @doc """
  Called via gRPC
  Based on given result and result_reason evaluates wheter some targets of given
  switch need to be triggerd and then starts SwitchTrigger process.
  """
  def proces_ppl_done_request(switch_id, ppl_result, ppl_result_reason) do
    Watchman.increment({@pipeline_done_metric, [:request]})

    case PipelineDoneImpl.proces_ppl_done_request(switch_id, ppl_result, ppl_result_reason) do
      {:ok, response} ->
        Watchman.increment({@pipeline_done_metric, [:response, :success]})
        {:ok, response}

      error ->
        Watchman.increment({@pipeline_done_metric, [:response, :failure]})
        error
    end
  end

  @doc """
  Calback for starting SwitchTrigger process called from SwitchProcess when pipeline is done
  """
  def update_switch_and_start_trigger(switch_id, ppl_result, ppl_result_reason),
    do: PipelineDoneImpl.update_switch_and_start_trigger(switch_id, ppl_result, ppl_result_reason)

  # Trigger related fucntions

  def trigger(params) do
    Watchman.increment({@trigger_metric, [:request]})

    case TriggerImpl.trigger(params) do
      {:ok, response} ->
        Watchman.increment({@trigger_metric, [:response, :success]})
        {:ok, response}

      error ->
        Watchman.increment({@trigger_metric, [:response, :failure]})
        error
    end
  end

  # Describe related fucntions

  def describe_switch(switch_id, triggers_no, requester_id) do
    Watchman.increment({@describe_metric, [:request]})

    case DescribeImpl.describe_switch(switch_id, triggers_no, requester_id) do
      {:ok, response} ->
        Watchman.increment({@describe_metric, [:response, :success]})
        {:ok, response}

      error ->
        Watchman.increment({@describe_metric, [:response, :failure]})
        error
    end
  end

  # DescribeMany related fucntions

  def describe_many(switch_ids, events_per_target, requester_id) do
    Watchman.increment({@describe_many_metric, [:request]})

    case DescribeManyImpl.describe_many(switch_ids, events_per_target, requester_id) do
      {:ok, response} ->
        Watchman.increment({@describe_many_metric, [:response, :success]})
        {:ok, response}

      error ->
        Watchman.increment({@describe_many_metric, [:response, :failure]})
        error
    end
  end

  # ListTriggerEvents related fucntions

  def list_triggers(switch_id, target_name, page, page_size) do
    Watchman.increment({@list_triggers_metric, [:request]})

    case ListTriggersImpl.list_triggers(switch_id, target_name, page, page_size) do
      {:ok, response} ->
        Watchman.increment({@list_triggers_metric, [:response, :success]})
        {:ok, response}

      error ->
        Watchman.increment({@list_triggers_metric, [:response, :failure]})
        error
    end
  end
end
