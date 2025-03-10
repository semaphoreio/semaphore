defmodule Rbac.Repo.SamlJitUser do
  use Rbac.Repo.Schema
  alias Rbac.Repo

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

  # def new(integration, payload) do
  #   %__MODULE__{
  #     integration_id: integration.id,
  #     org_id: integration.org_id,
  #     attributes: payload,
  #     email: email_from_payload(payload),
  #     state: :pending
  #   }
  # end

  def changeset(user, params \\ %{}) do
    user
    |> cast(params, @updatable_fields)
    |> validate_required(@required_fields)
  end

  def connect_user(saml_jit_user, user_id) do
    changeset(saml_jit_user, %{user_id: user_id}) |> Repo.update()
  end
end
