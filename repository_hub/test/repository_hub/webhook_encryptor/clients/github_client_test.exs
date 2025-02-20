defmodule RepositoryHub.WebhookEncryptor.GithubClientTest do
  # credo:disable-for-this-file
  use ExUnit.Case, async: true
  alias RepositoryHub.WebhookEncryptor.GithubClient, as: Client

  @create_event %{
    owner: "owner",
    repo: "repo",
    url: "url",
    events: ["push"],
    secret: "secret"
  }

  @remove_event %{
    owner: "owner",
    repo: "repo",
    hook_id: "old_hook_id"
  }

  describe "create_webhook/2" do
    test "uses proper headers" do
      Tesla.Mock.mock(fn %Tesla.Env{headers: headers} = env ->
        assert MapSet.new(headers) ==
                 MapSet.new([
                   {"authorization", "Bearer token"},
                   {"accept", "application/vnd.github+json"},
                   {"x-github-api-version", "2022-11-28"},
                   {"content-type", "application/json"}
                 ])

        id = DateTime.utc_now() |> DateTime.to_unix()
        body = Jason.encode!(%{"id" => id, "config" => %{"url" => "url"}})
        %Tesla.Env{env | status: 201, body: body}
      end)

      assert {:ok, %{id: _id, url: "url"}} = call_create()
    end

    test "when HTTP status 201 is returned then returns ID and URL" do
      Tesla.Mock.mock(fn %Tesla.Env{body: body} = env ->
        url = body |> Jason.decode!() |> get_in(["config", "url"])
        id = DateTime.utc_now() |> DateTime.to_unix()
        body = Jason.encode!(%{"id" => id, "config" => %{"url" => url}})
        %Tesla.Env{env | status: 201, body: body}
      end)

      assert {:ok, %{id: id, url: "url"}} = call_create()
      assert {integer_id, _} = Integer.parse(id)
      assert is_integer(integer_id)
    end

    test "when HTTP status 403 is returned then returns error" do
      Tesla.Mock.mock(fn env ->
        %Tesla.Env{env | status: 403, body: %{error: "forbidden"}}
      end)

      assert {:error, {:forbidden, %{error: "forbidden"}}} = call_create()
    end

    test "when HTTP status 404 is returned then returns error" do
      Tesla.Mock.mock(fn env ->
        %Tesla.Env{env | status: 404, body: %{error: "not_found"}}
      end)

      assert {:error, {:not_found, %{error: "not_found"}}} = call_create()
    end

    test "when HTTP status 422 is returned then returns error" do
      Tesla.Mock.mock(fn env ->
        %Tesla.Env{env | status: 422, body: %{error: "unprocessable"}}
      end)

      assert {:error, {:unprocessable, %{error: "unprocessable"}}} = call_create()
    end

    test "when other HTTP code is returned then returns env" do
      Tesla.Mock.mock(fn env -> %Tesla.Env{env | status: 400} end)
      assert {:error, %Tesla.Env{status: 400}} = call_create()
    end

    defp call_create do
      Client.new("token") |> Client.create_webhook(@create_event)
    end
  end

  describe "remove_webhook/2" do
    test "uses proper headers" do
      Tesla.Mock.mock(fn %Tesla.Env{headers: headers} = env ->
        assert MapSet.new(headers) ==
                 MapSet.new([
                   {"authorization", "Bearer token"},
                   {"accept", "application/vnd.github+json"},
                   {"x-github-api-version", "2022-11-28"}
                 ])

        %Tesla.Env{env | status: 204}
      end)

      assert {:ok, %{id: "old_hook_id"}} = call_remove()
    end

    test "when HTTP status 204 is returned then returns ID and URL" do
      Tesla.Mock.mock(fn %Tesla.Env{} = env ->
        %Tesla.Env{env | status: 204}
      end)

      assert {:ok, %{id: "old_hook_id"}} = call_remove()
    end

    test "when HTTP status 404 is returned then returns ID and URL" do
      Tesla.Mock.mock(fn %Tesla.Env{} = env ->
        %Tesla.Env{env | status: 404}
      end)

      assert {:ok, %{id: "old_hook_id"}} = call_remove()
    end

    test "when other HTTP code is returned then returns env" do
      Tesla.Mock.mock(fn env -> %Tesla.Env{env | status: 403} end)

      assert {:error, %Tesla.Env{status: 403}} = call_remove()
    end

    defp call_remove do
      Client.new("token") |> Client.remove_webhook(@remove_event)
    end
  end
end
