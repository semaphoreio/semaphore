defmodule Audit.Retention.PolicyMarker do
  @moduledoc """
  Subscribes to retention policy events and marks audit events for expiration.

  Listens to the same `usage.apply_organization_policy` AMQP event that
  Zebra and Plumber consume. On each message it:

  1. Marks events with `timestamp < cutoff_date` → sets `expires_at = now + grace_period`
  2. Unmarks events with `timestamp >= cutoff_date` → clears `expires_at`
  """

  require Logger

  alias Google.Protobuf.Timestamp
  alias InternalApi.Usage.OrganizationPolicyApply
  alias Audit.Retention.Queries

  @max_future_cutoff_skew_sec 60

  use Tackle.Consumer,
    url: Application.get_env(:audit, :amqp_url),
    service: "audit-retention",
    exchange: "usage_internal_api",
    routing_key: "usage.apply_organization_policy",
    retry_limit: 10,
    retry_delay: 10

  def handle_message(message) do
    with {:ok, event} <- decode(message),
         {:ok, org_id} <- validate_org_id(event.org_id),
         {:ok, cutoff} <- parse_cutoff(event.cutoff_date) do
      apply_policy(org_id, cutoff)
    else
      {:invalid, reason} ->
        Watchman.increment("retention.policy.invalid")
        Logger.warning("[Retention] Skipping invalid policy event: #{reason}")
        :ok
    end
  end

  @spec apply_policy(String.t(), DateTime.t()) :: :ok | no_return()
  defp apply_policy(org_id, cutoff) do
    {marked, unmarked} = Queries.mark_expiring(org_id, cutoff)

    Logger.info(
      "[Retention] org=#{org_id} cutoff=#{cutoff} marked=#{marked} unmarked=#{unmarked}"
    )

    :ok
  rescue
    e in [Postgrex.Error, DBConnection.ConnectionError] ->
      Watchman.increment("retention.policy.error")
      Logger.error("[Retention] Failed to process policy event for org=#{org_id}: #{inspect(e)}")
      reraise e, __STACKTRACE__

    e ->
      Logger.error(
        "[Retention] Unexpected policy processing error for org=#{org_id}: #{inspect(e)}"
      )

      reraise e, __STACKTRACE__
  end

  defp decode(message) do
    case OrganizationPolicyApply.decode(message) do
      %OrganizationPolicyApply{} = event -> {:ok, event}
      other -> {:invalid, "unexpected payload: #{inspect(other)}"}
    end
  rescue
    e -> {:invalid, "failed to decode message: #{inspect(e)}"}
  end

  defp validate_org_id(nil), do: {:invalid, "org_id is missing in policy payload"}
  defp validate_org_id(""), do: {:invalid, "org_id is missing in policy payload"}

  defp validate_org_id(org_id) when is_binary(org_id) do
    case Ecto.UUID.cast(org_id) do
      {:ok, valid_uuid} -> {:ok, valid_uuid}
      :error -> {:invalid, "invalid org_id format: expected UUID, got #{inspect(org_id)}"}
    end
  end

  defp validate_org_id(invalid), do: {:invalid, "invalid org_id: #{inspect(invalid)}"}

  defp parse_cutoff(nil), do: {:invalid, "cutoff_date is missing in policy payload"}

  defp parse_cutoff(%Timestamp{seconds: 0, nanos: 0}),
    do: {:invalid, "cutoff_date is missing in policy payload"}

  defp parse_cutoff(%Timestamp{seconds: seconds, nanos: nanos})
       when is_integer(seconds) and is_integer(nanos) and seconds >= 0 and nanos >= 0 and
              nanos < 1_000_000_000 do
    total_nanoseconds = seconds * 1_000_000_000 + nanos

    cutoff =
      total_nanoseconds
      |> DateTime.from_unix!(:nanosecond)
      |> DateTime.truncate(:second)

    now = DateTime.utc_now() |> DateTime.truncate(:second)
    skew_seconds = DateTime.diff(cutoff, now, :second)

    case skew_seconds do
      sec when sec > @max_future_cutoff_skew_sec ->
        {:invalid,
         "cutoff_date cannot be more than #{@max_future_cutoff_skew_sec}s in the future"}

      _ ->
        {:ok, cutoff}
    end
  rescue
    error -> {:invalid, "failed to parse cutoff_date: #{inspect(error)}"}
  end

  defp parse_cutoff(invalid),
    do: {:invalid, "invalid cutoff_date format: #{inspect(invalid)}"}
end
