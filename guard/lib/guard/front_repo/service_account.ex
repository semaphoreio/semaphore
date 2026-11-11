defmodule Guard.FrontRepo.ServiceAccount do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{
          id: String.t(),
          description: String.t(),
          creator_id: String.t(),
          owner_id: String.t() | nil,
          owner_set_at: DateTime.t() | nil,
          user: Guard.FrontRepo.User.t() | nil
        }

  schema "service_accounts" do
    field(:description, :string)
    field(:creator_id, :binary_id)
    # The member the account acts for. `creator_id` records who made it and never moves.
    field(:owner_id, :binary_id)
    # Set whenever an owner is decided, including to nobody. An account whose owner went
    # away keeps it, which is what stops the creator being read as a standing fallback.
    field(:owner_set_at, :utc_datetime)

    # The id field itself is the foreign key to user
    belongs_to(:user, Guard.FrontRepo.User, foreign_key: :id, define_field: false)
  end

  @doc """
  Changeset for creating a new service account.
  """
  def changeset(service_account, attrs) do
    service_account
    |> cast(attrs, [:description, :id, :creator_id, :owner_id, :owner_set_at])
    |> validate_required([:id, :creator_id])
    |> validate_length(:description,
      max: 500,
      message: "Description cannot exceed 500 characters"
    )
    |> foreign_key_constraint(:id, name: :service_accounts_id_fkey)
    |> foreign_key_constraint(:creator_id, name: :service_accounts_creator_id_fkey)
    |> foreign_key_constraint(:owner_id, name: :service_accounts_owner_id_fkey)
    |> unique_constraint(:id, name: :service_accounts_pkey)
  end

  @doc """
  Changeset for moving the account to another owner, or to none.

  Deciding on an owner is recorded either way, so a later pass can tell an account that
  was left without one from an account that was never given one.
  """
  def owner_changeset(service_account, attrs) do
    service_account
    |> cast(attrs, [:owner_id])
    |> put_change(:owner_set_at, DateTime.utc_now() |> DateTime.truncate(:second))
    |> foreign_key_constraint(:owner_id, name: :service_accounts_owner_id_fkey)
  end

  @doc """
  Changeset for updating an existing service account.
  Only allows updating the description field.
  """
  def update_changeset(service_account, attrs) do
    service_account
    |> cast(attrs, [:description])
    |> validate_length(:description,
      max: 500,
      message: "Description cannot exceed 500 characters"
    )
  end
end
