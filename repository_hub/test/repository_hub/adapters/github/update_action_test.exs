defmodule RepositoryHub.Server.Github.UpdateActionTest do
  @moduledoc false
  use RepositoryHub.ServerActionCase, async: false

  alias RepositoryHub.Adapters
  alias RepositoryHub.Server.UpdateAction
  alias RepositoryHub.InternalApiFactory

  alias RepositoryHub.{
    GithubClient,
    GithubClientFactory,
    RepositoryIntegratorClient,
    DeployKeysModelFactory,
    RepositoryModelFactory
  }

  alias InternalApi.Repository.UpdateResponse
  import Mock

  setup_with_mocks(
    for {GithubClient, opts, mocks} <- GithubClientFactory.mocks() do
      {GithubClient, opts,
       [
         find_webhook: fn _params, _opts ->
           {:error, %{status: GRPC.Status.not_found(), message: "Webhook not found"}}
         end
       ] ++ mocks}
    end
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
    end

    test "renames a github_app repository within the same installation", %{github_app_adapter: adapter} do
      repository = RepositoryModelFactory.githubapp_repo()
      DeployKeysModelFactory.create_deploy_key(project_id: repository.project_id, repository_id: repository.id)

      request =
        InternalApiFactory.update_request(
          repository_id: repository.id,
          url: "git@github.com:dummy/repository-2.git"
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
          private: false
        )

      DeployKeysModelFactory.create_deploy_key(project_id: repository.project_id, repository_id: repository.id)

      request =
        InternalApiFactory.update_request(
          repository_id: repository.id,
          url: "git@github.com:new-org/repository.git"
        )

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

      assert_called(GithubClient.find_repository(%{repo_owner: "new-org", repo_name: "repository"}, token: "new-tok"))
      assert_called(GithubClient.remove_webhook(%{repo_owner: "old-org", repo_name: "repository"}, token: "old-tok"))
      assert_called(GithubClient.remove_deploy_key(%{repo_owner: "old-org", repo_name: "repository"}, token: "old-tok"))
      assert_called(GithubClient.create_webhook(%{repo_owner: "new-org", repo_name: "repository"}, token: "new-tok"))
      assert_called(GithubClient.create_deploy_key(%{repo_owner: "new-org", repo_name: "repository"}, token: "new-tok"))
    end

    test "changes the url of an oauth repository using the user token for lookup and create", %{
      github_oauth_adapter: adapter
    } do
      repository = RepositoryModelFactory.github_repo()
      DeployKeysModelFactory.create_deploy_key(project_id: repository.project_id, repository_id: repository.id)

      request =
        InternalApiFactory.update_request(
          repository_id: repository.id,
          url: "git@github.com:other-owner/other-repository.git"
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
    end
  end
end
