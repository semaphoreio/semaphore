defmodule RepositoryHub.Server.Github.CreateActionTest do
  @moduledoc false
  use RepositoryHub.ServerActionCase, async: false

  alias RepositoryHub.Adapters
  alias RepositoryHub.Server.CreateAction
  alias RepositoryHub.InternalApiFactory
  alias InternalApi

  alias RepositoryHub.GithubClientFactory

  alias InternalApi.Repository.CreateResponse
  import Mock

  setup_with_mocks(
    GithubClientFactory.mocks() ++
      [
        {RepositoryHub.UserClient, [:passthrough],
         [
           describe: fn user_id ->
             # Return regular user by default, service account for specific test user
             if user_id == "service-account-user-id" do
               {:ok,
                %{
                  user_id: user_id,
                  user: %{creation_source: :SERVICE_ACCOUNT}
                }}
             else
               {:ok,
                %{
                  user_id: user_id,
                  user: %{creation_source: :NOT_SET}
                }}
             end
           end,
           get_repository_provider_logins: fn _, _ -> {:ok, ["radwo"]} end,
           get_repository_token: fn _integration_type, _user_id ->
             {:ok, "mock-oauth-token"}
           end
         ]}
      ]
  ) do
    %{github_app_adapter: Adapters.github_app(), github_oauth_adapter: Adapters.github_oauth()}
  end

  describe "Github CreateAction" do
    test "should create a repository", %{github_app_adapter: adapter} do
      request = InternalApiFactory.create_request(integration_type: :GITHUB_APP)

      assert {:ok, %CreateResponse{repository: _repository}} = CreateAction.execute(adapter, request)
    end

    test "should fail with insufficient rights on a github oauth repository", %{github_oauth_adapter: adapter} do
      request =
        InternalApiFactory.create_request(
          integration_type: :GITHUB_OAUTH_TOKEN,
          repository_url: "https://github.com/not_my_org/not_my_repo"
        )

      assert {:error, _} = CreateAction.execute(adapter, request)
    end

    test "should succeed with insufficient rights on a github app repository", %{github_app_adapter: adapter} do
      request =
        InternalApiFactory.create_request(
          integration_type: :GITHUB_APP,
          repository_url: "https://github.com/not_my_org/not_my_repo"
        )

      assert {:ok, _} = CreateAction.execute(adapter, request)
    end

    test "should fail when open source project want to create private repository", %{github_app_adapter: adapter} do
      request =
        InternalApiFactory.create_request(
          integration_type: :GITHUB_APP,
          repository_url: "https://github.com/open_source_org/not_my_repo",
          only_public: true
        )

      assert {:error, _} = CreateAction.execute(adapter, request)
    end

    test "should succeed when open source project want to create public repository", %{github_app_adapter: adapter} do
      request =
        InternalApiFactory.create_request(
          integration_type: :GITHUB_APP,
          repository_url: "https://github.com/open_source_org/not_my_repo",
          only_public: true,
          private: false
        )

      assert {:error, _} = CreateAction.execute(adapter, request)
    end

    test "should validate a request", %{github_app_adapter: adapter} do
      assertions = [
        {true, []},
        {false, integration_type: :GIT},
        {false, integration_type: :BITBUCKET},
        {true, integration_type: :GITHUB_OAUTH_TOKEN},
        {true, integration_type: :GITHUB_APP},
        {false, integration_type: -1},
        {false, integration_type: 3},
        {false, repository_url: ""},
        {false, repository_url: "https://gitlab.com/foo/bar"}
      ]

      for {true, params} <- assertions do
        request =
          InternalApiFactory.create_request()
          |> struct(params)

        assert {:ok, _} = CreateAction.validate(adapter, request)
      end

      for {false, params} <- assertions do
        request = InternalApiFactory.create_request() |> struct(params)

        assert(
          match?({:error, _}, CreateAction.validate(adapter, request)),
          "should fail validation when given #{inspect(params)}"
        )
      end
    end

    test "should succeed for service account with github_app integration", %{github_app_adapter: adapter} do
      request =
        InternalApiFactory.create_request(
          integration_type: :GITHUB_APP,
          user_id: "service-account-user-id"
        )

      assert {:ok, %CreateResponse{repository: _repository}} = CreateAction.execute(adapter, request)
    end

    test "should fail with clear error for service account with github_oauth_token", %{
      github_oauth_adapter: adapter
    } do
      request =
        InternalApiFactory.create_request(
          integration_type: :GITHUB_OAUTH_TOKEN,
          user_id: "service-account-user-id"
        )

      assert {:error, error_message} = CreateAction.execute(adapter, request)
      assert error_message =~ "Service accounts cannot use GitHub OAuth tokens"
    end
  end
end
