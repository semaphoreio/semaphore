defmodule Guard.FrontRepo.User do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Guard.FrontRepo

  # Max number of retries for token generation,
  # since the generated token can be invalid.
  @max_token_retries 10

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

    field(:creation_source, Ecto.Enum, values: [:okta, :saml_jit, :service_account])
    field(:single_org_user, :boolean)
    field(:org_id, :binary_id)
    field(:idempotency_token, :string)

    # blocked for abuse
    field(:blocked_at, :utc_datetime)

    # deactivated as part of Okta integration
    field(:deactivated, :boolean)
    field(:deactivated_at, :utc_datetime)

    # Service account relationship
    has_one(:service_account, Guard.FrontRepo.ServiceAccount, foreign_key: :id)

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
    |> validate_length(:name, max: 255, message: "Name cannot exceed 255 characters")
    |> validate_format(:email, ~r/^([\w\.%\+\-]+)@([\w\-]+\.)+([\w]{2,})$/i,
      message: "is not a valid email"
    )
    |> unique_constraint(:email, name: :index_users_on_email)
    |> unique_constraint(:authentication_token, name: :index_users_on_authentication_token)
    |> unique_constraint(:idempotency_token, name: "users_idempotency_token_index")
  end

  def active_user_by_token(token) do
    case FrontRepo.one(
           from(u in FrontRepo.User,
             where:
               u.authentication_token == ^token and is_nil(u.blocked_at) and
                 (is_nil(u.deactivated) or u.deactivated == false)
           )
           # Preload service account to avoid N+1 queries when checking if user is a service account
           |> preload(:service_account)
         ) do
      nil -> {:error, :not_found}
      user -> {:ok, user}
    end
  end

  def active_user_by_id(id) do
    case FrontRepo.one(
           from(u in FrontRepo.User,
             where:
               u.id == ^id and is_nil(u.blocked_at) and
                 (is_nil(u.deactivated) or u.deactivated == false)
           )
         ) do
      nil ->
        {:error, :not_found}

      user ->
        {:ok, user}
    end
  end

  def active_user_by_email(email) do
    case FrontRepo.one(
           from(u in FrontRepo.User,
             where:
               u.email == ^email and is_nil(u.blocked_at) and
                 (is_nil(u.deactivated) or u.deactivated == false)
           )
         ) do
      nil ->
        {:error, :not_found}

      user ->
        {:ok, user}
    end
  end

  def active_user_by_id_and_salt(id, salt) do
    case active_user_by_id(id) do
      {:error, :not_found} ->
        {:error, :not_found}

      {:ok, user} ->
        if Plug.Crypto.secure_compare(salt, user.salt) do
          {:ok, user}
        else
          {:error, :not_found}
        end
    end
  end

  def blocked_user_by_id(id) do
    case FrontRepo.one(
           from(u in FrontRepo.User,
             where: u.id == ^id and not is_nil(u.blocked_at)
           )
         ) do
      nil ->
        {:error, :not_found}

      user ->
        {:ok, user}
    end
  end

  def block_user(user) do
    user
    |> changeset(%{blocked_at: DateTime.utc_now()})
    |> FrontRepo.update()
  end

  def unblock_user(user) do
    user
    |> changeset(%{blocked_at: nil})
    |> FrontRepo.update()
  end

  def set_remember_timestamp(user) do
    user
    |> changeset(%{remember_created_at: DateTime.utc_now()})
    |> FrontRepo.update()
  end

  def record_visit(user_id) do
    query =
      from(u in FrontRepo.User,
        where: u.id == ^user_id,
        where: is_nil(u.visited_at) or fragment("visited_at < CURRENT_DATE"),
        update: [set: [visited_at: fragment("NOW()")]]
      )

    FrontRepo.update_all(query, [])
    :ok
  end

  def reset_auth_token(user) do
    case generate_authentication_token() do
      {:ok, {plain_token, hash_token}} ->
        update_user_authentication_token(user, hash_token)
        {:ok, plain_token}

      {:error, _message} = error ->
        error
    end
  end

  defp update_user_authentication_token(user, token) do
    user
    |> changeset(%{authentication_token: token})
    |> FrontRepo.update()
  end

  defp generate_authentication_token, do: generate_authentication_token(0)

  # Generates a new authentication token for a user.
  # There is a maximum number of retries to generate a token
  # because of the possibility of generating a token that is already in use or invalid,
  # even if the probability is low.
  defp generate_authentication_token(@max_token_retries) do
    {:error, "Could not generate authentication token."}
  end

  defp generate_authentication_token(retries) do
    token = Guard.AuthenticationToken.new(user_friendly: true)
    hash_token = Guard.AuthenticationToken.hash_token(token)

    if invalid_token?(hash_token) do
      generate_authentication_token(retries + 1)
    else
      {:ok, {token, hash_token}}
    end
  end

  def invalid_token?(token) do
    invalid_token_string = String.starts_with?(token, "-")

    exists_by_token =
      case active_user_by_token(token) do
        {:ok, _user} -> true
        {:error, _} -> false
      end

    invalid_token_string or exists_by_token
  end

  @doc """
  Returns true if the user is a service account.
  """
  def service_account?(%__MODULE__{creation_source: :service_account}), do: true
  def service_account?(_user), do: false

  @doc """
  Changeset for creating a service account user.
  This validates the specific requirements for service account users.
  """
  def service_account_changeset(user, params) do
    base_domain = Application.fetch_env!(:guard, :base_domain)
    escaped_domain = Regex.escape(base_domain)

    user
    |> cast(params, [
      :email,
      :name,
      :company,
      :authentication_token,
      :salt,
      :creation_source,
      :single_org_user,
      :org_id,
      :idempotency_token
    ])
    |> validate_required([:email, :name, :creation_source, :org_id])
    |> validate_length(:name, max: 255, message: "Name cannot exceed 255 characters")
    |> validate_inclusion(:creation_source, [:service_account])
    |> put_change(:single_org_user, true)
    |> validate_format(:email, ~r/^[\w\-\.]+@service-accounts\.[\w\-\.]+\.#{escaped_domain}$/i,
      message:
        "Service account email must follow the format: name@service-accounts.organization.#{base_domain}"
    )
    |> unique_constraint(:email, name: :index_users_on_email)
    |> unique_constraint(:authentication_token, name: :index_users_on_authentication_token)
    |> unique_constraint(:idempotency_token, name: "users_idempotency_token_index")
  end

  @doc """
  Generates a synthetic email for a service account.
  """
  def generate_service_account_email(service_account_name, organization_name) do
    # Sanitize names to ensure valid email format
    sanitized_sa_name = sanitize_email_part(service_account_name)
    sanitized_org_name = sanitize_email_part(organization_name)
    base_domain = Application.fetch_env!(:guard, :base_domain)

    "#{sanitized_sa_name}@service-accounts.#{sanitized_org_name}.#{base_domain}"
  end

  defp sanitize_email_part(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\-]/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
  end
end
