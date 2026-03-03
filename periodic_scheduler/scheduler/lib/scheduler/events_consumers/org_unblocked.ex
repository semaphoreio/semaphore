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

  defp unsuspend_batch(org_id, batch_no, has_failures \\ false) do
    with {:ok, periodics} <- PeriodicsQueries.get_all_from_org(org_id, batch_no),
         {:periodics_found, true} <- {:periodics_found, length(periodics) > 0},
         {:ok, %{failed: failed, ignored: ignored}} <- unsuspend_periodics(periodics) do
      log_failures(failed, org_id)
      log_ignored(ignored, org_id)

      unsuspend_batch(org_id, batch_no + 1, has_failures || length(failed) > 0)
    else
      {:periodics_found, false} ->
        finalize_result(has_failures, org_id)

      error ->
        LT.warn(error, "Error while unsuspending periodics from organization #{org_id}")
        {:error, :batch_processing_failed}
    end
  end

  defp log_failures([], _org_id), do: :ok

  defp log_failures(failed, org_id) do
    count = length(failed)
    Watchman.submit("scheduler.org_unblocked.unsuspend.failure", count)
    failed |> LT.warn("Failed to unsuspend #{count} periodics for organization #{org_id}")
  end

  defp log_ignored([], _org_id), do: :ok

  defp log_ignored(ignored, org_id) do
    count = length(ignored)
    Watchman.submit("scheduler.org_unblocked.unsuspend.ignored", count)
    ignored |> LT.info("Ignored #{count} periodics with data issues for organization #{org_id}")
  end

  defp finalize_result(false, org_id) do
    LT.info(org_id, "Unsuspended all periodics from organization")
    :ok
  end

  defp finalize_result(true, org_id) do
    LT.warn(org_id, "Finished unsuspending periodics from organization but some failed")
    {:error, :failed_unsuspending_periodics}
  end

  defp unsuspend_periodics(periodics) do
    result =
      Enum.reduce(periodics, %{unsuspended: [], ignored: [], failed: []}, fn periodic, acc ->
        case unsuspend_periodic(periodic) do
          {:ok, periodic} ->
            %{acc | unsuspended: [periodic.id | acc.unsuspended]}

          {:error, :missing_cron_expression} ->
            ignored_entry = %{id: periodic.id, reason: :missing_cron_expression}
            %{acc | ignored: [ignored_entry | acc.ignored]}

          other ->
            failed_entry = %{id: periodic.id, reason: other}
            %{acc | failed: [failed_entry | acc.failed]}
        end
      end)

    {:ok,
     %{
       unsuspended: Enum.reverse(result.unsuspended),
       ignored: Enum.reverse(result.ignored),
       failed: Enum.reverse(result.failed)
     }}
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
