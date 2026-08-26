defmodule RepositoryHub.BuildStatusGuard do
  @moduledoc """
  Cross-instance ordering guard for commit status delivery.

  One row per (repository_id, commit_sha, context, source_id) records the last
  delivered state and an in-flight lease. `claim/1` decides under a row lock
  (`SELECT ... FOR UPDATE` inside a transaction): it acquires the lease unless
  another delivery currently holds it (`:busy`), a PENDING status arrives
  after a terminal state was already delivered (`:skip`), or the caller asked
  to suppress a status that isn't reconciling an outstanding PENDING
  (`:suppressed`). The provider call
  happens outside the transaction; `finalize/2` and `release/2` complete or
  abandon the lease, using the claim timestamp as a fencing token so an
  expired claimant cannot overwrite newer state. Lease arithmetic uses the
  database clock, never the pods'.

  Requests without a source_id are not guarded. If the guard table does not
  exist yet (migration not run), operations return
  `{:error, :guard_unavailable}` so callers can deliver unguarded. A malformed
  repository_id returns `{:error, :invalid_key}` so the caller's own request
  validation can reject it instead of the guard crashing.
  """

  import Ecto.Query

  alias InternalApi.Repository.CreateBuildStatusRequest
  alias RepositoryHub.Model.BuildStatusGuards
  alias RepositoryHub.Repo

  require Logger

  @terminal_states ~w(SUCCESS FAILURE STOPPED)
  @lease_seconds 90

  @doc """
  Acquires the delivery lease for the request's check.

  Returns `{:ok, fence}` when the caller may deliver, `:skip` when the status
  is a stale PENDING that must not be delivered, `:suppressed` when the caller
  asked for suppression and no PENDING is outstanding for this check, `:busy`
  when another delivery for the same check is in flight, or an error tuple.

  A suppressed terminal state is still delivered when the last delivered state
  is PENDING, so a suppression decision that flipped mid-pipeline cannot leave
  a check pending forever.
  """
  @spec claim(CreateBuildStatusRequest.t()) ::
          {:ok, DateTime.t()} | :skip | :suppressed | :busy | {:error, term}
  def claim(request) do
    with {:ok, key} <- key(request) do
      pending? = request.status == :PENDING
      suppress? = request.suppress == true

      transaction(fn ->
        ensure_row(key)

        {row, db_now} =
          key
          |> by_key()
          |> lock("FOR UPDATE")
          |> select([g], {g, fragment("now()")})
          |> Repo.one!()

        cond do
          suppress? && pending? ->
            :suppressed

          suppress? && row.last_state != "PENDING" ->
            :suppressed

          pending? && row.last_state in @terminal_states ->
            :skip

          live_lease?(row, db_now) ->
            :busy

          true ->
            {1, _} =
              key
              |> by_key()
              |> Repo.update_all(set: [claimed_at: db_now, updated_at: db_now])

            {:ok, db_now}
        end
      end)
    end
  end

  @doc """
  Records the delivered state and clears the lease. A stale fence is a no-op.
  """
  @spec finalize(CreateBuildStatusRequest.t(), DateTime.t()) :: :ok | {:error, term}
  def finalize(request, fence) do
    case key(request) do
      {:ok, key} ->
        state = Atom.to_string(request.status)

        transaction(fn ->
          key
          |> by_key()
          |> where([g], g.claimed_at == ^fence)
          |> update([g],
            set: [last_state: ^state, claimed_at: nil, updated_at: fragment("now()")]
          )
          |> Repo.update_all([])
          |> case do
            {0, _} ->
              Logger.warning("[BuildStatusGuard] stale fence on finalize, state not recorded")
              :ok

            {_, _} ->
              :ok
          end
        end)

      {:error, :invalid_key} ->
        :ok
    end
  end

  @doc """
  Clears the lease without recording a delivery (the send failed). A stale
  fence is a no-op.
  """
  @spec release(CreateBuildStatusRequest.t(), DateTime.t()) :: :ok | {:error, term}
  def release(request, fence) do
    case key(request) do
      {:ok, key} ->
        transaction(fn ->
          key
          |> by_key()
          |> where([g], g.claimed_at == ^fence)
          |> update([g], set: [claimed_at: nil, updated_at: fragment("now()")])
          |> Repo.update_all([])

          :ok
        end)

      {:error, :invalid_key} ->
        :ok
    end
  end

  @doc false
  def terminal_states, do: @terminal_states

  @doc false
  def lease_seconds, do: @lease_seconds

  defp key(request) do
    case Ecto.UUID.cast(request.repository_id) do
      {:ok, repository_id} ->
        {:ok,
         %{
           repository_id: repository_id,
           commit_sha: request.commit_sha,
           context: request.context,
           source_id: request.source_id
         }}

      :error ->
        {:error, :invalid_key}
    end
  end

  defp by_key(key) do
    from(g in BuildStatusGuards,
      where:
        g.repository_id == ^key.repository_id and g.commit_sha == ^key.commit_sha and
          g.context == ^key.context and g.source_id == ^key.source_id
    )
  end

  # updated_at only feeds retention cleanup, so the app clock is precise
  # enough here; lease decisions always use the database clock.
  defp ensure_row(key) do
    Repo.insert_all(
      BuildStatusGuards,
      [Map.put(key, :updated_at, DateTime.utc_now())],
      on_conflict: :nothing
    )
  end

  defp live_lease?(%{claimed_at: nil}, _db_now), do: false

  defp live_lease?(%{claimed_at: claimed_at}, db_now),
    do: DateTime.diff(db_now, claimed_at, :microsecond) < @lease_seconds * 1_000_000

  defp transaction(fun) do
    case Repo.transaction(fun) do
      {:ok, result} -> result
      {:error, reason} -> {:error, reason}
    end
  rescue
    error in Postgrex.Error ->
      case error.postgres do
        %{code: :undefined_table} -> {:error, :guard_unavailable}
        _ -> {:error, error}
      end

    error ->
      {:error, error}
  end
end
