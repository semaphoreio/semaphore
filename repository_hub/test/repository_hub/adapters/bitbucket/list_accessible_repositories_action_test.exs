defmodule RepositoryHub.Server.Bitbucket.ListAccessibleRepositoriesActionTest do
  @moduledoc false
  use RepositoryHub.ServerActionCase, async: true

  alias RepositoryHub.Adapters
  alias RepositoryHub.Server.ListAccessibleRepositoriesAction
  alias RepositoryHub.InternalApiFactory

  describe "Bitbucket ListAccessibleRepositoriesAction" do
    setup do
      %{
        adapter: Adapters.bitbucket()
      }
    end

    test "should create a build status", %{adapter: _adapter} do
    end

    test "should validate a request", %{adapter: adapter} do
      request = InternalApiFactory.list_accessible_repositories_request(integration_type: :BITBUCKET)

      assert {:ok, _} = ListAccessibleRepositoriesAction.validate(adapter, request)

      assertions = [
        ok: [
          integration_type: :BITBUCKET
        ],
        error: [
          integration_type: :GITHUB_APP,
          integration_type: :GITHUB_OAUTH_TOKEN,
          user_id: "",
          user_id: "not an uuid",
          integration_type: -1,
          integration_type: :GITLAB
        ]
      ]

      for {assertion_match, assertions} <- assertions do
        for {key, value} <- assertions do
          request = Map.put(request, key, value)
          expected = match?({^assertion_match, _}, ListAccessibleRepositoriesAction.validate(adapter, request))
          assert(expected, "Should be #{assertion_match} when `#{inspect(key)}` is set to `#{inspect(value)}`")
        end
      end
    end
  end
end
