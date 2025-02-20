defmodule TaskApiReferent.Initializator.Job do
  @moduledoc """
  Initializes Job states in Job Agent
  """

  alias TaskApiReferent.Initializator, as: Init
  alias TaskApiReferent.Service
  alias Util.ToTuple

  def init_jobs(jobs) do
    jobs
    |> Enum.with_index()
    |> Enum.map(fn {job, index} -> init_job(job, index) end)
    |> ToTuple.ok()
  end

  defp init_job(job, index) do
    with job_id <- UUID.uuid4(),
         {:ok, job_state} <- init_state(job, job_id, index)
    do
      Service.Job.set(job_id, job_state)
      job_id
    end
  end

  # Transforms Job struct to the Map we persist in JobAgent
  defp init_state(job, job_id, index) do
    with {:ok, name} <- Map.fetch(job, :name),

         prologue_commands <- Map.get(job, :prologue_commands),
         {:ok, prologue_cmd_ids} <- Init.Command.init_commands(:PROLOGUE, prologue_commands),

         always_cmds <- Map.get(job, :epilogue_always_cmds),
         {:ok, always_cmd_ids} <- Init.Command.init_commands(:ALWAYS, always_cmds),

         on_pass_cmds <- Map.get(job, :epilogue_on_pass_cmds),
         {:ok, on_pass_cmd_ids} <- Init.Command.init_commands(:ON_PASS, on_pass_cmds),

         on_fail_cmds <- Map.get(job, :epilogue_on_fail_cmds),
         {:ok, on_fail_cmd_ids} <- Init.Command.init_commands(:ON_FAIL, on_fail_cmds),

         {:ok, env_vars} <- Map.fetch(job, :env_vars),

         {:ok, commands} <- Map.fetch(job, :commands),
         {:ok, command_ids} <- Init.Command.init_commands(:JOB, commands)
    do
      %{
        id: job_id,
        state: :RUNNING,
        result: :FAILED,
        name: name,
        index: index,
        commands: command_ids,
        prologue_commands: prologue_cmd_ids,
        always_cmds: always_cmd_ids,
        on_pass_cmds: on_pass_cmd_ids,
        on_fail_cmds: on_fail_cmd_ids,
        env_vars: env_vars,
        stopped: false
      } |> ToTuple.ok()
    end
  end
end
