defmodule RepositoryHub.Server.Github.ListAccessibleRepositoriesActionTest do
  @moduledoc false
  use RepositoryHub.ServerActionCase, async: false

  alias RepositoryHub.Toolkit
  alias RepositoryHub.Adapters
  alias RepositoryHub.Server.ListAccessibleRepositoriesAction
  alias RepositoryHub.InternalApiFactory
  alias RepositoryHub.GithubAppFactory

  import Mock

  describe "Github(Oauth) ListAccessibleRepositoriesAction" do
    setup_with_mocks([
      {RepositoryHub.UserClient, [],
       [
         get_repository_token: fn integration_type, user_id ->
           token = "#{user_id}-#{integration_type}-token"
           expires_at = %Google.Protobuf.Timestamp{seconds: 0, nanos: 0}
           Toolkit.wrap({token, expires_at})
         end
       ]},
      {RepositoryHub.GithubClient, [],
       [
         list_repositories: fn _, _ ->
           [
             %{
               "id" => 1,
               "name" => "Test",
               "full_name" => "Full test",
               "git_url" => "github.com/test",
               "description" => "Test description"
             },
             %{
               "id" => 2,
               "name" => "Test2",
               "full_name" => "Full test2",
               "git_url" => "github.com/test2",
               "description" => "Test2 description"
             },
             %{
               "id" => 3,
               "name" => "Test3",
               "full_name" => "Full test3",
               "git_url" => "git@github.com/test3",
               "description" => "Test3 description"
             }
           ]
           |> Toolkit.wrap()
         end
       ]}
    ]) do
      :ok
    end

    test "should list remote repositories that the user can access" do
      request = InternalApiFactory.list_accessible_repositories_request(integration_type: :GITHUB_OAUTH_TOKEN)

      result = ListAccessibleRepositoriesAction.execute(Adapters.github_oauth(), request)

      assert {:ok, _response} = result
    end
  end

  describe "Github(App) ListAccessibleRepositoriesAction" do
    # TODO replace with GrpcMock
    setup_with_mocks([
      {RepositoryHub.UserClient, [],
       [
         get_repository_provider_uids: fn _, _ -> {:ok, ["1"]} end
       ]}
    ]) do
      {:ok, _} = GithubAppFactory.create_collaborator(r_name: "robot/repository-1")
      {:ok, _} = GithubAppFactory.create_collaborator(r_name: "robot/repository-2")
      {:ok, _} = GithubAppFactory.create_collaborator(r_name: "robot/repository-3")
      {:ok, _} = GithubAppFactory.create_collaborator(r_name: "robot/repository-4")
      :ok
    end

    test "should list remote repositories that the user can access" do
      request = InternalApiFactory.list_accessible_repositories_request(integration_type: :GITHUB_APP)

      result = ListAccessibleRepositoriesAction.execute(Adapters.github_app(), request)

      assert {:ok, _response} = result
    end
  end

  describe "" do
    test "should validate a request" do
      adapter = Adapters.github_oauth()

      request = InternalApiFactory.list_accessible_repositories_request(integration_type: :GITHUB_APP)

      assert {:ok, _} = ListAccessibleRepositoriesAction.validate(adapter, request)

      assertions = [
        ok: [
          integration_type: :GITHUB_APP,
          integration_type: :GITHUB_OAUTH_TOKEN
        ],
        error: [
          integration_type: :BITBUCKET,
          user_id: "",
          user_id: "not an uuid",
          integration_type: -1,
          integration_type: 3
        ]
      ]

      for {assertion_match, assertions} <- assertions do
        for {key, value} <- assertions do
          request = Map.put(request, key, value)

          expected =
            match?(
              {^assertion_match, _},
              ListAccessibleRepositoriesAction.validate(Adapters.github_oauth(), request)
            )

          assert(
            expected,
            "Should be #{assertion_match} when `#{inspect(key)}` is set to `#{inspect(value)}` for github oauth"
          )

          expected =
            match?(
              {^assertion_match, _},
              ListAccessibleRepositoriesAction.validate(Adapters.github_app(), request)
            )

          assert(
            expected,
            "Should be #{assertion_match} when `#{inspect(key)}` is set to `#{inspect(value)}` for github app"
          )
        end
      end
    end
  end
end
