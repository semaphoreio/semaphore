defmodule Guard.McpOAuth.Server.Test do
  use Guard.RepoCase, async: false

  alias Guard.McpOAuth.PKCE
  alias Guard.Store.{McpOAuthClient, McpOAuthAuthCode}

  @port 4003
  @base_url "http://localhost:#{@port}/mcp/oauth"
  @redirect_uri "http://localhost:3000/callback"
  @code_verifier "test-code-verifier-that-is-long-enough-for-pkce"

  setup do
    FunRegistry.clear!()
    Guard.FakeServers.setup_responses_for_development()

    user_id = Ecto.UUID.generate()
    {:ok, _user} = Support.Factories.RbacUser.insert(user_id)

    System.put_env("MCP_OAUTH_JWT_KEYS", "test-secret-key-for-mcp-oauth-tests")

    on_exit(fn ->
      System.delete_env("MCP_OAUTH_JWT_KEYS")
    end)

    {:ok, user_id: user_id}
  end

  defp mcp_oauth_url(path), do: "#{@base_url}#{path}"

  defp default_headers, do: [{"x-forwarded-proto", "https"}, {"user-agent", "test-agent"}]

  defp auth_headers(user_id),
    do: [{"x-semaphore-user-id", user_id} | default_headers()]

  defp json_headers,
    do: [{"content-type", "application/json"} | default_headers()]

  defp form_headers,
    do: [{"content-type", "application/x-www-form-urlencoded"} | default_headers()]

  defp create_test_client(redirect_uri \\ @redirect_uri) do
    client_id = "mcp_test_#{System.unique_integer([:positive])}"

    {:ok, client} =
      McpOAuthClient.create(%{
        client_id: client_id,
        client_name: "Test MCP Client",
        redirect_uris: [redirect_uri]
      })

    client
  end

  defp create_test_auth_code(user_id, client_id, opts \\ []) do
    redirect_uri = Keyword.get(opts, :redirect_uri, @redirect_uri)
    code_verifier = Keyword.get(opts, :code_verifier, @code_verifier)
    code_challenge = PKCE.compute_challenge(code_verifier)
    code = McpOAuthAuthCode.generate_code()

    expires_at =
      DateTime.utc_now()
      |> DateTime.add(600, :second)
      |> DateTime.truncate(:second)

    {:ok, auth_code} =
      McpOAuthAuthCode.create(%{
        code: code,
        client_id: client_id,
        user_id: user_id,
        redirect_uri: redirect_uri,
        code_challenge: code_challenge,
        expires_at: expires_at
      })

    auth_code
  end

  defp exchange_code_for_tokens(user_id, client) do
    auth_code = create_test_auth_code(user_id, client.client_id)

    body =
      URI.encode_query(%{
        "grant_type" => "authorization_code",
        "code" => auth_code.code,
        "redirect_uri" => @redirect_uri,
        "client_id" => client.client_id,
        "code_verifier" => @code_verifier
      })

    {:ok, response} = HTTPoison.post(mcp_oauth_url("/token"), body, form_headers())
    assert response.status_code == 200

    Jason.decode!(response.body)
  end

  defp refresh_body(client_id, refresh_token) do
    URI.encode_query(%{
      "grant_type" => "refresh_token",
      "refresh_token" => refresh_token,
      "client_id" => client_id
    })
  end

  defp refresh(client_id, refresh_token) do
    {:ok, response} =
      HTTPoison.post(
        mcp_oauth_url("/token"),
        refresh_body(client_id, refresh_token),
        form_headers()
      )

    assert response.status_code == 200

    Jason.decode!(response.body)
  end

  defp authorize_query(client_id, opts \\ []) do
    redirect_uri = Keyword.get(opts, :redirect_uri, @redirect_uri)
    code_challenge = PKCE.compute_challenge(@code_verifier)

    params = %{
      "response_type" => "code",
      "client_id" => client_id,
      "redirect_uri" => redirect_uri,
      "code_challenge" => code_challenge,
      "code_challenge_method" => "S256",
      "scope" => "mcp",
      "state" => "test-state"
    }

    "?" <> URI.encode_query(params)
  end

  # ====================
  # Protected Resource Metadata
  # ====================

  describe "GET /.well-known/oauth-protected-resource" do
    test "returns resource metadata" do
      {:ok, response} =
        HTTPoison.get(mcp_oauth_url("/.well-known/oauth-protected-resource"), default_headers())

      assert response.status_code == 200
      assert_content_type(response, "application/json")

      body = Jason.decode!(response.body)
      assert is_binary(body["resource"])
      assert is_list(body["authorization_servers"])
      assert length(body["authorization_servers"]) > 0
    end
  end

  # ====================
  # Authorization Server Metadata
  # ====================

  describe "GET /.well-known/oauth-authorization-server" do
    test "returns server metadata" do
      {:ok, response} =
        HTTPoison.get(
          mcp_oauth_url("/.well-known/oauth-authorization-server"),
          default_headers()
        )

      assert response.status_code == 200
      assert_content_type(response, "application/json")

      body = Jason.decode!(response.body)
      assert is_binary(body["issuer"])
      assert is_binary(body["authorization_endpoint"])
      assert is_binary(body["token_endpoint"])
      assert is_binary(body["registration_endpoint"])
      assert is_list(body["response_types_supported"])
      assert is_list(body["grant_types_supported"])
      assert "authorization_code" in body["grant_types_supported"]
      assert "refresh_token" in body["grant_types_supported"]
      assert is_list(body["code_challenge_methods_supported"])
      assert "S256" in body["code_challenge_methods_supported"]
    end
  end

  # ====================
  # OpenID Connect Discovery
  # ====================

  describe "GET /.well-known/openid-configuration" do
    test "returns same metadata as oauth-authorization-server" do
      {:ok, response} =
        HTTPoison.get(
          mcp_oauth_url("/.well-known/openid-configuration"),
          default_headers()
        )

      assert response.status_code == 200
      assert_content_type(response, "application/json")

      body = Jason.decode!(response.body)
      assert is_binary(body["issuer"])
      assert is_binary(body["authorization_endpoint"])
      assert is_binary(body["token_endpoint"])
    end
  end

  # ====================
  # JWKS
  # ====================

  describe "GET /jwks" do
    test "returns empty key set" do
      {:ok, response} = HTTPoison.get(mcp_oauth_url("/jwks"), default_headers())

      assert response.status_code == 200
      assert_content_type(response, "application/json")
      assert Jason.decode!(response.body) == %{"keys" => []}
    end
  end

  # ====================
  # Dynamic Client Registration
  # ====================

  describe "POST /register" do
    test "valid registration" do
      body =
        Jason.encode!(%{
          "redirect_uris" => ["http://localhost:3000/callback"],
          "client_name" => "My MCP Client"
        })

      {:ok, response} = HTTPoison.post(mcp_oauth_url("/register"), body, json_headers())

      assert response.status_code == 201
      assert_content_type(response, "application/json")

      result = Jason.decode!(response.body)
      assert is_binary(result["client_id"])
      assert result["redirect_uris"] == ["http://localhost:3000/callback"]
      assert result["grant_types"] == ["authorization_code", "refresh_token"]
      assert result["client_name"] == "My MCP Client"
    end

    test "missing redirect_uris returns error" do
      body = Jason.encode!(%{"client_name" => "Bad Client"})

      {:ok, response} = HTTPoison.post(mcp_oauth_url("/register"), body, json_headers())

      assert response.status_code == 400
      assert_content_type(response, "application/json")

      result = Jason.decode!(response.body)
      assert result["error"] == "invalid_redirect_uri"
    end

    test "invalid redirect URI scheme returns error" do
      body =
        Jason.encode!(%{
          "redirect_uris" => ["ftp://evil.example.com/callback"]
        })

      {:ok, response} = HTTPoison.post(mcp_oauth_url("/register"), body, json_headers())

      assert response.status_code == 400
      assert_content_type(response, "application/json")

      result = Jason.decode!(response.body)
      assert result["error"] == "invalid_redirect_uri"
    end
  end

  # ====================
  # Authorization Endpoint
  # ====================

  describe "GET /authorize" do
    test "valid params with authenticated user returns consent page", %{user_id: user_id} do
      client = create_test_client()
      query = authorize_query(client.client_id)

      {:ok, response} = HTTPoison.get(mcp_oauth_url("/authorize#{query}"), auth_headers(user_id))

      assert response.status_code == 200
      assert_content_type(response, "text/html")
      assert response.body =~ "Authorize MCP Access"
      assert response.body =~ "<form"
      assert response.body =~ client.client_id
    end

    test "valid params without authentication redirects to login" do
      client = create_test_client()
      query = authorize_query(client.client_id)

      {:ok, response} =
        HTTPoison.get(mcp_oauth_url("/authorize#{query}"), default_headers(),
          follow_redirect: false
        )

      assert response.status_code == 302

      location = get_header(response, "location")
      assert location =~ "/login"
    end

    test "missing client_id returns error" do
      code_challenge = PKCE.compute_challenge(@code_verifier)

      params =
        URI.encode_query(%{
          "response_type" => "code",
          "redirect_uri" => @redirect_uri,
          "code_challenge" => code_challenge,
          "code_challenge_method" => "S256"
        })

      {:ok, response} = HTTPoison.get(mcp_oauth_url("/authorize?#{params}"), default_headers())

      assert response.status_code == 400
      assert_content_type(response, "application/json")

      result = Jason.decode!(response.body)
      assert result["error"] == "invalid_request"
    end

    test "invalid client_id returns error" do
      code_challenge = PKCE.compute_challenge(@code_verifier)

      params =
        URI.encode_query(%{
          "response_type" => "code",
          "client_id" => "nonexistent-client",
          "redirect_uri" => @redirect_uri,
          "code_challenge" => code_challenge,
          "code_challenge_method" => "S256"
        })

      {:ok, response} = HTTPoison.get(mcp_oauth_url("/authorize?#{params}"), default_headers())

      assert response.status_code == 400
      assert_content_type(response, "application/json")

      result = Jason.decode!(response.body)
      assert result["error"] == "invalid_client"
    end

    test "missing PKCE code_challenge redirects with error" do
      client = create_test_client()

      params =
        URI.encode_query(%{
          "response_type" => "code",
          "client_id" => client.client_id,
          "redirect_uri" => @redirect_uri,
          "code_challenge_method" => "S256",
          "state" => "test-state"
        })

      {:ok, response} =
        HTTPoison.get(mcp_oauth_url("/authorize?#{params}"), default_headers(),
          follow_redirect: false
        )

      assert response.status_code == 302

      location = get_header(response, "location")
      assert location =~ "error=invalid_request"
      assert location =~ @redirect_uri
    end
  end

  # ====================
  # Token Endpoint
  # ====================

  describe "POST /token" do
    test "valid token exchange", %{user_id: user_id} do
      client = create_test_client()
      auth_code = create_test_auth_code(user_id, client.client_id)

      body =
        URI.encode_query(%{
          "grant_type" => "authorization_code",
          "code" => auth_code.code,
          "redirect_uri" => @redirect_uri,
          "client_id" => client.client_id,
          "code_verifier" => @code_verifier
        })

      {:ok, response} = HTTPoison.post(mcp_oauth_url("/token"), body, form_headers())

      assert response.status_code == 200
      assert_content_type(response, "application/json")

      result = Jason.decode!(response.body)
      assert is_binary(result["access_token"])
      assert is_binary(result["refresh_token"])
      assert result["token_type"] == "Bearer"
      assert result["expires_in"] == 86_400
      assert result["scope"] == "mcp"

      signer = Joken.Signer.create("HS256", System.get_env("MCP_OAUTH_JWT_KEYS"))
      assert {:ok, claims} = Joken.verify(result["access_token"], signer)
      assert claims["exp"] - claims["iat"] == 86_400
    end

    test "token exchange honors configured TTL", %{user_id: user_id} do
      original = Application.fetch_env!(:guard, :mcp_oauth_access_token_ttl_seconds)
      Application.put_env(:guard, :mcp_oauth_access_token_ttl_seconds, 120)

      on_exit(fn ->
        Application.put_env(:guard, :mcp_oauth_access_token_ttl_seconds, original)
      end)

      client = create_test_client()
      auth_code = create_test_auth_code(user_id, client.client_id)

      body =
        URI.encode_query(%{
          "grant_type" => "authorization_code",
          "code" => auth_code.code,
          "redirect_uri" => @redirect_uri,
          "client_id" => client.client_id,
          "code_verifier" => @code_verifier
        })

      {:ok, response} = HTTPoison.post(mcp_oauth_url("/token"), body, form_headers())

      assert response.status_code == 200
      result = Jason.decode!(response.body)
      assert result["expires_in"] == 120

      signer = Joken.Signer.create("HS256", System.get_env("MCP_OAUTH_JWT_KEYS"))
      assert {:ok, claims} = Joken.verify(result["access_token"], signer)
      assert claims["exp"] - claims["iat"] == 120
    end

    test "invalid grant_type returns error" do
      body =
        URI.encode_query(%{
          "grant_type" => "client_credentials",
          "code" => "some-code",
          "client_id" => "some-client"
        })

      {:ok, response} = HTTPoison.post(mcp_oauth_url("/token"), body, form_headers())

      assert response.status_code == 400
      assert_content_type(response, "application/json")

      result = Jason.decode!(response.body)
      assert result["error"] == "unsupported_grant_type"
    end

    test "invalid auth code returns error", %{user_id: _user_id} do
      client = create_test_client()

      body =
        URI.encode_query(%{
          "grant_type" => "authorization_code",
          "code" => "invalid-code",
          "redirect_uri" => @redirect_uri,
          "client_id" => client.client_id,
          "code_verifier" => @code_verifier
        })

      {:ok, response} = HTTPoison.post(mcp_oauth_url("/token"), body, form_headers())

      assert response.status_code == 400
      assert_content_type(response, "application/json")

      result = Jason.decode!(response.body)
      assert result["error"] == "invalid_grant"
    end

    test "wrong PKCE verifier returns error", %{user_id: user_id} do
      client = create_test_client()
      auth_code = create_test_auth_code(user_id, client.client_id)

      body =
        URI.encode_query(%{
          "grant_type" => "authorization_code",
          "code" => auth_code.code,
          "redirect_uri" => @redirect_uri,
          "client_id" => client.client_id,
          "code_verifier" => "wrong-verifier"
        })

      {:ok, response} = HTTPoison.post(mcp_oauth_url("/token"), body, form_headers())

      assert response.status_code == 400
      assert_content_type(response, "application/json")

      result = Jason.decode!(response.body)
      assert result["error"] == "invalid_grant"
    end

    test "missing code_verifier returns error", %{user_id: user_id} do
      client = create_test_client()
      auth_code = create_test_auth_code(user_id, client.client_id)

      body =
        URI.encode_query(%{
          "grant_type" => "authorization_code",
          "code" => auth_code.code,
          "redirect_uri" => @redirect_uri,
          "client_id" => client.client_id
        })

      {:ok, response} = HTTPoison.post(mcp_oauth_url("/token"), body, form_headers())

      assert response.status_code == 400
      assert_content_type(response, "application/json")

      result = Jason.decode!(response.body)
      assert result["error"] == "invalid_request"
    end
  end

  # ====================
  # Token Endpoint - refresh_token grant
  # ====================

  describe "POST /token with grant_type=refresh_token" do
    test "returns a new access token and rotates the refresh token", %{user_id: user_id} do
      client = create_test_client()
      tokens = exchange_code_for_tokens(user_id, client)

      {:ok, response} =
        HTTPoison.post(
          mcp_oauth_url("/token"),
          refresh_body(client.client_id, tokens["refresh_token"]),
          form_headers()
        )

      assert response.status_code == 200
      assert_content_type(response, "application/json")

      result = Jason.decode!(response.body)
      assert is_binary(result["access_token"])
      assert result["token_type"] == "Bearer"
      assert result["expires_in"] == 86_400
      assert result["scope"] == "mcp"

      # Rotation: the refresh token is single-use and replaced on every refresh.
      assert is_binary(result["refresh_token"])
      assert result["refresh_token"] != tokens["refresh_token"]

      signer = Joken.Signer.create("HS256", System.get_env("MCP_OAUTH_JWT_KEYS"))
      assert {:ok, claims} = Joken.verify(result["access_token"], signer)
      assert claims["semaphore_user_id"] == user_id
      assert claims["scope"] == "mcp"
    end

    test "the rotated refresh token can be used again", %{user_id: user_id} do
      client = create_test_client()
      tokens = exchange_code_for_tokens(user_id, client)

      first = refresh(client.client_id, tokens["refresh_token"])
      second = refresh(client.client_id, first["refresh_token"])

      assert is_binary(second["access_token"])
      assert second["refresh_token"] != first["refresh_token"]
    end

    test "replaying a used refresh token revokes the whole family", %{user_id: user_id} do
      client = create_test_client()
      tokens = exchange_code_for_tokens(user_id, client)

      rotated = refresh(client.client_id, tokens["refresh_token"])

      # Replay of the consumed token.
      {:ok, response} =
        HTTPoison.post(
          mcp_oauth_url("/token"),
          refresh_body(client.client_id, tokens["refresh_token"]),
          form_headers()
        )

      assert response.status_code == 400
      assert Jason.decode!(response.body)["error"] == "invalid_grant"

      # The token handed out by the replayed exchange is revoked as well.
      {:ok, response} =
        HTTPoison.post(
          mcp_oauth_url("/token"),
          refresh_body(client.client_id, rotated["refresh_token"]),
          form_headers()
        )

      assert response.status_code == 400
      assert Jason.decode!(response.body)["error"] == "invalid_grant"
    end

    test "refresh token is bound to the client it was issued to", %{user_id: user_id} do
      client = create_test_client()
      other_client = create_test_client()
      tokens = exchange_code_for_tokens(user_id, client)

      {:ok, response} =
        HTTPoison.post(
          mcp_oauth_url("/token"),
          refresh_body(other_client.client_id, tokens["refresh_token"]),
          form_headers()
        )

      assert response.status_code == 400
      assert Jason.decode!(response.body)["error"] == "invalid_grant"

      # The original client can still refresh: a mismatched client_id must not
      # consume or revoke the token.
      assert is_binary(refresh(client.client_id, tokens["refresh_token"])["access_token"])
    end

    test "expired refresh token returns error", %{user_id: user_id} do
      client = create_test_client()

      {:ok, token, _record} =
        Guard.Store.McpOAuthRefreshToken.issue(%{
          client_id: client.client_id,
          user_id: user_id,
          expires_at:
            DateTime.utc_now() |> DateTime.add(-60, :second) |> DateTime.truncate(:second)
        })

      {:ok, response} =
        HTTPoison.post(
          mcp_oauth_url("/token"),
          refresh_body(client.client_id, token),
          form_headers()
        )

      assert response.status_code == 400
      assert Jason.decode!(response.body)["error"] == "invalid_grant"
    end

    test "unknown refresh token returns error" do
      client = create_test_client()

      {:ok, response} =
        HTTPoison.post(
          mcp_oauth_url("/token"),
          refresh_body(client.client_id, "not-a-real-token"),
          form_headers()
        )

      assert response.status_code == 400
      assert Jason.decode!(response.body)["error"] == "invalid_grant"
    end

    test "missing refresh_token returns error" do
      %{client_id: client_id} = create_test_client()

      body = URI.encode_query(%{"grant_type" => "refresh_token", "client_id" => client_id})

      {:ok, response} = HTTPoison.post(mcp_oauth_url("/token"), body, form_headers())

      assert response.status_code == 400
      assert Jason.decode!(response.body)["error"] == "invalid_request"
    end

    test "missing client_id returns error" do
      body = URI.encode_query(%{"grant_type" => "refresh_token", "refresh_token" => "abc"})

      {:ok, response} = HTTPoison.post(mcp_oauth_url("/token"), body, form_headers())

      assert response.status_code == 400
      assert Jason.decode!(response.body)["error"] == "invalid_request"
    end
  end

  # ====================
  # Catch-all
  # ====================

  describe "catch-all" do
    test "unknown path returns 404" do
      {:ok, response} = HTTPoison.get(mcp_oauth_url("/nonexistent"), default_headers())

      assert response.status_code == 404
      assert response.body == "Not Found"
    end
  end

  # ====================
  # Assertion Helpers
  # ====================

  defp assert_content_type(response, expected_type) do
    content_type = get_header(response, "content-type")
    assert content_type =~ expected_type
  end

  defp get_header(response, name) do
    case Enum.find(response.headers, fn {k, _v} -> String.downcase(k) == name end) do
      {_, value} -> value
      nil -> nil
    end
  end
end
