defmodule Ppl.Retention.PolicyConsumer do
  @moduledoc """
  Subscribes to usage.ApplyOrganizationPolicyEvent and marks pipelines for expiration.
  """

  @consumer_opts Application.compile_env(:ppl, __MODULE__, [])

  use Tackle.Consumer,
    url: System.get_env("RABBITMQ_URL"),
    exchange: Keyword.get(@consumer_opts, :exchange, "usage_internal_api"),
    routing_key: Keyword.get(@consumer_opts, :routing_key, "usage.apply_organization_policy"),
    service: "plumber-retention"

  require Logger

  alias Google.Protobuf.Timestamp
  alias InternalApi.Usage.OrganizationPolicyApply
  alias Ppl.Retention.PolicyApplier

  def handle_message(message) do
    with {:ok, event} <- decode(message),
         {:ok, cutoff} <- cutoff_to_naive(event.cutoff_date),
         {:ok, org_id} <- non_empty(event.org_id) do
      {marked, unmarked} = PolicyApplier.mark_expiring(org_id, cutoff)
      Watchman.submit({"retention.marked", [org_id]}, marked, :count)
      Watchman.submit({"retention.unmarked", [org_id]}, unmarked, :count)

      Logger.info(
        "[Retention] org=#{org_id} cutoff=#{cutoff} marked=#{marked} unmarked=#{unmarked}"
      )
    else
      {:error, reason} ->
        Logger.error("[Retention] Failed to apply policy event: #{inspect(reason)}")
    end
  end

  defp decode(message) do
    OrganizationPolicyApply.decode(message)
    |> case do
      %OrganizationPolicyApply{} = event -> {:ok, event}
      other -> {:error, {:unexpected_payload, other}}
    end
  rescue
    e -> {:error, e}
  end

  defp cutoff_to_naive(%Timestamp{seconds: 0, nanos: 0}), do: {:error, :missing_cutoff}

  defp cutoff_to_naive(%Timestamp{seconds: seconds, nanos: nanos}) do
    {:ok, datetime} = DateTime.from_unix(seconds, :second)
    micros = div(nanos, 1_000)
    {:ok, datetime |> DateTime.add(micros, :microsecond) |> DateTime.to_naive()}
  end

  defp cutoff_to_naive(nil), do: {:error, :missing_cutoff}

  defp non_empty(value) when value in [nil, ""], do: {:error, :missing_org_id}
  defp non_empty(value), do: {:ok, value}
end
