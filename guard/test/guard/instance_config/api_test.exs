defmodule Guard.InstanceConfig.ApiTest do
  use Guard.RepoCase, async: false
  use Plug.Test
  require Logger

  @port 4004
  @host "http://localhost:#{@port}"
  @org_id "78114608-be8a-465a-b9cd-81970fb802c6"

  setup do
    FunRegistry.clear!()
    Guard.FakeServers.setup_responses_for_development()
    Guard.InstanceConfigRepo.delete_all(Guard.InstanceConfig.Models.Config)

    :ok
  end

  describe "Health Checks" do
    test "Pod Health Check" do
      {:ok, response} =
        "#{@host}/is_alive"
        |> URI.encode()
        |> HTTPoison.get()

      assert response.status_code == 200
    end
  end

  describe "/github_app_manifest" do
    setup do
      bypass = Guard.Mocks.GithubAppApi.github_app_manifest_server()

      %{bypass: bypass}
    end

    test "when state is present and contains org_id" do
      {:ok, resp} = send_manifest_flow_request(token: token())
      # there is no browser test so we can't check the automatic redirect
      # so just checking a few basic things
      assert resp.status_code == 200
      assert String.contains?(resp.body, "redirectForm")
      assert String.contains?(resp.body, "Go to GitHub")
      assert String.contains?(resp.body, "manifest")
      assert String.contains?(resp.body, "redirect_url")
    end

    test "when org_id is missing redirect to front" do
      headers = [{"user-agent", "test-agent"}]

      {:ok, response} =
        "#{@host}/github_app_manifest?org_id="
        |> URI.encode()
        |> HTTPoison.get(headers)

      assert response.status_code == 302
      redirect_url = response.headers |> List.keyfind("location", 0) |> elem(1)
      assert String.contains?(redirect_url, "Organization ID is required")
      assert String.contains?(redirect_url, "alert")
    end
  end

  describe "/github_app_manifest_callback" do
    setup do
      bypass = Guard.Mocks.GithubAppApi.github_app_manifest_server()

      %{bypass: bypass}
    end

    test "when state does not match the state set in the cookie redirect to front" do
      token = token(org_id: "123")

      {:ok, resp} =
        send_manifest_flow_request(
          path: "/github_app_manifest_callback",
          token: token,
          cookie: "github_app_state=#{token()}",
          query: [code: Guard.Mocks.GithubAppApi.code()]
        )

      assert resp.status_code == 302
      redirect_url = resp.headers |> List.keyfind("location", 0) |> elem(1)
      assert String.contains?(redirect_url, "CSRF token mismatch")
      assert String.contains?(redirect_url, "alert")
    end

    test "when code is missing redirect to front" do
      {:ok, resp} =
        send_manifest_flow_request(path: "/github_app_manifest_callback", token: token())

      assert resp.status_code == 302
      redirect_url = resp.headers |> List.keyfind("location", 0) |> elem(1)
      assert String.contains?(redirect_url, "Code is missing")
      assert String.contains?(redirect_url, "alert")
    end

    test "when all params are correct fetch the github app data and redirect to github app installation" do
      {:ok, resp} =
        send_manifest_flow_request(
          path: "/github_app_manifest_callback",
          query: [code: Guard.Mocks.GithubAppApi.code()],
          token: token()
        )

      assert resp.status_code == 302
      redirect_url = resp.headers |> List.keyfind("location", 0) |> elem(1)
      assert String.contains?(redirect_url, "/installations/new")

      set_cookie_header = resp.headers |> List.keyfind("set-cookie", 0) |> elem(1)

      cookie_state =
        set_cookie_header |> String.split(";") |> List.first() |> String.split("=") |> Enum.at(1)

      assert String.contains?(redirect_url, cookie_state)
    end
  end

  ###
  ### Helper functions
  ###

  defp send_manifest_flow_request(params) do
    path = params[:path] || "/github_app_manifest"

    token = params[:token] || ""

    cookie = params[:cookie] || "github_app_state=#{token}"

    headers =
      (params[:headers] || []) ++
        [{"x-forwarded-proto", "https"}, {"user-agent", "test-agent"}, {"Cookie", cookie}]

    params_query = params[:query] || []
    default_query_params = [state: token, org_id: @org_id]

    query_params = Keyword.merge(default_query_params, params_query)
    query_string = parse_query_params(query_params)

    response =
      "#{@host}/#{path}#{query_string}"
      |> URI.encode()
      |> HTTPoison.get(headers)

    response
  end

  defp token, do: token(org_id: @org_id)

  defp token(params) do
    %{org_id: params[:org_id], token: "16characterslong"}
    |> Jason.encode!()
    |> Base.encode64()
  end

  defp parse_query_params(nil), do: ""
  defp parse_query_params(params), do: "?#{URI.encode_query(params)}"
end
