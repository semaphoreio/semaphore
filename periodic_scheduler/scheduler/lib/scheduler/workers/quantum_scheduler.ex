defmodule Scheduler.Workers.QuantumScheduler do
  @moduledoc """
  Used for scheduling periodic jobs via quantum application.
  """

  use Quantum, otp_app: :scheduler

  alias Util.ToTuple
  alias Scheduler.Actions

  def start_periodic_job(periodic) do
    with job_name <- String.to_atom(periodic.id),
         :ok <- delete_job(job_name),
         {:ok, schedule} <- add_random_second(periodic.at) do
      start_periodic_job_(periodic.id, job_name, schedule)
    end
  end

  defp start_periodic_job_(periodic_id, job_name, schedule) do
    new_job()
    |> Quantum.Job.set_name(job_name)
    |> Quantum.Job.set_schedule(schedule)
    |> Quantum.Job.set_run_strategy(%Quantum.RunStrategy.Local{})
    |> Quantum.Job.set_task({Actions, :start_schedule_task, [periodic_id, DateTime.utc_now()]})
    |> add_job()
    |> ToTuple.ok()
  end

  defp add_random_second(at_string) when is_binary(at_string) do
    at_string
    |> String.trim()
    |> do_add_random_second()
  end

  defp add_random_second(_), do: {:error, :missing_cron_expression}

  defp do_add_random_second(""), do: {:error, :missing_cron_expression}

  defp do_add_random_second(at_string) do
    with {:ok, schedule} <- Crontab.CronExpression.Parser.parse(at_string),
         rand_sec <- :rand.uniform(60) - 1,
         schedule <- Map.merge(schedule, %{extended: true, second: [rand_sec]}) do
      {:ok, schedule}
    end
  end
end
