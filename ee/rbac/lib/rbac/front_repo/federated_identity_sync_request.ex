defmodule Rbac.FrontRepo.FederatedIdentitySyncRequest do
  @moduledoc """
  Read-only view of the Keycloak federated-identity sync outbox.

  guard owns this table: it enqueues the rows, drains them, and dead-letters
  the ones that never succeed. rbac only needs to know whether a sync is still
  outstanding for an identity, because while one is, the losers' identities may
  still be attached in Keycloak and pushing would attach the same identity to
  two Keycloak users (see `pending?/2`).
  """

  use Ecto.Schema

  import Ecto.Query

  alias Rbac.FrontRepo

  # Rows at or past this many attempts are dead-lettered: guard stops retrying
  # them, so they must stop gating pushes here too or the claiming user is
  # locked out of this provider forever. Must match @max_attempts in
  # guard/lib/guard/front_repo/federated_identity_sync_request.ex - guard
  # writes these rows and rbac reads them.
  @max_attempts 20

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

  @spec max_attempts() :: pos_integer()
  def max_attempts, do: @max_attempts
end
