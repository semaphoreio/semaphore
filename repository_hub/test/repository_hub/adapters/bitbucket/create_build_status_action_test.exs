defmodule RepositoryHub.Server.Bitbucket.CreateBuildStatusActionTest do
  @moduledoc false
  use RepositoryHub.ServerActionCase, async: false

  alias RepositoryHub.Adapters
  alias RepositoryHub.Server.CreateBuildStatusAction
  alias RepositoryHub.{BitbucketClient, InternalApiFactory, BitbucketClientFactory, RepositoryModelFactory}

  import Mock

  describe "Bitbucket CreateBuildStatusAction" do
    setup_with_mocks(BitbucketClientFactory.mocks()) do
      %{
        repository: RepositoryModelFactory.bitbucket_repo(),
        adapter: Adapters.bitbucket()
      }
    end

    test "should create a build status", %{adapter: adapter, repository: repository} do
      request = InternalApiFactory.create_build_status_request(repository_id: repository.id)
      result = CreateBuildStatusAction.execute(adapter, request)

      assert {:ok, _response} = result
    end

    test "should truncate build status context to accepted length", %{adapter: adapter, repository: repository} do
      with_mock(BitbucketClient,
        create_build_status: fn _, _ ->
          {:ok, %Google.Protobuf.Empty{}}
        end
      ) do
        request =
          InternalApiFactory.create_build_status_request(
            repository_id: repository.id,
            context: "b6fb43d1-b7b5-4e17-8290-68daa1866305_too-big"
          )

        CreateBuildStatusAction.execute(adapter, request)

        assert_called(
          BitbucketClient.create_build_status(
            %{
              repo_owner: "dummy",
              repo_name: "repository",
              commit_sha: request.commit_sha,
              status: "SUCCESSFUL",
              url: request.url,
              context: "b6fb43d1-b7b5-4e17-8290-68daa1866305_too",
              description: request.description
            },
            :_
          )
        )
      end
    end

    test "should validate a request", %{adapter: adapter, repository: repository} do
      request = InternalApiFactory.create_build_status_request(repository_id: repository.id)
      assert {:ok, _} = CreateBuildStatusAction.validate(adapter, request)

      invalid_assertions = [
        repository_id: "",
        repository_id: "not an uuid",
        commit_sha: "",
        commit_sha: "not a sha",
        status: "",
        status: "not a status",
        url: "",
        url: "not url",
        description: "",
        context: ""
      ]

      for {key, invalid_value} <- invalid_assertions do
        request = Map.put(request, key, invalid_value)
        assert {:error, _} = CreateBuildStatusAction.validate(adapter, request)
      end
    end
  end
end
