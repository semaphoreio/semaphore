defmodule Front.Async do
  @doc """
  The default Task is a great abstraction in Elixir, but it has several issues
  that make it easy to shot ourselves in the foot while using it.

  The Async module is a wrapper around the default Task implementation, and
  provides sane defaults for most actions.

  The Async module also offers out-of-the-box observation primitives like metrics
  and debug logs.

  Basic usage without observation:

    task = Async.run(fn -> IO.puts "hello" end)
    {:ok, result} = Async.await(task)

  Usage with observation turned on:

    task = Async.run(fn -> IO.puts "hello" end, metric: "printing.hello")
    {:ok, result} = Async.await(task)

  Usage with multiple async functions:

  {secrets, organization, branch, hook, agent_types} =
    Async.run([
      fn -> Secret.list(user_id, org_id) end,
      fn -> Organization.find(org_id) end,
      fn -> Branch.find(project_id, branch_name) end,
      fn -> RepoProxy.find(hook_id) end,
      fn -> AgentType.list() end
  ])
  """

  require Logger
  alias Front.TaskSupervisor

  defstruct [:task, :observe, :started_at, :metric_name]

  @default_timeout 30_000

  def run(functions) when is_list(functions) do
    tasks = functions |> Enum.map(fn fun -> run(fun) end)

    tasks
    |> Enum.map(fn task ->
      {:ok, result} = await(task)
      result
    end)
    |> List.to_tuple()
  end

  def run(fun) do
    task = Task.Supervisor.async_nolink(TaskSupervisor, fun)

    %__MODULE__{
      task: task,
      observe: false,
      started_at: :os.system_time(:millisecond)
    }
  end

  def run(fun, metric: metric_name) do
    task = Task.Supervisor.async_nolink(TaskSupervisor, fun)

    %__MODULE__{
      task: task,
      observe: true,
      metric_name: metric_name,
      started_at: :os.system_time(:millisecond)
    }
  end

  def await(async_task, options \\ []) do
    timeout = Keyword.get(options, :timeout, @default_timeout)

    res = Task.yield(async_task.task, timeout) || Task.shutdown(async_task.task)
    duration = :os.system_time(:millisecond) - async_task.started_at

    if async_task.observe do
      Watchman.submit("#{async_task.metric_name}.duration", duration, :timing)
    end

    case res do
      {:ok, result} ->
        if async_task.observe do
          Watchman.increment("#{async_task.metric_name}.success")
          Logger.debug(fn -> "Async #{async_task.metric_name} response OK in #{duration}ms" end)
        end

        {:ok, result}

      {:exit, reason} ->
        if async_task.observe do
          Watchman.increment("#{async_task.metric_name}.error")

          Logger.debug(fn ->
            "Async #{async_task.metric_name} ERROR reason: #{reason} in #{duration}ms"
          end)
        end

        {:exit, reason}

      nil ->
        if async_task.observe do
          Watchman.increment("#{async_task.metric_name}.timeout")

          Logger.debug(fn ->
            "Async #{async_task.metric_name} failed to get response in #{timeout}ms"
          end)
        end

        {:error, :timeout}
    end
  end
end
