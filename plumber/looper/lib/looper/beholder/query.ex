defmodule Looper.Beholder.Query do
  @moduledoc false

  import Ecto.Query
  alias Looper.CommonQuery, as: CQ

  @doc """
  Find all stuck items that have been recovered 'threshold_count' times
  """
  def get_repeatedly_stuck(cfg) do
    cfg
    |> Map.get(:query)
    |> where_in_scheduling_longer_than(Map.get(cfg, :threshold_sec))
    |> where_exclude_states(Map.get(cfg, :excluded_states))
    |> where_recovery_count_threshold_reached(Map.get(cfg, :threshold_count))
    |> execute_get_all(Map.get(cfg, :repo))
  end

  @doc """
  Terminate (transitions to terminal state) passed stuck items.
  """
  def abort_repeatedly_stuck(stuck_items, cfg) do
    cfg
    |> Map.get(:query)
    |> where_item_in_stuck_items(stuck_items)
    |> update_set([state:  Map.get(cfg, :terminal_state)])
    |> update_set([result: Map.get(cfg, :result_on_abort)])
    |> update_result_reason(Map.get(cfg, :result_reason_on_abort))
    |> update_timestamp()
    |> execute_update_all(Map.get(cfg, :repo))
  end

  defp update_result_reason(query, ""), do: query
  defp update_result_reason(query, result_reason) do
    query |> update_set([result_reason: result_reason])
  end

  @doc """
  Find all items that are in scheduling state longer than `threshold_sec`
  and that heve been recovered less than `threshold_count` times
  -> move them back to the state they were before entering scheduling.
  """
  def recover_stuck(cfg) do
    cfg
    |> Map.get(:query)
    |> where_in_scheduling_longer_than(Map.get(cfg, :threshold_sec))
    |> where_exclude_states(Map.get(cfg, :excluded_states))
    |> where_recovery_count_threshold_not_reached(Map.get(cfg, :threshold_count))
    # Updates
    |> update_in_scheduling(false)
    |> update(inc: [recovery_count: 1])
    |> update_timestamp()
    # Call update on previous query (query with updates)
    |> execute_update_all(Map.get(cfg, :repo))
  end

  defp where_item_in_stuck_items(q, stuck_items) do
    stuck_items_ids = Enum.map(stuck_items, fn %{id: id} -> id end)
    q |> where([p], p.id in ^stuck_items_ids)
  end

  defp where_in_scheduling_longer_than(q, seconds) do
    q |> where(in_scheduling: ^true) |> CQ.where_event_older_than_sec(seconds)
  end

  defp where_exclude_states(q, states), do:
    q |> where([p], not (p.state in ^states))

  defp where_recovery_count_threshold_reached(q, threshold), do:
    q |> where([p], p.recovery_count >= ^threshold)

  defp where_recovery_count_threshold_not_reached(q, threshold), do:
    q |> where([p], p.recovery_count < ^threshold)

  defp update_in_scheduling(q, in_scheduling), do:
    q |> update_set([in_scheduling: in_scheduling])

  defp update_timestamp(q), do: update_set(q, [updated_at: CQ.now_naive()])

  defp update_set(q, fields), do: q |> update(set: ^fields)

  defp execute_update_all(q, repo), do: q |> select([s], s) |> repo.update_all([])

  defp execute_get_all(q, repo), do: q |> repo.all()
end
