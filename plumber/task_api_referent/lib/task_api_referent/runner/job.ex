defmodule TaskApiReferent.Runner.Job do
  @moduledoc """
  Contains all functions concerning job execution.
  """

  alias TaskApiReferent.Runner
  alias TaskApiReferent.Service

  @doc "Starts execution of multiple Jobs, specified by List of job_id's."
  def execute(jobs_ids) when is_list(jobs_ids) do
    jobs_ids
    |> Enum.reduce([], &([Task.async(__MODULE__, :execute, [&1]) | &2]))
    |> Enum.map(&(Task.await(&1, 50_000)))
  end

  @doc "Executes Job Setup, Commands and Conclusion. Sets appropriate Job Status."
  def execute(job_id) when is_binary(job_id) do
    {:ok, prologue_commands_ids} = Service.Job.get_property(job_id, :prologue_commands)
    {:ok, always_cmd_ids} = Service.Job.get_property(job_id, :always_cmds)
    {:ok, on_pass_cmd_ids} = Service.Job.get_property(job_id, :on_pass_cmds)
    {:ok, on_fail_cmd_ids} = Service.Job.get_property(job_id, :on_fail_cmds)
    {:ok, job_commands_ids} = Service.Job.get_property(job_id, :commands)
    {:ok, env_vars} = get_env_vars(job_id)

    execution_result =
    with {:ok, _} <- setup(job_id, prologue_commands_ids, env_vars),
         {:ok, _} <- Runner.Command.execute_all(job_id, job_commands_ids, env_vars)
    do
      set_status(:ok, job_id)
    else
      {:error, _} ->
        set_status(:error, job_id)
      {:setup, _} ->
        set_status(:setup, job_id)
      {:stop, _} ->
        set_status(:stop, job_id)
    end

    conclude(job_id, always_cmd_ids, env_vars)
    run_on_pass?(job_id, on_pass_cmd_ids, env_vars, execution_result)
    run_on_fail?(job_id, on_fail_cmd_ids, env_vars, execution_result)
    execution_result
  end

  # Fetch EnvVars from Job and transform them to a list of Tuples
  defp get_env_vars(job_id) do
    with {:ok, job_env_vars} <- Service.Job.get_property(job_id, :env_vars),
         job_env_vars <- vars_to_list(job_env_vars)
    do
      {:ok, job_env_vars}
    end
  end

  # Transforms list of Environment Variable structs to a list of Tuples.
  defp vars_to_list(env_vars) do
    Enum.map(env_vars, fn(variable) ->
      {variable.name, variable.value}
    end)
  end

  # Setup for a job
  # Executes prologue commands
  defp setup(job_id, prologue_commands_ids, env_vars) do
    with false    <- Enum.empty?(prologue_commands_ids),
         {:ok, _} <- Runner.Command.execute_all(job_id, prologue_commands_ids, env_vars)
    do
      {:ok, "job setup passed"}
    else
      true ->
        {:ok, "job setup passed but there were no prologue commands specified"}
      {:error, _} ->
        {:setup, "job setup failed"}
    end
  end

  # Executes epilogue_commands after all jobs. They don't affect Job's or Task's status.
  defp conclude(job_id, epilogue_commands, env_vars) do
    if !is_nil(epilogue_commands) and not_stopped(job_id) do
      Runner.Command.execute_all(job_id, epilogue_commands, env_vars)
    end
  end

  defp not_stopped(job_id), do: Service.Job.get_property(job_id, :stopped) == {:ok, false}

  defp run_on_pass?(job_id, cmd_ids, env_vars, {:ok, _}), do: conclude(job_id, cmd_ids, env_vars)
  defp run_on_pass?(job_id, cmd_ids, env_vars, _), do: :skip

  defp run_on_fail?(job_id, cmd_ids, env_vars, :error), do: conclude(job_id, cmd_ids, env_vars)
  defp run_on_fail?(job_id, cmd_ids, env_vars, _), do: :skip


  # Sets appropriate job status depending on the execution results of all commands.
  defp set_status(:ok, job_id) do
    Service.Job.set_property(job_id, :state, :FINISHED)
    Service.Job.set_property(job_id, :result, :PASSED)
    {:ok, "task passed"}
  end
  defp set_status(:setup, job_id) do
    Service.Job.set_property(job_id, :state, :FINISHED)
    Service.Job.set_property(job_id, :result, :FAILED)
    :error
  end
  defp set_status(:error, job_id) do
    Service.Job.set_property(job_id, :state, :FINISHED)
    Service.Job.set_property(job_id, :result, :FAILED)
    :error
  end
  defp set_status(:stop, job_id) do
    Service.Job.set_property(job_id, :state, :FINISHED)
    Service.Job.set_property(job_id, :result, :STOPPED)
    :stop
  end
end
