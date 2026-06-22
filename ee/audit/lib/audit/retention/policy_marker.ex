defmodule Audit.Retention.PolicyMarker do
  @moduledoc """
  Subscribes to retention policy events and marks audit events for expiration.

  Listens to the same `usage.apply_organization_policy` AMQP event that
  Zebra and Plumber consume. On each message it:

  1. Marks events with `timestamp < cutoff_date` → sets `expires_at = now + grace_period`
  2. Unmarks events with `timestamp >= cutoff_date` → clears `expires_at`

  ## Retention floor

  `cutoff_date` is computed by the upstream publisher, not this service. To
  guarantee a minimum retention, any cutoff newer than
  `now - min_retention_days` (default 400) is *clamped* back to that floor
  rather than honored: a too-short window (or a future/misconfigured cutoff)
  still deletes everything older than the floor instead of silently dropping
  the event, but audit logs younger than the floor are never expired. Clamps
  are surfaced via the `retention.policy.cutoff_clamped` metric.

  ## Cleanup of existing organizations (upstream dependency)

  This consumer is edge-triggered: an org's old events are only marked when a
  `usage.apply_organization_policy` event arrives for it. Cleaning up
  organizations that predate the rollout therefore relies on the upstream
  publisher periodically *replaying* the policy for all orgs — the same
  contract Zebra/Plumber already depend on. There is intentionally no
  per-service backfill here; if the platform is purely edge-triggered, the
  replay must be added upstream so all consumers benefit.
  """

  require Logger

  alias Google.Protobuf.Timestamp
  alias InternalApi.Usage.OrganizationPolicyApply
  alias Audit.Retention.Queries

  @default_min_retention_days 400

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
         {:ok, cutoff} <- resolve_cutoff(event.cutoff_date) do
      apply_policy(org_id, cutoff)
    else
      {:invalid, reason} ->
        Watchman.increment("retention.policy.invalid")
        Logger.warning("[Retention] Skipping invalid policy event: #{reason}")
        :ok
    end
  end

  # A cutoff newer than the retention floor (a window shorter than the floor, a
  # future date, or a misconfigured publisher) is clamped back to the floor
  # instead of dropped, so we still delete everything older than the floor
  # rather than silently doing nothing. Clamps are surfaced for monitoring.
  defp resolve_cutoff(raw) do
    case parse_cutoff(raw) do
      {:clamped, floor} ->
        Watchman.increment("retention.policy.cutoff_clamped")

        Logger.warning("[Retention] cutoff newer than the retention floor; clamping to #{floor}")

        {:ok, floor}

      other ->
        other
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

    days = min_retention_days()
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    floor = DateTime.add(now, -days * 86_400, :second)

    # The floor is a hard minimum retention. A cutoff newer than it (a window
    # shorter than the floor, or a future/misconfigured date) is clamped back to
    # the floor rather than honored — never expire audit logs younger than the
    # floor, but still delete everything older than it.
    if DateTime.compare(cutoff, floor) == :gt do
      {:clamped, floor}
    else
      {:ok, cutoff}
    end
  rescue
    error -> {:invalid, "failed to parse cutoff_date: #{inspect(error)}"}
  end

  defp parse_cutoff(invalid),
    do: {:invalid, "invalid cutoff_date format: #{inspect(invalid)}"}

  # The 400-day policy is a *hard* floor: configuration may only make retention
  # more conservative (a larger value), never weaken it. Any value below the
  # policy — including a misconfigured 1 or a non-integer — falls back to the
  # 400-day default, so production cannot be tricked into deleting recent audit
  # logs by lowering this knob.
  defp min_retention_days do
    config = Application.get_env(:audit, __MODULE__, [])

    case Keyword.get(config, :min_retention_days, @default_min_retention_days) do
      days when is_integer(days) and days >= @default_min_retention_days -> days
      _ -> @default_min_retention_days
    end
  end
end
