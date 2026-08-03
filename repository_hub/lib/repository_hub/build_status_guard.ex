defmodule RepositoryHub.BuildStatusGuard do
  @moduledoc """
  Cross-instance ordering guard for commit status delivery.

  One row per (repository_id, commit_sha, context, source_id) records the last
  delivered state and an in-flight lease. `claim/1` is a single atomic upsert:
  it acquires the lease unless another delivery currently holds it (`:busy`)
  or a PENDING status arrives after a terminal state was already delivered
  (`:skip`). The provider call happens outside any transaction; `finalize/2`
  and `release/2` complete or abandon the lease, using the claim timestamp as
  a fencing token so an expired claimant cannot overwrite newer state.

  Requests without a source_id are not guarded. If the guard table does not
  exist yet (migration not run), operations return
  `{:error, :guard_unavailable}` so callers can deliver unguarded. A malformed
  repository_id returns `{:error, :invalid_key}` so the caller's own request
  validation can reject it instead of the guard crashing.
  """

  alias RepositoryHub.Repo
  alias InternalApi.Repository.CreateBuildStatusRequest

  require Logger

  @terminal_states ~w(SUCCESS FAILURE STOPPED)
  @lease_seconds 90

  @claim_sql """
  INSERT INTO build_status_guards AS g
    (repository_id, commit_sha, context, source_id, claimed_at, updated_at)
  VALUES ($1, $2, $3, $4, now(), now())
  ON CONFLICT (repository_id, commit_sha, context, source_id) DO UPDATE
  SET claimed_at = now(), updated_at = now()
  WHERE (g.claimed_at IS NULL OR g.claimed_at < now() - interval '#{@lease_seconds} seconds')
    AND NOT (COALESCE(g.last_state, '') = ANY('{#{Enum.join(@terminal_states, ",")}}') AND $5)
  RETURNING g.claimed_at
  """

  @classify_sql """
  SELECT last_state, COALESCE(claimed_at >= now() - interval '#{@lease_seconds} seconds', false)
  FROM build_status_guards
  WHERE repository_id = $1 AND commit_sha = $2 AND context = $3 AND source_id = $4
  """

  @finalize_sql """
  UPDATE build_status_guards
  SET last_state = $5, claimed_at = NULL, updated_at = now()
  WHERE repository_id = $1 AND commit_sha = $2 AND context = $3 AND source_id = $4
    AND claimed_at = $6
  """

  @release_sql """
  UPDATE build_status_guards
  SET claimed_at = NULL, updated_at = now()
  WHERE repository_id = $1 AND commit_sha = $2 AND context = $3 AND source_id = $4
    AND claimed_at = $5
  """

  @doc """
  Acquires the delivery lease for the request's check.

  Returns `{:ok, fence}` when the caller may deliver, `:skip` when the status
  is a stale PENDING that must not be delivered, `:busy` when another delivery
  for the same check is in flight, or an error tuple.
  """
  @spec claim(CreateBuildStatusRequest.t()) ::
          {:ok, DateTime.t()} | :skip | :busy | {:error, term}
  def claim(request) do
    pending? = request.status == :PENDING

    case key_params(request) do
      {:ok, params} ->
        case query(@claim_sql, params ++ [pending?]) do
          {:ok, %{rows: [[fence]]}} -> {:ok, fence}
          {:ok, %{rows: []}} -> classify(params, pending?)
          {:error, _} = error -> error
        end

      :error ->
        {:error, :invalid_key}
    end
  end

  @doc """
  Records the delivered state and clears the lease. A stale fence is a no-op.
  """
  @spec finalize(CreateBuildStatusRequest.t(), DateTime.t()) :: :ok | {:error, term}
  def finalize(request, fence) do
    case key_params(request) do
      {:ok, params} ->
        state = Atom.to_string(request.status)

        case query(@finalize_sql, params ++ [state, fence]) do
          {:ok, %{num_rows: 0}} ->
            Logger.warning("[BuildStatusGuard] stale fence on finalize, state not recorded")
            :ok

          {:ok, _} ->
            :ok

          {:error, _} = error ->
            error
        end

      :error ->
        :ok
    end
  end

  @doc """
  Clears the lease without recording a delivery (the send failed). A stale
  fence is a no-op.
  """
  @spec release(CreateBuildStatusRequest.t(), DateTime.t()) :: :ok | {:error, term}
  def release(request, fence) do
    case key_params(request) do
      {:ok, params} ->
        case query(@release_sql, params ++ [fence]) do
          {:ok, _} -> :ok
          {:error, _} = error -> error
        end

      :error ->
        :ok
    end
  end

  @doc false
  def terminal_states, do: @terminal_states

  @doc false
  def lease_seconds, do: @lease_seconds

  defp classify(params, pending?) do
    case query(@classify_sql, params) do
      {:ok, %{rows: [[last_state, live?]]}} ->
        cond do
          pending? && last_state in @terminal_states -> :skip
          live? -> :busy
          true -> :busy
        end

      {:ok, %{rows: []}} ->
        :busy

      {:error, _} = error ->
        error
    end
  end

  defp key_params(request) do
    case Ecto.UUID.dump(request.repository_id) do
      {:ok, uuid} -> {:ok, [uuid, request.commit_sha, request.context, request.source_id]}
      :error -> :error
    end
  end

  defp query(sql, params) do
    case Repo.query(sql, params) do
      {:ok, _} = ok ->
        ok

      {:error, %Postgrex.Error{postgres: %{code: :undefined_table}}} ->
        {:error, :guard_unavailable}

      {:error, _} = error ->
        error
    end
  rescue
    error -> {:error, error}
  end
end
