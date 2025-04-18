defmodule Rbac.Repo.GroupManagementRequest.Test do
  use Rbac.RepoCase, async: true

  alias Rbac.Repo.GroupManagementRequest

  describe "create_new_request/4" do
    test "Validate all of the entries are rolled back if the last one is invalid" do
      group_id = Ecto.UUID.generate()
      user_ids = [Ecto.UUID.generate(), "invalid-uuid"]
      {:error, _} = GroupManagementRequest.create_new_request(user_ids, group_id, :add_user, nil)
      refute GroupManagementRequest |> Rbac.Repo.exists?()
    end
  end
end
