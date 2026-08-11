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
        get: fn url, _headers, _opts ->
          body =
            case url do
              "https://api.bitbucket.org/2.0/user/workspaces" ->
                Jason.encode!(%{
                  "values" => [
                    %{"workspace" => %{"slug" => "example-workspace"}}
                  ]
                })

              "https://api.bitbucket.org/2.0/user/workspaces/example-workspace/permissions/repositories" ->
                Jason.encode!(%{
                  "values" => [
                    %{
                      "permission" => "admin",
                      "repository" => %{
                        "uuid" => "{repo-1}",
                        "full_name" => "example-workspace/example-repo",
                        "name" => "example-repo"
                      }
                    }
                  ]
                })

              _ ->
                Jason.encode!(%{"values" => []})
            end

          response = %HTTPoison.Response{
            status_code: 200,
            body: body,
            headers: [],
            request_url: url,
            request: nil
          }

          {:ok, response}
        end
      ) do
        params = BitbucketClientFactory.list_repositories_params()
        response = BitbucketClient.list_repositories(params, token: "foobar")
        assert {:ok, %{"values" => values}} = response
        assert length(values) == 1
        assert get_in(hd(values), ["repository", "full_name"]) == "example-workspace/example-repo"
      end
    end

    test "list_repositories returns partial results when pagination limit is reached" do
      with_mock(HTTPoison, [],
        get: fn url, _headers, _opts ->
          body =
            case url do
              "https://api.bitbucket.org/2.0/user/workspaces" ->
                Jason.encode!(%{
                  "values" => [
                    %{"workspace" => %{"slug" => "example-workspace"}}
                  ]
                })

              _ ->
                page =
                  url
                  |> URI.parse()
                  |> Map.get(:query)
                  |> case do
                    nil ->
                      1

                    query ->
                      query
                      |> URI.decode_query()
                      |> Map.get("page", "1")
                      |> String.to_integer()
                  end

                page_values = [
                  %{
                    "permission" => "admin",
                    "repository" => %{
                      "uuid" => "{repo-#{page}}",
                      "full_name" => "example-workspace/repo-#{page}",
                      "name" => "repo-#{page}"
                    }
                  }
                ]

                page_response =
                  if page < 25 do
                    %{
                      "values" => page_values,
                      "next" =>
                        "https://api.bitbucket.org/2.0/user/workspaces/example-workspace/permissions/repositories?page=#{page + 1}"
                    }
                  else
                    %{"values" => page_values}
                  end

                Jason.encode!(page_response)
            end

          response = %HTTPoison.Response{
            status_code: 200,
            body: body,
            headers: [],
            request_url: url,
            request: nil
          }

          {:ok, response}
        end
      ) do
        params = BitbucketClientFactory.list_repositories_params(page_token: "", query: "")
        response = BitbucketClient.list_repositories(params, token: "foobar")

        assert {:ok, %{"values" => values}} = response
        assert length(values) == 20
        assert Enum.any?(values, &(get_in(&1, ["repository", "full_name"]) == "example-workspace/repo-1"))
        assert Enum.any?(values, &(get_in(&1, ["repository", "full_name"]) == "example-workspace/repo-20"))
        refute Enum.any?(values, &(get_in(&1, ["repository", "full_name"]) == "example-workspace/repo-21"))
      end
    end

    test "list_repositories filters entries without repository identity when deduplicating" do
      with_mock(HTTPoison, [],
        get: fn url, _headers, _opts ->
          body =
            case url do
              "https://api.bitbucket.org/2.0/user/workspaces" ->
                Jason.encode!(%{
                  "values" => [
                    %{"workspace" => %{"slug" => "example-workspace"}}
                  ]
                })

              "https://api.bitbucket.org/2.0/user/workspaces/example-workspace/permissions/repositories" ->
                Jason.encode!(%{
                  "values" => [
                    %{
                      "permission" => "admin",
                      "repository" => %{
                        "uuid" => "{repo-1}",
                        "full_name" => "example-workspace/repo-1",
                        "name" => "repo-1"
                      }
                    },
                    %{
                      "permission" => "admin",
                      "repository" => %{"name" => "repo-1"}
                    },
                    %{
                      "permission" => "admin",
                      "repository" => %{"name" => "repo-2"}
                    }
                  ]
                })

              _ ->
                Jason.encode!(%{"values" => []})
            end

          response = %HTTPoison.Response{
            status_code: 200,
            body: body,
            headers: [],
            request_url: url,
            request: nil
          }

          {:ok, response}
        end
      ) do
        params = BitbucketClientFactory.list_repositories_params(page_token: "", query: "")
        response = BitbucketClient.list_repositories(params, token: "foobar")

        assert {:ok, %{"values" => values}} = response
        assert length(values) == 1
        assert get_in(hd(values), ["repository", "full_name"]) == "example-workspace/repo-1"
      end
    end

    test "list_repositories skips failed workspace and keeps successful workspace results" do
      with_mock(HTTPoison, [],
        get: fn url, _headers, _opts ->
          response =
            case url do
              "https://api.bitbucket.org/2.0/user/workspaces" ->
                %HTTPoison.Response{
                  status_code: 200,
                  body:
                    Jason.encode!(%{
                      "values" => [
                        %{"workspace" => %{"slug" => "workspace-1"}},
                        %{"workspace" => %{"slug" => "workspace-2"}}
                      ]
                    }),
                  headers: [],
                  request_url: url,
                  request: nil
                }

              "https://api.bitbucket.org/2.0/user/workspaces/workspace-1/permissions/repositories" ->
                %HTTPoison.Response{
                  status_code: 200,
                  body:
                    Jason.encode!(%{
                      "values" => [
                        %{
                          "permission" => "admin",
                          "repository" => %{
                            "uuid" => "{repo-1}",
                            "full_name" => "workspace-1/repo-1",
                            "name" => "repo-1"
                          }
                        }
                      ]
                    }),
                  headers: [],
                  request_url: url,
                  request: nil
                }

              "https://api.bitbucket.org/2.0/user/workspaces/workspace-2/permissions/repositories" ->
                %HTTPoison.Response{
                  status_code: 503,
                  body: "service unavailable",
                  headers: [],
                  request_url: url,
                  request: nil
                }
            end

          {:ok, response}
        end
      ) do
        params = BitbucketClientFactory.list_repositories_params(page_token: "", query: "")
        response = BitbucketClient.list_repositories(params, token: "foobar")

        assert {:ok, %{"values" => values}} = response
        assert length(values) == 1
        assert get_in(hd(values), ["repository", "full_name"]) == "workspace-1/repo-1"
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
