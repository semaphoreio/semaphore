defmodule Rbac.FrontRepo.FederatedIdentitySyncRequest do
  @moduledoc """
  Durable outbox row for a pending Keycloak federated-identity sync.

  Inserted in the same database transaction that releases the losing
  repo_host_accounts rows of a claim, so a committed claim always leaves a
  persistent record of the Keycloak work it requires. A row is deleted only
  when its sync fully succeeds; failed or interrupted syncs are retried by
  guard's drainer, which processes this shared table.

  While a row is pending for a (repo_host, uid) pair, pushes of that identity
  from other code paths must be skipped (see `pending?/2`) — the losers'
  identities may still be attached in Keycloak, and pushing would attach the
  same identity to two Keycloak users.
  """

  use Ecto.Schema

  require Logger

  import Ecto.Query

  alias Rbac.FrontRepo

  @base_retry_seconds 60
  @max_retry_seconds 3600
  @max_error_length 500
  # Attempts after which a row is dead-lettered: it stops being retried and
  # stops gating identity pushes. Must match @max_attempts in
  # guard/lib/guard/front_repo/federated_identity_sync_request.ex — the table
  # is shared, and guard's drainer decides what it will still pick up.
  @max_attempts 20
  @dead_letter_metric "rbac.federated_identity_sync.dead_letter"
  # Head start for the in-process sync before guard's drainer may lease the
  # row. Must match @lease_seconds in
  # guard/lib/guard/front_repo/federated_identity_sync_request.ex — rbac has no
  # drainer of its own, so guard leases the rows rbac enqueues.
  @lease_seconds 300

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

  @spec enqueue(Rbac.FrontRepo.RepoHostAccount.t(), [String.t()]) :: t()
  def enqueue(account, released_user_ids) do
    %__MODULE__{
      repo_host: account.repo_host,
      uid: account.github_uid,
      claiming_user_id: account.user_id,
      released_user_ids: released_user_ids,
      login: account.login,
      # One lease ahead, not now: the claim starts an in-process sync for this
      # row immediately, and that task holds no lease. Due-now would let
      # guard's next drainer tick pick up a row already in flight and run the
      # Keycloak move twice.
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

  def record_failure(%__MODULE__{id: id, attempts: attempts} = request, error) do
    attempts = attempts + 1
    retry_at = DateTime.add(now(), retry_delay_seconds(attempts), :second)

    if attempts == @max_attempts, do: dead_letter(request, error)

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

  # Crossing the attempt ceiling. The row stays in the table - it records a
  # claim whose Keycloak side was never reconciled, and that needs a human -
  # but it stops being retried and stops gating identity pushes.
  #
  # Releasing the gate is the lesser of two harms. Holding it means the
  # claiming user can never sign in through this provider again. Releasing it
  # means an identity may be pushed while a losing user still holds it in
  # Keycloak, which Keycloak itself rejects if it enforces uniqueness for the
  # provider. A broken login is certain; the duplicate is not.
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
