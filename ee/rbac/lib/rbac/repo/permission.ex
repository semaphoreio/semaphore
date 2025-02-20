defmodule Rbac.Repo.Permission do
  require Logger
  use Rbac.Repo.Schema
  import Ecto.Query
  alias Rbac.Repo.Scope

  schema "permissions" do
    field(:name, :string)
    field(:description, :string)
    belongs_to(:scope, Scope)
  end

  def changeset(permission, params \\ %{}) do
    permission
    |> cast(params, [:name, :scope_id])
    |> validate_required([:name, :scope_id])
    |> unique_constraint(:name)
    |> foreign_key_constraint(:scope_id)
  end

  def get_permission_id(permission_name) do
    __MODULE__
    |> where([p], p.name == ^permission_name)
    |> select([p], p.id)
    |> Rbac.Repo.one()
  end

  def fetch_permissions(scope_name \\ nil) do
    __MODULE__
    |> join(:inner, [p], s in Scope, on: p.scope_id == s.id)
    |> filter_by_scope(scope_name)
    |> preload(:scope)
    |> Rbac.Repo.all()
  end

  @permissions_yaml_path "./assets/permissions.yaml"
  def insert_default_permissions do
    Logger.info("Inserting default permissions")
    {:ok, permissions} = YamlElixir.read_from_file(@permissions_yaml_path)

    org_permissions =
      Enum.map(permissions["permissions"]["organization"], fn permission ->
        %{
          name: permission["name"],
          scope_id: Rbac.Repo.Scope.get_scope_by_name("org_scope").id,
          description: permission["description"]
        }
      end)

    project_permissions =
      Enum.map(permissions["permissions"]["project"], fn permission ->
        %{
          name: permission["name"],
          scope_id: Rbac.Repo.Scope.get_scope_by_name("project_scope").id,
          description: permission["description"]
        }
      end)

    Rbac.Repo.insert_all(__MODULE__, project_permissions ++ org_permissions,
      on_conflict: {:replace, [:description]},
      conflict_target: :name
    )
  end

  ###
  ### Helper functions
  ###

  defp filter_by_scope(query, "project_scope" = scope),
    do: query |> where([_, s], s.scope_name == ^scope)

  defp filter_by_scope(query, "org_scope" = scope),
    do: query |> where([_, s], s.scope_name == ^scope)

  defp filter_by_scope(query, _) do
    query |> where([_, s], s.scope_name in ["org_scope", "project_scope"])
  end
end
