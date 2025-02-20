defmodule Rbac.Repo.UserGroupBinding do
  use Rbac.Repo.Schema
  alias Rbac.Repo.{RbacUser, Group}

  import Ecto.Query, only: [where: 3, join: 4, select: 3]

  @primary_key false
  schema "user_group_bindings" do
    belongs_to(:user, RbacUser, primary_key: true)
    belongs_to(:group, Group, primary_key: true)
  end

  @spec fetch_group_members(String.t()) :: [RbacUser.t()]
  def fetch_group_members(group_id) do
    __MODULE__
    |> where([ugb], ugb.group_id == ^group_id)
    |> join(:inner, [ugb], u in assoc(ugb, :user))
    |> select([_, u], u)
    |> Rbac.Repo.all()
  end
end
