defmodule Looper.StateWatch.Query do
  @moduledoc """
  StateWatch queries
  """

  import Ecto.Query

  alias Looper.Util

  def count_events_by_state(params) do
    params.schema
    |> in_included_state(params.included_states)
    |> group_by([p], [p.state])
    |> select([p], {p.state, count(p.id)})
    |> execute(:all, params.repo)
    |> Util.return_ok_tuple()
  rescue
    e -> {:error, e}
  catch
    a, b -> {:error, [a, b]}
  end

  defp in_included_state(q, states), do:
    q |> where([p], p.state in ^states)

  defp execute(q, operation, repo), do:
    apply(repo, operation, [q])
end
