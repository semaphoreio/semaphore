defmodule Scheduler.EventsConsumers.OrgBlocked do
  @moduledoc """
  Receives Organization blocked events from the RabbitMQ and suspends all
  schedulers from that org.
  """

  alias InternalApi.Organization.OrganizationBlocked
  alias Scheduler.Periodics.Model.PeriodicsQueries
  alias Scheduler.Workers.QuantumScheduler
  alias Util.{Metrics, ToTuple}
  alias LogTee, as: LT

  use Tackle.Consumer,
    url: System.get_env("RABBITMQ_URL"),
    exchange: "organization_exchange",
    routing_key: "blocked",
    service: "periodic-scheduler"

  def handle_message(message) do
    Metrics.benchmark("OrgEvenstConsumer.org_blocked_event", fn ->
      message
      |> decode_message()
      |> suspend_periodics_from_org()
    end)
  end

  defp decode_message(message) do
    Wormhole.capture(OrganizationBlocked, :decode, [message], stacktrace: true)
  end

  def suspend_periodics_from_org({:ok, %{org_id: org_id}})
      when is_binary(org_id) and org_id != "" do
    suspend_batch(org_id, 0)
  end

  def suspend_periodics_from_org(error),
    do: error |> LT.warn("Error while processing org blocked RabbitMQ message:")

  defp suspend_batch(org_id, batch_no) do
    with {:ok, periodics} <- PeriodicsQueries.get_all_from_org(org_id, batch_no),
         {:periodics_found, true} <- {:periodics_found, length(periodics) > 0},
         {:ok, _periodics} <- suspend_periodics(periodics) do
      suspend_batch(org_id, batch_no + 1)
    else
      {:periodics_found, false} ->
        LT.info(org_id, "Suspended all periodics from organization")

      error ->
        LT.warn(error, "Error while suspending periodics from organization #{org_id}")
    end
  end

  defp suspend_periodics(periodics) do
    periodics
    |> Enum.reduce_while({:ok, []}, fn periodic, {:ok, results} ->
      case suspend_periodic(periodic) do
        {:ok, periodic} -> {:cont, {:ok, results ++ [periodic]}}
        error -> {:halt, error}
      end
    end)
  end

  defp suspend_periodic(periodic) do
    with {:ok, periodic} <- PeriodicsQueries.suspend(periodic),
         :ok <- delete_quantum_job(periodic.id) do
      periodic
      |> LT.info("Suspended periodic due to organization being supended")
      |> ToTuple.ok()
    else
      {:error, error} ->
        error |> LT.warn("Error while trying to suspend periodic #{periodic.id} ")
        {:error, error}

      error ->
        error
        |> LT.warn("Error while trying to suspend periodic #{periodic.id} ")
        |> ToTuple.error()
    end
  end

  defp delete_quantum_job(id) do
    id |> String.to_atom() |> QuantumScheduler.delete_job()
  end
end
