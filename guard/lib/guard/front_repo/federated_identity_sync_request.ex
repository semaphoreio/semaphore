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

  import Ecto.Query

  alias Guard.FrontRepo

  @base_retry_seconds 60
  @max_retry_seconds 3600
  # While leased, a row is invisible to other drainers; must exceed the worst
  # case processing time of a single row (a few Keycloak calls with retries).
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
      next_attempt_at: now()
    }
    |> FrontRepo.insert!()
  end

  @spec pending?(String.t(), String.t()) :: boolean()
  def pending?(repo_host, uid) do
    from(r in __MODULE__, where: r.repo_host == ^repo_host and r.uid == ^uid)
    |> FrontRepo.exists?()
  end

  @spec pending_count() :: non_neg_integer()
  def pending_count do
    FrontRepo.aggregate(__MODULE__, :count, :id)
  end

  @spec complete(t() | nil) :: :ok
  def complete(nil), do: :ok

  def complete(%__MODULE__{id: id}) do
    from(r in __MODULE__, where: r.id == ^id) |> FrontRepo.delete_all()
    :ok
  end

  @spec record_failure(t() | nil, String.t()) :: :ok
  def record_failure(nil, _error), do: :ok

  def record_failure(%__MODULE__{id: id, attempts: attempts}, error) do
    attempts = attempts + 1
    retry_at = DateTime.add(now(), retry_delay_seconds(attempts), :second)

    from(r in __MODULE__, where: r.id == ^id)
    |> FrontRepo.update_all(
      set: [
        attempts: attempts,
        last_error: String.slice(error, 0, @max_error_length),
        next_attempt_at: retry_at,
        updated_at: now()
      ]
    )

    :ok
  end

  @doc """
  Atomically leases a batch of due rows: pushes their `next_attempt_at` into
  the future so concurrent drainers skip them, and returns the leased rows.
  The lock is held only for this single statement — never across the
  Keycloak calls that process the rows.
  """
  @spec lease_due(pos_integer()) :: [t()]
  def lease_due(limit) do
    now = now()
    lease_until = DateTime.add(now, @lease_seconds, :second)

    due =
      from(r in __MODULE__,
        where: r.next_attempt_at <= ^now,
        order_by: [asc: r.inserted_at],
        limit: ^limit,
        lock: "FOR UPDATE SKIP LOCKED",
        select: r.id
      )

    {_count, rows} =
      from(r in __MODULE__, where: r.id in subquery(due), select: r)
      |> FrontRepo.update_all(set: [next_attempt_at: lease_until, updated_at: now])

    rows
  end

  defp retry_delay_seconds(attempts) do
    min(@base_retry_seconds * Integer.pow(2, min(attempts, 6)), @max_retry_seconds)
  end

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
end
