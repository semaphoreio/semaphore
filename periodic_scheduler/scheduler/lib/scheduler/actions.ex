defmodule Scheduler.Actions do
  @moduledoc """
  Module collects and provides simple interface for different actions implemented
  in different modules in actions folder.
  """

  alias Scheduler.Actions.{
    ApplyImpl,
    ScheduleWfImpl,
    DescribeImpl,
    ListImpl,
    ListKeysetImpl,
    DeleteImpl,
    PauseImpl,
    GetProjectIdImpl,
    UnpauseImpl,
    RunNowImpl,
    LatestTriggersImpl,
    HistoryImpl,
    PersistImpl
  }

  @apply_metric "PeriodicSch.action_apply"
  @schedule_wf_metric "PeriodicSch.action_schedule_wf"
  @pause_metric "PeriodicSch.action_pause"
  @unpause_metric "PeriodicSch.action_unpause"
  @run_now_metric "PeriodicSch.action_run_now"
  @describe_metric "PeriodicSch.action_describe"
  @latest_triggers_metric "PeriodicSch.action_latest_triggers"
  @history_metric "PeriodicSch.action_history"
  @list_metric "PeriodicSch.action_list"
  @list_keyset_metric "PeriodicSch.action_list_keyset"
  @delete_metric "PeriodicSch.action_delete"
  @get_project_id_metric "PeriodicSch.action_get_project_id"
  @persist_metric "PeriodicSch.action_get_project_id"

  @action_opts [
    {:apply, [impl: ApplyImpl, metric: @apply_metric]},
    {:start_schedule_task, [impl: ScheduleWfImpl, metric: @schedule_wf_metric]},
    {:schedule_wf, [impl: ScheduleWfImpl, metric: @schedule_wf_metric]},
    {:pause, [impl: PauseImpl, metric: @pause_metric]},
    {:unpause, [impl: UnpauseImpl, metric: @unpause_metric]},
    {:run_now, [impl: RunNowImpl, metric: @run_now_metric]},
    {:describe, [impl: DescribeImpl, metric: @describe_metric]},
    {:latest_triggers, [impl: LatestTriggersImpl, metric: @latest_triggers_metric]},
    {:history, [impl: HistoryImpl, metric: @history_metric]},
    {:list, [impl: ListImpl, metric: @list_metric]},
    {:list_keyset, [impl: ListKeysetImpl, metric: @list_keyset_metric]},
    {:delete, [impl: DeleteImpl, metric: @delete_metric]},
    {:get_project_id, [impl: GetProjectIdImpl, metric: @get_project_id_metric]},
    {:persist, [impl: PersistImpl, metric: @persist_metric]}
  ]

  def start_schedule_task(params, timestamp),
    do: execute(:start_schedule_task, [params, timestamp])

  def schedule_wf(periodic, trigger), do: execute(:schedule_wf, [periodic, trigger])

  def apply(params), do: execute(:apply, [params])
  def pause(params), do: execute(:pause, [params])
  def unpause(params), do: execute(:unpause, [params])
  def run_now(params), do: execute(:run_now, [params])
  def describe(params), do: execute(:describe, [params])
  def latest_triggers(params), do: execute(:latest_triggers, [params])
  def history(params), do: execute(:history, [params])
  def list(params), do: execute(:list, [params])
  def list_keyset(params), do: execute(:list_keyset, [params])
  def delete(params), do: execute(:delete, [params])
  def get_project_id(params), do: execute(:get_project_id, [params])
  def persist(params), do: execute(:persist, [params])

  defp execute(action, params) do
    opts = Keyword.fetch!(@action_opts, action)
    impl = Keyword.fetch!(opts, :impl)
    metric = Keyword.fetch!(opts, :metric)

    Watchman.increment({metric, [:request]})

    case Kernel.apply(impl, action, params) do
      {:ok, response} ->
        Watchman.increment({metric, [:response, :success]})
        {:ok, response}

      error ->
        Watchman.increment({metric, [:response, :failure]})
        error
    end
  end
end
