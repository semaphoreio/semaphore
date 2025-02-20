defmodule TaskApiReferent.Agent.Job do
  @moduledoc """
  Elixir Agent used to persist state of every Job

  example:
    %{job_id:
      %{
        id: UUID,
        state: :RUNNING,
        result: :PASSED,
        name: "job name",
        index: 4,
        commands: [cmd_id1, cmd_id2, ...],
        prologue_commands: [command_id1, command_id2, ...],
        always_cmds: [command_id1, command_id2, ...],
        on_pass_cmds: [command_id1, command_id2, ...],
        on_fail_cmds: [command_id1, command_id2, ...],
        env_vars: [%{name: "ev1", value: "val1"}, %{name: "ev2", value: "val2"}, ...],
        stopped: false
      }
    }
  """

  use Agent

  @doc "Starts an Agent and initializes state Map"
  def start_link(opts \\ []) do
    opts = Keyword.put_new(opts, :name, __MODULE__)
    Agent.start_link(fn -> %{} end, opts)
  end

  @doc "Gets Job's state Map"
  def get(job_id) do
    Agent.get(__MODULE__, fn map ->
      case Map.get(map, job_id) do
        nil -> {:error, "'job_id' parameter that you provided doesn't match any job."}
        state -> {:ok, state}
      end
    end)
  end

  @doc "Sets Job's state Map"
  def set(job_id, value) do
    Agent.get_and_update(__MODULE__, fn map ->
      new_state = Map.put(map, job_id, value)
      {{:ok, {job_id, value}}, new_state}
    end)
  end

end
