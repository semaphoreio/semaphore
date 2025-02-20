defmodule RepositoryHub.TentacatFactory do
  @moduledoc """
  This factory provides mocked responses from the Tentacat library that's used as a github client.
  """
  import RepositoryHub.Toolkit

  def mocks do
    [
      {Tentacat, [], get: fn "rate_limit", _ -> {200, %{"rate" => %{"remaining" => 15_000}}, nil} end},
      {Tentacat.Repositories, [], repo_get: &repo_get_mock/3, list_mine: &list_mine_mock/2},
      {Tentacat.Repositories.Statuses, [], create: &create_build_status_mock/5},
      {Tentacat.Repositories.Collaborators, [], list: &list_mock/4},
      {Tentacat.Contents, [], find_in: &find_in_mock/5},
      {Tentacat.Hooks, [],
       [
         create: &create_webhook_mock/4
       ]},
      {Tentacat.Repositories.DeployKeys, [],
       [
         find: &find_deploy_key_mock/4,
         create: &create_deploy_key_mock/4,
         remove: &remove_deploy_key_mock/4
       ]},
      {Tentacat.Repositories.Branches, [], find: &get_branch/4},
      {Tentacat.Repositories.Tags, [], list: &list_tags/3},
      {Tentacat.Commits, [], find: &get_commit/4}
    ]
  end

  def create_build_status_mock(_, _, _, _, _) do
    response = %HTTPoison.Response{
      status_code: 201,
      body: "{}",
      headers: []
    }

    {201, %{}, response}
  end

  def list_mock(_path, _client, _params, _opts) do
    response = %HTTPoison.Response{
      status_code: 200,
      body: "{}",
      headers: []
    }

    {200, %{}, response}
  end

  def list_mine_mock(_client, _params) do
    response = %HTTPoison.Response{
      status_code: 200,
      body: "{}",
      headers: []
    }

    {200, %{}, response}
  end

  def find_in_mock(_client, _repo_owner, _repo_name, _path, _commit_sha) do
    response_body =
      %{
        "content" => "dGVzdA=="
      }
      |> Jason.encode!()

    status_code = 200

    response = %HTTPoison.Response{
      status_code: status_code,
      body: response_body,
      headers: []
    }

    {status_code, Jason.decode!(response_body), response}
  end

  def repo_get_mock(_client, repo_owner, repo_name) do
    response_body =
      %{
        id: 1234,
        description: "#{repo_name} repository of #{repo_owner}.",
        private: true,
        permissions: %{
          admin: true
        },
        created_at: "2021-12-04T12:33:02Z"
      }
      |> Jason.encode!()

    status_code = 200

    response = %HTTPoison.Response{
      status_code: status_code,
      body: response_body,
      headers: []
    }

    {status_code, Jason.decode!(response_body), response}
  end

  def find_deploy_key_mock(_client, owner, repo, key_id) do
    response_body =
      %{
        id: key_id,
        url: "https://api.github.com/repos/#{owner}/#{repo}/keys/#{key_id}",
        title: "semaphore-#{owner}-#{repo}",
        verified: true,
        created_at: "2011-01-26T19:01:12Z",
        read_only: true
      }
      |> Jason.encode!()

    status_code = 200

    response = %HTTPoison.Response{
      status_code: status_code,
      body: response_body,
      headers: []
    }

    {status_code, Jason.decode!(response_body), response}
  end

  def create_deploy_key_mock(_client, owner, repo, params) do
    key_id = rem(:erlang.unique_integer(), 1_000_000)

    params =
      params
      |> Enum.into([])
      |> with_defaults(
        title: "semaphore-#{owner}-#{repo}",
        read_only: true,
        key: ssh_key()
      )
      |> Enum.into(%{})

    response_body =
      %{
        id: key_id,
        key: params.key,
        url: "https://api.github.com/repos/#{owner}/#{repo}/keys/#{key_id}",
        title: params.title,
        verified: true,
        created_at: "2014-12-10T15:53:42Z",
        read_only: params.read_only
      }
      |> Jason.encode!()

    status_code = 201

    response = %HTTPoison.Response{
      status_code: status_code,
      body: Jason.encode!(response_body),
      headers: []
    }

    {status_code, Jason.decode!(response_body), response}
  end

  def remove_deploy_key_mock(_client, owner, repo, key_id) do
    response_body =
      %{
        id: key_id,
        url: "https://api.github.com/repos/#{owner}/#{repo}/keys/#{key_id}",
        title: "semaphore-#{owner}-#{repo}",
        verified: true,
        created_at: "2021-12-04T12:33:02Z",
        read_only: true
      }
      |> Jason.encode!()

    status_code = 204

    response = %HTTPoison.Response{
      status_code: status_code,
      body: Jason.encode!(response_body),
      headers: []
    }

    {status_code, Jason.decode!(response_body), response}
  end

  def create_webhook_mock(_client, _owner, "failed", _params) do
    response_body = %{
      "documentation_url" => "https://docs.github.com/rest/webhooks/repos#create-a-repository-webhook",
      "errors" => [
        %{
          "code" => "custom",
          "message" => "The \"pull_request\" event cannot have more than 20 hooks",
          "resource" => "Hook"
        },
        %{
          "code" => "custom",
          "message" => "The \"push\" event cannot have more than 20 hooks",
          "resource" => "Hook"
        }
      ],
      "message" => "Validation Failed"
    }

    status_code = 422

    response = %HTTPoison.Response{
      status_code: status_code,
      body: response_body,
      headers: []
    }

    {status_code, response_body, response}
  end

  def create_webhook_mock(_client, _owner, _repo, params) do
    hook_id = rem(:erlang.unique_integer(), 1_000_000)

    response_body =
      %{
        type: "Repository",
        id: hook_id,
        name: params["name"],
        active: true,
        events: params["events"],
        config: %{
          content_type: "json",
          insecure_ssl: 0,
          url: params["config"]["url"]
        }
      }
      |> Jason.encode!()

    status_code = 201

    response = %HTTPoison.Response{
      status_code: status_code,
      body: Jason.encode!(response_body),
      headers: []
    }

    {status_code, Jason.decode!(response_body), response}
  end

  def get_branch(_client, _branch, _owner, _repo) do
    response_body =
      %{
        name: "master",
        commit: %{
          sha: "da500aa4f54cbf8f3eb47a1dc2c136715c9197b9"
        }
      }
      |> Jason.encode!()

    status_code = 200

    response = %HTTPoison.Response{
      status_code: status_code,
      body: Jason.encode!(response_body),
      headers: []
    }

    {status_code, Jason.decode!(response_body), response}
  end

  def list_tags(_client, _owner, _repo) do
    response_body =
      [
        %{
          name: "v1.0.0",
          commit: %{
            sha: "f0bb5942f47193d153a205dc089cbbf38299dd1a",
            commit: %{
              message: "Commit message"
            }
          }
        },
        %{
          name: "v1.0.1",
          commit: %{
            sha: "48038c4d189536a0862a2c20ed832dc34bd1c8b2",
            commit: %{
              message: "Commit message"
            }
          }
        }
      ]
      |> Jason.encode!()

    status_code = 200

    response = %HTTPoison.Response{
      status_code: status_code,
      body: Jason.encode!(response_body),
      headers: []
    }

    {status_code, Jason.decode!(response_body), response}
  end

  def get_commit(_client, _sha, _owner, "chmura") do
    response_body =
      %{
        sha: "48038c4d189536a0862a2c20ed832dc34bd1c8b2",
        commit: %{
          message: "Commit message"
        },
        author: %{
          login: "author",
          id: 1_234_567,
          avatar_url: "https://avatars.githubusercontent.com/u/1234567?v=4"
        }
      }
      |> Jason.encode!()

    status_code = 200

    response = %HTTPoison.Response{
      status_code: status_code,
      body: Jason.encode!(response_body),
      headers: []
    }

    {status_code, for(_ <- 1..5, do: {status_code, Jason.decode!(response_body), response}), response}
  end

  def get_commit(_client, _sha, _owner, _repo) do
    response_body =
      %{
        sha: "48038c4d189536a0862a2c20ed832dc34bd1c8b2",
        commit: %{
          message: "Commit message"
        },
        author: %{
          login: "author",
          id: 1_234_567,
          avatar_url: "https://avatars.githubusercontent.com/u/1234567?v=4"
        }
      }
      |> Jason.encode!()

    status_code = 200

    response = %HTTPoison.Response{
      status_code: status_code,
      body: Jason.encode!(response_body),
      headers: []
    }

    {status_code, Jason.decode!(response_body), response}
  end

  def ssh_key do
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCxmqMtdF2CQ9IBwROV8wOpnVJHbpjty8EJ6SFsvmhsUm2bhAQy0/9aFCEKSLqEdCbcD3wq9KIFp0nGlsPBXA1P3tetz1uN2fHtNM/YGjp/c4mZ5NGQaatSjiBl5tSV7/6H2MjTn8+JOanjI45KKlrK1haJWp9kmQVatK3Sm1wqy/vx4kzrHXP5WOh6ZhsOEdvgbD6+NOQdCynhem0o1uUZGsMTKUEwsngyVPQhF2Nd4XfAaNS6Kwo7X6C0SV7Gn5Mt1a1R6vhfy9b4FUkOoZJA1zhLSWK7VEarPkvKhCwRGdwTehZBmqPArCANMXR5wwYu2L7KZtjTQmdqjFKUPdv/qSdg1e9QAp+K0fMdYVuD/5Zh45DPOqJt3jJ6zbfyIub2m9g5kErwuygWsYrxLrmQVhqzX5/qyqvmYuy84ZsAc8x5wsSS76Ebc2AN7b8fNQpu5PEKqVAXKYVka+1EgiM17QjAxKkCSNQ9fpns6flFMrA+wmlrRpuPML9caRko2Pc="
  end
end
