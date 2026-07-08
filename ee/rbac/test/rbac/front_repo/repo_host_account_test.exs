defmodule Rbac.FrontRepo.RepoHostAccountTest do
  use Rbac.RepoCase, async: true

  alias Rbac.FrontRepo.RepoHostAccount

  defp create_params(overrides) do
    Map.merge(
      %{
        login: "octocat",
        github_uid: "10001",
        repo_host: "github",
        user_id: Ecto.UUID.generate(),
        name: "The Octocat",
        permission_scope: "user:email"
      },
      overrides
    )
  end

  describe "GitHub account uniqueness" do
    test "create/1 rejects a GitHub uid already connected to another user" do
      {:ok, existing} = Support.Members.insert_repo_host_account(github_uid: "10001")

      assert {:error, %Ecto.Changeset{} = changeset} =
               RepoHostAccount.create(create_params(%{github_uid: existing.github_uid}))

      assert RepoHostAccount.uid_taken_error?(changeset)
    end

    test "create/1 rejects the uid even when the existing link is revoked" do
      {:ok, _} = Support.Members.insert_repo_host_account(github_uid: "10002", revoked: true)

      assert {:error, %Ecto.Changeset{} = changeset} =
               RepoHostAccount.create(create_params(%{github_uid: "10002"}))

      assert RepoHostAccount.uid_taken_error?(changeset)
    end

    test "create/1 allows the same uid under a different repo_host" do
      {:ok, _} = Support.Members.insert_repo_host_account(github_uid: "10003")

      assert {:ok, _} =
               RepoHostAccount.create(
                 create_params(%{github_uid: "10003", repo_host: "bitbucket"})
               )
    end

    test "update_repo_host_account/4 with reset rejects switching to another user's uid" do
      {:ok, _} = Support.Members.insert_repo_host_account(github_uid: "10004")

      {:ok, mine} =
        Support.Members.insert_repo_host_account(
          github_uid: "10005",
          login: "mine",
          name: "Mine",
          permission_scope: "user:email"
        )

      assert {:error, %Ecto.Changeset{} = changeset} =
               RepoHostAccount.update_repo_host_account(
                 mine.user_id,
                 :github,
                 %{
                   github_uid: "10004",
                   login: "mine",
                   name: "Mine",
                   permission_scope: "user:email"
                 },
                 reset: true
               )

      assert RepoHostAccount.uid_taken_error?(changeset)

      {:ok, unchanged} = RepoHostAccount.get_for_github_user(mine.user_id)
      assert unchanged.github_uid == "10005"
    end

    test "update_repo_host_account/4 allows reconnecting the user's own uid" do
      {:ok, mine} =
        Support.Members.insert_repo_host_account(
          github_uid: "10006",
          login: "reconnect",
          name: "Reconnect",
          permission_scope: "repo,user:email",
          token: "old-token"
        )

      assert {:ok, updated} =
               RepoHostAccount.update_repo_host_account(
                 mine.user_id,
                 :github,
                 %{
                   github_uid: "10006",
                   login: "reconnect",
                   name: "Reconnect",
                   token: "refreshed-token",
                   permission_scope: "repo,user:email"
                 },
                 reset: true
               )

      assert updated.github_uid == "10006"
      assert updated.token == "refreshed-token"
    end

    test "uid_taken_error?/1 is false for other changeset errors" do
      changeset =
        %RepoHostAccount{}
        |> Ecto.Changeset.cast(%{}, [:login])
        |> Ecto.Changeset.validate_required([:login])

      refute RepoHostAccount.uid_taken_error?(changeset)
      refute RepoHostAccount.uid_taken_error?(:invalid_data)
    end
  end
end
