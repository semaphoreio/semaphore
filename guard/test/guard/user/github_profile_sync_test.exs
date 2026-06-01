defmodule Guard.User.GithubProfileSyncTest do
  use Guard.RepoCase, async: false

  import ExUnit.CaptureLog
  import Mock
  import Tesla.Mock

  alias Guard.FrontRepo.RepoHostAccount
  alias Guard.User.GithubProfileSync

  setup do
    {:ok, user} = Support.Factories.RbacUser.insert()

    {:ok, _} = Support.Members.insert_user(id: user.id, email: user.email, name: user.name)

    {:ok, rha} =
      Support.Members.insert_repo_host_account(
        login: "octocat",
        name: "The Octocat",
        github_uid: "583231",
        user_id: user.id,
        token: "token",
        revoked: false,
        permission_scope: "repo"
      )

    {:ok, user: user, rha: rha}
  end

  describe "sync/3 — passthrough cases" do
    test "returns input untouched for non-github account", %{user: user} do
      account = %RepoHostAccount{repo_host: "bitbucket", revoked: false}
      assert {:ok, ^account} = GithubProfileSync.sync({:ok, account}, user.id, "token")
    end

    test "returns input untouched for revoked github account", %{user: user} do
      account = %RepoHostAccount{repo_host: "github", revoked: true}
      assert {:ok, ^account} = GithubProfileSync.sync({:ok, account}, user.id, "token")
    end

    test "returns input untouched for non-:ok tuple", %{user: user} do
      assert {:error, :boom} = GithubProfileSync.sync({:error, :boom}, user.id, "token")
    end
  end

  describe "sync/3 — github profile fetch" do
    test "persists login change", %{user: user, rha: rha} do
      mock_global(fn
        %{method: :get, url: "https://api.github.com/user/583231"} ->
          json(%{"id" => 583_231, "login" => "octocat-renamed", "name" => "The Octocat"})
      end)

      with_mock Guard.Events.UserUpdated, publish: fn _u, _e, _r -> :ok end do
        assert {:ok, updated} = GithubProfileSync.sync({:ok, rha}, user.id, "token")
        assert updated.login == "octocat-renamed"

        assert called(Guard.Events.UserUpdated.publish(user.id, "user_exchange", "updated"))
      end
    end

    test "persists name change", %{user: user, rha: rha} do
      mock_global(fn
        %{method: :get, url: "https://api.github.com/user/583231"} ->
          json(%{"id" => 583_231, "login" => "octocat", "name" => "Mona Lisa"})
      end)

      with_mock Guard.Events.UserUpdated, publish: fn _u, _e, _r -> :ok end do
        assert {:ok, updated} = GithubProfileSync.sync({:ok, rha}, user.id, "token")
        assert updated.name == "Mona Lisa"

        assert called(Guard.Events.UserUpdated.publish(user.id, "user_exchange", "updated"))
      end
    end

    test "no-op when github reports the same profile", %{user: user, rha: rha} do
      mock_global(fn
        %{method: :get, url: "https://api.github.com/user/583231"} ->
          json(%{"id" => 583_231, "login" => rha.login, "name" => rha.name})
      end)

      with_mock Guard.Events.UserUpdated, publish: fn _u, _e, _r -> :ok end do
        assert {:ok, returned} = GithubProfileSync.sync({:ok, rha}, user.id, "token")
        assert returned.id == rha.id
        refute called(Guard.Events.UserUpdated.publish(:_, :_, :_))
      end
    end

    test "does not clobber stored name when github returns null", %{user: user, rha: rha} do
      mock_global(fn
        %{method: :get, url: "https://api.github.com/user/583231"} ->
          json(%{"id" => 583_231, "login" => "octocat-renamed", "name" => nil})
      end)

      with_mock Guard.Events.UserUpdated, publish: fn _u, _e, _r -> :ok end do
        assert {:ok, updated} = GithubProfileSync.sync({:ok, rha}, user.id, "token")
        assert updated.login == "octocat-renamed"
        assert updated.name == rha.name
      end
    end

    test "warns and bumps failure metric when github fetch returns 5xx", %{user: user, rha: rha} do
      mock_global(fn
        %{method: :get, url: "https://api.github.com/user/583231"} ->
          {:ok, %Tesla.Env{status: 500, body: %{"message" => "boom"}}}
      end)

      with_mocks([
        {Guard.Events.UserUpdated, [], publish: fn _u, _e, _r -> :ok end},
        {Watchman, [], increment: fn _ -> :ok end}
      ]) do
        log =
          capture_log([level: :warning], fn ->
            assert {:ok, returned} = GithubProfileSync.sync({:ok, rha}, user.id, "token")
            assert returned.id == rha.id
          end)

        assert log =~ "[warning]"
        assert log =~ "Skipping GitHub profile sync for #{user.id}"
        assert log =~ ":http"
        assert called(Watchman.increment("guard.github_profile_sync.failure"))
        refute called(Guard.Events.UserUpdated.publish(:_, :_, :_))
      end
    end

    test "debug-logs and does not bump metric on 4xx (non-404)", %{user: user, rha: rha} do
      mock_global(fn
        %{method: :get, url: "https://api.github.com/user/583231"} ->
          {:ok, %Tesla.Env{status: 403, body: %{"message" => "rate limited"}}}
      end)

      with_mocks([
        {Guard.Events.UserUpdated, [], publish: fn _u, _e, _r -> :ok end},
        {Watchman, [], increment: fn _ -> :ok end}
      ]) do
        warning_log =
          capture_log([level: :warning], fn ->
            assert {:ok, _} = GithubProfileSync.sync({:ok, rha}, user.id, "token")
          end)

        debug_log =
          capture_log([level: :debug], fn ->
            assert {:ok, _} = GithubProfileSync.sync({:ok, rha}, user.id, "token")
          end)

        refute warning_log =~ "Skipping GitHub profile sync"
        assert debug_log =~ "Skipping GitHub profile sync for #{user.id}"
        refute called(Watchman.increment(:_))
        refute called(Guard.Events.UserUpdated.publish(:_, :_, :_))
      end
    end

    test "debug-logs and does not bump metric on 404", %{user: user, rha: rha} do
      mock_global(fn
        %{method: :get, url: "https://api.github.com/user/583231"} ->
          {:ok, %Tesla.Env{status: 404, body: %{"message" => "Not Found"}}}
      end)

      with_mocks([
        {Guard.Events.UserUpdated, [], publish: fn _u, _e, _r -> :ok end},
        {Watchman, [], increment: fn _ -> :ok end}
      ]) do
        warning_log =
          capture_log([level: :warning], fn ->
            assert {:ok, _} = GithubProfileSync.sync({:ok, rha}, user.id, "token")
          end)

        debug_log =
          capture_log([level: :debug], fn ->
            assert {:ok, _} = GithubProfileSync.sync({:ok, rha}, user.id, "token")
          end)

        refute warning_log =~ "Skipping GitHub profile sync"
        assert debug_log =~ ":not_found"
        refute called(Watchman.increment(:_))
        refute called(Guard.Events.UserUpdated.publish(:_, :_, :_))
      end
    end

    test "debug-logs and does not bump metric on network/transport error", %{user: user, rha: rha} do
      mock_global(fn
        %{method: :get, url: "https://api.github.com/user/583231"} ->
          {:error, :timeout}
      end)

      with_mocks([
        {Guard.Events.UserUpdated, [], publish: fn _u, _e, _r -> :ok end},
        {Watchman, [], increment: fn _ -> :ok end}
      ]) do
        warning_log =
          capture_log([level: :warning], fn ->
            assert {:ok, _} = GithubProfileSync.sync({:ok, rha}, user.id, "token")
          end)

        debug_log =
          capture_log([level: :debug], fn ->
            assert {:ok, _} = GithubProfileSync.sync({:ok, rha}, user.id, "token")
          end)

        refute warning_log =~ "Skipping GitHub profile sync"
        assert debug_log =~ ":transport"
        refute called(Watchman.increment(:_))
        refute called(Guard.Events.UserUpdated.publish(:_, :_, :_))
      end
    end

    test "log line does not contain raw login or name values", %{user: user, rha: rha} do
      new_login = "secret-login-#{System.unique_integer([:positive])}"
      new_name = "Secret Display Name #{System.unique_integer([:positive])}"

      mock_global(fn
        %{method: :get, url: "https://api.github.com/user/583231"} ->
          json(%{"id" => 583_231, "login" => new_login, "name" => new_name})
      end)

      with_mock Guard.Events.UserUpdated, publish: fn _u, _e, _r -> :ok end do
        log =
          capture_log([level: :info], fn ->
            GithubProfileSync.sync({:ok, rha}, user.id, "token")
          end)

        sync_line =
          log
          |> String.split("\n")
          |> Enum.find("", &String.contains?(&1, "GitHub profile changed for user"))

        assert sync_line =~ "fields=login,name"
        refute sync_line =~ new_login
        refute sync_line =~ new_name
        refute sync_line =~ rha.name
      end
    end

    test "bumps failure metric and returns {:ok, account} when update_profile fails",
         %{user: user, rha: rha} do
      mock_global(fn
        %{method: :get, url: "https://api.github.com/user/583231"} ->
          json(%{"id" => 583_231, "login" => "octocat-renamed", "name" => rha.name})
      end)

      forced_error = {:error, %Ecto.Changeset{errors: [login: {"is invalid", []}], valid?: false}}

      with_mocks([
        {RepoHostAccount, [:passthrough], update_profile: fn _, _ -> forced_error end},
        {Guard.Events.UserUpdated, [], publish: fn _u, _e, _r -> :ok end},
        {Watchman, [], increment: fn _ -> :ok end}
      ]) do
        assert {:ok, returned} = GithubProfileSync.sync({:ok, rha}, user.id, "token")
        assert returned.id == rha.id
        assert called(Watchman.increment("guard.github_profile_sync.failure"))
        refute called(Guard.Events.UserUpdated.publish(:_, :_, :_))
      end
    end
  end
end
