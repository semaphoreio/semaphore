defmodule Support.Factories.SubjectRoleBinding do
  alias Ecto.UUID

  def insert(options \\ []) do
    %Rbac.Repo.SubjectRoleBinding{
      role_id: get_role_id(options[:role_id]),
      org_id: get_org_id(options[:org_id]),
      project_id: options[:project_id],
      subject_id: get_subject_id(options[:subject_id]),
      binding_source: get_binding_source(options[:binding_source])
    }
    |> Rbac.Repo.insert()
  end

  defp get_org_id(nil), do: UUID.generate()
  defp get_org_id(org_id), do: org_id

  defp get_role_id(nil) do
    {:ok, rbac_role} = Support.Factories.RbacRole.insert()
    rbac_role.id
  end

  defp get_role_id(role_id), do: role_id

  defp get_subject_id(nil) do
    {:ok, user} = Support.Factories.RbacUser.insert()

    user.id
  end

  defp get_subject_id(subject_id), do: subject_id

  defp get_binding_source(nil), do: :manually_assigned
  defp get_binding_source(binding_source), do: binding_source
end
