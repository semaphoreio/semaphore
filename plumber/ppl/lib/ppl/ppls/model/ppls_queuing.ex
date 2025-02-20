defmodule Ppl.Ppls.Model.PplsQueuing do
  @moduledoc """
  Enter scheduling query for queuing state
  """
  alias Ppl.Query2Ecto.STM
  alias Ppl.Ppls.Model.Ppls
  alias Ppl.EctoRepo, as: Repo

  def queuing_enter_scheduling do
    with {:ok, resp} <- Repo.transaction(&queuing_enter_scheduling_/0),
      do: resp
  end

  def queuing_enter_scheduling_ do
    # Fom docs: The effects of SET LOCAL last only till the end of the
    # current transaction, whether committed or not.
    #
    # With ENABLE_NESTLOOP == true query on ~800 queued pipelines
    # takes ~12 sec to execute.
    # With ENABLE_NESTLOOP == false it takes ~100ms !!!
    "SET LOCAL ENABLE_NESTLOOP TO FALSE;"
    |> Repo.query()

    queuing_enter_scheduling_select_query()
    |> queuing_enter_scheduling_update_query()
    |> Repo.query([NaiveDateTime.utc_now()])
    |> STM.load(Ppls)
  end

  def queuing_enter_scheduling_update_query(select_query) do "
    UPDATE pipelines
    SET in_scheduling = true, updated_at = $1
    FROM (#{select_query}) AS subquery
    WHERE pipelines.id = subquery.id
      AND pipelines.state = 'queuing'
      AND pipelines.in_scheduling = false
    RETURNING pipelines.*, subquery.updated_at as old_update_time
  " end

  def queuing_enter_scheduling_select_query() do "
    SELECT DISTINCT ON (p.queue_id)  p.*
    FROM pipelines AS p
    LEFT JOIN pipelines AS s
      ON p.queue_id = s.queue_id and
        (s.state in ('running', 'stopping') or
          (s.state in ('queuing') and s.in_scheduling in (true)))
    WHERE (p.state='queuing' AND s.state IS NULL)
          OR (p.state='queuing' AND p.terminate_request IS NOT NULL)
          OR (p.state='queuing' AND p.parallel_run = true)
    ORDER BY p.queue_id, p.inserted_at
    LIMIT 1
  " end
end
