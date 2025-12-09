defmodule Zebra.Workers.JobDeletionPolicyMarker do
  require Logger

  alias Zebra.Models.Job
  alias Google.Protobuf.Timestamp

  @default_grace_period_days 14
  @min_grace_period_days 7

  use Tackle.Consumer,
    url: Application.get_env(:zebra, :amqp_url),
    service: "zebra",
    exchange: "usage_internal_api",
    routing_key: "usage.apply_organization_policy",
    retry_limit: 10,
    retry_delay: 10

  def handle_message(message) do
    with {:ok, decoded} <- decode_message(message),
         {:ok, org_id} <- validate_org_id(decoded.org_id),
         {:ok, cutoff_date} <- parse_cutoff_date(decoded.cutoff_date),
         {:ok, days} <- validate_policy_days() do
      {marked, unmarked} = Job.mark_jobs_for_deletion(org_id, cutoff_date, days)

      Watchman.submit({"retention.marked", [org_id]}, marked, :count)
      Watchman.submit({"retention.unmarked", [org_id]}, unmarked, :count)

      Logger.info(
        "Marked #{marked} jobs for deletion, unmarked #{unmarked} jobs for org #{org_id}."
      )
    else
      {:error, reason} ->
        Logger.error("Failed to process policy message: #{reason}")
        raise ArgumentError, reason
    end
  end

  defp decode_message(message) do
    {:ok, InternalApi.Usage.OrganizationPolicyApply.decode(message)}
  rescue
    error ->
      {:error, "Failed to decode message: #{inspect(error)}"}
  end

  defp validate_org_id(org_id) when is_binary(org_id) and byte_size(org_id) > 0 do
    case Ecto.UUID.cast(org_id) do
      {:ok, valid_uuid} -> {:ok, valid_uuid}
      :error -> {:error, "Invalid org_id format: expected UUID, got #{inspect(org_id)}"}
    end
  end

  defp validate_org_id(nil), do: {:error, "org_id is missing in policy payload"}
  defp validate_org_id(""), do: {:error, "org_id is missing in policy payload"}
  defp validate_org_id(invalid), do: {:error, "Invalid org_id: #{inspect(invalid)}"}

  defp parse_cutoff_date(nil), do: {:error, "cutoff_date is missing in policy payload"}

  defp parse_cutoff_date(%Timestamp{seconds: seconds, nanos: nanos})
       when is_integer(seconds) and is_integer(nanos) and seconds >= 0 and nanos >= 0 do
    total_nanoseconds = seconds * 1_000_000_000 + nanos

    cutoff_date =
      total_nanoseconds
      |> DateTime.from_unix!(:nanosecond)
      |> DateTime.truncate(:second)

    {:ok, cutoff_date}
  rescue
    error ->
      {:error, "Failed to parse cutoff_date: #{inspect(error)}"}
  end

  defp parse_cutoff_date(invalid),
    do: {:error, "Invalid cutoff_date format: #{inspect(invalid)}"}

  defp validate_policy_days do
    case Application.fetch_env(:zebra, __MODULE__) do
      {:ok, config} ->
        case Keyword.fetch(config, :days) do
          {:ok, days} when is_integer(days) and days >= @min_grace_period_days ->
            {:ok, days}

          {:ok, days} when is_integer(days) and days > 0 ->
            Logger.warning(
              "Configured grace period #{days} days is below minimum #{@min_grace_period_days} days, using minimum"
            )

            {:ok, @min_grace_period_days}

          {:ok, invalid} ->
            Logger.warning(
              "Invalid grace period configuration: expected positive integer >= #{@min_grace_period_days}, got #{inspect(invalid)}, using default #{@default_grace_period_days} days"
            )

            {:ok, @default_grace_period_days}

          :error ->
            Logger.info(
              "Grace period configuration missing, using default #{@default_grace_period_days} days"
            )

            {:ok, @default_grace_period_days}
        end

      :error ->
        Logger.info(
          "Worker configuration missing, using default grace period #{@default_grace_period_days} days"
        )

        {:ok, @default_grace_period_days}
    end
  end
end
