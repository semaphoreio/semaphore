defmodule Rbac.Repo.Scope do
  use Rbac.Repo.Schema
  import Ecto.Query, only: [where: 3, select: 3]

  schema "scopes" do
    field(:scope_name, :string)
  end

  def changeset(scope, params \\ %{}) do
    scope
    |> cast(params, [:scope_name])
    |> validate_required(:scope_name)
    |> unique_constraint(:scope_name)
  end

  @spec get_scope_by_name(String.t()) :: %__MODULE__{} | nil
  def get_scope_by_name(scope_name) do
    __MODULE__ |> where([s], s.scope_name == ^scope_name) |> Rbac.Repo.one()
  end

  @spec get_scope_by_id(EctolUUID.t()) :: %__MODULE__{} | nil
  def get_scope_by_id(id) do
    __MODULE__ |> where([s], s.id == ^id) |> Rbac.Repo.one()
  end

  def scope_name_to_id(nil), do: nil

  def scope_name_to_id(scope_name) do
    __MODULE__
    |> where([s], s.scope_name == ^scope_name)
    |> select([s], s.id)
    |> Rbac.Repo.one()
  end
end
