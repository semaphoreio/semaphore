defmodule TaskApiReferent.Runner.Command do
  @moduledoc """
  Containes all functions concerning Command execution.
  """

  alias TaskApiReferent.Service

  @doc "Executes all commands in sequence and returns a list of execution results."
  def execute_all(job_id, commands_ids, env_vars) when is_list(commands_ids) do
    with commands_result <-
          Enum.map(commands_ids, fn(command_id) ->
            {:ok, command} = Service.Command.get(command_id)
            {:ok, stopped} = is_job_stopped?(job_id)
            {status, execution_result} = execute(Map.get(command, :command), env_vars, stopped)
            set_status(status, command_id)
            set_execution_result(execution_result, command_id)

            status
          end),
    do: set_execution_status(commands_result)
  end

  @doc "Executes a single command, with environment variables."
  def execute(command, env_vars, false) when is_binary(command) do
    case System.cmd "/bin/bash", ["-c", command], env: env_vars do
      {execution_result, 127} ->
        {:error, execution_result}
      {execution_result, _} ->
        {:ok, execution_result}
    end
  end
  def execute(command, _env_vars, true) when is_binary(command) do
    {:stopped, :STOPPED}
  end

  defp is_job_stopped?(nil), do: {:ok, false}
  defp is_job_stopped?(job_id), do: Service.Job.get_property(job_id, :stopped)

  # Sets appropriate exit status in CommandAgent, depending on Command's execution result
  defp set_status(:error, command_id) do
    Service.Command.set_property(command_id, :result, :FAILED)
  end
  defp set_status(:ok, command_id) do
    Service.Command.set_property(command_id, :result, :PASSED)
  end
  defp set_status(:stopped, command_id) do
    Service.Command.set_property(command_id, :result, :STOPPED)
  end

  # Saves Command's execution result in CommandAgent
  defp set_execution_result(execution_result, command_id) do
    Service.Command.set_property(command_id, :execution_result, execution_result)
  end

  defp set_execution_status(commands_result) do
    cond do
      Enum.member?(commands_result, :error) == true
        ->   {:error, "one of the commands is invalid"}

      Enum.member?(commands_result, :stopped) == true
        ->  {:stop, "commands execution was stopped"}

      true -> {:ok, "all commands executed properly"}
    end
  end

end
