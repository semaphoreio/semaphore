defmodule Rbac.Repo.RbacRole do
  require Logger
  use Rbac.Repo.Schema
  alias Rbac.Repo.{Permission, Scope}
  import Ecto.Query, only: [where: 3, preload: 2]

  schema "rbac_roles" do
    field(:name, :string)
    field(:org_id, :binary_id)
    field(:description, :string)
    field(:editable, :boolean)
    belongs_to(:scope, Scope)
    many_to_many(:permissions, Permission, join_through: "role_permission_bindings")

    timestamps()

    many_to_many(:inherited_role, __MODULE__,
      join_through: "role_inheritance",
      join_keys: [inheriting_role_id: :id, inherited_role_id: :id]
    )

    many_to_many(:proj_role_mapping, __MODULE__,
      join_through: "org_role_to_proj_role_mappings",
      join_keys: [org_role_id: :id, proj_role_id: :id]
    )
  end

  def changeset(role, params \\ %{}) do
    role
    |> cast(params, [:name, :org_id, :scope_id, :description, :editable])
    |> validate_required([:name, :org_id, :scope_id])
    |> unique_constraint([:name, :org_id, :scope_id])
  end

  @doc """
    Returns RbacRole struct or nil if role does not exist
  """
  def get_role_by_id(""), do: nil

  # Deprecated, use Rbac.Store.RbacRole.fetch instead
  def get_role_by_id(role_id, org_id \\ nil) do
    __MODULE__
    |> where([r], r.id == ^role_id)
    |> filter_role_by_org(org_id)
    |> preload(:scope)
    |> preload(:permissions)
    |> Rbac.Repo.one()
  end

  def get_role_by_name(name, scope_name, org_id) do
    scope = Scope.get_scope_by_name(scope_name)

    __MODULE__
    |> where([r], r.name == ^name and r.scope_id == ^scope.id and r.org_id == ^org_id)
    |> Rbac.Repo.one()
    |> case do
      nil -> {:error, :not_found}
      role -> {:ok, role}
    end
  end

  @doc """
    Return list of roles belonging to a given org

    Arguments:
    - org_id:         Id of organization whos roles are to be returned.
    - role_scope_id:  Return only roles that are of given scope.
                      If omitted, all the roles will be returned, regardless of their scope.

    NOTE: It is assumed both values are valid uuids, otherwise Ecto will throw an error
  """
  @spec list_roles(String.t(), String.t()) :: list(__MODULE__)
  def list_roles(org_id, role_scope_id \\ nil) do
    __MODULE__
    |> where([r], r.org_id == ^org_id)
    |> filter_role_by_scope(role_scope_id)
    |> preload(:scope)
    |> preload(:permissions)
    |> Rbac.Repo.all()
  end

  ###
  ### Helper functions
  ###

  defp filter_role_by_scope(query, nil), do: query
  defp filter_role_by_scope(query, ""), do: query
  defp filter_role_by_scope(query, scope_id), do: query |> where([r], r.scope_id == ^scope_id)

  defp filter_role_by_org(query, nil), do: query
  defp filter_role_by_org(query, org_id), do: query |> where([r], r.org_id == ^org_id)
end
