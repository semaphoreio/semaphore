defmodule RepositoryHub.BitbucketClientTest do
  use RepositoryHub.Case, async: false

  alias RepositoryHub.{BitbucketClient, BitbucketClientFactory}

  import Mock

  describe "BitbucketClient" do
    test "create_build_status" do
      with_mock(HTTPoison, [],
        post: fn _url, _body, _headers, _opts ->
          response = %HTTPoison.Response{
            status_code: 200,
            body: "{}",
            headers: []
          }

          {:ok, response}
        end
      ) do
        params = BitbucketClientFactory.build_status_params()
        response = BitbucketClient.create_build_status(params, token: "foobar")
        assert {:ok, _result} = response
      end
    end

    test "list_repository_collaborators" do
      with_mock(HTTPoison, [],
        get: fn _url, _body, _headers ->
          response = %HTTPoison.Response{
            status_code: 200,
            body: "{}",
            headers: []
          }

          {:ok, response}
        end
      ) do
        params = BitbucketClientFactory.list_repository_collaborators_params()
        response = BitbucketClient.list_repository_collaborators(params, token: "foobar")
        assert {:ok, _result} = response
      end
    end

    test "list_repositories" do
      with_mock(HTTPoison, [],
        get: fn _url, _body, _headers ->
          response = %HTTPoison.Response{
            status_code: 200,
            body: "{}",
            headers: []
          }

          {:ok, response}
        end
      ) do
        params = BitbucketClientFactory.list_repositories_params()
        response = BitbucketClient.list_repositories(params, token: "foobar")
        assert {:ok, _result} = response
      end
    end

    test "get_file" do
      with_mock(HTTPoison, [],
        get: fn _url, _body, _headers ->
          response = %HTTPoison.Response{
            status_code: 200,
            body: "test",
            headers: []
          }

          {:ok, response}
        end
      ) do
        params = BitbucketClientFactory.get_file_params()
        response = BitbucketClient.get_file(params, token: "foobar")

        assert {:ok, file_contents} = response

        assert file_contents == Base.encode64("test")
      end
    end
  end
end
