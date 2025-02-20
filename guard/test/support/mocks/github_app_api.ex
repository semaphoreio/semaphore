defmodule Guard.Mocks.GithubAppApi do
  @code Ecto.UUID.generate()

  def github_app_manifest_server do
    bypass = Bypass.open()
    endpoint = "http://localhost:#{bypass.port}"

    Bypass.stub(bypass, "POST", "/settings/apps/new", fn conn ->
      conn = fetch_conn_params(conn)

      redirect_url =
        "http://localhost:4004/github_app_manifest_callback?state=#{conn.params["state"]}&code=#{@code}"

      Plug.Conn.resp(conn, 301, redirect_url)
    end)

    github_app_api()

    Application.put_env(:guard, :github_app_install_url, endpoint)

    bypass
  end

  def github_app_api do
    Tesla.Mock.mock_global(fn
      %{method: :post, url: "https://api.github.com/app-manifests/#{@code}/conversions"} ->
        private_key = JOSE.JWK.generate_key({:rsa, 1024})
        {_, pem_private_key} = JOSE.JWK.to_pem(private_key)

        resp = %Tesla.Env{
          status: 200,
          body: %{
            "slug" => "test-gh-app",
            "id" => 100,
            "name" => "test gh app",
            "description" => "test github app",
            "external_url" => "https://test-gh-app.com",
            "html_url" => "https://test-gh-app.com",
            "client_id" => "test-client-id",
            "client_secret" => "test-client-secret",
            "webhook_secret" => "webhoooook",
            "pem" => pem_private_key,
            "permissions" => %{
              "administration" => "write",
              "checks" => "write",
              "metadata" => "read"
            },
            "events" => [
              "push",
              "pull_request"
            ]
          }
        }

        {:ok, resp}

      %{method: :get, url: "https://api.github.com/app"} ->
        resp = %Tesla.Env{
          status: 200,
          body: %{
            "slug" => "test-gh-app",
            "id" => 100,
            "name" => "test gh app",
            "description" => "test github app",
            "external_url" => "https://test-gh-app.com",
            "html_url" => "https://test-gh-app.com",
            "client_id" => "test-client-id",
            "client_secret" => "test-client-secret",
            "webhook_secret" => "webhoooook",
            "pem" => "RSA PRIVATE KEY",
            "permissions" => %{
              "administration" => "write",
              "checks" => "write",
              "metadata" => "read"
            },
            "events" => [
              "push",
              "pull_request"
            ]
          }
        }

        {:ok, resp}
    end)
  end

  def code, do: @code

  defp fetch_conn_params(conn) do
    opts = Plug.Parsers.init(parsers: [:urlencoded, :json], pass: ["*/*"], json_decoder: Jason)

    conn
    |> Plug.Conn.fetch_query_params()
    |> Plug.Parsers.call(opts)
  end
end
