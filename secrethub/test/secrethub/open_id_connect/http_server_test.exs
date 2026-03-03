defmodule Secrethub.OpenIDConnect.HTTPServerTest do
  use Secrethub.DataCase

  @org_id ""
  @org_username "testera"

  @port Application.compile_env!(:secrethub, :openid_connect_http_port)
  @host "http://localhost:#{@port}"

  @headers [
    "content-type": "application/json",
    "x-semaphore-org-id": @org_id,
    "x-semaphore-org-username": @org_username
  ]

  describe "healthcheck endpoints" do
    test "GET /" do
      {:ok, response} = request("/")

      assert response.status_code == 200
    end

    test "GET /is_alive" do
      {:ok, response} = request("/is_alive")

      assert response.status_code == 200
    end
  end

  describe "public OpenID connect configuration endpoints" do
    test "GET /.well-known/openid-configuration" do
      domain = Application.fetch_env!(:secrethub, :domain)

      {:ok, response} = request("/.well-known/openid-configuration")

      assert response.status_code == 200

      assert {"cache-control", "max-age=900, public, must-revalidate"} in response.headers

      {:ok, body} = Poison.decode(response.body)

      full_url = "#{@org_username}.#{domain}"

      assert Map.get(body, "issuer") == "https://#{full_url}"
      assert Map.get(body, "jwks_uri") == "https://#{full_url}/.well-known/jwks.json"
    end

    test "GET /.well-known/jwks" do
      {:ok, response} = HTTPoison.get("#{@host}/.well-known/jwks")

      assert response.status_code == 200

      assert {"cache-control", "max-age=900, public, must-revalidate"} in response.headers

      {:ok, body} = Poison.decode(response.body)

      assert body == %{"keys" => Secrethub.OpenIDConnect.KeyManager.public_keys(:openid_keys)}
    end

    test "GET /.well-known/jwks.json" do
      {:ok, response} = HTTPoison.get("#{@host}/.well-known/jwks")

      assert response.status_code == 200

      assert {"cache-control", "max-age=900, public, must-revalidate"} in response.headers

      {:ok, body} = Poison.decode(response.body)

      assert body == %{"keys" => Secrethub.OpenIDConnect.KeyManager.public_keys(:openid_keys)}
    end
  end

  describe "public OpenID connect configuration endpoints for on-prem" do
    setup do
      Application.put_env(:secrethub, :on_prem?, true)
      Application.put_env(:secrethub, :openid_keys_cache_max_age_in_s, 1000)

      on_exit(fn ->
        Application.put_env(:secrethub, :on_prem?, false)
        Application.put_env(:secrethub, :openid_keys_cache_max_age_in_s, 0)
      end)
    end

    test "GET /.well-known/openid-configuration" do
      {:ok, response} = request("/.well-known/openid-configuration")

      assert response.status_code == 200

      cache_max_age = Application.fetch_env!(:secrethub, :openid_keys_cache_max_age_in_s)

      assert {"cache-control", "max-age=#{cache_max_age}, public, must-revalidate"} in response.headers
    end

    test "GET /.well-known/jwks" do
      {:ok, response} = HTTPoison.get("#{@host}/.well-known/jwks")

      assert response.status_code == 200

      cache_max_age = Application.fetch_env!(:secrethub, :openid_keys_cache_max_age_in_s)

      assert {"cache-control", "max-age=#{cache_max_age}, public, must-revalidate"} in response.headers

      {:ok, body} = Poison.decode(response.body)

      assert body == %{"keys" => Secrethub.OpenIDConnect.KeyManager.public_keys(:openid_keys)}
    end

    test "GET /.well-known/jwks.json" do
      {:ok, response} = HTTPoison.get("#{@host}/.well-known/jwks.json")

      assert response.status_code == 200

      cache_max_age = Application.fetch_env!(:secrethub, :openid_keys_cache_max_age_in_s)

      assert {"cache-control", "max-age=#{cache_max_age}, public, must-revalidate"} in response.headers

      {:ok, body} = Poison.decode(response.body)

      assert body == %{"keys" => Secrethub.OpenIDConnect.KeyManager.public_keys(:openid_keys)}
    end
  end

  test "unknown urls return 404" do
    {:ok, response} = HTTPoison.get("#{@host}/.well-known/jwks/tralala")
    assert response.status_code == 404
  end

  defp request(path) do
    HTTPoison.get("#{@host}#{path}", @headers)
  end
end
