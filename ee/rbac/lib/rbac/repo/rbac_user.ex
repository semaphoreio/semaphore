defmodule Rbac.Repo.RbacUser do
  use Rbac.Repo.Schema
  alias Rbac.Repo.Subject

  @primary_key false

  schema "rbac_users" do
    belongs_to(:subject, Subject, foreign_key: :id, primary_key: true)

    has_many(:oidc_users, Rbac.Repo.OIDCUser,
      references: :id,
      foreign_key: :user_id,
      on_delete: :delete_all
    )

    field(:email, :string)
    field(:name, :string)

    timestamps()
  end

  def changeset(rbac_user, params \\ %{}) do
    rbac_user
    |> cast(params, [:id, :email])
    |> validate_required([:id, :email])
    |> unique_constraint(:email, name: :rbac_users_email_index)
    |> foreign_key_constraint(:id)
  end
end
