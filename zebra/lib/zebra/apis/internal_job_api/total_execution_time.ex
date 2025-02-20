defmodule Zebra.Apis.InternalJobApi.TotalExecutionTime do
  alias Zebra.LegacyRepo, as: Repo

  def calculate(org_id) do
    {:ok, uuid} = Ecto.UUID.dump(org_id)

    query = """
      SELECT
        extract(EPOCH FROM
          SUM(CASE
              WHEN aasm_state = 'finished' THEN finished_at - started_at
              WHEN aasm_state = 'started'  THEN now() - started_at
              ELSE interval '0'
          END)
        )
      FROM jobs WHERE jobs.organization_id = $1
       AND jobs.created_at > now() - interval '24h'
    """

    res = Ecto.Adapters.SQL.query!(Repo, query, [uuid])
    rows = hd(res.rows)
    value = hd(rows) || 0

    {:ok, value}
  end
end
