defmodule Ppl.TimeLimits.Model.TrackingStateScheduling do
  @moduledoc """
  Find time_limits that have reached the deadline.
  """

  alias Ppl.Query2Ecto.STM
  alias Ppl.TimeLimits.Model.TimeLimits
  alias Ppl.EctoRepo, as: Repo
  alias Util.Metrics

  def get_deadline_reached(type) do
    Metrics.benchmark("Ppl.time_limit.tracking_STM", "enter_scheduling",  fn ->
      with {:ok, resp} <- Repo.transaction(fn -> find_deadline_reached(type) end),
        do: resp
    end)
  end

  def find_deadline_reached(type) do
    type
    |> select_deadline_reached()
    |> time_limit_update_query()
    |> Repo.query([NaiveDateTime.utc_now()])
    |> STM.load(TimeLimits)
  end

  defp select_deadline_reached(type) do "
    SELECT tl.*
    FROM time_limits AS tl
    WHERE
      tl.in_scheduling = false
      AND
      tl.state = 'tracking'
      AND
      tl.type = '#{type}'
      AND (
        tl.deadline < NOW()
        OR
        tl.terminate_request IS NOT NULL
      )
    LIMIT 1
  " end

  def time_limit_update_query(select_query) do "
    UPDATE time_limits AS time_limit
    SET in_scheduling = true, updated_at = $1
    FROM (#{select_query}) AS subquery
    WHERE time_limit.id = subquery.id and time_limit.in_scheduling = false
    RETURNING time_limit.*, subquery.updated_at as old_update_time
  " end
end
