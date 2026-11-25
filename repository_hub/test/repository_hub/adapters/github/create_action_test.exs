defmodule RepositoryHub.Server.Github.CreateActionTest do
  @moduledoc false
  use RepositoryHub.ServerActionCase, async: false

  alias RepositoryHub.Adapters
  alias RepositoryHub.Model.RepositoryQuery
  alias RepositoryHub.Server.CreateAction
  alias RepositoryHub.InternalApiFactory
  alias InternalApi

  alias RepositoryHub.GithubClientFactory

  alias InternalApi.Repository.CreateResponse
  import Mock

  @org_id "ca5ea1a0-0000-4000-8000-0000000000a1"
  @owner_id "ca5ea1a0-0000-4000-8000-0000000000a2"
  @loginless_owner_id "ca5ea1a0-0000-4000-8000-0000000000a3"
  @pushless_owner_id "ca5ea1a0-0000-4000-8000-0000000000a4"
  @pushless_login "reader-only"

  @service_accounts %{
    "service-account-user-id" => %{owner_id: @owner_id, owner_active: true},
    "ownerless-service-account-id" => %{owner_id: "", owner_active: false},
    "departed-owner-service-account-id" => %{owner_id: @owner_id, owner_active: false},
    "loginless-owner-service-account-id" => %{owner_id: @loginless_owner_id, owner_active: true},
    "pushless-owner-service-account-id" => %{owner_id: @pushless_owner_id, owner_active: true}
  }

  setup_with_mocks(
    github_mocks() ++
      [
        {RepositoryHub.UserClient, [:passthrough],
         [
           describe: fn user_id ->
             # Return regular user by default, service account for specific test user
             source = if Map.has_key?(@service_accounts, user_id), do: :SERVICE_ACCOUNT, else: :NOT_SET

             {:ok, %{user_id: user_id, user: %{creation_source: source, org_id: @org_id}}}
           end,
           get_repository_provider_logins: fn _, user_id ->
             case user_id do
               @loginless_owner_id -> {:ok, []}
               @pushless_owner_id -> {:ok, [@pushless_login]}
               _ -> {:ok, ["radwo"]}
             end
           end,
           get_repository_token: fn _integration_type, _user_id ->
             {:ok, "mock-oauth-token"}
           end
         ]},
        {RepositoryHub.ServiceAccountClient, [:passthrough],
         [
           describe: fn service_account_id, _org_id ->
             owner = Map.get(@service_accounts, service_account_id, %{owner_id: @owner_id, owner_active: true})

             {:ok, %{service_account: owner}}
           end
         ]}
      ]
  ) do
    %{github_app_adapter: Adapters.github_app(), github_oauth_adapter: Adapters.github_oauth()}
  end

  # The shared factory grants push to every login. What the owner rule turns on is the
  # owner's own permission, so one login here answers without it.
  defp github_mocks do
    Enum.map(GithubClientFactory.mocks(), fn
      {RepositoryHub.GithubClient, opts, functions} ->
        {RepositoryHub.GithubClient, opts,
         Keyword.put(functions, :repository_permissions, fn
           %{username: @pushless_login}, _opts -> {:ok, %{"admin" => false, "push" => false}}
           params, opts -> GithubClientFactory.repository_permissions(params, opts)
         end)}

      mock ->
        mock
    end)
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

    test "should fail with a clear error when the user has no GitHub account connected", %{
      github_app_adapter: adapter
    } do
      request = InternalApiFactory.create_request(integration_type: :GITHUB_APP)

      :meck.expect(RepositoryHub.UserClient, :get_repository_provider_logins, fn :GITHUB, _user_id -> {:ok, []} end)

      assert {:error, %{message: message}} = CreateAction.execute(adapter, request)
      assert message == "Connect your GitHub account to Semaphore to add this repository."
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

    test "refuses a service account that has no owner", %{github_app_adapter: adapter} do
      request =
        InternalApiFactory.create_request(
          integration_type: :GITHUB_APP,
          user_id: "ownerless-service-account-id"
        )

      assert {:error, %{message: message}} = CreateAction.execute(adapter, request)
      assert message =~ "no owner in the organization"
      assert [] = RepositoryQuery.list_by_project(request.project_id)
    end

    test "refuses a service account whose owner is no longer a member", %{github_app_adapter: adapter} do
      request =
        InternalApiFactory.create_request(
          integration_type: :GITHUB_APP,
          user_id: "departed-owner-service-account-id"
        )

      assert {:error, %{message: message}} = CreateAction.execute(adapter, request)
      assert message =~ "no owner in the organization"
      assert [] = RepositoryQuery.list_by_project(request.project_id)
    end

    test "refuses a service account whose owner has no GitHub account connected", %{github_app_adapter: adapter} do
      request =
        InternalApiFactory.create_request(
          integration_type: :GITHUB_APP,
          user_id: "loginless-owner-service-account-id"
        )

      assert {:error, %{message: message}} = CreateAction.execute(adapter, request)
      assert message =~ "owner of this service account has no GitHub account"
      assert [] = RepositoryQuery.list_by_project(request.project_id)
    end

    test "refuses a service account whose owner cannot push to the repository", %{github_app_adapter: adapter} do
      request =
        InternalApiFactory.create_request(
          integration_type: :GITHUB_APP,
          user_id: "pushless-owner-service-account-id"
        )

      assert {:error, _} = CreateAction.execute(adapter, request)
      assert [] = RepositoryQuery.list_by_project(request.project_id)
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
