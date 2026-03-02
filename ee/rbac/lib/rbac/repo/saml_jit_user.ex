defmodule Rbac.Repo.SamlJitUser do
  use Rbac.Repo.Schema
  alias Rbac.Repo
  import Ecto.Query, only: [where: 3]

  @timestamps_opts [type: :utc_datetime]

  @required_fields [
    :org_id,
    :integration_id,
    :attributes,
    :state,
    :email
  ]

  @updatable_fields [
    :attributes,
    :state,
    :email,
    :updated_at,
    :user_id
  ]

  schema "saml_jit_users" do
    belongs_to(:integration, Repo.OktaIntegration)

    field(:org_id, :binary_id)
    field(:attributes, :map)
    field(:state, Ecto.Enum, values: [:pending, :processed])
    field(:user_id, :binary_id)
    field(:email, :string)

    timestamps()
  end

  def create(integration, email, attributes) do
    new(integration, email, attributes)
    |> changeset()
    |> Rbac.Repo.insert()
  end

  def find_by_email(integration, email) do
    __MODULE__
    |> where([u], u.integration_id == ^integration.id and u.email == ^email)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      user -> {:ok, user}
    end
  end

  def find_by_user_id(user_id) do
    __MODULE__
    |> where([u], u.user_id == ^user_id)
    |> Repo.all()
  end

  def delete(%__MODULE__{} = saml_jit_user) do
    Repo.delete(saml_jit_user)
  end

  def connect_user(%__MODULE__{} = saml_jit_user, user_id) do
    changeset(saml_jit_user, %{user_id: user_id}) |> Repo.update()
  end

  def construct_name(%__MODULE__{} = user) do
    name = extract_attribute(user, "firstName") <> " " <> extract_attribute(user, "lastName")

    if String.trim(name) == "" do
      user.email |> String.split("@") |> List.first()
    else
      name
    end
  end

  def mark_as_processed(%__MODULE__{} = user) do
    changeset(user, %{state: :processed}) |> Rbac.Repo.update()
  end

  defp new(integration, email, attributes) do
    %__MODULE__{
      integration_id: integration.id,
      org_id: integration.org_id,
      attributes: attributes,
      email: String.downcase(email),
      state: :pending
    }
  end

  defp changeset(%__MODULE__{} = user, params \\ %{}) do
    user
    |> cast(params, @updatable_fields)
    |> validate_required(@required_fields)
  end

  defp extract_attribute(%__MODULE__{} = user, name) do
    Map.get(user.attributes, name, [""]) |> List.first()
  end
end
