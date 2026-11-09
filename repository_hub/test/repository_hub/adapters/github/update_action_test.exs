defmodule RepositoryHub.Server.Github.UpdateActionTest do
  @moduledoc false
  use RepositoryHub.ServerActionCase, async: false

  alias RepositoryHub.Adapters
  alias RepositoryHub.Server.{RegenerateDeployKeyAction, UpdateAction}
  alias RepositoryHub.InternalApiFactory

  alias RepositoryHub.{
    GithubClient,
    GithubClientFactory,
    RepositoryIntegratorClient,
    UserClient,
    DeployKeysModelFactory,
    RepositoryModelFactory
  }

  alias InternalApi.Repository.{RegenerateDeployKeyResponse, UpdateResponse}
  import Mock

  setup_with_mocks(
    for {GithubClient, opts, mocks} <- GithubClientFactory.mocks() do
      {GithubClient, opts,
       [
         find_webhook: fn _params, _opts ->
           {:error, %{status: GRPC.Status.not_found(), message: "Webhook not found"}}
         end
       ] ++ mocks}
    end ++
      [
        {UserClient, [:passthrough],
         [
           describe: fn
             "service-account-user-id" = user_id ->
               {:ok, %{user_id: user_id, user: %{creation_source: :SERVICE_ACCOUNT}}}

             user_id ->
               {:ok, %{user_id: user_id, user: %{creation_source: :NOT_SET}}}
           end,
           get_repository_provider_logins: fn :GITHUB, _user_id -> {:ok, ["radwo"]} end
         ]}
      ]
  ) do
    %{github_app_adapter: Adapters.github_app(), github_oauth_adapter: Adapters.github_oauth()}
  end

  describe "Github UpdateAction" do
    test "saves settings without touching GitHub when the url did not change", %{github_app_adapter: adapter} do
      repository = RepositoryModelFactory.githubapp_repo()

      request =
        InternalApiFactory.update_request(
          repository_id: repository.id,
          url: "git@github.com:dummy/repository.git",
          pipeline_file: ".semaphore/semaphore-2.yml"
        )

      assert %UpdateResponse{} = UpdateAction.execute(adapter, request)

      {:ok, updated_repository} = RepositoryHub.Model.RepositoryQuery.get_by_id(repository.id)
      assert updated_repository.pipeline_file == ".semaphore/semaphore-2.yml"
      assert updated_repository.hook_id == repository.hook_id

      assert_not_called(GithubClient.find_repository(:_, :_))
      assert_not_called(GithubClient.remove_webhook(:_, :_))
      assert_not_called(GithubClient.create_webhook(:_, :_))
      assert_not_called(UserClient.describe(:_))
    end

    test "rejects a pipeline file longer than 255 characters with a clear error", %{github_app_adapter: adapter} do
      repository = RepositoryModelFactory.githubapp_repo()

      request =
        InternalApiFactory.update_request(
          repository_id: repository.id,
          url: "git@github.com:dummy/repository.git",
          pipeline_file: String.duplicate("a", 256)
        )

      assert {:error, "pipeline_file should be at most 255 character(s)"} = UpdateAction.execute(adapter, request)

      {:ok, unchanged_repository} = RepositoryHub.Model.RepositoryQuery.get_by_id(repository.id)
      assert unchanged_repository.pipeline_file == repository.pipeline_file
    end

    test "changes the url to another repository within the same installation", %{github_app_adapter: adapter} do
      repository = RepositoryModelFactory.githubapp_repo()
      DeployKeysModelFactory.create_deploy_key(project_id: repository.project_id, repository_id: repository.id)

      request =
        InternalApiFactory.update_request(
          repository_id: repository.id,
          url: "git@github.com:dummy/repository-2.git",
          user_id: "requester-user-id"
        )

      assert %UpdateResponse{repository: response_repository} = UpdateAction.execute(adapter, request)
      assert response_repository.url == "git@github.com:dummy/repository-2.git"

      {:ok, updated_repository} = RepositoryHub.Model.RepositoryQuery.get_by_id(repository.id)
      assert updated_repository.owner == "dummy"
      assert updated_repository.name == "repository-2"
      assert updated_repository.url == "git@github.com:dummy/repository-2.git"

      old_token = "gha-#{repository.remote_id}"
      target_token = "gha-"

      assert_called(
        GithubClient.find_repository(%{repo_owner: "dummy", repo_name: "repository-2"}, token: target_token)
      )

      assert_called(GithubClient.remove_webhook(%{repo_owner: "dummy", repo_name: "repository"}, token: old_token))
      assert_called(GithubClient.remove_deploy_key(%{repo_owner: "dummy", repo_name: "repository"}, token: old_token))
      assert_called(GithubClient.create_webhook(%{repo_owner: "dummy", repo_name: "repository-2"}, token: target_token))

      assert_called(
        GithubClient.create_deploy_key(%{repo_owner: "dummy", repo_name: "repository-2"}, token: target_token)
      )
    end

    test "moves a github_app repository to an organization served by another installation", %{
      github_app_adapter: adapter
    } do
      repository =
        RepositoryModelFactory.githubapp_repo(
          owner: "old-org",
          url: "git@github.com:old-org/repository.git",
          remote_id: "999",
          private: false,
          default_branch: "master"
        )

      DeployKeysModelFactory.create_deploy_key(project_id: repository.project_id, repository_id: repository.id)

      request =
        InternalApiFactory.update_request(
          repository_id: repository.id,
          url: "git@github.com:new-org/repository.git",
          user_id: "requester-user-id"
        )

      :meck.expect(GithubClient, :find_repository, fn params, _opts ->
        {:ok, github_repository} = GithubClientFactory.find_repository_mock(params, [])
        {:ok, %{github_repository | default_branch: "main"}}
      end)

      with_mock RepositoryIntegratorClient, [:passthrough],
        get_token: fn
          _integration_type, "old-org/repository", _remote_id -> {:ok, "old-tok"}
          _integration_type, "new-org/repository", _remote_id -> {:ok, "new-tok"}
        end do
        assert %UpdateResponse{} = UpdateAction.execute(adapter, request)
      end

      {:ok, updated_repository} = RepositoryHub.Model.RepositoryQuery.get_by_id(repository.id)
      assert updated_repository.owner == "new-org"
      assert updated_repository.url == "git@github.com:new-org/repository.git"
      assert updated_repository.remote_id == "12345"
      assert updated_repository.private == true
      assert updated_repository.default_branch == "main"

      [{:ok, created_webhook}] =
        for {_pid, {GithubClient, :create_webhook, _args}, result} <- :meck.history(GithubClient), do: result

      assert updated_repository.hook_id == created_webhook.id

      assert_called(GithubClient.find_repository(%{repo_owner: "new-org", repo_name: "repository"}, token: "new-tok"))

      assert_called(
        GithubClient.repository_permissions(
          %{repo_owner: "new-org", repo_name: "repository", username: "radwo"},
          token: "new-tok"
        )
      )

      assert_called(GithubClient.remove_webhook(%{repo_owner: "old-org", repo_name: "repository"}, token: "old-tok"))
      assert_called(GithubClient.remove_deploy_key(%{repo_owner: "old-org", repo_name: "repository"}, token: "old-tok"))
      assert_called(GithubClient.create_webhook(%{repo_owner: "new-org", repo_name: "repository"}, token: "new-tok"))
      assert_called(GithubClient.create_deploy_key(%{repo_owner: "new-org", repo_name: "repository"}, token: "new-tok"))
    end

    test "keeps the old webhook and deploy key when creating the target deploy key fails", %{
      github_app_adapter: adapter
    } do
      repository =
        RepositoryModelFactory.githubapp_repo(
          owner: "old-org",
          url: "git@github.com:old-org/repository.git",
          remote_id: "999"
        )

      DeployKeysModelFactory.create_deploy_key(project_id: repository.project_id, repository_id: repository.id)

      request =
        InternalApiFactory.update_request(
          repository_id: repository.id,
          url: "git@github.com:new-org/repository.git",
          user_id: "requester-user-id"
        )

      :meck.expect(GithubClient, :create_deploy_key, fn _params, _opts ->
        {:error, %{status: GRPC.Status.failed_precondition(), message: "deploy key creation failed"}}
      end)

      with_mock RepositoryIntegratorClient, [:passthrough],
        get_token: fn
          _integration_type, "old-org/repository", _remote_id -> {:ok, "old-tok"}
          _integration_type, "new-org/repository", _remote_id -> {:ok, "new-tok"}
        end do
        assert {:error, %{message: "deploy key creation failed"}} = UpdateAction.execute(adapter, request)
      end

      {:ok, unchanged_repository} = RepositoryHub.Model.RepositoryQuery.get_by_id(repository.id)
      assert unchanged_repository.url == "git@github.com:old-org/repository.git"
      assert unchanged_repository.remote_id == "999"
      assert unchanged_repository.hook_id == repository.hook_id

      [{:ok, created_webhook}] =
        for {_pid, {GithubClient, :create_webhook, _args}, result} <- :meck.history(GithubClient), do: result

      assert_called(
        GithubClient.remove_webhook(%{repo_owner: "new-org", webhook_id: created_webhook.id}, token: "new-tok")
      )

      assert_not_called(GithubClient.remove_webhook(%{repo_owner: "old-org"}, :_))
      assert_not_called(GithubClient.remove_deploy_key(:_, :_))
    end

    test "keeps the old webhook and deploy key when saving the settings fails after the move", %{
      github_app_adapter: adapter
    } do
      repository =
        RepositoryModelFactory.githubapp_repo(
          owner: "old-org",
          url: "git@github.com:old-org/repository.git",
          remote_id: "999"
        )

      {:ok, deploy_key} =
        DeployKeysModelFactory.create_deploy_key(project_id: repository.project_id, repository_id: repository.id)

      request =
        InternalApiFactory.update_request(
          repository_id: repository.id,
          url: "git@github.com:new-org/repository.git",
          pipeline_file: String.duplicate("a", 300),
          user_id: "requester-user-id"
        )

      with_mock RepositoryIntegratorClient, [:passthrough],
        get_token: fn
          _integration_type, "old-org/repository", _remote_id -> {:ok, "old-tok"}
          _integration_type, "new-org/repository", _remote_id -> {:ok, "new-tok"}
        end do
        assert {:error, _} = UpdateAction.execute(adapter, request)
      end

      assert_old_resources_kept_and_created_resources_removed(repository, deploy_key)
    end

    test "keeps the old webhook and deploy key when the transaction raises after the move", %{
      github_app_adapter: adapter
    } do
      repository =
        RepositoryModelFactory.githubapp_repo(
          owner: "old-org",
          url: "git@github.com:old-org/repository.git",
          remote_id: "999"
        )

      {:ok, deploy_key} =
        DeployKeysModelFactory.create_deploy_key(project_id: repository.project_id, repository_id: repository.id)

      request =
        InternalApiFactory.update_request(
          repository_id: repository.id,
          url: "git@github.com:new-org/repository.git",
          user_id: "requester-user-id"
        )

      with_mocks [
        {RepositoryIntegratorClient, [:passthrough],
         get_token: fn
           _integration_type, "old-org/repository", _remote_id -> {:ok, "old-tok"}
           _integration_type, "new-org/repository", _remote_id -> {:ok, "new-tok"}
         end},
        {RepositoryHub.Repo, [:passthrough],
         transaction: fn %Ecto.Multi{} -> raise DBConnection.ConnectionError, "connection closed" end}
      ] do
        assert_raise DBConnection.ConnectionError, fn -> UpdateAction.execute(adapter, request) end
      end

      assert_old_resources_kept_and_created_resources_removed(repository, deploy_key)
    end

    test "removes the target webhook when creating the target deploy key raises", %{github_app_adapter: adapter} do
      repository =
        RepositoryModelFactory.githubapp_repo(
          owner: "old-org",
          url: "git@github.com:old-org/repository.git",
          remote_id: "999"
        )

      {:ok, deploy_key} =
        DeployKeysModelFactory.create_deploy_key(project_id: repository.project_id, repository_id: repository.id)

      request =
        InternalApiFactory.update_request(
          repository_id: repository.id,
          url: "git@github.com:new-org/repository.git",
          user_id: "requester-user-id"
        )

      :meck.expect(GithubClient, :create_deploy_key, fn _params, _opts -> raise RuntimeError, "connection reset" end)

      with_mock RepositoryIntegratorClient, [:passthrough],
        get_token: fn
          _integration_type, "old-org/repository", _remote_id -> {:ok, "old-tok"}
          _integration_type, "new-org/repository", _remote_id -> {:ok, "new-tok"}
        end do
        assert_raise RuntimeError, fn -> UpdateAction.execute(adapter, request) end
      end

      {:ok, unchanged_repository} = RepositoryHub.Model.RepositoryQuery.get_by_id(repository.id)
      assert unchanged_repository.url == "git@github.com:old-org/repository.git"
      assert unchanged_repository.hook_id == repository.hook_id
      assert {:ok, %{id: deploy_key_id}} = RepositoryHub.Model.DeployKeyQuery.get_by_repository_id(repository.id)
      assert deploy_key_id == deploy_key.id

      [{:ok, created_webhook}] =
        for {_pid, {GithubClient, :create_webhook, _args}, result} <- :meck.history(GithubClient), do: result

      assert_called(
        GithubClient.remove_webhook(%{repo_owner: "new-org", webhook_id: created_webhook.id}, token: "new-tok")
      )

      assert_not_called(GithubClient.remove_webhook(%{repo_owner: "old-org"}, :_))
      assert_not_called(GithubClient.remove_deploy_key(:_, :_))
    end

    test "completes the move when the transaction raises after it committed", %{github_app_adapter: adapter} do
      repository =
        RepositoryModelFactory.githubapp_repo(
          owner: "old-org",
          url: "git@github.com:old-org/repository.git",
          remote_id: "999"
        )

      DeployKeysModelFactory.create_deploy_key(project_id: repository.project_id, repository_id: repository.id)

      request =
        InternalApiFactory.update_request(
          repository_id: repository.id,
          url: "git@github.com:new-org/repository.git",
          user_id: "requester-user-id"
        )

      with_mocks [
        {RepositoryIntegratorClient, [:passthrough],
         get_token: fn
           _integration_type, "old-org/repository", _remote_id -> {:ok, "old-tok"}
           _integration_type, "new-org/repository", _remote_id -> {:ok, "new-tok"}
         end},
        {RepositoryHub.Repo, [:passthrough],
         transaction: fn %Ecto.Multi{} = multi ->
           :meck.passthrough([multi])
           raise DBConnection.ConnectionError, "connection closed"
         end}
      ] do
        assert %UpdateResponse{repository: response_repository} = UpdateAction.execute(adapter, request)
        assert response_repository.url == "git@github.com:new-org/repository.git"
      end

      [{:ok, created_webhook}] =
        for {_pid, {GithubClient, :create_webhook, _args}, result} <- :meck.history(GithubClient), do: result

      {:ok, updated_repository} = RepositoryHub.Model.RepositoryQuery.get_by_id(repository.id)
      assert updated_repository.url == "git@github.com:new-org/repository.git"
      assert updated_repository.hook_id == created_webhook.id

      assert_called(GithubClient.remove_webhook(%{repo_owner: "old-org", repo_name: "repository"}, token: "old-tok"))
      assert_called(GithubClient.remove_deploy_key(%{repo_owner: "old-org", repo_name: "repository"}, token: "old-tok"))
      assert_not_called(GithubClient.remove_webhook(%{repo_owner: "new-org"}, :_))
      assert_not_called(GithubClient.remove_deploy_key(%{repo_owner: "new-org"}, :_))
    end

    test "keeps the created webhook and key when the commit landed but cannot be confirmed", %{
      github_app_adapter: adapter
    } do
      repository =
        RepositoryModelFactory.githubapp_repo(
          owner: "old-org",
          url: "git@github.com:old-org/repository.git",
          remote_id: "999"
        )

      DeployKeysModelFactory.create_deploy_key(project_id: repository.project_id, repository_id: repository.id)

      request =
        InternalApiFactory.update_request(
          repository_id: repository.id,
          url: "git@github.com:new-org/repository.git",
          user_id: "requester-user-id"
        )

      with_mocks [
        {RepositoryIntegratorClient, [:passthrough],
         get_token: fn
           _integration_type, "old-org/repository", _remote_id -> {:ok, "old-tok"}
           _integration_type, "new-org/repository", _remote_id -> {:ok, "new-tok"}
         end},
        {RepositoryHub.Model.RepositoryQuery, [:passthrough], []},
        {Watchman, [:passthrough], []},
        {RepositoryHub.Repo, [:passthrough],
         transaction: fn %Ecto.Multi{} = multi ->
           :meck.passthrough([multi])
           fail_repository_read_back()
           raise DBConnection.ConnectionError, "connection closed"
         end}
      ] do
        assert_raise DBConnection.ConnectionError, fn -> UpdateAction.execute(adapter, request) end
        assert_called(Watchman.increment({"github_app.update_url.unclear_commit", []}))
      end

      [{:ok, created_webhook}] =
        for {_pid, {GithubClient, :create_webhook, _args}, result} <- :meck.history(GithubClient), do: result

      {:ok, updated_repository} = RepositoryHub.Model.RepositoryQuery.get_by_id(repository.id)
      assert updated_repository.hook_id == created_webhook.id

      assert_not_called(GithubClient.remove_webhook(:_, :_))
      assert_not_called(GithubClient.remove_deploy_key(:_, :_))
    end

    test "keeps the created webhook and key when the commit did not land but that cannot be confirmed", %{
      github_app_adapter: adapter
    } do
      repository =
        RepositoryModelFactory.githubapp_repo(
          owner: "old-org",
          url: "git@github.com:old-org/repository.git",
          remote_id: "999"
        )

      DeployKeysModelFactory.create_deploy_key(project_id: repository.project_id, repository_id: repository.id)

      request =
        InternalApiFactory.update_request(
          repository_id: repository.id,
          url: "git@github.com:new-org/repository.git",
          user_id: "requester-user-id"
        )

      with_mocks [
        {RepositoryIntegratorClient, [:passthrough],
         get_token: fn
           _integration_type, "old-org/repository", _remote_id -> {:ok, "old-tok"}
           _integration_type, "new-org/repository", _remote_id -> {:ok, "new-tok"}
         end},
        {RepositoryHub.Model.RepositoryQuery, [:passthrough], []},
        {RepositoryHub.Repo, [:passthrough],
         transaction: fn %Ecto.Multi{} ->
           fail_repository_read_back()
           raise DBConnection.ConnectionError, "connection closed"
         end}
      ] do
        assert_raise DBConnection.ConnectionError, fn -> UpdateAction.execute(adapter, request) end
      end

      {:ok, unchanged_repository} = RepositoryHub.Model.RepositoryQuery.get_by_id(repository.id)
      assert unchanged_repository.hook_id == repository.hook_id

      assert_not_called(GithubClient.remove_webhook(:_, :_))
      assert_not_called(GithubClient.remove_deploy_key(:_, :_))
    end

    test "rotates the webhook secret when an orphan webhook already exists on the target", %{
      github_app_adapter: adapter
    } do
      repository =
        RepositoryModelFactory.githubapp_repo(
          owner: "old-org",
          url: "git@github.com:old-org/repository.git",
          remote_id: "999"
        )

      DeployKeysModelFactory.create_deploy_key(project_id: repository.project_id, repository_id: repository.id)

      request =
        InternalApiFactory.update_request(
          repository_id: repository.id,
          url: "git@github.com:new-org/repository.git",
          user_id: "requester-user-id"
        )

      :meck.expect(GithubClient, :find_webhook, fn _params, _opts ->
        {:ok, %{id: "orphan-hook-id", url: "example.com/hooks/github", has_secret?: false}}
      end)

      with_mock RepositoryIntegratorClient, [:passthrough],
        get_token: fn
          _integration_type, "old-org/repository", _remote_id -> {:ok, "old-tok"}
          _integration_type, "new-org/repository", _remote_id -> {:ok, "new-tok"}
        end do
        assert %UpdateResponse{} = UpdateAction.execute(adapter, request)
      end

      {:ok, updated_repository} = RepositoryHub.Model.RepositoryQuery.get_by_id(repository.id)

      assert_called(
        GithubClient.remove_webhook(
          %{repo_owner: "new-org", repo_name: "repository", webhook_id: "orphan-hook-id"},
          token: "new-tok"
        )
      )

      assert_called(GithubClient.create_webhook(%{repo_owner: "new-org", repo_name: "repository"}, token: "new-tok"))

      [sent_secret] =
        for {_pid, {GithubClient, :create_webhook, [params, _opts]}, _result} <- :meck.history(GithubClient),
            do: params.secret

      payload = ~s({"action":"ping"})

      signature =
        "sha256=" <>
          (:crypto.mac(:hmac, :sha256, sent_secret, payload)
           |> Base.encode16()
           |> String.downcase())

      assert {:ok, true} =
               RepositoryHub.Model.Repositories.hook_signature_valid?(updated_repository, payload, signature)
    end

    test "names the webhook and creates nothing when removing a stale webhook on the target fails", %{
      github_app_adapter: adapter
    } do
      repository =
        RepositoryModelFactory.githubapp_repo(
          owner: "old-org",
          url: "git@github.com:old-org/repository.git",
          remote_id: "999"
        )

      DeployKeysModelFactory.create_deploy_key(project_id: repository.project_id, repository_id: repository.id)

      request =
        InternalApiFactory.update_request(
          repository_id: repository.id,
          url: "git@github.com:new-org/repository.git",
          user_id: "requester-user-id"
        )

      :meck.expect(GithubClient, :find_webhook, fn _params, _opts ->
        {:ok, %{id: "stale-hook-id", url: "example.com/hooks/github", has_secret?: false}}
      end)

      :meck.expect(GithubClient, :remove_webhook, fn _params, _opts ->
        {:error, %{status: GRPC.Status.failed_precondition(), message: "Removing webhook failed."}}
      end)

      with_mocks [
        {RepositoryIntegratorClient, [:passthrough],
         get_token: fn
           _integration_type, "old-org/repository", _remote_id -> {:ok, "old-tok"}
           _integration_type, "new-org/repository", _remote_id -> {:ok, "new-tok"}
         end},
        {Watchman, [:passthrough], []}
      ] do
        assert {:error, %{message: message}} = UpdateAction.execute(adapter, request)
        assert message =~ "webhook stale-hook-id"
        assert message =~ "new-org/repository"
        assert_called(Watchman.increment({"github_app.update_url.stale_webhook_removal_failed", []}))
      end

      {:ok, unchanged_repository} = RepositoryHub.Model.RepositoryQuery.get_by_id(repository.id)
      assert unchanged_repository.url == repository.url
      assert unchanged_repository.hook_id == repository.hook_id

      assert_not_called(GithubClient.create_webhook(:_, :_))
      assert_not_called(GithubClient.create_deploy_key(:_, :_))
    end

    test "completes the move even when removing the old webhook and deploy key fails", %{
      github_app_adapter: adapter
    } do
      repository =
        RepositoryModelFactory.githubapp_repo(
          owner: "old-org",
          url: "git@github.com:old-org/repository.git",
          remote_id: "999"
        )

      DeployKeysModelFactory.create_deploy_key(project_id: repository.project_id, repository_id: repository.id)

      request =
        InternalApiFactory.update_request(
          repository_id: repository.id,
          url: "git@github.com:new-org/repository.git",
          user_id: "requester-user-id"
        )

      :meck.expect(GithubClient, :remove_webhook, fn _params, _opts ->
        raise "github is unreachable"
      end)

      :meck.expect(GithubClient, :remove_deploy_key, fn _params, _opts ->
        {:error, %{status: GRPC.Status.unavailable(), message: "github is unreachable"}}
      end)

      with_mocks([
        {RepositoryIntegratorClient, [:passthrough],
         get_token: fn
           _integration_type, "old-org/repository", _remote_id -> {:ok, "old-tok"}
           _integration_type, "new-org/repository", _remote_id -> {:ok, "new-tok"}
         end},
        {Watchman, [:passthrough], [increment: fn _ -> :ok end]}
      ]) do
        assert %UpdateResponse{} = UpdateAction.execute(adapter, request)
      end

      {:ok, updated_repository} = RepositoryHub.Model.RepositoryQuery.get_by_id(repository.id)
      assert updated_repository.url == "git@github.com:new-org/repository.git"
      assert updated_repository.remote_id == "12345"

      [{:ok, created_webhook}] =
        for {_pid, {GithubClient, :create_webhook, _args}, result} <- :meck.history(GithubClient), do: result

      assert updated_repository.hook_id == created_webhook.id
    end

    test "fails with a clear error when the GitHub App has no access to the target repository", %{
      github_app_adapter: adapter
    } do
      repository =
        RepositoryModelFactory.githubapp_repo(
          owner: "old-org",
          url: "git@github.com:old-org/repository.git",
          remote_id: "999"
        )

      DeployKeysModelFactory.create_deploy_key(project_id: repository.project_id, repository_id: repository.id)

      request =
        InternalApiFactory.update_request(
          repository_id: repository.id,
          url: "git@github.com:new-org/repository.git",
          user_id: "requester-user-id"
        )

      :meck.expect(GithubClient, :find_repository, fn _params, _opts ->
        {:error, %{status: GRPC.Status.failed_precondition(), message: "Error while looking up repository"}}
      end)

      with_mocks([
        {RepositoryIntegratorClient, [:passthrough],
         get_token: fn
           _integration_type, "old-org/repository", _remote_id -> {:ok, "old-tok"}
           _integration_type, "new-org/repository", _remote_id -> {:ok, ""}
         end},
        {Watchman, [:passthrough], []}
      ]) do
        assert {:error, %{message: message}} = UpdateAction.execute(adapter, request)

        assert message ==
                 "Semaphore GitHub App is not installed on new-org, or it has no access to repository."

        assert_called(Watchman.increment({"github_app.update_url.target_token_fallback", ["error"]}))
      end

      {:ok, unchanged_repository} = RepositoryHub.Model.RepositoryQuery.get_by_id(repository.id)
      assert unchanged_repository.url == "git@github.com:old-org/repository.git"
      assert unchanged_repository.remote_id == "999"
      assert unchanged_repository.hook_id == repository.hook_id

      assert_called(GithubClient.find_repository(%{repo_owner: "new-org", repo_name: "repository"}, token: "old-tok"))
      assert_not_called(GithubClient.remove_webhook(:_, :_))
      assert_not_called(GithubClient.remove_deploy_key(:_, :_))
    end

    test "renames a repository with the current token when the new name is not known to the installation yet", %{
      github_app_adapter: adapter
    } do
      repository =
        RepositoryModelFactory.githubapp_repo(
          owner: "old-org",
          url: "git@github.com:old-org/repository.git",
          remote_id: "999"
        )

      DeployKeysModelFactory.create_deploy_key(project_id: repository.project_id, repository_id: repository.id)

      request =
        InternalApiFactory.update_request(
          repository_id: repository.id,
          url: "git@github.com:old-org/renamed.git",
          user_id: "requester-user-id"
        )

      with_mocks([
        {RepositoryIntegratorClient, [:passthrough],
         get_token: fn
           _integration_type, _slug, "999" -> {:ok, "old-tok"}
           _integration_type, "old-org/renamed", "" -> {:ok, ""}
         end},
        {Watchman, [:passthrough], []}
      ]) do
        assert %UpdateResponse{} = UpdateAction.execute(adapter, request)

        assert_called(Watchman.increment({"github_app.update_url.target_token_fallback", ["ok"]}))
      end

      {:ok, updated_repository} = RepositoryHub.Model.RepositoryQuery.get_by_id(repository.id)
      assert updated_repository.url == "git@github.com:old-org/renamed.git"

      assert_called(GithubClient.find_repository(%{repo_owner: "old-org", repo_name: "renamed"}, token: "old-tok"))

      assert_called(
        GithubClient.repository_permissions(
          %{repo_owner: "old-org", repo_name: "renamed", username: "radwo"},
          token: "old-tok"
        )
      )

      assert_called(GithubClient.create_webhook(%{repo_owner: "old-org", repo_name: "renamed"}, token: "old-tok"))
      assert_called(GithubClient.create_deploy_key(%{repo_owner: "old-org", repo_name: "renamed"}, token: "old-tok"))
    end

    test "saves settings when the url did not change even if no target token is available", %{
      github_app_adapter: adapter
    } do
      repository = RepositoryModelFactory.githubapp_repo(remote_id: "999")

      request =
        InternalApiFactory.update_request(
          repository_id: repository.id,
          url: "git@github.com:dummy/repository.git",
          pipeline_file: ".semaphore/semaphore-2.yml"
        )

      with_mock RepositoryIntegratorClient, [:passthrough],
        get_token: fn
          _integration_type, _slug, "999" -> {:ok, "old-tok"}
          _integration_type, _slug, "" -> {:ok, ""}
        end do
        assert %UpdateResponse{} = UpdateAction.execute(adapter, request)
      end

      {:ok, updated_repository} = RepositoryHub.Model.RepositoryQuery.get_by_id(repository.id)
      assert updated_repository.pipeline_file == ".semaphore/semaphore-2.yml"

      assert_not_called(GithubClient.find_repository(:_, :_))
    end

    test "saves github_app settings with one token lookup, so a failing second lookup does not matter", %{
      github_app_adapter: adapter
    } do
      repository = RepositoryModelFactory.githubapp_repo()

      request =
        InternalApiFactory.update_request(
          repository_id: repository.id,
          url: "git@github.com:dummy/repository.git",
          pipeline_file: ".semaphore/semaphore-2.yml"
        )

      with_mock RepositoryIntegratorClient, [:passthrough], [] do
        :meck.expect(
          RepositoryIntegratorClient,
          :get_token,
          [:_, :_, :_],
          :meck.seq([{:ok, "tok"}, {:error, "token lookup failed"}])
        )

        assert %UpdateResponse{} = UpdateAction.execute(adapter, request)
        assert_called_exactly(RepositoryIntegratorClient.get_token(:_, :_, :_), 1)
      end

      {:ok, updated_repository} = RepositoryHub.Model.RepositoryQuery.get_by_id(repository.id)
      assert updated_repository.pipeline_file == ".semaphore/semaphore-2.yml"
    end

    test "saves oauth settings with one token lookup, so a failing second lookup does not matter", %{
      github_oauth_adapter: adapter
    } do
      repository = RepositoryModelFactory.github_repo()

      request =
        InternalApiFactory.update_request(
          repository_id: repository.id,
          url: repository.url,
          pipeline_file: ".semaphore/semaphore-2.yml"
        )

      :meck.expect(
        UserClient,
        :get_repository_token,
        [:_, :_],
        :meck.seq([{:ok, "tok"}, {:error, "token lookup failed"}])
      )

      assert %UpdateResponse{} = UpdateAction.execute(adapter, request)

      assert_called_exactly(UserClient.get_repository_token(:_, :_), 1)
      assert_called_exactly(UserClient.describe(:_), 1)

      {:ok, updated_repository} = RepositoryHub.Model.RepositoryQuery.get_by_id(repository.id)
      assert updated_repository.pipeline_file == ".semaphore/semaphore-2.yml"
    end

    test "moves a repository when the old GitHub App installation is gone", %{github_app_adapter: adapter} do
      repository =
        RepositoryModelFactory.githubapp_repo(
          owner: "old-org",
          url: "git@github.com:old-org/repository.git",
          remote_id: "999"
        )

      {:ok, old_deploy_key} =
        DeployKeysModelFactory.create_deploy_key(project_id: repository.project_id, repository_id: repository.id)

      request =
        InternalApiFactory.update_request(
          repository_id: repository.id,
          url: "git@github.com:new-org/repository.git",
          user_id: "requester-user-id"
        )

      with_mock RepositoryIntegratorClient, [:passthrough],
        get_token: fn
          _integration_type, "old-org/repository", _remote_id -> {:ok, ""}
          _integration_type, "new-org/repository", _remote_id -> {:ok, "new-tok"}
        end do
        assert %UpdateResponse{} = UpdateAction.execute(adapter, request)
      end

      {:ok, updated_repository} = RepositoryHub.Model.RepositoryQuery.get_by_id(repository.id)
      assert updated_repository.url == "git@github.com:new-org/repository.git"

      {:ok, new_deploy_key} = RepositoryHub.Model.DeployKeyQuery.get_by_repository_id(repository.id)
      assert new_deploy_key.id != old_deploy_key.id

      assert_not_called(GithubClient.remove_webhook(:_, :_))
      assert_not_called(GithubClient.remove_deploy_key(:_, :_))
      assert_called(GithubClient.create_webhook(%{repo_owner: "new-org", repo_name: "repository"}, token: "new-tok"))
      assert_called(GithubClient.create_deploy_key(%{repo_owner: "new-org", repo_name: "repository"}, token: "new-tok"))
    end

    test "keeps the webhook and deploy key when the url points to the same repository under a new name", %{
      github_app_adapter: adapter
    } do
      repository = RepositoryModelFactory.githubapp_repo(remote_id: "12345", connected: false)
      DeployKeysModelFactory.create_deploy_key(project_id: repository.project_id, repository_id: repository.id)
      {:ok, deploy_key} = RepositoryHub.Model.DeployKeyQuery.get_by_repository_id(repository.id)

      request =
        InternalApiFactory.update_request(
          repository_id: repository.id,
          url: "git@github.com:dummy/renamed.git",
          user_id: "requester-user-id"
        )

      assert %UpdateResponse{} = UpdateAction.execute(adapter, request)

      {:ok, updated_repository} = RepositoryHub.Model.RepositoryQuery.get_by_id(repository.id)
      assert updated_repository.url == "git@github.com:dummy/renamed.git"
      assert updated_repository.name == "renamed"
      assert updated_repository.connected
      assert updated_repository.hook_id == repository.hook_id
      assert {:ok, %{id: deploy_key_id}} = RepositoryHub.Model.DeployKeyQuery.get_by_repository_id(repository.id)
      assert deploy_key_id == deploy_key.id

      assert_called(
        GithubClient.repository_permissions(%{repo_owner: "dummy", repo_name: "renamed", username: "radwo"}, :_)
      )

      assert_not_called(GithubClient.remove_webhook(:_, :_))
      assert_not_called(GithubClient.remove_deploy_key(:_, :_))
      assert_not_called(GithubClient.create_webhook(:_, :_))
      assert_not_called(GithubClient.create_deploy_key(:_, :_))
    end

    test "changes the url and creates a deploy key when the project has none", %{github_app_adapter: adapter} do
      repository = RepositoryModelFactory.githubapp_repo()

      request =
        InternalApiFactory.update_request(
          repository_id: repository.id,
          url: "git@github.com:dummy/repository-2.git",
          user_id: "requester-user-id"
        )

      assert %UpdateResponse{} = UpdateAction.execute(adapter, request)

      {:ok, updated_repository} = RepositoryHub.Model.RepositoryQuery.get_by_id(repository.id)
      assert updated_repository.url == "git@github.com:dummy/repository-2.git"
      assert {:ok, _} = RepositoryHub.Model.DeployKeyQuery.get_by_repository_id(repository.id)

      assert_not_called(GithubClient.remove_deploy_key(:_, :_))
      assert_called(GithubClient.create_deploy_key(%{repo_owner: "dummy", repo_name: "repository-2"}, :_))
    end

    test "changes the url of an oauth repository using the user token for lookup and create", %{
      github_oauth_adapter: adapter
    } do
      repository = RepositoryModelFactory.github_repo()
      DeployKeysModelFactory.create_deploy_key(project_id: repository.project_id, repository_id: repository.id)

      request =
        InternalApiFactory.update_request(
          repository_id: repository.id,
          url: "git@github.com:other-owner/other-repository.git",
          user_id: "requester-user-id"
        )

      assert %UpdateResponse{} = UpdateAction.execute(adapter, request)

      {:ok, updated_repository} = RepositoryHub.Model.RepositoryQuery.get_by_id(repository.id)
      assert updated_repository.owner == "other-owner"
      assert updated_repository.name == "other-repository"

      [lookup_token] =
        for {_pid, {GithubClient, :find_repository, [_params, opts]}, _result} <- :meck.history(GithubClient),
            do: opts[:token]

      [create_token] =
        for {_pid, {GithubClient, :create_webhook, [_params, opts]}, _result} <- :meck.history(GithubClient),
            do: opts[:token]

      assert String.ends_with?(lookup_token, "-github_oauth_token")
      assert create_token == lookup_token
      assert_called_exactly(UserClient.get_repository_token(:_, :_), 1)

      assert_called(
        GithubClient.repository_permissions(
          %{repo_owner: "other-owner", repo_name: "other-repository", username: "radwo"},
          token: lookup_token
        )
      )
    end
  end

  describe "Github UpdateAction requester check" do
    test "rejects a url change without a requester", %{github_app_adapter: adapter} do
      repository = RepositoryModelFactory.githubapp_repo()

      request =
        InternalApiFactory.update_request(
          repository_id: repository.id,
          url: "git@github.com:dummy/repository-2.git"
        )

      assert {:error, %{status: status, message: message}} = UpdateAction.execute(adapter, request)
      assert status == GRPC.Status.failed_precondition()
      assert message == "Changing the repository URL requires a known requester."

      {:ok, unchanged_repository} = RepositoryHub.Model.RepositoryQuery.get_by_id(repository.id)
      assert unchanged_repository.url == repository.url

      assert_not_called(UserClient.describe(:_))
      assert_not_called(GithubClient.find_repository(:_, :_))
      assert_not_called(GithubClient.create_webhook(:_, :_))
    end

    test "rejects a url change when the requester cannot push to the target repository", %{
      github_app_adapter: adapter
    } do
      repository =
        RepositoryModelFactory.githubapp_repo(
          owner: "old-org",
          url: "git@github.com:old-org/repository.git",
          remote_id: "999"
        )

      DeployKeysModelFactory.create_deploy_key(project_id: repository.project_id, repository_id: repository.id)

      request =
        InternalApiFactory.update_request(
          repository_id: repository.id,
          url: "git@github.com:new-org/repository.git",
          user_id: "requester-user-id"
        )

      :meck.expect(GithubClient, :repository_permissions, fn _params, _opts ->
        {:ok, %{"admin" => false, "push" => false, "pull" => true}}
      end)

      with_mock RepositoryIntegratorClient, [:passthrough],
        get_token: fn
          _integration_type, "old-org/repository", _remote_id -> {:ok, "old-tok"}
          _integration_type, "new-org/repository", _remote_id -> {:ok, "new-tok"}
        end do
        assert {:error, %{message: message}} = UpdateAction.execute(adapter, request)

        assert message ==
                 "Write permissions are required on the repository to change the project's repository URL."
      end

      {:ok, unchanged_repository} = RepositoryHub.Model.RepositoryQuery.get_by_id(repository.id)
      assert unchanged_repository.url == "git@github.com:old-org/repository.git"
      assert unchanged_repository.hook_id == repository.hook_id

      assert_not_called(GithubClient.remove_webhook(:_, :_))
      assert_not_called(GithubClient.remove_deploy_key(:_, :_))
      assert_not_called(GithubClient.create_webhook(:_, :_))
      assert_not_called(GithubClient.create_deploy_key(:_, :_))
    end

    test "rejects a url change when the requester has no GitHub account connected", %{
      github_app_adapter: adapter
    } do
      repository = RepositoryModelFactory.githubapp_repo()

      request =
        InternalApiFactory.update_request(
          repository_id: repository.id,
          url: "git@github.com:dummy/repository-2.git",
          user_id: "requester-user-id"
        )

      :meck.expect(UserClient, :get_repository_provider_logins, fn :GITHUB, _user_id -> {:ok, []} end)

      assert {:error, %{message: message}} = UpdateAction.execute(adapter, request)
      assert message == "Connect your GitHub account to Semaphore to change the repository URL."

      {:ok, unchanged_repository} = RepositoryHub.Model.RepositoryQuery.get_by_id(repository.id)
      assert unchanged_repository.url == repository.url

      assert_not_called(GithubClient.repository_permissions(:_, :_))
      assert_not_called(GithubClient.create_webhook(:_, :_))
    end

    test "rejects a url change requested by a service account", %{github_app_adapter: adapter} do
      repository =
        RepositoryModelFactory.githubapp_repo(
          owner: "old-org",
          url: "git@github.com:old-org/repository.git",
          remote_id: "999"
        )

      request =
        InternalApiFactory.update_request(
          repository_id: repository.id,
          url: "git@github.com:old-org/other.git",
          user_id: "service-account-user-id"
        )

      assert {:error, %{message: message}} = UpdateAction.execute(adapter, request)
      assert message == "Service accounts can't change the repository URL."

      {:ok, unchanged_repository} = RepositoryHub.Model.RepositoryQuery.get_by_id(repository.id)
      assert unchanged_repository.url == "git@github.com:old-org/repository.git"

      assert_not_called(GithubClient.find_repository(:_, :_))
      assert_not_called(GithubClient.remove_webhook(:_, :_))
      assert_not_called(GithubClient.create_webhook(:_, :_))
    end

    for {requester, user_id} <- [
          {"a person", "requester-user-id"},
          {"a service account", "service-account-user-id"}
        ] do
      test "stores GitHub's owner, name and url when #{requester} saves a url that differs only in letter case", %{
        github_app_adapter: adapter
      } do
        repository =
          RepositoryModelFactory.githubapp_repo(
            owner: "OldCase",
            url: "git@github.com:OldCase/repository.git",
            remote_id: "12345"
          )

        github_reports("12345", "oldcase", "repository")

        request =
          InternalApiFactory.update_request(
            repository_id: repository.id,
            url: "git@github.com:OLDCASE/Repository.git",
            pipeline_file: ".semaphore/semaphore-2.yml",
            user_id: unquote(user_id)
          )

        with_mock RepositoryIntegratorClient, [:passthrough], [] do
          :meck.expect(
            RepositoryIntegratorClient,
            :get_token,
            [:_, :_, :_],
            :meck.seq([{:ok, "tok"}, {:error, "token lookup failed"}])
          )

          assert %UpdateResponse{repository: response_repository} = UpdateAction.execute(adapter, request)
          assert response_repository.url == "git@github.com:oldcase/repository.git"
          assert_called_exactly(RepositoryIntegratorClient.get_token(:_, :_, :_), 1)
        end

        {:ok, updated_repository} = RepositoryHub.Model.RepositoryQuery.get_by_id(repository.id)
        assert updated_repository.pipeline_file == ".semaphore/semaphore-2.yml"
        assert updated_repository.owner == "oldcase"
        assert updated_repository.name == "repository"
        assert updated_repository.url == "git@github.com:oldcase/repository.git"
        assert updated_repository.hook_id == repository.hook_id

        assert_called(GithubClient.find_repository(:_, token: "tok"))
        assert_not_called(UserClient.describe(:_))
        assert_not_called(GithubClient.create_webhook(:_, :_))
        assert_not_called(GithubClient.create_deploy_key(:_, :_))
        assert_not_called(GithubClient.remove_webhook(:_, :_))
        assert_not_called(GithubClient.remove_deploy_key(:_, :_))
      end
    end

    test "saves the settings and keeps the url when GitHub reports another repository under that name", %{
      github_app_adapter: adapter
    } do
      repository =
        RepositoryModelFactory.githubapp_repo(
          owner: "OldCase",
          url: "git@github.com:OldCase/repository.git",
          remote_id: "999"
        )

      github_reports("12345", "oldcase", "repository")

      request =
        InternalApiFactory.update_request(
          repository_id: repository.id,
          url: "git@github.com:oldcase/repository.git",
          pipeline_file: ".semaphore/semaphore-2.yml",
          user_id: "service-account-user-id"
        )

      assert %UpdateResponse{} = UpdateAction.execute(adapter, request)

      {:ok, updated_repository} = RepositoryHub.Model.RepositoryQuery.get_by_id(repository.id)
      assert updated_repository.pipeline_file == ".semaphore/semaphore-2.yml"
      assert updated_repository.owner == "OldCase"
      assert updated_repository.url == "git@github.com:OldCase/repository.git"
      assert updated_repository.remote_id == "999"

      assert_called(GithubClient.find_repository(:_, :_))
    end

    for {failure, lookup} <- [
          {"answers with an error", quote(do: fn _params, _opts -> {:error, "lookup failed"} end)},
          {"raises", quote(do: fn _params, _opts -> raise "connection closed" end)}
        ] do
      test "saves the settings and keeps the url when the lookup of a case-only url #{failure}", %{
        github_app_adapter: adapter
      } do
        repository =
          RepositoryModelFactory.githubapp_repo(
            owner: "OldCase",
            url: "git@github.com:OldCase/repository.git",
            remote_id: "12345"
          )

        :meck.expect(GithubClient, :find_repository, unquote(lookup))

        request =
          InternalApiFactory.update_request(
            repository_id: repository.id,
            url: "git@github.com:oldcase/repository.git",
            pipeline_file: ".semaphore/semaphore-2.yml",
            user_id: "service-account-user-id"
          )

        assert %UpdateResponse{} = UpdateAction.execute(adapter, request)

        {:ok, updated_repository} = RepositoryHub.Model.RepositoryQuery.get_by_id(repository.id)
        assert updated_repository.pipeline_file == ".semaphore/semaphore-2.yml"
        assert updated_repository.url == "git@github.com:OldCase/repository.git"

        assert_called(GithubClient.find_repository(:_, :_))
      end
    end

    test "stores the owner and name GitHub reports, not the letter case of the requested url", %{
      github_app_adapter: adapter
    } do
      repository = RepositoryModelFactory.githubapp_repo()

      :meck.expect(GithubClient, :find_repository, fn params, opts ->
        {:ok, github_repository} = GithubClientFactory.find_repository_mock(params, opts)

        {:ok,
         %{
           github_repository
           | owner: "new-org",
             name: "repository",
             ssh_url: "git@github.com:new-org/repository.git"
         }}
      end)

      request =
        InternalApiFactory.update_request(
          repository_id: repository.id,
          url: "git@github.com:New-Org/Repository.git",
          user_id: "requester-user-id"
        )

      assert %UpdateResponse{repository: response_repository} = UpdateAction.execute(adapter, request)
      assert response_repository.url == "git@github.com:new-org/repository.git"

      {:ok, updated_repository} = RepositoryHub.Model.RepositoryQuery.get_by_id(repository.id)
      assert updated_repository.owner == "new-org"
      assert updated_repository.name == "repository"
      assert updated_repository.url == "git@github.com:new-org/repository.git"
    end

    test "rejects an oauth url change when the requester is not an admin of the target repository", %{
      github_oauth_adapter: adapter
    } do
      repository = RepositoryModelFactory.github_repo()
      DeployKeysModelFactory.create_deploy_key(project_id: repository.project_id, repository_id: repository.id)

      request =
        InternalApiFactory.update_request(
          repository_id: repository.id,
          url: "git@github.com:other-owner/other-repository.git",
          user_id: "requester-user-id"
        )

      :meck.expect(GithubClient, :repository_permissions, fn _params, _opts ->
        {:ok, %{"admin" => false, "push" => true, "pull" => true}}
      end)

      assert {:error, %{message: message}} = UpdateAction.execute(adapter, request)
      assert message == "Admin permissions are required on the repository to change the project's repository URL."

      {:ok, unchanged_repository} = RepositoryHub.Model.RepositoryQuery.get_by_id(repository.id)
      assert unchanged_repository.url == repository.url

      assert_not_called(GithubClient.remove_webhook(:_, :_))
      assert_not_called(GithubClient.create_webhook(:_, :_))
    end

    test "rejects an oauth url change requested by a service account", %{github_oauth_adapter: adapter} do
      repository = RepositoryModelFactory.github_repo()

      request =
        InternalApiFactory.update_request(
          repository_id: repository.id,
          url: "git@github.com:other-owner/other-repository.git",
          user_id: "service-account-user-id"
        )

      assert {:error, %{message: message}} = UpdateAction.execute(adapter, request)

      assert message == "Service accounts can't change the repository URL."

      {:ok, unchanged_repository} = RepositoryHub.Model.RepositoryQuery.get_by_id(repository.id)
      assert unchanged_repository.url == repository.url

      assert_not_called(GithubClient.find_repository(:_, :_))
      assert_not_called(GithubClient.create_webhook(:_, :_))
    end
  end

  describe "Github UpdateAction overlapping url changes" do
    test "leaves one deploy key when the project has none", %{github_app_adapter: adapter} do
      with_real_connections(fn pool ->
        repository = RepositoryModelFactory.githubapp_repo()

        assert_one_deploy_key_after_overlapping_url_changes(adapter, repository, pool)
      end)
    end

    test "leaves one deploy key when the project has one", %{github_app_adapter: adapter} do
      with_real_connections(fn pool ->
        repository = RepositoryModelFactory.githubapp_repo()
        DeployKeysModelFactory.create_deploy_key(project_id: repository.project_id, repository_id: repository.id)

        assert_one_deploy_key_after_overlapping_url_changes(adapter, repository, pool)
      end)
    end

    test "leaves one deploy key when regenerating a key that does not exist overlaps a url change", %{
      github_app_adapter: adapter
    } do
      with_real_connections(fn pool ->
        repository = RepositoryModelFactory.githubapp_repo()

        assert_one_deploy_key_after_regenerate_overlaps_url_change(adapter, repository, pool)
      end)
    end

    test "leaves one deploy key when regenerating the key overlaps a url change", %{github_app_adapter: adapter} do
      with_real_connections(fn pool ->
        repository = RepositoryModelFactory.githubapp_repo()
        DeployKeysModelFactory.create_deploy_key(project_id: repository.project_id, repository_id: repository.id)

        assert_one_deploy_key_after_regenerate_overlaps_url_change(adapter, repository, pool)
      end)
    end
  end

  defp github_reports(id, owner, name) do
    :meck.expect(GithubClient, :find_repository, fn params, opts ->
      {:ok, github_repository} = GithubClientFactory.find_repository_mock(params, opts)

      {:ok,
       %{
         github_repository
         | id: id,
           owner: owner,
           name: name,
           ssh_url: "git@github.com:#{owner}/#{name}.git"
       }}
    end)
  end

  defp fail_repository_read_back do
    :meck.expect(RepositoryHub.Model.RepositoryQuery, :get_by_id, fn _id -> {:error, "connection closed"} end)
  end

  defp with_real_connections(test_body) do
    {:ok, pool} = Repo.start_link(name: nil, pool: DBConnection.ConnectionPool, pool_size: 3)
    Repo.put_dynamic_repo(pool)

    try do
      test_body.(pool)
    after
      Repo.delete_all(RepositoryHub.Model.DeployKeys)
      Repo.delete_all(RepositoryHub.Model.Repositories)
      Repo.put_dynamic_repo(Repo)
      Supervisor.stop(pool)
    end
  end

  defp assert_one_deploy_key_after_overlapping_url_changes(adapter, repository, pool) do
    test_process = self()

    :meck.expect(GithubClient, :create_deploy_key, fn _params, _opts ->
      send(test_process, {:creating_deploy_key, self()})

      receive do
        :continue -> {:ok, %{id: System.unique_integer([:positive])}}
      end
    end)

    with_mock RepositoryHub.Model.DeployKeys, [:passthrough],
      generate_private_public_key_pair: fn -> {"private-key", "public-key"} end do
      requests =
        for name <- ["repository-2", "repository-3"] do
          Task.async(fn ->
            Repo.put_dynamic_repo(pool)

            request =
              InternalApiFactory.update_request(
                repository_id: repository.id,
                url: "git@github.com:dummy/#{name}.git",
                user_id: "requester-user-id"
              )

            UpdateAction.execute(adapter, request)
          end)
        end

      assert_receive {:creating_deploy_key, first_request}, 5_000
      assert_receive {:creating_deploy_key, second_request}, 5_000
      send(first_request, :continue)
      send(second_request, :continue)

      assert [%UpdateResponse{}, %UpdateResponse{}] = Task.await_many(requests)
    end

    assert [_deploy_key] =
             Repo.all(from(key in RepositoryHub.Model.DeployKeys, where: key.project_id == ^repository.project_id))

    assert {:ok, _} = RepositoryHub.Model.DeployKeyQuery.get_by_repository_id(repository.id)
  end

  defp assert_one_deploy_key_after_regenerate_overlaps_url_change(adapter, repository, pool) do
    test_process = self()
    key_pair = RepositoryHub.Model.DeployKeys.generate_private_public_key_pair()

    :meck.expect(GithubClient, :create_deploy_key, fn
      %{repo_name: "repository-2"}, _opts ->
        {:ok, %{id: System.unique_integer([:positive]), title: "url change"}}

      _params, _opts ->
        send(test_process, {:regenerating_deploy_key, self()})

        receive do
          :continue -> {:ok, %{id: System.unique_integer([:positive]), title: "regenerate"}}
        end
    end)

    with_mock RepositoryHub.Model.DeployKeys, [:passthrough], generate_private_public_key_pair: fn -> key_pair end do
      regenerate =
        Task.async(fn ->
          Repo.put_dynamic_repo(pool)

          RegenerateDeployKeyAction.execute(
            adapter,
            InternalApiFactory.regenerate_deploy_key_request(repository_id: repository.id)
          )
        end)

      assert_receive {:regenerating_deploy_key, regenerate_process}, 5_000

      url_change =
        Task.async(fn ->
          Repo.put_dynamic_repo(pool)

          UpdateAction.execute(
            adapter,
            InternalApiFactory.update_request(
              repository_id: repository.id,
              url: "git@github.com:dummy/repository-2.git",
              user_id: "requester-user-id"
            )
          )
        end)

      wait_for_query_blocked_on_a_lock()
      send(regenerate_process, :continue)

      assert [{:ok, %RegenerateDeployKeyResponse{}}, %UpdateResponse{}] = Task.await_many([regenerate, url_change])
    end

    assert [_deploy_key] =
             Repo.all(from(key in RepositoryHub.Model.DeployKeys, where: key.project_id == ^repository.project_id))

    assert {:ok, _} = RepositoryHub.Model.DeployKeyQuery.get_by_repository_id(repository.id)
  end

  defp wait_for_query_blocked_on_a_lock(attempts \\ 60)
  defp wait_for_query_blocked_on_a_lock(0), do: :ok

  defp wait_for_query_blocked_on_a_lock(attempts) do
    %{rows: [[blocked]]} =
      Repo.query!(
        "SELECT count(*) FROM pg_stat_activity WHERE datname = current_database() AND wait_event_type = 'Lock'"
      )

    if blocked == 0 do
      Process.sleep(50)
      wait_for_query_blocked_on_a_lock(attempts - 1)
    end
  end

  defp assert_old_resources_kept_and_created_resources_removed(repository, deploy_key) do
    {:ok, unchanged_repository} = RepositoryHub.Model.RepositoryQuery.get_by_id(repository.id)
    assert unchanged_repository.url == "git@github.com:old-org/repository.git"
    assert unchanged_repository.remote_id == "999"
    assert unchanged_repository.hook_id == repository.hook_id
    assert {:ok, %{id: deploy_key_id}} = RepositoryHub.Model.DeployKeyQuery.get_by_repository_id(repository.id)
    assert deploy_key_id == deploy_key.id

    [{:ok, created_webhook}] =
      for {_pid, {GithubClient, :create_webhook, _args}, result} <- :meck.history(GithubClient), do: result

    [{:ok, created_key}] =
      for {_pid, {GithubClient, :create_deploy_key, _args}, result} <- :meck.history(GithubClient), do: result

    assert_called(
      GithubClient.remove_webhook(%{repo_owner: "new-org", webhook_id: created_webhook.id}, token: "new-tok")
    )

    assert_called(GithubClient.remove_deploy_key(%{repo_owner: "new-org", key_id: created_key.id}, token: "new-tok"))
    assert_not_called(GithubClient.remove_webhook(%{repo_owner: "old-org"}, :_))
    assert_not_called(GithubClient.remove_deploy_key(%{repo_owner: "old-org"}, :_))
  end
end
