defmodule Support.Factories.RepoToRoleMapping do
  alias Rbac.Repo.RepoToRoleMapping
  alias Ecto.UUID

  @doc """
    Expected arg options:
    - org_id (organization which owns the mapper)
    - admin_role_id (id of the role which will be assigned to users that have admin access to the repo)
    - push_role_id (id of the role which will be assigned to users that have push access to the repo)
    - pull_role_id (id of the role which will be assigned to users that have pull access to the repo)

    All of these parameters are optional. If role id are not given, new roles will be created and used.
    If org_id is not given, new one will be generated
  """
  def insert(options \\ []) do
    %RepoToRoleMapping{
      org_id: get_org_id(options[:org_id]),
      admin_access_role_id: get_role_id(options[:admin_role_id]),
      push_access_role_id: get_role_id(options[:push_role_id]),
      pull_access_role_id: get_role_id(options[:pull_role_id])
    }
    |> Rbac.Repo.insert(on_conflict: :replace_all, conflict_target: :org_id)
  end

  defp get_org_id(nil), do: UUID.generate()
  defp get_org_id(org_id), do: org_id

  defp get_role_id(nil) do
    {:ok, role} = Support.Factories.RbacRole.insert()
    Map.get(role, :id)
  end

  defp get_role_id(role_id), do: role_id
end
