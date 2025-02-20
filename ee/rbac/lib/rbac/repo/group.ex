defmodule Rbac.Repo.Group do
  use Rbac.Repo.Schema
  alias Rbac.Repo.Subject

  @primary_key false

  schema "groups" do
    belongs_to(:subject, Subject, foreign_key: :id, primary_key: true)
    field(:org_id, :binary_id)
    field(:creator_id, :binary_id)
    field(:description, :string)
  end

  def changeset(group, params \\ %{}) do
    group
    |> cast(params, [:id, :org_id, :creator_id, :description])
    |> validate_required([:id, :org_id, :creator_id, :description])
    |> foreign_key_constraint(:id)
  end
end
