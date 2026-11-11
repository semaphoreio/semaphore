defmodule RepositoryHub.GithubAdapterTest do
  use ExUnit.Case, async: false

  alias RepositoryHub.{
    GithubAdapter,
    GithubClient,
    Model,
    RepositoryIntegratorClient,
    ServiceAccountClient,
    UserClient
  }

  import Mock

  doctest GithubAdapter

  @repository %{owner: "an-org", name: "a-repo"}
  @org_id "ca5ea1a0-0000-4000-8000-000000000001"
  @owner_id "ca5ea1a0-0000-4000-8000-000000000002"
  @service_account_id "ca5ea1a0-0000-4000-8000-000000000003"
  @member_id "ca5ea1a0-0000-4000-8000-000000000004"

  test "token/3 passes repository remote_id for github app integration" do
    adapter = GithubAdapter.new("github_app")
    {:ok, git_repository} = Model.GitRepository.new("git@github.com:dummy/repository.git", "repo-remote-id-123")

    with_mock RepositoryIntegratorClient, [:passthrough],
      get_token: fn _integration_type, _repository_slug, _repository_remote_id ->
        {:ok, "github-app-token"}
      end do
      assert {:ok, "github-app-token"} = GithubAdapter.token(adapter, Ecto.UUID.generate(), git_repository)

      assert_called(
        RepositoryIntegratorClient.get_token(
          :GITHUB_APP,
          "dummy/repository",
          "repo-remote-id-123"
        )
      )
    end
  end

  test "token/3 passes empty remote_id for github app integration when missing" do
    adapter = GithubAdapter.new("github_app")
    {:ok, git_repository} = Model.GitRepository.new("git@github.com:dummy/repository.git")

    with_mock RepositoryIntegratorClient, [:passthrough],
      get_token: fn _integration_type, _repository_slug, _repository_remote_id ->
        {:ok, "github-app-token"}
      end do
      assert {:ok, "github-app-token"} = GithubAdapter.token(adapter, Ecto.UUID.generate(), git_repository)

      assert_called(
        RepositoryIntegratorClient.get_token(
          :GITHUB_APP,
          "dummy/repository",
          ""
        )
      )
    end
  end

  describe "github_app_permissions/3" do
    test "asks GitHub about a member's own account" do
      with_permission_mocks(fn ->
        assert {:ok, %{"push" => true}} = GithubAdapter.github_app_permissions(member(), @repository, "a-token")

        assert_called(UserClient.get_repository_provider_logins(:GITHUB, @member_id))
        assert_called(GithubClient.repository_permissions(:meck.is(&(&1.username == "a-member")), :_))
      end)
    end

    test "asks GitHub about the owner's account for a service account" do
      with_permission_mocks(fn ->
        assert {:ok, %{"push" => true}} =
                 GithubAdapter.github_app_permissions(service_account(), @repository, "a-token")

        assert_called(ServiceAccountClient.describe(@service_account_id, @org_id))
        assert_called(UserClient.get_repository_provider_logins(:GITHUB, @owner_id))
        assert_called(GithubClient.repository_permissions(:meck.is(&(&1.username == "an-owner")), :_))
      end)
    end

    test "passes on what the owner may not do" do
      with_permission_mocks(
        fn ->
          assert {:ok, %{"push" => false}} =
                   GithubAdapter.github_app_permissions(service_account(), @repository, "a-token")
        end,
        permissions: %{"admin" => false, "push" => false}
      )
    end

    test "refuses a service account that has no owner" do
      with_permission_mocks(
        fn ->
          assert {:error, %{message: message}} =
                   GithubAdapter.github_app_permissions(service_account(), @repository, "a-token")

          assert message =~ "no owner in the organization"
          refute called(GithubClient.repository_permissions(:_, :_))
        end,
        owner_id: "",
        owner_active: false
      )
    end

    test "refuses a service account whose owner is no longer a member" do
      with_permission_mocks(
        fn ->
          assert {:error, %{message: message}} =
                   GithubAdapter.github_app_permissions(service_account(), @repository, "a-token")

          assert message =~ "no owner in the organization"
          refute called(GithubClient.repository_permissions(:_, :_))
        end,
        owner_active: false
      )
    end

    test "refuses a service account whose owner has no GitHub account connected" do
      with_permission_mocks(
        fn ->
          assert {:error, %{message: message}} =
                   GithubAdapter.github_app_permissions(service_account(), @repository, "a-token")

          assert message =~ "owner of this service account has no GitHub account"
        end,
        logins: []
      )
    end

    test "does not look for an owner on a self-hosted install" do
      on_prem(fn ->
        with_permission_mocks(fn ->
          assert {:ok, %{"push" => true}} =
                   GithubAdapter.github_app_permissions(service_account(), @repository, "a-token")

          refute called(ServiceAccountClient.describe(:_, :_))
        end)
      end)
    end

    test "does not look for an owner while the rule is turned off" do
      enforcement_off(fn ->
        with_permission_mocks(
          fn ->
            assert {:ok, %{"admin" => true, "push" => true}} =
                     GithubAdapter.github_app_permissions(service_account(), @repository, "a-token")

            refute called(ServiceAccountClient.describe(:_, :_))
          end,
          owner_id: "",
          owner_active: false
        )
      end)
    end
  end

  defp member do
    %{user_id: @member_id, user: %{creation_source: :NOT_SET, org_id: @org_id}}
  end

  defp service_account do
    %{user_id: @service_account_id, user: %{creation_source: :SERVICE_ACCOUNT, org_id: @org_id}}
  end

  defp with_permission_mocks(body, opts \\ []) do
    owner_id = Keyword.get(opts, :owner_id, @owner_id)
    owner_active = Keyword.get(opts, :owner_active, true)
    logins = Keyword.get(opts, :logins, nil)
    permissions = Keyword.get(opts, :permissions, %{"admin" => false, "push" => true})

    with_mocks([
      {ServiceAccountClient, [:passthrough],
       [
         describe: fn _id, _org_id ->
           {:ok, %{service_account: %{owner_id: owner_id, owner_active: owner_active}}}
         end
       ]},
      {UserClient, [:passthrough],
       [
         get_repository_provider_logins: fn :GITHUB, user_id ->
           {:ok, logins || logins_for(user_id)}
         end
       ]},
      {GithubClient, [:passthrough], [repository_permissions: fn _params, _opts -> {:ok, permissions} end]}
    ]) do
      body.()
    end
  end

  defp logins_for(@owner_id), do: ["an-owner"]
  defp logins_for(@member_id), do: ["a-member"]
  defp logins_for(_user_id), do: []

  defp on_prem(body), do: with_env(:on_prem?, true, body)

  defp enforcement_off(body), do: with_env(:enforce_service_account_owner?, false, body)

  defp with_env(key, value, body) do
    previous = Application.get_env(:repository_hub, key)
    Application.put_env(:repository_hub, key, value)

    try do
      body.()
    after
      Application.put_env(:repository_hub, key, previous)
    end
  end
end
