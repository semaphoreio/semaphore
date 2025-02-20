defmodule Looper.STM.Query do
  @moduledoc """
  STM queries
  """

  import Ecto.Query

  alias Looper.CommonQuery, as: CQ
  alias Looper.Util

  @doc """
  Select single item to transition to "scheduling"
  """
  def select_item_to_schedule(cfg) do
    cfg
    |> Map.get(:initial_query)
    # Entries older (waiting longer) than `cooling_time`.
    |> CQ.where_event_older_than_sec(Map.get(cfg, :cooling_time_sec))
    # Only entries in requested `state`.
    |> where(state: ^Map.get(cfg, :observed_state))
    # Only entries not being scheduled currently.
    |> where(in_scheduling: ^false)
    # Next 2 together: pick oldest entry.
    |> order_by([p], [asc: p.updated_at])
    |> limit(1)
    # Lock the entry for update during the transaction and
    # exclude already locked enties.
    # Ensures that only one looper takes the entry - prevents race.
    |> lock("FOR UPDATE SKIP LOCKED")
    |> select(^Map.get(cfg, :returning))
    # |> Repo.one
    |> execute(:one, Map.get(cfg, :repo))
    |> Util.return_ok_tuple()
  end

  @doc """
  Transition previously selected item to scheduling
  """
  def transition_to_scheduling(id, cfg) do
    cfg
    |> Map.get(:schema)
    |> where(id: ^id)
    |> select([s], s)
    |> Map.get(cfg, :repo).update_all([set: set_in_scheduling(true)])
    |> transition_validate_response()
  end

  @doc """
  Transition item out of scheduling to desired 'state'
  Update additional fields also.
  """
  def to_state(item, updates, cfg) do
    cfg
    |> Map.get(:initial_query)
    |> where(id: ^item.id)
    |> update(set: ^updates)
    |> update(set: [recovery_count: 0])
    |> update(set: ^set_in_scheduling(false))
    |> select(^Map.get(cfg, :returning))
    |> Map.get(cfg, :repo).update_all([])
    |> transition_validate_response()
  end

  # It has to be exactly 1 item
  defp transition_validate_response({1, [item]}), do: {:ok, item}
  defp transition_validate_response(resp), do: {:error, resp}

  defp execute(q, operation, repo), do:
    apply(repo, operation, [q])

  defp set_in_scheduling(in_scheduling?), do:
    [in_scheduling: in_scheduling?, updated_at: CQ.now_naive()]
end
