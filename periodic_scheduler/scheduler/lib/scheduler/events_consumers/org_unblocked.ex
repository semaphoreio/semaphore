defmodule Scheduler.EventsConsumers.OrgUnblocked do
  @moduledoc """
  Receives Organization unblocked events from the RabbitMQ and unblocks all
  schedulers from that org.
  """

  alias InternalApi.Organization.OrganizationUnblocked
  alias Scheduler.Periodics.Model.PeriodicsQueries
  alias Scheduler.Workers.QuantumScheduler
  alias Util.{Metrics, ToTuple}
  alias LogTee, as: LT

  use Tackle.Consumer,
    url: System.get_env("RABBITMQ_URL"),
    exchange: "organization_exchange",
    routing_key: "unblocked",
    service: "periodic-scheduler"

  def handle_message(message) do
    Metrics.benchmark("OrgEvenstConsumer.org_unblocked_event", fn ->
      message
      |> decode_message()
      |> unsuspend_periodics_from_org()
    end)
  end

  defp decode_message(message) do
    Wormhole.capture(OrganizationUnblocked, :decode, [message], stacktrace: true)
  end

  def unsuspend_periodics_from_org({:ok, %{org_id: org_id}})
      when is_binary(org_id) and org_id != "" do
    unsuspend_batch(org_id, 0)
  end

  def unsuspend_periodics_from_org(error),
    do: error |> LT.warn("Error while processing org unblocked RabbitMQ message:")

  defp unsuspend_batch(org_id, batch_no) do
    with {:ok, periodics} <- PeriodicsQueries.get_all_from_org(org_id, batch_no),
         {:periodics_found, true} <- {:periodics_found, length(periodics) > 0},
         {:ok, _periodics} <- unsuspend_periodics(periodics) do
      unsuspend_batch(org_id, batch_no + 1)
    else
      {:periodics_found, false} ->
        LT.info(org_id, "Unsuspended all periodics from organization")

      error ->
        LT.warn(error, "Error while unsuspending periodics from organization #{org_id}")
    end
  end

  defp unsuspend_periodics(periodics) do
    periodics
    |> Enum.reduce_while({:ok, []}, fn periodic, {:ok, results} ->
      case unsuspend_periodic(periodic) do
        {:ok, periodic} -> {:cont, {:ok, results ++ [periodic]}}
        error -> {:halt, error}
      end
    end)
  end

  defp unsuspend_periodic(periodic) do
    with {:ok, periodic} <- PeriodicsQueries.unsuspend(periodic),
         {:ok, _job} <- QuantumScheduler.start_periodic_job(periodic) do
      periodic
      |> LT.info("Unsuspended periodic due to organization being unblocked")
      |> ToTuple.ok()
    else
      {:error, error} ->
        error |> LT.warn("Error while trying to unsuspend periodic #{periodic.id} ")
        {:error, error}

      error ->
        error
        |> LT.warn("Error while trying to unsuspend periodic #{periodic.id} ")
        |> ToTuple.error()
    end
  end
end
