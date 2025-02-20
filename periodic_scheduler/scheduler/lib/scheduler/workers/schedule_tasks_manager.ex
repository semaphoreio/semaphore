defmodule Scheduler.Workers.ScheduleTaskManager do
  @moduledoc """
  Supervisor for Schedule_task processes.
  """

  use DynamicSupervisor

  alias Scheduler.Workers.ScheduleTask

  def start_link(_arg) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    DynamicSupervisor.init(
      strategy: :one_for_one,
      max_restarts: 1000,
      extra_arguments: []
    )
  end

  def start_schedule_task(periodic, trigger) do
    spec = {ScheduleTask, {periodic, trigger}}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def finish_schedule_task(pid) do
    DynamicSupervisor.terminate_child(__MODULE__, pid)
  end

  def children() do
    DynamicSupervisor.which_children(__MODULE__)
  end

  def count_children() do
    DynamicSupervisor.count_children(__MODULE__)
  end
end
