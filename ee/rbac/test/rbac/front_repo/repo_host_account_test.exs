defmodule Rbac.FrontRepo.RepoHostAccountTest do
  use Rbac.RepoCase, async: true

  alias Rbac.FrontRepo.RepoHostAccount

  defp insert_full_rha(overrides) do
    defaults = [
      login: "octocat",
      name: "The Octocat",
      permission_scope: "user:email"
    ]

    Support.Members.insert_repo_host_account(Keyword.merge(defaults, overrides))
  end

  # Keeps assertions off unrelated log lines emitted during a test.
  defp app_log(log) do
    log
    |> String.split("\n")
    |> Enum.filter(&(&1 =~ "RepoHostAccount"))
    |> Enum.join("\n")
  end

  describe "GitHub uid uniqueness" do
    # rbac's OIDC signup reaches update_repo_host_account directly, so guard's
    # check on its own write paths does not cover it.
    test "refuses to point a link at a uid another user actively holds" do
      {:ok, theirs} = insert_full_rha(github_uid: "30001", user_id: Ecto.UUID.generate())

      assert {:error, :uid_taken} =
               RepoHostAccount.update_repo_host_account(
                 Ecto.UUID.generate(),
                 :github,
                 %{github_uid: theirs.github_uid, login: "claimer", name: "Claimer"},
                 reset: true
               )
    end

    test "allows the same user to keep their own uid" do
      user_id = Ecto.UUID.generate()
      {:ok, mine} = insert_full_rha(github_uid: "30002", user_id: user_id)

      assert {:ok, _} =
               RepoHostAccount.update_repo_host_account(
                 user_id,
                 :github,
                 %{github_uid: mine.github_uid, login: "octocat", name: "The Octocat"},
                 reset: true
               )
    end

    test "a revoked link still blocks while it is inside the grace window" do
      {:ok, theirs} =
        insert_full_rha(github_uid: "30003", user_id: Ecto.UUID.generate(), revoked: true)

      assert theirs.revoked

      assert {:error, :uid_taken} =
               RepoHostAccount.update_repo_host_account(
                 Ecto.UUID.generate(),
                 :github,
                 %{github_uid: theirs.github_uid, login: "claimer", name: "Claimer"},
                 reset: true
               )
    end

    test "a refusal is counted, since the OIDC caller discards the result" do
      import Mock

      {:ok, theirs} = insert_full_rha(github_uid: "30005", user_id: Ecto.UUID.generate())

      with_mock Watchman, increment: fn _ -> :ok end do
        assert {:error, :uid_taken} =
                 RepoHostAccount.update_repo_host_account(
                   Ecto.UUID.generate(),
                   :github,
                   %{github_uid: theirs.github_uid, login: "claimer", name: "Claimer"},
                   reset: true
                 )

        assert_called(
          Watchman.increment({"rbac.repo_host_account.account_taken", ["github", "oidc_sync"]})
        )
      end
    end

    test "a non-github provider is not gated on the uid" do
      {:ok, theirs} = insert_full_rha(github_uid: "30004", user_id: Ecto.UUID.generate())

      assert {:ok, _} =
               RepoHostAccount.update_repo_host_account(
                 Ecto.UUID.generate(),
                 :bitbucket,
                 %{github_uid: theirs.github_uid, login: "claimer", name: "Claimer"},
                 reset: true
               )
    end
  end

  describe "logging" do
    import ExUnit.CaptureLog

    test "a token refresh logs the changed field names, never the token" do
      {:ok, mine} =
        insert_full_rha(
          github_uid: "10020",
          login: "logger",
          permission_scope: "repo,user:email",
          token: "old-token"
        )

      log =
        capture_log(fn ->
          assert {:ok, _} =
                   RepoHostAccount.update_repo_host_account(
                     mine.user_id,
                     :github,
                     %{
                       github_uid: "10020",
                       login: "logger",
                       name: "The Octocat",
                       token: "gho_supersecrettoken",
                       refresh_token: "ghr_supersecretrefresh",
                       permission_scope: "repo,user:email"
                     },
                     reset: true
                   )
        end)

      assert app_log(log) =~ "Successfully updated RepoHostAccount for #{mine.user_id}"
      assert app_log(log) =~ ":token"
      refute app_log(log) =~ "gho_supersecrettoken"
      refute app_log(log) =~ "ghr_supersecretrefresh"
      refute app_log(log) =~ "old-token"
    end

    test "a reset logs the real uid and login transition" do
      {:ok, mine} =
        insert_full_rha(
          github_uid: "10021",
          login: "before",
          permission_scope: "repo,user:email",
          token: "old-token"
        )

      log =
        capture_log(fn ->
          assert {:ok, _} =
                   RepoHostAccount.update_repo_host_account(
                     mine.user_id,
                     :github,
                     %{
                       github_uid: "10022",
                       login: "after",
                       name: "The Octocat",
                       token: "gho_supersecrettoken",
                       permission_scope: "repo,user:email"
                     },
                     reset: true
                   )
        end)

      assert app_log(log) =~ "uid 10021 -> 10022"
      assert app_log(log) =~ "login before -> after"
      refute app_log(log) =~ "gho_supersecrettoken"
      refute app_log(log) =~ "old-token"
    end

    test "a rejected reset logs the changeset errors and the attempted transition" do
      {:ok, mine} =
        insert_full_rha(
          github_uid: "10024",
          login: "claimer",
          permission_scope: "repo,user:email"
        )

      log =
        capture_log(fn ->
          # a blank name fails validate_required in reset_account/3
          assert {:error, %Ecto.Changeset{}} =
                   RepoHostAccount.update_repo_host_account(
                     mine.user_id,
                     :github,
                     %{
                       github_uid: "10025",
                       login: "claimer",
                       name: "",
                       token: "gho_supersecrettoken",
                       permission_scope: "repo,user:email"
                     },
                     reset: true
                   )
        end)

      assert app_log(log) =~ "Failed to reset RepoHostAccount for #{mine.user_id}"
      assert app_log(log) =~ "uid 10024 -> 10025"
      refute app_log(log) =~ "gho_supersecrettoken"
    end

    test "a link missing required identity fields logs which ones are missing" do
      log =
        capture_log(fn ->
          assert {:error, :invalid_data} =
                   RepoHostAccount.update_repo_host_account(
                     Ecto.UUID.generate(),
                     :github,
                     %{github_uid: nil, login: nil, token: "gho_supersecrettoken"},
                     reset: true
                   )
        end)

      assert app_log(log) =~ "missing [:github_uid, :login]"
      refute app_log(log) =~ "gho_supersecrettoken"
    end
  end

  describe "inspecting a link" do
    test "credentials are redacted" do
      account = %RepoHostAccount{
        login: "octocat",
        github_uid: "10001",
        token: "gho_supersecrettoken",
        refresh_token: "ghr_supersecretrefresh"
      }

      inspected = inspect(account)

      refute inspected =~ "gho_supersecrettoken"
      refute inspected =~ "ghr_supersecretrefresh"
      assert inspected =~ "octocat"
      assert inspected =~ "10001"
    end

    test "credentials are redacted when nested in a changeset" do
      account = %RepoHostAccount{login: "octocat", github_uid: "10001"}

      changeset =
        Ecto.Changeset.cast(account, %{token: "gho_supersecrettoken"}, [:token, :login])

      refute inspect(changeset) =~ "gho_supersecrettoken"
    end
  end
end
