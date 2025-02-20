defmodule RepositoryHub.ServerTest do
  use ExUnit.Case, async: false
  import RepositoryHub.Toolkit
  alias RepositoryHub.Server
  alias RepositoryHub.InternalApiFactory

  import Mock

  setup do
    stream = %GRPC.Server.Stream{}

    %{stream: stream}
  end

  describe "#{Server}.list_accessible_repositories" do
    setup_with_mocks([
      {Server.ListAccessibleRepositoriesAction, [], [validate: fn _, request -> wrap(request) end]},
      {Server.ListAccessibleRepositoriesAction, [],
       [execute: fn _, _ -> InternalApiFactory.list_accessible_repositories_response() end]}
    ]) do
      :ok
    end

    test "works", %{stream: stream} do
      request = RepositoryHub.InternalApiFactory.list_accessible_repositories_request()

      assert %InternalApi.Repository.ListAccessibleRepositoriesResponse{} =
               Server.list_accessible_repositories(request, stream)
    end
  end

  describe "#{Server}.create" do
    setup_with_mocks([
      {Server.CreateAction, [],
       execute: fn _a, _r ->
         error("some error message")
       end},
      {Server.CreateAction, [], validate: fn _a, r -> r end}
    ]) do
      :ok
    end

    test "error in action => returns error text" do
      github_app = :GITHUB_APP

      req = %InternalApi.Repository.CreateRequest{integration_type: github_app}
      assert_raise GRPC.RPCError, "some error message", fn -> Server.create(req, nil) end
    end
  end
end
