defmodule Guard.User.GithubProfileSyncTest do
  use Guard.RepoCase, async: false

  import ExUnit.CaptureLog
  import Mock
  import Tesla.Mock

  alias Guard.FrontRepo.RepoHostAccount
  alias Guard.User.GithubProfileSync

  setup do
    {user, rha} = Support.Members.insert_user_with_github_account()
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

    test "warns and bumps tagged failure metric when github fetch returns 5xx",
         %{user: user, rha: rha} do
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
        assert called(Watchman.increment({"guard.github_profile_sync.failure", ["http_5xx"]}))
        refute called(Guard.Events.UserUpdated.publish(:_, :_, :_))
      end
    end

    for status <- [401, 403, 429] do
      test "warns and bumps tagged failure metric when github fetch returns #{status}",
           %{user: user, rha: rha} do
        status = unquote(status)

        mock_global(fn
          %{method: :get, url: "https://api.github.com/user/583231"} ->
            {:ok, %Tesla.Env{status: status, body: %{"message" => "denied"}}}
        end)

        with_mocks([
          {Guard.Events.UserUpdated, [], publish: fn _u, _e, _r -> :ok end},
          {Watchman, [], increment: fn _ -> :ok end}
        ]) do
          log =
            capture_log([level: :warning], fn ->
              assert {:ok, _} = GithubProfileSync.sync({:ok, rha}, user.id, "token")
            end)

          assert log =~ "GitHub profile sync auth/limit failure for #{user.id}"
          assert log =~ ":http"

          assert called(
                   Watchman.increment({"guard.github_profile_sync.failure", ["http_#{status}"]})
                 )

          refute called(Guard.Events.UserUpdated.publish(:_, :_, :_))
        end
      end
    end

    silent_cases = [
      {"404", {:ok, %Tesla.Env{status: 404, body: %{"message" => "Not Found"}}}},
      {"network/transport error", {:error, :timeout}}
    ]

    for {desc, mock_response} <- silent_cases do
      test "skips silently on #{desc} without warning or metric",
           %{user: user, rha: rha} do
        mock_response = unquote(Macro.escape(mock_response))

        mock_global(fn
          %{method: :get, url: "https://api.github.com/user/583231"} ->
            mock_response
        end)

        with_mocks([
          {Guard.Events.UserUpdated, [], publish: fn _u, _e, _r -> :ok end},
          {Watchman, [], increment: fn _ -> :ok end}
        ]) do
          warning_log =
            capture_log([level: :warning], fn ->
              assert {:ok, _} = GithubProfileSync.sync({:ok, rha}, user.id, "token")
            end)

          refute warning_log =~ "Skipping GitHub profile sync"
          refute called(Watchman.increment(:_))
          refute called(Guard.Events.UserUpdated.publish(:_, :_, :_))
        end
      end
    end

    test "bumps tagged changeset failure metric and returns {:ok, account} when update_profile fails",
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
        assert called(Watchman.increment({"guard.github_profile_sync.failure", ["changeset"]}))
        refute called(Guard.Events.UserUpdated.publish(:_, :_, :_))
      end
    end

    test "bumps tagged success counter on changed write", %{user: user, rha: rha} do
      mock_global(fn
        %{method: :get, url: "https://api.github.com/user/583231"} ->
          json(%{"id" => 583_231, "login" => "octocat-renamed", "name" => rha.name})
      end)

      with_mocks([
        {Guard.Events.UserUpdated, [], publish: fn _u, _e, _r -> :ok end},
        {Watchman, [], increment: fn _ -> :ok end}
      ]) do
        assert {:ok, _} = GithubProfileSync.sync({:ok, rha}, user.id, "token")
        assert called(Watchman.increment({"guard.github_profile_sync.success", ["changed"]}))
      end
    end

    test "bumps tagged success counter on no-change write", %{user: user, rha: rha} do
      mock_global(fn
        %{method: :get, url: "https://api.github.com/user/583231"} ->
          json(%{"id" => 583_231, "login" => rha.login, "name" => rha.name})
      end)

      with_mocks([
        {Guard.Events.UserUpdated, [], publish: fn _u, _e, _r -> :ok end},
        {Watchman, [], increment: fn _ -> :ok end}
      ]) do
        assert {:ok, _} = GithubProfileSync.sync({:ok, rha}, user.id, "token")
        assert called(Watchman.increment({"guard.github_profile_sync.success", ["no_change"]}))
        refute called(Guard.Events.UserUpdated.publish(:_, :_, :_))
      end
    end

    test "error log never contains the OAuth access or refresh token", %{user: user, rha: rha} do
      secret_token = "ghp_TEST_OAUTH_ACCESS_TOKEN_VALUE"
      secret_refresh = "ghr_TEST_OAUTH_REFRESH_TOKEN_VALUE"

      {:ok, rha_with_secrets} =
        rha
        |> Ecto.Changeset.change(%{token: secret_token, refresh_token: secret_refresh})
        |> Guard.FrontRepo.update(force: true)

      mock_global(fn
        %{method: :get, url: "https://api.github.com/user/583231"} ->
          json(%{"id" => 583_231, "login" => "octocat-renamed", "name" => rha_with_secrets.name})
      end)

      # Build a *real* changeset whose `:data` is the rha — exercises the
      # default-Inspect leak path that a forged %Ecto.Changeset{} would skip.
      real_changeset_error =
        {:error,
         rha_with_secrets
         |> Ecto.Changeset.change(%{login: "octocat-renamed"})
         |> Ecto.Changeset.add_error(:login, "is invalid")
         |> Map.put(:valid?, false)}

      with_mocks([
        {RepoHostAccount, [:passthrough], update_profile: fn _, _ -> real_changeset_error end},
        {Guard.Events.UserUpdated, [], publish: fn _u, _e, _r -> :ok end},
        {Watchman, [], increment: fn _ -> :ok end}
      ]) do
        log =
          ExUnit.CaptureLog.capture_log([level: :error], fn ->
            assert {:ok, _returned} =
                     GithubProfileSync.sync({:ok, rha_with_secrets}, user.id, "tok")
          end)

        refute log =~ secret_token
        refute log =~ secret_refresh
        # Field/message from the changeset must still be logged for diagnostics.
        assert log =~ "login:is invalid"
      end
    end
  end
end
