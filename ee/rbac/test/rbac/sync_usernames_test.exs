defmodule Rbac.SyncUsernamesTest do
  use Rbac.RepoCase

  alias Rbac.Repo
  alias Rbac.Repo.Collaborator

  setup do
    Support.Rbac.Store.clear!()

    :ok
  end

  describe ".propagate/1" do
    test "updates stale github_username on collaborator rows that match by github_uid" do
      user_id = Ecto.UUID.generate()
      uid = "184065"
      project_id = Ecto.UUID.generate()

      {:ok, _} = Support.Factories.FrontUser.insert(id: user_id, email: "user@example.com")
      {:ok, _} = Support.Factories.RbacUser.insert(user_id, "User", "user@example.com")

      {:ok, _} =
        Support.Members.insert_repo_host_account(
          login: "user-renamed",
          name: "user-renamed",
          github_uid: uid,
          user_id: user_id,
          repo_host: "github"
        )

      {:ok, stale} =
        Support.Collaborators.insert(
          project_id: project_id,
          github_username: "user-old",
          github_uid: uid
        )

      assert {:ok, 1} = Rbac.SyncUsernames.propagate(user_id)

      assert %Collaborator{github_username: "user-renamed"} = Repo.get!(Collaborator, stale.id)
    end

    test "is a no-op when the stored username already matches" do
      user_id = Ecto.UUID.generate()
      uid = "184065"
      project_id = Ecto.UUID.generate()

      {:ok, _} = Support.Factories.FrontUser.insert(id: user_id, email: "user@example.com")
      {:ok, _} = Support.Factories.RbacUser.insert(user_id, "User", "user@example.com")

      {:ok, _} =
        Support.Members.insert_repo_host_account(
          login: "user-current",
          name: "user-current",
          github_uid: uid,
          user_id: user_id,
          repo_host: "github"
        )

      {:ok, untouched} =
        Support.Collaborators.insert(
          project_id: project_id,
          github_username: "user-current",
          github_uid: uid
        )

      assert {:ok, 0} = Rbac.SyncUsernames.propagate(user_id)

      assert %Collaborator{github_username: "user-current"} =
               Repo.get!(Collaborator, untouched.id)
    end

    test "does not touch collaborator rows that belong to a different uid" do
      user_id = Ecto.UUID.generate()
      uid = "184065"
      other_uid = "999999"
      project_id = Ecto.UUID.generate()

      {:ok, _} = Support.Factories.FrontUser.insert(id: user_id, email: "user@example.com")
      {:ok, _} = Support.Factories.RbacUser.insert(user_id, "User", "user@example.com")

      {:ok, _} =
        Support.Members.insert_repo_host_account(
          login: "user-renamed",
          name: "user-renamed",
          github_uid: uid,
          user_id: user_id,
          repo_host: "github"
        )

      {:ok, other} =
        Support.Collaborators.insert(
          project_id: project_id,
          github_username: "someone-else",
          github_uid: other_uid
        )

      assert {:ok, 0} = Rbac.SyncUsernames.propagate(user_id)

      assert %Collaborator{github_username: "someone-else"} = Repo.get!(Collaborator, other.id)
    end

    test "returns {:error, :user_not_found} when the user does not exist" do
      assert {:error, :user_not_found} =
               Rbac.SyncUsernames.propagate(Ecto.UUID.generate())
    end
  end
end
