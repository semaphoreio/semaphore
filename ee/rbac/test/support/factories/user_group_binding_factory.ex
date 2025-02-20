defmodule Support.Factories.UserGroupBinding do
  def insert(options \\ []) do
    %Rbac.Repo.UserGroupBinding{
      group_id: get_group_id(options[:group_id]),
      user_id: get_user_id(options[:user_id])
    }
    |> Rbac.Repo.insert()
  end

  defp get_group_id(nil) do
    {:ok, group} = Support.Factories.Group.insert()
    group.id
  end

  defp get_group_id(group_id), do: group_id

  defp get_user_id(nil) do
    {:ok, user} = Support.Factories.RbacUser.insert()
    user.id
  end

  defp get_user_id(user_id), do: user_id
end
