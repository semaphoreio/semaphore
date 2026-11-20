defmodule Audit.Retention do
  @moduledoc """
  Audit log retention is enabled per organization by the `audit_logs_retention`
  feature. The policy marker checks it before marking events and the deleter
  checks it again before deleting them. A failed lookup counts as disabled when
  nothing is cached; if only the refresh after a feature change fails, the last
  known value is kept until the cache expires.

  Events younger than the retention floor (`min_retention_days`, at least 400)
  are never marked, and never deleted.
  """

  @feature :audit_logs_retention
  @default_min_retention_days 400

  @spec enabled?(String.t()) :: boolean()
  def enabled?(org_id), do: FeatureProvider.feature_enabled?(@feature, param: org_id)

  @doc """
  Returns the retention floor: events with a timestamp before it may expire,
  events at or after it are kept.
  """
  @spec floor() :: DateTime.t()
  def floor do
    DateTime.utc_now()
    |> DateTime.truncate(:second)
    |> DateTime.add(-min_retention_days() * 86_400, :second)
  end

  # Configuration may only make retention stricter: values below 400 days,
  # or not integers, fall back to 400.
  defp min_retention_days do
    config = Application.get_env(:audit, __MODULE__, [])

    case Keyword.get(config, :min_retention_days, @default_min_retention_days) do
      days when is_integer(days) and days >= @default_min_retention_days -> days
      _ -> @default_min_retention_days
    end
  end
end
