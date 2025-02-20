defmodule Scheduler.Workers.Initializer do
  @moduledoc """
  It is invoked on Application start and it loads all periodics from DB in batches
  and starts quantum job for each of them.
  """
  use GenServer, restart: :transient

  alias Scheduler.Workers.QuantumScheduler
  alias Scheduler.Periodics.Model.PeriodicsQueries
  alias LogTee, as: LT

  def start_link(_params) do
    GenServer.start_link(__MODULE__, %{})
  end

  def init(_params) do
    send(self(), :scann_db)
    {:ok, %{}}
  end

  def handle_info(:scann_db, state) do
    scann_batch(NaiveDateTime.utc_now(), 0, state)
  end

  defp scann_batch(timestamp, batch_no, state) do
    with {:ok, periodics} <- PeriodicsQueries.get_older_then(timestamp, batch_no),
         {:periodics_found, true} <- {:periodics_found, length(periodics) > 0},
         {:ok, _jobs} <- start_quantum_jobs(periodics) do
      scann_batch(timestamp, batch_no + 1, state)
    else
      {:periodics_found, false} ->
        {:stop, :normal, state}

      error ->
        error |> restart(state)
    end
  end

  defp start_quantum_jobs(periodics) do
    periodics
    |> Enum.reduce_while({:ok, []}, fn periodic, {:ok, jobs} ->
      start_quantum_job(jobs, periodic)
    end)
  end

  defp start_quantum_job(jobs, _periodic = %{paused: true}), do: {:cont, {:ok, jobs}}

  defp start_quantum_job(jobs, _periodic = %{recurring: false}), do: {:cont, {:ok, jobs}}

  defp start_quantum_job(jobs, periodic = %{suspended: true}) do
    msg = "Suspended org #{periodic.organization_id} - skiped initialization of periodic"
    periodic.id |> LT.info(msg)
    {:cont, {:ok, jobs}}
  end

  defp start_quantum_job(jobs, periodic) do
    case QuantumScheduler.start_periodic_job(periodic) do
      {:ok, job} ->
        {:cont, {:ok, jobs ++ [job]}}

      error ->
        error
        |> LT.warn("Error while trying to initialize Periodic #{periodic.id}: #{inspect(error)}}")

        Watchman.increment("scheduler.periodic.initialization.error")
        {:cont, {:ok, jobs}}
    end
  end

  defp restart(error, state) do
    error
    |> LT.warn("Error while trying to initialize Periodics on startup")

    {:stop, :restart, state}
  end
end
