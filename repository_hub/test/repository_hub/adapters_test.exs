defmodule RepositoryHub.AdaptersTest do
  use RepositoryHub.Case, async: false
  doctest RepositoryHub.Adapters, import: true
  alias RepositoryHub.{InternalApiFactory, RepositoryModelFactory, Adapters}

  setup do
    integration_type_mapping = [
      {:GITHUB_OAUTH_TOKEN, Adapters.github_oauth()},
      {:GITHUB_APP, Adapters.github_app()},
      {:BITBUCKET, Adapters.bitbucket()},
      {:GITLAB, Adapters.gitlab()}
    ]

    [github_repo, githubapp_repo, bitbucket_repo, gitlab_repo] = RepositoryModelFactory.seed_repositories()

    repository_id_mapping = [
      {github_repo.id, Adapters.github_oauth()},
      {githubapp_repo.id, Adapters.github_app()},
      {bitbucket_repo.id, Adapters.bitbucket()},
      {gitlab_repo.id, Adapters.gitlab()}
    ]

    %{
      repository_id_mapping: repository_id_mapping,
      integration_type_mapping: integration_type_mapping
    }
  end

  describe "selecting adapter" do
    test "works as expected for DescribeRequest" do
      request = InternalApiFactory.describe_request()
      assert {:ok, Adapters.universal()} == Adapters.pick(request)
    end

    test "works as expected for ListRequest" do
      request = InternalApiFactory.list_request()
      assert {:ok, Adapters.universal()} == Adapters.pick(request)
    end

    test "works as expected for CreateRequest", %{integration_type_mapping: integration_type_mapping} do
      for {integration_type, selected_adapter} <- integration_type_mapping do
        request = InternalApiFactory.create_request(integration_type: integration_type)
        assert {:ok, selected_adapter} == Adapters.pick(request)
      end
    end

    test "works as expected for DeleteRequest", %{repository_id_mapping: repository_id_mapping} do
      for {repository_id, selected_adapter} <- repository_id_mapping do
        request = InternalApiFactory.delete_request(repository_id: repository_id)
        assert {:ok, selected_adapter} == Adapters.pick(request)
      end
    end

    test "works as expected for GetFileRequest", %{repository_id_mapping: repository_id_mapping} do
      for {repository_id, selected_adapter} <- repository_id_mapping do
        request = InternalApiFactory.get_file_request(repository_id: repository_id)
        assert {:ok, selected_adapter} == Adapters.pick(request)
      end
    end

    test "works as expected for GetFilesRequest", %{repository_id_mapping: repository_id_mapping} do
      for {repository_id, selected_adapter} <- repository_id_mapping do
        request = InternalApiFactory.get_files_request(repository_id: repository_id)
        assert {:ok, selected_adapter} == Adapters.pick(request)
      end
    end

    test "works as expected for GetChangedFilePathsRequest", %{
      repository_id_mapping: repository_id_mapping
    } do
      for {repository_id, selected_adapter} <- repository_id_mapping do
        request = InternalApiFactory.get_changed_file_paths_request(repository_id: repository_id)
        assert {:ok, selected_adapter} == Adapters.pick(request)
      end
    end

    test "works as expected for CommitRequest", %{repository_id_mapping: repository_id_mapping} do
      for {repository_id, selected_adapter} <- repository_id_mapping do
        request = InternalApiFactory.commit_request(repository_id: repository_id)
        assert {:ok, selected_adapter} == Adapters.pick(request)
      end
    end

    test "works as expected for GetSshKeyRequest" do
      request = InternalApiFactory.get_ssh_key_request()
      assert {:ok, Adapters.universal()} == Adapters.pick(request)
    end

    test "works as expected for ListAccessibleRepositoriesRequest", %{
      integration_type_mapping: integration_type_mapping
    } do
      for {integration_type, selected_adapter} <- integration_type_mapping do
        request = InternalApiFactory.list_accessible_repositories_request(integration_type: integration_type)

        assert {:ok, selected_adapter} == Adapters.pick(request)
      end
    end

    test "works as expected for ListCollaboratorsRequest", %{
      repository_id_mapping: repository_id_mapping
    } do
      for {repository_id, selected_adapter} <- repository_id_mapping do
        request = InternalApiFactory.list_collaborators_request(repository_id: repository_id)
        assert {:ok, selected_adapter} == Adapters.pick(request)
      end
    end

    test "works as expected for CreateBuildStatusRequest", %{
      repository_id_mapping: repository_id_mapping
    } do
      for {repository_id, selected_adapter} <- repository_id_mapping do
        request = InternalApiFactory.create_build_status_request(repository_id: repository_id)
        assert {:ok, selected_adapter} == Adapters.pick(request)
      end
    end

    test "works as expected for ForkRequest", %{
      integration_type_mapping: integration_type_mapping
    } do
      for {integration_type, selected_adapter} <- integration_type_mapping do
        request = InternalApiFactory.fork_request(integration_type: integration_type)

        assert {:ok, selected_adapter} == Adapters.pick(request)
      end
    end

    test "works as expected for CheckDeployKeyRequest", %{
      repository_id_mapping: repository_id_mapping
    } do
      for {repository_id, selected_adapter} <- repository_id_mapping do
        request = InternalApiFactory.check_deploy_key_request(repository_id: repository_id)
        assert {:ok, selected_adapter} == Adapters.pick(request)
      end
    end

    test "works as expected for RegenerateDeployKeyRequest", %{
      repository_id_mapping: repository_id_mapping
    } do
      for {repository_id, selected_adapter} <- repository_id_mapping do
        request = InternalApiFactory.regenerate_deploy_key_request(repository_id: repository_id)
        assert {:ok, selected_adapter} == Adapters.pick(request)
      end
    end

    test "works as expected for CheckWebhookRequest", %{
      repository_id_mapping: repository_id_mapping
    } do
      for {repository_id, selected_adapter} <- repository_id_mapping do
        request = InternalApiFactory.check_webhook_request(repository_id: repository_id)
        assert {:ok, selected_adapter} == Adapters.pick(request)
      end
    end

    test "works as expected for RegenerateWebhookRequest", %{
      repository_id_mapping: repository_id_mapping
    } do
      for {repository_id, selected_adapter} <- repository_id_mapping do
        request = InternalApiFactory.regenerate_webhook_request(repository_id: repository_id)
        assert {:ok, selected_adapter} == Adapters.pick(request)
      end
    end
  end
end
