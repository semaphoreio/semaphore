defmodule Rbac.FrontRepo.User do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Rbac.FrontRepo

  @type t :: %__MODULE__{
          authentication_token: String.t(),
          blocked_at: DateTime.t(),
          creation_source: String.t(),
          deactivated: boolean(),
          deactivated_at: DateTime.t(),
          email: String.t(),
          id: String.t(),
          company: String.t(),
          idempotency_token: String.t(),
          name: String.t(),
          org_id: String.t(),
          remember_created_at: DateTime.t(),
          salt: String.t(),
          single_org_user: boolean(),
          created_at: DateTime.t(),
          updated_at: DateTime.t(),
          visited_at: DateTime.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "users" do
    field(:email, :string)
    field(:name, :string)
    field(:company, :string)
    field(:authentication_token, :string)
    field(:salt, :string)
    field(:remember_created_at, :utc_datetime)
    field(:visited_at, :utc_datetime)

    field(:creation_source, Ecto.Enum, values: [:okta, :saml_jit])
    field(:single_org_user, :boolean)
    field(:org_id, :binary_id)
    field(:idempotency_token, :string)

    # blocked for abuse
    field(:blocked_at, :utc_datetime)

    # deactivated as part of Okta integration
    field(:deactivated, :boolean)
    field(:deactivated_at, :utc_datetime)

    timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
  end

  def changeset(user, params) do
    user
    |> cast(params, [
      :email,
      :name,
      :company,
      :authentication_token,
      :blocked_at,
      :remember_created_at,
      :salt,
      :creation_source,
      :single_org_user,
      :org_id,
      :idempotency_token,
      :deactivated,
      :deactivated_at,
      :visited_at
    ])
    |> validate_required([:email, :name])
    |> validate_format(:email, ~r/^([\w\.%\+\-]+)@([\w\-]+\.)+([\w]{2,})$/i,
      message: "is not a valid email"
    )
    |> unique_constraint(:email, name: :index_users_on_email)
    |> unique_constraint(:authentication_token, name: :index_users_on_authentication_token)
    |> unique_constraint(:idempotency_token, name: "users_idempotency_token_index")
  end

  def active_user_by_id(id) do
    case FrontRepo.one(
           from(u in FrontRepo.User,
             where: u.id == ^id and is_nil(u.blocked_at)
           )
         ) do
      nil ->
        {:error, :not_found}

      user ->
        {:ok, user}
    end
  end

  def set_remember_timestamp(user) do
    user
    |> changeset(%{remember_created_at: DateTime.utc_now()})
    |> FrontRepo.update()
  end
end
