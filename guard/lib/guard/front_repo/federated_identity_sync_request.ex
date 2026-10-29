defmodule Guard.FrontRepo.FederatedIdentitySyncRequest do
  @moduledoc """
  Durable outbox row for a pending Keycloak federated-identity sync.

  Inserted in the same database transaction that releases the losing
  repo_host_accounts rows of a claim, so a committed claim always leaves a
  persistent record of the Keycloak work it requires. A row is deleted only
  when its sync fully succeeds; failed or interrupted syncs are retried by
  `Guard.FederatedIdentitySyncDrainer` with exponential backoff.

  While a row is pending for a (repo_host, uid) pair, pushes of that identity
  from other code paths must be skipped (see `pending?/2`) — the losers'
  identities may still be attached in Keycloak, and pushing would attach the
  same identity to two Keycloak users.
  """

  use Ecto.Schema

  require Logger

  import Ecto.Query

  alias Guard.FrontRepo

  @base_retry_seconds 60
  @max_retry_seconds 3600
  # Attempts after which a row is dead-lettered: the drainer stops retrying it
  # and it stops gating identity pushes. With the backoff above this is a day
  # or so of retries, long past the point where a failure is still plausibly
  # transient.
  @max_attempts 20
  @dead_letter_metric "guard.federated_identity_sync.dead_letter"
  # While leased, a row is invisible to other drainers. The holder renews it
  # before each Keycloak step (see renew_lease/1), so this only has to exceed
  # the worst case of one step with its retries.
  @lease_seconds 300
  @max_error_length 500

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "federated_identity_sync_requests" do
    field(:repo_host, :string)
    field(:uid, :string)
    field(:claiming_user_id, :binary_id)
    field(:released_user_ids, {:array, :binary_id}, default: [])
    field(:login, :string)
    field(:attempts, :integer, default: 0)
    field(:last_error, :string)
    field(:next_attempt_at, :utc_datetime)

    timestamps(type: :utc_datetime)
  end

  @spec enqueue(Guard.FrontRepo.RepoHostAccount.t(), [String.t()]) :: t()
  def enqueue(account, released_user_ids) do
    %__MODULE__{
      repo_host: account.repo_host,
      uid: account.github_uid,
      claiming_user_id: account.user_id,
      released_user_ids: released_user_ids,
      login: account.login,
      # The insert is the in-process sync's lease: it starts on this row
      # immediately, and a due-now row would let the next drainer tick run the
      # same Keycloak move alongside it. The drainer only sees the row once
      # that task stops renewing.
      next_attempt_at: DateTime.add(now(), @lease_seconds, :second)
    }
    |> FrontRepo.insert!()
  end

  @doc """
  True while a claim for this identity still has Keycloak work outstanding.

  Dead-lettered rows are excluded. They still describe unfinished work, but a
  row that will never be retried must not gate identity pushes forever: doing
  so leaves the claiming user unable to log in through this provider, with no
  path to recovery. The trade is deliberate - see `record_failure/2`.
  """
  @spec pending?(String.t(), String.t()) :: boolean()
  def pending?(repo_host, uid) do
    from(r in __MODULE__,
      where: r.repo_host == ^repo_host and r.uid == ^uid,
      where: r.attempts < @max_attempts
    )
    |> FrontRepo.exists?()
  end

  @doc """
  Rows still awaiting a successful sync, excluding dead-lettered ones.
  """
  @spec pending_count() :: non_neg_integer()
  def pending_count do
    from(r in __MODULE__, where: r.attempts < @max_attempts)
    |> FrontRepo.aggregate(:count, :id)
  end

  @doc """
  Rows that exhausted their attempts. They are kept for investigation: each
  one is a claim whose Keycloak state was never reconciled.
  """
  @spec dead_letter_count() :: non_neg_integer()
  def dead_letter_count do
    from(r in __MODULE__, where: r.attempts >= @max_attempts)
    |> FrontRepo.aggregate(:count, :id)
  end

  @spec max_attempts() :: pos_integer()
  def max_attempts, do: @max_attempts

  @spec complete(t() | nil) :: :ok
  def complete(nil), do: :ok

  def complete(%__MODULE__{id: id}) do
    from(r in __MODULE__, where: r.id == ^id) |> FrontRepo.delete_all()
    :ok
  end

  @spec record_failure(t() | nil, String.t()) :: :ok
  def record_failure(nil, _error), do: :ok

  def record_failure(%__MODULE__{} = request, error) do
    now = now()
    # Under the lease nobody else writes attempts, so the stored value is ours.
    retry_at = DateTime.add(now, retry_delay_seconds(request.attempts + 1), :second)

    {_count, attempts} =
      leased_by(request)
      |> select([r], r.attempts)
      |> FrontRepo.update_all(
        inc: [attempts: 1],
        set: [
          last_error: String.slice(error, 0, @max_error_length),
          next_attempt_at: retry_at,
          updated_at: now
        ]
      )

    case attempts do
      [@max_attempts] -> dead_letter(request, error)
      [_] -> :ok
      [] -> log_lease_lost(request)
    end

    :ok
  end

  @doc """
  Extends the lease this caller holds on `request`, returning the row with the
  new lease, or `:lost` when another run took the row over or it is gone.

  A row's processing time grows with its losers, so the holder renews before
  each Keycloak step instead of sizing one lease for the whole row.
  """
  @spec renew_lease(t() | nil) :: {:ok, t() | nil} | :lost
  def renew_lease(nil), do: {:ok, nil}

  def renew_lease(%__MODULE__{} = request) do
    now = now()

    {_count, rows} =
      leased_by(request)
      |> select([r], r)
      |> FrontRepo.update_all(
        set: [next_attempt_at: DateTime.add(now, @lease_seconds, :second), updated_at: now]
      )

    case rows do
      [row] -> {:ok, row}
      [] -> :lost
    end
  end

  # The lease is next_attempt_at itself: whoever last moved it holds the row.
  # A run that lost it matches nothing, so it cannot overwrite the new holder.
  defp leased_by(%__MODULE__{id: id, next_attempt_at: held}) do
    from(r in __MODULE__, where: r.id == ^id and r.next_attempt_at == ^held)
  end

  defp log_lease_lost(request) do
    Logger.info(
      "[FederatedIdentitySync] Sync request #{request.id} is no longer leased by this run; " <>
        "leaving it to its current holder"
    )
  end

  @doc """
  Ids of rows whose next attempt is due, oldest first.

  These are candidates, not a claim: a row may be leased by another drainer
  before this caller gets to it. Lease each one with `lease/1` immediately
  before processing it, and skip the ones that come back `nil`.
  """
  @spec due_ids(pos_integer()) :: [String.t()]
  def due_ids(limit) do
    from(r in __MODULE__,
      where: r.next_attempt_at <= ^now(),
      where: r.attempts < @max_attempts,
      order_by: [asc: r.inserted_at],
      limit: ^limit,
      select: r.id
    )
    |> FrontRepo.all()
  end

  @doc """
  Leases one due row, returning it, or `nil` when it is no longer due.

  The lease is taken per row rather than per batch: a batch is processed
  serially, so a single lease covering all of it expires under the rows still
  waiting their turn, and another drainer picks them up while this one is
  still working. Leasing here means the window only has to cover one row.

  `next_attempt_at <= now` in the WHERE clause is what makes this a claim.
  Concurrent updates serialize on the row lock, and the loser re-evaluates
  the condition against the winner's committed row, finds the lease in the
  future and matches nothing. The statement holds the lock on its own — never
  across the Keycloak calls that follow.
  """
  @spec lease(String.t()) :: t() | nil
  def lease(id) do
    now = now()
    lease_until = DateTime.add(now, @lease_seconds, :second)

    {_count, rows} =
      from(r in __MODULE__,
        where: r.id == ^id and r.next_attempt_at <= ^now,
        where: r.attempts < @max_attempts,
        select: r
      )
      |> FrontRepo.update_all(set: [next_attempt_at: lease_until, updated_at: now])

    case rows do
      [row] -> row
      _ -> nil
    end
  end

  # Crossing the attempt ceiling. The row stays in the table - it records a
  # claim whose Keycloak side was never reconciled, and that needs a human -
  # but it stops being retried and stops gating identity pushes.
  #
  # Releasing the gate is safe because the push is guarded at the API
  # boundary: Guard.Api.OIDC.set_federated_identity/3 asks Keycloak who holds
  # the identity and refuses with {:error, :held_by_other} rather than posting
  # a duplicate. Holding the gate instead would leave the claiming user unable
  # to sign in through this provider, permanently and with no recovery path.
  #
  # Do not restore the gate without also removing that check. Keycloak 25.x
  # enforces federated-identity uniqueness only WITHIN a single user, so
  # nothing below this layer stops two users holding the same (provider, uid).
  defp dead_letter(%__MODULE__{} = request, error) do
    Logger.error(
      "[FederatedIdentitySync] Dead-lettering sync request #{request.id} after " <>
        "#{@max_attempts} attempts: #{request.repo_host} uid #{request.uid} claimed by " <>
        "user #{request.claiming_user_id}, released #{inspect(request.released_user_ids)}, " <>
        "last error: #{error}. Keycloak was never reconciled for this claim and the " <>
        "identity push is no longer gated."
    )

    Watchman.increment({@dead_letter_metric, [request.repo_host]})
  end

  defp retry_delay_seconds(attempts) do
    min(@base_retry_seconds * Integer.pow(2, min(attempts, 6)), @max_retry_seconds)
  end

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
end
