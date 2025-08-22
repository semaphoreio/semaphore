defmodule Guard.FrontRepo.ServiceAccount do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{
          id: String.t(),
          description: String.t(),
          creator_id: String.t(),
          user: Guard.FrontRepo.User.t() | nil
        }

  schema "service_accounts" do
    field(:description, :string)
    field(:creator_id, :binary_id)

    # The id field itself is the foreign key to user
    belongs_to(:user, Guard.FrontRepo.User, foreign_key: :id, define_field: false)
  end

  @doc """
  Changeset for creating a new service account.
  """
  def changeset(service_account, attrs) do
    service_account
    |> cast(attrs, [:description, :id, :creator_id])
    |> validate_required([:id, :creator_id])
    |> validate_length(:description,
      max: 500,
      message: "Description cannot exceed 500 characters"
    )
    |> foreign_key_constraint(:id, name: :service_accounts_id_fkey)
    |> foreign_key_constraint(:creator_id, name: :service_accounts_creator_id_fkey)
    |> unique_constraint(:id, name: :service_accounts_pkey)
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
