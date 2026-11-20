defmodule Zebra.Workers.FinishedJobCleaner do
  @moduledoc """
  Drops data that finished jobs no longer need, once they are older than a
  cutoff (3 days by default):

    - agent_auth_token: still needed by post-job processing for a while
      after the job finishes, so it is not cleared at finish.
    - private_ssh_key: already cleared when the job finishes; cleared here
      too for rows written before that.

  The worker walks jobs in (finished_at, id) order, which is served by the
  jobs (finished_at, id) index, one batch per tick. Progress is stored in
  job_cleanup_cursors, so a restarted worker resumes where it stopped and
  the first pass drains old rows over time. Every update is guarded by the
  same predicates, so processing a row twice changes nothing.

  Throttling: at most `batch_size` rows per tick, `naptime` ms between ticks
  while there is work, `longnaptime` ms once it has caught up with the cutoff.
  """

  require Logger
  import Ecto.Query

  alias Zebra.LegacyRepo, as: Repo
  alias Zebra.Models.Job

  @cursor_name "finished_job_cleaner"
  @start_finished_at ~N[1970-01-01 00:00:00]
  @start_job_id "00000000-0000-0000-0000-000000000000"

  defstruct [:cursor_name, :cutoff_days, :batch_size, :naptime, :longnaptime]

  def start_link do
    with {:ok, config} <- fetch_config(),
         {:ok, worker} <- build(config) do
      pid = spawn_link(fn -> loop(worker) end)
      Logger.info("FinishedJobCleaner started with config: #{inspect(worker)}")
      {:ok, pid}
    else
      {:error, reason} ->
        Logger.error("Failed to start FinishedJobCleaner: #{reason}")
        {:error, reason}
    end
  end

  def loop(worker) do
    result = tick(worker)

    :timer.sleep(naptime(worker, result))

    loop(worker)
  end

  @doc """
  Sleep before the next tick: short while full batches keep coming, long once
  the walk has reached the cutoff or the tick could not run.
  """
  def naptime(worker, {:ok, %{scanned: scanned}}) when scanned >= worker.batch_size,
    do: worker.naptime

  def naptime(worker, _), do: worker.longnaptime

  @doc """
  Processes one batch. Returns {:ok, %{scanned: n, cleaned: m}}, or
  {:ok, :locked} when another instance holds the cursor.
  """
  def tick(worker) do
    Watchman.benchmark("finished_job_cleaner.tick.duration", fn ->
      Repo.transaction(fn -> process_batch(worker) end)
    end)
    |> case do
      {:ok, {:ok, stats}} ->
        submit_metrics(stats)
        {:ok, stats}

      {:ok, :locked} ->
        {:ok, :locked}

      {:error, reason} ->
        Logger.error("FinishedJobCleaner tick failed: #{inspect(reason)}")
        {:error, reason}
    end
  rescue
    e ->
      Logger.error("FinishedJobCleaner tick raised: #{inspect(e)}")
      {:error, e}
  end

  defp process_batch(worker) do
    ensure_cursor(worker.cursor_name)

    case lock_cursor(worker.cursor_name) do
      nil ->
        :locked

      {cursor_finished_at, cursor_id} ->
        cutoff = cutoff(worker)
        batch = next_batch(cursor_finished_at, cursor_id, cutoff, worker.batch_size)

        cleaned = clean(batch)

        case List.last(batch) do
          nil -> :ok
          {finished_at, id} -> move_cursor(worker.cursor_name, finished_at, id)
        end

        {:ok, %{scanned: length(batch), cleaned: cleaned}}
    end
  end

  defp cutoff(worker) do
    DateTime.utc_now()
    |> DateTime.add(-worker.cutoff_days * 86_400, :second)
    |> DateTime.truncate(:second)
  end

  defp next_batch(cursor_finished_at, cursor_id, cutoff, limit) do
    from(j in Job,
      where: j.finished_at < ^cutoff,
      where:
        fragment(
          "(?, ?) > (?, ?)",
          j.finished_at,
          j.id,
          ^cursor_finished_at,
          type(^cursor_id, :binary_id)
        ),
      order_by: [asc: j.finished_at, asc: j.id],
      limit: ^limit,
      # raw value: the :utc_datetime field type would drop microseconds, and a
      # cursor rounded down could keep selecting the same rows
      select: {fragment("?", j.finished_at), j.id}
    )
    |> Repo.all()
  end

  defp clean([]), do: 0

  defp clean(batch) do
    ids = Enum.map(batch, fn {_, id} -> id end)

    {cleaned, _} =
      from(j in Job,
        where: j.id in ^ids,
        where: j.aasm_state == ^Job.state_finished(),
        where: not is_nil(j.agent_auth_token) or not is_nil(j.private_ssh_key)
      )
      |> Repo.update_all(set: [agent_auth_token: nil, private_ssh_key: nil])

    cleaned
  end

  defp ensure_cursor(name) do
    Repo.insert_all(
      "job_cleanup_cursors",
      [
        %{
          name: name,
          finished_at: @start_finished_at,
          job_id: dump_uuid(@start_job_id),
          updated_at: now()
        }
      ],
      on_conflict: :nothing,
      conflict_target: :name
    )
  end

  # SKIP LOCKED: with more than one replica, only one of them works on a
  # cursor at a time; the others skip the tick.
  defp lock_cursor(name) do
    from(c in "job_cleanup_cursors",
      where: c.name == ^name,
      lock: "FOR UPDATE SKIP LOCKED",
      select: {c.finished_at, c.job_id}
    )
    |> Repo.one()
    |> case do
      nil -> nil
      {finished_at, job_id} -> {to_naive(finished_at), Ecto.UUID.cast!(job_id)}
    end
  end

  defp move_cursor(name, finished_at, id) do
    from(c in "job_cleanup_cursors", where: c.name == ^name)
    |> Repo.update_all(
      set: [
        finished_at: to_naive(finished_at),
        job_id: dump_uuid(id),
        updated_at: now()
      ]
    )
  end

  defp dump_uuid(id), do: Ecto.UUID.dump!(id)

  # job_cleanup_cursors and jobs.finished_at are timestamps without time zone,
  # in UTC. Precision is kept as is, never rounded.
  defp to_naive(dt = %DateTime{}), do: DateTime.to_naive(dt)
  defp to_naive(ndt = %NaiveDateTime{}), do: ndt

  defp now, do: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)

  defp submit_metrics(%{scanned: scanned, cleaned: cleaned}) do
    Watchman.submit("finished_job_cleaner.scanned", scanned, :count)
    Watchman.submit("finished_job_cleaner.cleaned", cleaned, :count)
  end

  #
  # Config
  #

  defp fetch_config do
    case Application.fetch_env(:zebra, __MODULE__) do
      {:ok, config} -> {:ok, config}
      :error -> {:error, "Worker configuration is missing"}
    end
  end

  def build(config) do
    with {:ok, cutoff_days} <- positive(config, :cutoff_days),
         {:ok, batch_size} <- positive(config, :batch_size),
         {:ok, naptime} <- positive(config, :naptime),
         {:ok, longnaptime} <- positive(config, :longnaptime) do
      {:ok,
       %__MODULE__{
         cursor_name: Keyword.get(config, :cursor_name, @cursor_name),
         cutoff_days: cutoff_days,
         batch_size: batch_size,
         naptime: naptime,
         longnaptime: longnaptime
       }}
    end
  end

  defp positive(config, key) do
    case Keyword.fetch(config, key) do
      {:ok, value} when is_integer(value) and value > 0 ->
        {:ok, value}

      {:ok, invalid} ->
        {:error, "Invalid #{key}: expected positive integer, got #{inspect(invalid)}"}

      :error ->
        {:error, "#{key} configuration is missing"}
    end
  end
end
