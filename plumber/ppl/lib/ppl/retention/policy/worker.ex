defmodule Ppl.Retention.Policy.Worker do
  @moduledoc """
  Subscribes to retention policy events and marks pipelines for expiration.

  ## Runtime Control

  - `pause/0` - pause handling events indefinitely
  - `pause_for/1` - pause for N milliseconds
  - `resume/0` - resume handling events
  - `status/0` - returns `:running` or `:paused`
  - `config/0` - returns current configuration
  - `update_config/1` - updates sleep_ms (poll interval when paused)
  """

  use Tackle.Consumer,
    url: System.get_env("RABBITMQ_URL"),
    exchange: "usage_internal_api",
    routing_key: "usage.apply_organization_policy",
    service: "plumber-retention"

  require Logger

  alias Google.Protobuf.Timestamp
  alias InternalApi.Usage.OrganizationPolicyApply
  alias Ppl.Retention.Policy.Queries
  alias Ppl.Retention.Policy.State
  alias Ppl.Retention.StateAgent

  def pause do
    StateAgent.update_state(__MODULE__, &State.pause/1)
    Logger.info("[Retention] Policy.Worker paused")
    :ok
  end

  def pause_for(ms) when is_integer(ms) and ms > 0 do
    StateAgent.update_state(__MODULE__, &State.pause_for(&1, ms))
    Logger.info("[Retention] Policy.Worker paused for #{ms}ms")
    :ok
  end

  def resume do
    StateAgent.update_state(__MODULE__, &State.resume/1)
    Logger.info("[Retention] Policy.Worker resumed")
    :ok
  end

  def status do
    case State.check_pause(StateAgent.get_state(__MODULE__)) do
      {:running, _} -> :running
      {:paused, _} -> :paused
    end
  end

  def paused? do
    case State.check_pause(StateAgent.get_state(__MODULE__)) do
      {:running, _} -> false
      {:paused, _} -> true
    end
  end

  def config, do: State.to_config(StateAgent.get_state(__MODULE__))

  def update_config(opts) do
    StateAgent.update_state(__MODULE__, &State.update(&1, opts))
    :ok
  end

  def handle_message(message) do
    wait_until_running()
    process_message(message)
  end

  defp process_message(message) do
    with {:ok, event} <- decode(message),
         {:ok, cutoff} <- parse_cutoff(event.cutoff_date),
         {:ok, org_id} <- validate_org_id(event.org_id) do
      {marked, unmarked} = Queries.mark_expiring(org_id, cutoff)
      Logger.info("[Retention] org=#{org_id} cutoff=#{cutoff} marked=#{marked} unmarked=#{unmarked}")
    else
      {:error, reason} ->
        Logger.error("[Retention] Failed to process policy event: #{inspect(reason)}")
    end
  end

  defp decode(message) do
    case OrganizationPolicyApply.decode(message) do
      %OrganizationPolicyApply{} = event -> {:ok, event}
      other -> {:error, {:unexpected_payload, other}}
    end
  rescue
    e -> {:error, e}
  end

  defp parse_cutoff(%Timestamp{seconds: 0, nanos: 0}), do: {:error, :missing_cutoff}
  defp parse_cutoff(nil), do: {:error, :missing_cutoff}

  defp parse_cutoff(%Timestamp{seconds: seconds, nanos: nanos}) do
    {:ok, datetime} = DateTime.from_unix(seconds, :second)
    micros = div(nanos, 1_000)
    naive = datetime |> DateTime.add(micros, :microsecond) |> DateTime.to_naive()
    {:ok, naive}
  end

  defp validate_org_id(nil), do: {:error, :missing_org_id}
  defp validate_org_id(""), do: {:error, :missing_org_id}
  defp validate_org_id(org_id), do: {:ok, org_id}

  defp wait_until_running do
    state = StateAgent.get_state(__MODULE__)

    case State.check_pause(state) do
      {:running, new_state} ->
        StateAgent.put_state(__MODULE__, new_state)

      {:paused, _} ->
        Process.sleep(state.sleep_ms)
        wait_until_running()
    end
  end
end
