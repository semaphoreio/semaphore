defmodule Guard.McpOAuth.Server.Test do
  use Guard.RepoCase, async: false

  import Ecto.Query

  alias Guard.{FrontRepo, Repo}
  alias Guard.McpOAuth.PKCE
  alias Guard.Repo.{McpOAuthRefreshToken, McpOAuthRefreshTokenFamily}
  alias Guard.Store.{McpOAuthClient, McpOAuthAuthCode}

  @port 4003
  @base_url "http://localhost:#{@port}/mcp/oauth"
  @redirect_uri "http://localhost:3000/callback"
  @code_verifier "test-code-verifier-that-is-long-enough-for-pkce"

  setup do
    FunRegistry.clear!()
    Guard.FakeServers.setup_responses_for_development()

    user_id = Ecto.UUID.generate()
    user_name = "session-user-#{System.unique_integer([:positive])}"
    {:ok, _user} = Support.Factories.RbacUser.insert(user_id, user_name)
    {:ok, _user} = Support.Factories.FrontUser.insert(id: user_id, name: user_name)

    other_user_id = Ecto.UUID.generate()
    other_user_name = "other-user-#{System.unique_integer([:positive])}"
    {:ok, _other_user} = Support.Factories.RbacUser.insert(other_user_id, other_user_name)

    {:ok, _other_user} =
      Support.Factories.FrontUser.insert(id: other_user_id, name: other_user_name)

    System.put_env("MCP_OAUTH_JWT_KEYS", "test-secret-key-for-mcp-oauth-tests")

    on_exit(fn ->
      System.delete_env("MCP_OAUTH_JWT_KEYS")
    end)

    {:ok,
     user_id: user_id,
     user_name: user_name,
     other_user_id: other_user_id,
     other_user_name: other_user_name}
  end

  defp mcp_oauth_url(path), do: "#{@base_url}#{path}"

  defp default_headers, do: [{"x-forwarded-proto", "https"}, {"user-agent", "test-agent"}]

  # An x-semaphore-user-id request header, independent of session state. It MUST
  # NOT authenticate a request by itself.
  defp id_header_only(user_id),
    do: [{"x-semaphore-user-id", user_id} | default_headers()]

  # Builds a genuine authenticated web-login session (OIDC) for user_id and
  # returns the request headers carrying its signed+encrypted session cookie,
  # exactly as a signed-in browser would send them.
  defp session_headers(user_id, extra_headers \\ []) do
    session = create_oidc_session(user_id)
    [session_cookie_header(session) | extra_headers ++ default_headers()]
  end

  defp create_oidc_session(user_id) do
    {:ok, session} =
      Guard.Store.OIDCSession.create(%{
        user_id: user_id,
        id_token_enc: "id-token-enc",
        refresh_token_enc: "refresh-token-enc",
        expires_at: DateTime.utc_now() |> DateTime.add(3600, :second),
        ip_address: "127.0.0.1",
        user_agent: "test-agent"
      })

    session
  end

  defp session_cookie_header(session) do
    value =
      %{"id_provider" => "OIDC", "oidc_session_id" => session.id}
      |> Guard.Session.encrypt_cookie()

    {"cookie", "#{Application.get_env(:guard, :session_key)}=#{value}"}
  end

  # Extracts the session cookie set on a response (it now carries the CSRF
  # state stored while rendering the consent page) so a follow-up POST can
  # satisfy Plug.CSRFProtection while remaining the same authenticated session.
  defp extract_session_cookie(response) do
    key = Application.get_env(:guard, :session_key)

    response.headers
    |> Enum.filter(fn {k, _} -> String.downcase(k) == "set-cookie" end)
    |> Enum.find_value(fn {_, v} ->
      pair = v |> String.split(";", parts: 2) |> List.first()

      case String.split(pair, "=", parts: 2) do
        [^key, val] -> "#{key}=#{val}"
        _ -> nil
      end
    end)
  end

  defp extract_csrf_token(body) do
    case Regex.run(~r/name="_csrf_token"\s+value="([^"]+)"/, body) do
      [_, token] -> token
      _ -> nil
    end
  end

  defp extract_code(location) do
    case Regex.run(~r/[?&]code=([^&]+)/, location || "") do
      [_, code] -> URI.decode_www_form(code)
      _ -> nil
    end
  end

  defp grant_form_body(client_id, csrf_token) do
    URI.encode_query(%{
      "client_id" => client_id,
      "redirect_uri" => @redirect_uri,
      "code_challenge" => PKCE.compute_challenge(@code_verifier),
      "state" => "test-state",
      "scope" => "mcp",
      "_csrf_token" => csrf_token
    })
  end

  # Drives GET /authorize -> POST /grant-selection -> POST /token with a real
  # authenticated session, optionally adding an x-semaphore-user-id header on
  # the grant POST, and returns the decoded JWT claims of the minted token.
  defp complete_oauth_flow(client, session_user_id, opts \\ []) do
    extra_user_id_header =
      case Keyword.get(opts, :header_user_id) do
        nil -> []
        header_user_id -> [{"x-semaphore-user-id", header_user_id}]
      end

    {:ok, authorize_resp} =
      HTTPoison.get(
        mcp_oauth_url("/authorize#{authorize_query(client.client_id)}"),
        session_headers(session_user_id)
      )

    200 = authorize_resp.status_code
    csrf_token = extract_csrf_token(authorize_resp.body)
    post_cookie = extract_session_cookie(authorize_resp)

    {:ok, grant_resp} =
      HTTPoison.post(
        mcp_oauth_url("/grant-selection"),
        grant_form_body(client.client_id, csrf_token),
        [{"content-type", "application/x-www-form-urlencoded"}, {"cookie", post_cookie}] ++
          extra_user_id_header ++ default_headers(),
        follow_redirect: false
      )

    302 = grant_resp.status_code
    code = grant_resp |> get_header("location") |> extract_code()

    token_body =
      URI.encode_query(%{
        "grant_type" => "authorization_code",
        "code" => code,
        "redirect_uri" => @redirect_uri,
        "client_id" => client.client_id,
        "code_verifier" => @code_verifier
      })

    {:ok, token_resp} = HTTPoison.post(mcp_oauth_url("/token"), token_body, form_headers())
    200 = token_resp.status_code
    result = Jason.decode!(token_resp.body)

    signer = Joken.Signer.create("HS256", System.get_env("MCP_OAUTH_JWT_KEYS"))
    {:ok, claims} = Joken.verify(result["access_token"], signer)
    claims
  end

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

  defp post_token(params) do
    {:ok, response} =
      HTTPoison.post(mcp_oauth_url("/token"), URI.encode_query(params), form_headers())

    {response.status_code, Jason.decode!(response.body)}
  end

  defp exchange_code(client, user_id) do
    auth_code = create_test_auth_code(user_id, client.client_id)

    {200, tokens} =
      post_token(%{
        "grant_type" => "authorization_code",
        "code" => auth_code.code,
        "redirect_uri" => @redirect_uri,
        "client_id" => client.client_id,
        "code_verifier" => @code_verifier
      })

    tokens
  end

  defp refresh(refresh_token, client_id, params \\ %{}) do
    %{"grant_type" => "refresh_token", "refresh_token" => refresh_token, "client_id" => client_id}
    |> Map.merge(params)
    |> post_token()
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
      assert body["revocation_endpoint"] == "#{body["issuer"]}/revoke"
      assert body["revocation_endpoint_auth_methods_supported"] == ["none", "client_secret_post"]
      assert body["client_id_metadata_document_supported"] == true
      assert is_list(body["response_types_supported"])
      assert body["grant_types_supported"] == ["authorization_code", "refresh_token"]
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
    test "valid params with an authenticated session returns consent page", %{user_id: user_id} do
      client = create_test_client()
      query = authorize_query(client.client_id)

      {:ok, response} =
        HTTPoison.get(mcp_oauth_url("/authorize#{query}"), session_headers(user_id))

      assert response.status_code == 200
      assert_content_type(response, "text/html")
      assert response.body =~ "Authorize MCP Access"
      assert response.body =~ "<form"
      assert response.body =~ client.client_id
    end

    test "valid params without authentication redirects to login, and back" do
      client = create_test_client()
      query = authorize_query(client.client_id)

      {:ok, response} =
        HTTPoison.get(mcp_oauth_url("/authorize#{query}"), default_headers(),
          follow_redirect: false
        )

      assert response.status_code == 302

      location = response |> get_header("location") |> URI.parse()

      assert "#{location.scheme}://#{location.host}#{location.path}" ==
               "https://id.localhost/login"

      back = location.query |> URI.decode_query() |> Map.fetch!("redirect_to") |> URI.parse()

      assert "#{back.scheme}://#{back.host}#{back.path}" ==
               "https://mcp.localhost/mcp/oauth/authorize"

      assert URI.decode_query(back.query)["client_id"] == client.client_id
    end

    test "prompt=create without authentication redirects to signup, and back" do
      client = create_test_client()
      query = authorize_query(client.client_id) <> "&prompt=create"

      {:ok, response} =
        HTTPoison.get(mcp_oauth_url("/authorize#{query}"), default_headers(),
          follow_redirect: false
        )

      assert response.status_code == 302

      location = response |> get_header("location") |> URI.parse()

      assert "#{location.scheme}://#{location.host}#{location.path}" ==
               "https://id.localhost/signup"

      back = location.query |> URI.decode_query() |> Map.fetch!("redirect_to") |> URI.parse()
      assert back.path == "/mcp/oauth/authorize"
      refute URI.decode_query(back.query)["prompt"]
    end

    test "an x-semaphore-user-id header alone, without a session, redirects to login", %{
      user_id: user_id
    } do
      client = create_test_client()
      query = authorize_query(client.client_id)

      {:ok, response} =
        HTTPoison.get(mcp_oauth_url("/authorize#{query}"), id_header_only(user_id),
          follow_redirect: false
        )

      assert response.status_code == 302

      location = get_header(response, "location")
      assert location =~ "/login"
      # No authorization code was issued: the redirect is to login, not back to
      # the client redirect_uri with a code.
      refute location =~ "code="
      refute location =~ @redirect_uri
    end

    test "an authenticated session's own identity is unaffected by an x-semaphore-user-id header",
         %{
           user_id: user_id,
           user_name: user_name,
           other_user_id: other_user_id,
           other_user_name: other_user_name
         } do
      client = create_test_client()
      query = authorize_query(client.client_id)

      # A signed-in session also supplies an x-semaphore-user-id header naming a
      # different user.
      headers = session_headers(other_user_id, [{"x-semaphore-user-id", user_id}])

      {:ok, response} = HTTPoison.get(mcp_oauth_url("/authorize#{query}"), headers)

      assert response.status_code == 200
      # The consent page identifies the session user, never the user named by the
      # header.
      assert response.body =~ other_user_name
      refute response.body =~ user_name
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
      assert result["token_type"] == "Bearer"
      assert result["expires_in"] == 3_600
      assert result["scope"] == "mcp"

      signer = Joken.Signer.create("HS256", System.get_env("MCP_OAUTH_JWT_KEYS"))
      assert {:ok, claims} = Joken.verify(result["access_token"], signer)
      assert claims["exp"] - claims["iat"] == 3_600
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

  describe "POST /token with an authorization code presented again" do
    setup %{user_id: user_id} do
      client = create_test_client()
      auth_code = create_test_auth_code(user_id, client.client_id)
      {200, tokens} = post_token(code_params(auth_code.code, client.client_id))

      {:ok, client: client, auth_code: auth_code, tokens: tokens}
    end

    defp code_params(code, client_id) do
      %{
        "grant_type" => "authorization_code",
        "code" => code,
        "redirect_uri" => @redirect_uri,
        "client_id" => client_id,
        "code_verifier" => @code_verifier
      }
    end

    test "revokes the refresh tokens the code issued", %{
      client: client,
      auth_code: auth_code,
      tokens: tokens
    } do
      assert {200, rotated} = refresh(tokens["refresh_token"], client.client_id)

      assert {400, %{"error" => "invalid_grant"}} =
               post_token(code_params(auth_code.code, client.client_id))

      assert {400, %{"error" => "invalid_grant"}} =
               refresh(rotated["refresh_token"], client.client_id)

      [family] = Repo.all(McpOAuthRefreshTokenFamily)
      assert family.auth_code_id == auth_code.id
      refute is_nil(family.revoked_at)
    end

    test "revokes nothing when presented by another client, or expired", %{
      client: client,
      auth_code: auth_code,
      tokens: tokens
    } do
      other = create_test_client()

      assert {400, %{"error" => "invalid_grant"}} =
               post_token(code_params(auth_code.code, other.client_id))

      auth_code
      |> Ecto.Changeset.change(
        expires_at: DateTime.utc_now() |> DateTime.add(-1) |> DateTime.truncate(:second)
      )
      |> Repo.update!()

      assert {400, %{"error" => "invalid_grant"}} =
               post_token(code_params(auth_code.code, client.client_id))

      assert {400, %{"error" => "invalid_grant"}} =
               post_token(code_params("unknown-code", client.client_id))

      assert {200, _} = refresh(tokens["refresh_token"], client.client_id)
    end
  end

  describe "POST /token with a refresh token" do
    setup %{user_id: user_id} do
      client = create_test_client()

      {:ok, client: client, tokens: exchange_code(client, user_id)}
    end

    test "rotates the refresh token and issues an MCP token", %{
      client: client,
      tokens: tokens,
      user_id: user_id
    } do
      assert {200, result} = refresh(tokens["refresh_token"], client.client_id)
      assert result["token_type"] == "Bearer"
      assert result["expires_in"] == 3_600
      assert result["scope"] == "mcp"
      assert is_binary(result["refresh_token"])
      refute result["refresh_token"] == tokens["refresh_token"]

      signer = Joken.Signer.create("HS256", System.get_env("MCP_OAUTH_JWT_KEYS"))
      assert {:ok, claims} = Joken.verify(result["access_token"], signer)
      assert claims["sub"] == user_id
      assert claims["scope"] == "mcp"

      assert {200, _} = refresh(result["refresh_token"], client.client_id)
    end

    test "accepts a rotated token again within the grace period, without extending it", %{
      client: client,
      tokens: tokens
    } do
      assert {200, first} = refresh(tokens["refresh_token"], client.client_id)

      used_at = DateTime.utc_now() |> DateTime.add(-20) |> DateTime.truncate(:second)
      [used] = Repo.all(from(t in McpOAuthRefreshToken, where: not is_nil(t.used_at)))
      used |> Ecto.Changeset.change(used_at: used_at) |> Repo.update!()

      assert {200, second} = refresh(tokens["refresh_token"], client.client_id)
      refute first["refresh_token"] == second["refresh_token"]
      assert Repo.reload!(used).used_at == used_at
    end

    test "leaves only the token issued last live after a reuse within the grace period", %{
      client: client,
      tokens: tokens
    } do
      assert {200, first} = refresh(tokens["refresh_token"], client.client_id)
      assert {200, second} = refresh(tokens["refresh_token"], client.client_id)

      used_at = DateTime.utc_now() |> DateTime.add(-31) |> DateTime.truncate(:second)

      from(t in McpOAuthRefreshToken, where: not is_nil(t.used_at))
      |> Repo.update_all(set: [used_at: used_at])

      assert {400, %{"error" => "invalid_grant"}} =
               refresh(first["refresh_token"], client.client_id)

      assert {400, %{"error" => "invalid_grant"}} =
               refresh(second["refresh_token"], client.client_id)
    end

    test "revokes the family when a rotated token is reused after the grace period", %{
      client: client,
      tokens: tokens
    } do
      assert {200, rotated} = refresh(tokens["refresh_token"], client.client_id)

      used_at = DateTime.utc_now() |> DateTime.add(-31) |> DateTime.truncate(:second)

      from(t in McpOAuthRefreshToken, where: not is_nil(t.used_at))
      |> Repo.update_all(set: [used_at: used_at])

      assert {400, %{"error" => "invalid_grant"}} =
               refresh(tokens["refresh_token"], client.client_id)

      assert {400, %{"error" => "invalid_grant"}} =
               refresh(rotated["refresh_token"], client.client_id)
    end

    test "refreshes only for the client the token was issued to", %{
      client: client,
      tokens: tokens
    } do
      assert {400, %{"error" => "invalid_grant"}} =
               refresh(tokens["refresh_token"], create_test_client().client_id)

      assert {200, _} = refresh(tokens["refresh_token"], client.client_id)
    end

    test "rejects expired tokens and families", %{
      client: client,
      tokens: tokens,
      user_id: user_id
    } do
      past = DateTime.utc_now() |> DateTime.add(-1) |> DateTime.truncate(:second)

      Repo.update_all(McpOAuthRefreshToken, set: [expires_at: past])

      assert {400, %{"error" => "invalid_grant"}} =
               refresh(tokens["refresh_token"], client.client_id)

      tokens = exchange_code(client, user_id)
      Repo.update_all(McpOAuthRefreshTokenFamily, set: [expires_at: past])

      assert {400, %{"error" => "invalid_grant"}} =
               refresh(tokens["refresh_token"], client.client_id)
    end

    test "revokes the family of a blocked or deactivated user", %{
      client: client,
      user_id: user_id
    } do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      user = from(u in FrontRepo.User, where: u.id == ^user_id)

      for change <- [[blocked_at: now], [deactivated: true]] do
        tokens = exchange_code(client, user_id)

        FrontRepo.update_all(user, set: change)

        assert {400, %{"error" => "invalid_grant"}} =
                 refresh(tokens["refresh_token"], client.client_id)

        FrontRepo.update_all(user, set: [blocked_at: nil, deactivated: false])

        assert {400, %{"error" => "invalid_grant"}} =
                 refresh(tokens["refresh_token"], client.client_id)
      end
    end

    test "keeps the scope originally granted", %{client: client, tokens: tokens} do
      assert {400, %{"error" => "invalid_scope"}} =
               refresh(tokens["refresh_token"], client.client_id, %{"scope" => "computers"})

      assert {200, %{"scope" => "mcp"}} =
               refresh(tokens["refresh_token"], client.client_id, %{"scope" => "mcp"})
    end

    test "requires a refresh token", %{client: client} do
      assert {400, %{"error" => "invalid_request"}} =
               post_token(%{"grant_type" => "refresh_token", "client_id" => client.client_id})
    end

    test "rotates one token for concurrent requests", %{client: client, tokens: tokens} do
      results =
        1..3
        |> Task.async_stream(fn _ -> refresh(tokens["refresh_token"], client.client_id) end)
        |> Enum.map(fn {:ok, result} -> result end)

      refresh_tokens = for {200, result} <- results, do: result["refresh_token"]
      assert refresh_tokens |> Enum.uniq() |> length() == 3
    end
  end

  # ====================
  # Grant selection -> token: identity binding
  # ====================

  describe "POST /revoke" do
    setup %{user_id: user_id} do
      client = create_test_client()

      {:ok, client: client, tokens: exchange_code(client, user_id)}
    end

    defp revoke(params) do
      {:ok, response} =
        HTTPoison.post(mcp_oauth_url("/revoke"), URI.encode_query(params), form_headers())

      {response.status_code, response.body}
    end

    test "revokes the token's family, from a token already rotated", %{
      client: client,
      tokens: tokens
    } do
      assert {200, rotated} = refresh(tokens["refresh_token"], client.client_id)

      assert {200, ""} =
               revoke(%{"token" => tokens["refresh_token"], "client_id" => client.client_id})

      assert {400, %{"error" => "invalid_grant"}} =
               refresh(rotated["refresh_token"], client.client_id)
    end

    test "answers the same for an unknown token, or one already revoked", %{
      client: client,
      tokens: tokens
    } do
      params = %{"token" => tokens["refresh_token"], "client_id" => client.client_id}

      assert {200, ""} = revoke(%{params | "token" => "unknown"})
      assert {200, ""} = revoke(params)
      assert {200, ""} = revoke(Map.put(params, "token_type_hint", "refresh_token"))
    end

    test "leaves another client's token live", %{client: client, tokens: tokens} do
      other = create_test_client()

      assert {200, ""} =
               revoke(%{"token" => tokens["refresh_token"], "client_id" => other.client_id})

      assert {200, _} = refresh(tokens["refresh_token"], client.client_id)
    end

    test "needs the token and the client" do
      assert {400, body} = revoke(%{"token" => "a-token"})
      assert Jason.decode!(body)["error"] == "invalid_request"
    end
  end

  describe "authorize -> grant -> token identity binding" do
    test "an authenticated session mints a token bound to that session user", %{user_id: user_id} do
      client = create_test_client()

      claims = complete_oauth_flow(client, user_id)

      assert claims["sub"] == user_id
      assert claims["semaphore_user_id"] == user_id
    end

    test "an x-semaphore-user-id header does not change which user a session's grant is bound to",
         %{user_id: user_id, other_user_id: other_user_id} do
      client = create_test_client()

      # A signed-in session also supplies an x-semaphore-user-id header naming a
      # different user on the grant POST. The minted token is bound to the
      # session user, never to the user id in the header.
      claims = complete_oauth_flow(client, other_user_id, header_user_id: user_id)

      assert claims["sub"] == other_user_id
      assert claims["semaphore_user_id"] == other_user_id
      refute claims["sub"] == user_id
    end

    test "grant-selection with only an x-semaphore-user-id header and no session issues no code",
         %{
           user_id: user_id
         } do
      client = create_test_client()

      {:ok, response} =
        HTTPoison.post(
          mcp_oauth_url("/grant-selection"),
          grant_form_body(client.client_id, "invalid-csrf"),
          [{"content-type", "application/x-www-form-urlencoded"} | id_header_only(user_id)],
          follow_redirect: false
        )

      # Rejected before any authorization code is issued (unauthenticated
      # identity and/or missing CSRF): never a 302 back to the client with a code.
      refute response.status_code == 302
      refute (get_header(response, "location") || "") =~ "code="
    end
  end

  # ====================
  # semaphore.computer's client
  # ====================

  @computers_client_id "semaphore-computer"
  @computers_client_secret "computers-secret"
  @computers_redirect_uri "https://semaphore.computer.test/auth/callback"
  @computers_audience "https://api.semaphore.computer.test"
  @computers_mcp_resource "https://api.semaphore.computer.test/mcp"

  defp computers_authorize(user_id, redirect_uri \\ @computers_redirect_uri),
    do: computers_authorize_as(session_headers(user_id), redirect_uri)

  defp computers_authorize_as(headers, redirect_uri \\ @computers_redirect_uri) do
    query =
      "?" <>
        URI.encode_query(%{
          "response_type" => "code",
          "client_id" => @computers_client_id,
          "redirect_uri" => redirect_uri,
          "code_challenge" => PKCE.compute_challenge(@code_verifier),
          "code_challenge_method" => "S256",
          "state" => "computers-state"
        })

    {:ok, response} =
      HTTPoison.get(mcp_oauth_url("/authorize#{query}"), headers, follow_redirect: false)

    response
  end

  defp warden_session_headers(user_id, salt) do
    value = Guard.Session.encrypt_cookie(%{"warden.user.user.key" => [[user_id], salt]})
    [{"cookie", "#{Application.get_env(:guard, :session_key)}=#{value}"} | default_headers()]
  end

  defp computers_token(code, params) do
    body =
      URI.encode_query(
        Map.merge(
          %{
            "grant_type" => "authorization_code",
            "code" => code,
            "redirect_uri" => @computers_redirect_uri,
            "client_id" => @computers_client_id,
            "code_verifier" => @code_verifier
          },
          params
        )
      )

    {:ok, response} = HTTPoison.post(mcp_oauth_url("/token"), body, form_headers())
    response
  end

  # Drives an MCP client through GET /authorize -> POST /grant-selection ->
  # POST /token for resource, as a browser would: the grant form carries what
  # the consent page put in it. Returns the consent page and the token answer.
  defp resource_flow(client, user_id, resource, token_params \\ %{}) do
    query =
      authorize_query(client.client_id) <> "&" <> URI.encode_query(%{"resource" => resource})

    {:ok, consent} = HTTPoison.get(mcp_oauth_url("/authorize#{query}"), session_headers(user_id))
    200 = consent.status_code

    [_, granted] = Regex.run(~r/name="resource" value="([^"]*)"/, consent.body)

    {:ok, grant} =
      HTTPoison.post(
        mcp_oauth_url("/grant-selection"),
        grant_form_body(client.client_id, extract_csrf_token(consent.body)) <>
          "&" <> URI.encode_query(%{"resource" => granted}),
        [
          {"content-type", "application/x-www-form-urlencoded"},
          {"cookie", extract_session_cookie(consent)}
        ] ++ default_headers(),
        follow_redirect: false
      )

    302 = grant.status_code

    answer =
      post_token(
        Map.merge(
          %{
            "grant_type" => "authorization_code",
            "code" => grant |> get_header("location") |> extract_code(),
            "redirect_uri" => @redirect_uri,
            "client_id" => client.client_id,
            "code_verifier" => @code_verifier,
            "resource" => resource
          },
          token_params
        )
      )

    {consent.body, answer}
  end

  defp computers_claims(access_token) do
    {:ok, jwks_resp} = HTTPoison.get(mcp_oauth_url("/jwks"), default_headers())
    [key] = Jason.decode!(jwks_resp.body)["keys"]

    {true, jwt, _jws} = JOSE.JWT.verify_strict(JOSE.JWK.from_map(key), ["RS256"], access_token)
    jwt.fields
  end

  describe "semaphore.computer's client" do
    setup do
      {_, pem} = {:rsa, 2048} |> JOSE.JWK.generate_key() |> JOSE.JWK.to_pem()

      env = %{
        "COMPUTERS_OAUTH_CLIENT_ID" => @computers_client_id,
        "COMPUTERS_OAUTH_CLIENT_SECRET" => @computers_client_secret,
        "COMPUTERS_OAUTH_REDIRECT_URIS" => @computers_redirect_uri,
        "COMPUTERS_OAUTH_AUDIENCE" => @computers_audience,
        "COMPUTERS_MCP_RESOURCES" =>
          "https://other.computer.test/mcp, #{@computers_mcp_resource}",
        "COMPUTERS_OAUTH_SIGNING_KEY" => String.replace(pem, "\n", "\\n")
      }

      System.put_env(env)
      on_exit(fn -> env |> Map.keys() |> Enum.each(&System.delete_env/1) end)

      :ok
    end

    test "signs people in without asking for consent", %{user_id: user_id} do
      response = computers_authorize(user_id)

      assert response.status_code == 302

      location = get_header(response, "location")
      assert String.starts_with?(location, @computers_redirect_uri <> "?")
      assert extract_code(location)
      assert location =~ "state=computers-state"
    end

    test "signs nobody in whose user is blocked or deactivated", %{user_id: user_id} do
      update = fn change ->
        Guard.FrontRepo.User
        |> Guard.FrontRepo.get!(user_id)
        |> Ecto.Changeset.change(change)
        |> Guard.FrontRepo.update!()
      end

      now = DateTime.utc_now() |> DateTime.truncate(:second)

      for change <- [[blocked_at: now], [deactivated: true]] do
        update.(change)

        location = user_id |> computers_authorize() |> get_header("location")
        assert String.starts_with?(location, "https://id.localhost/login?")

        update.(blocked_at: nil, deactivated: false)
      end

      location = user_id |> computers_authorize() |> get_header("location")
      assert String.starts_with?(location, @computers_redirect_uri)
    end

    test "signs a warden session in only with its user's salt", %{user_id: user_id} do
      Guard.FrontRepo.User
      |> Guard.FrontRepo.get!(user_id)
      |> Ecto.Changeset.change(salt: "salt")
      |> Guard.FrontRepo.update!()

      response = user_id |> warden_session_headers("salt") |> computers_authorize_as()
      assert response |> get_header("location") |> String.starts_with?(@computers_redirect_uri)

      response = user_id |> warden_session_headers("other") |> computers_authorize_as()

      assert response
             |> get_header("location")
             |> String.starts_with?("https://id.localhost/login?")
    end

    test "sends the browser nowhere it was not configured with", %{user_id: user_id} do
      response = computers_authorize(user_id, "https://evil.example.com/callback")

      assert response.status_code == 400
      refute get_header(response, "location")
    end

    test "revokes its refresh token only with its secret", %{user_id: user_id} do
      code = user_id |> computers_authorize() |> get_header("location") |> extract_code()
      token_resp = computers_token(code, %{"client_secret" => @computers_client_secret})
      tokens = Jason.decode!(token_resp.body)
      form = %{"token" => tokens["refresh_token"], "client_id" => @computers_client_id}

      {:ok, refused} =
        HTTPoison.post(mcp_oauth_url("/revoke"), URI.encode_query(form), form_headers())

      assert refused.status_code == 401
      assert Jason.decode!(refused.body)["error"] == "invalid_client"

      secret = %{"client_secret" => @computers_client_secret}
      assert {200, rotated} = refresh(tokens["refresh_token"], @computers_client_id, secret)

      {:ok, revoked} =
        HTTPoison.post(
          mcp_oauth_url("/revoke"),
          URI.encode_query(Map.merge(form, secret)),
          form_headers()
        )

      assert revoked.status_code == 200

      assert {400, %{"error" => "invalid_grant"}} =
               refresh(rotated["refresh_token"], @computers_client_id, secret)
    end

    test "issues RS256 tokens for its API, which the key at /jwks checks", %{user_id: user_id} do
      code = user_id |> computers_authorize() |> get_header("location") |> extract_code()

      token_resp = computers_token(code, %{"client_secret" => @computers_client_secret})
      assert token_resp.status_code == 200

      result = Jason.decode!(token_resp.body)
      assert result["scope"] == "computers"
      assert result["expires_in"] == 3600

      {:ok, jwks_resp} = HTTPoison.get(mcp_oauth_url("/jwks"), default_headers())
      assert [key] = Jason.decode!(jwks_resp.body)["keys"]
      assert key["kty"] == "RSA"
      assert key["use"] == "sig"
      refute Map.has_key?(key, "d")

      assert {true, jwt, jws} =
               JOSE.JWT.verify_strict(JOSE.JWK.from_map(key), ["RS256"], result["access_token"])

      assert jws.fields["kid"] == key["kid"]
      assert jwt.fields["iss"] == Guard.McpOAuth.JWT.issuer()
      assert jwt.fields["aud"] == @computers_audience
      assert jwt.fields["scope"] == "computers"
      assert jwt.fields["semaphore_user_id"] == user_id
      assert jwt.fields["exp"] > System.system_time(:second)
    end

    test "issues no token without the client secret, and keeps the code", %{user_id: user_id} do
      code = user_id |> computers_authorize() |> get_header("location") |> extract_code()

      for params <- [%{}, %{"client_secret" => "wrong"}] do
        response = computers_token(code, params)

        assert response.status_code == 400
        assert Jason.decode!(response.body)["error"] == "invalid_client"
      end

      response = computers_token(code, %{"client_secret" => @computers_client_secret})
      assert response.status_code == 200
    end

    test "refreshes its RS256 tokens only with its client secret", %{user_id: user_id} do
      code = user_id |> computers_authorize() |> get_header("location") |> extract_code()

      tokens =
        code
        |> computers_token(%{"client_secret" => @computers_client_secret})
        |> Map.fetch!(:body)
        |> Jason.decode!()

      for params <- [%{}, %{"client_secret" => "wrong"}] do
        assert {400, %{"error" => "invalid_client"}} =
                 refresh(tokens["refresh_token"], @computers_client_id, params)
      end

      assert {400, %{"error" => "invalid_grant"}} =
               refresh(tokens["refresh_token"], create_test_client().client_id)

      assert {200, result} =
               refresh(tokens["refresh_token"], @computers_client_id, %{
                 "client_secret" => @computers_client_secret
               })

      assert result["scope"] == "computers"
      assert result["expires_in"] == 3600
      refute result["refresh_token"] == tokens["refresh_token"]

      {:ok, jwks_resp} = HTTPoison.get(mcp_oauth_url("/jwks"), default_headers())
      assert [key] = Jason.decode!(jwks_resp.body)["keys"]

      assert {true, jwt, _jws} =
               JOSE.JWT.verify_strict(JOSE.JWK.from_map(key), ["RS256"], result["access_token"])

      assert jwt.fields["aud"] == @computers_audience
      assert jwt.fields["scope"] == "computers"
      assert jwt.fields["semaphore_user_id"] == user_id

      System.put_env("COMPUTERS_OAUTH_CLIENT_ID", "renamed")

      assert {400, %{"error" => "invalid_grant"}} =
               refresh(result["refresh_token"], @computers_client_id)
    end

    test "is not there when its signing key is not an RSA private key", %{user_id: user_id} do
      System.put_env("COMPUTERS_OAUTH_SIGNING_KEY", "not a key")

      response = computers_authorize(user_id)
      assert response.status_code == 400

      {:ok, jwks_resp} = HTTPoison.get(mcp_oauth_url("/jwks"), default_headers())
      assert Jason.decode!(jwks_resp.body)["keys"] == []
    end

    test "gives an MCP client its RS256 tokens for its MCP server, and refreshes them", %{
      user_id: user_id
    } do
      client = create_test_client()

      {consent, {200, tokens}} = resource_flow(client, user_id, @computers_mcp_resource)
      assert consent =~ "wants to use Semaphore Computer as you."
      assert tokens["scope"] == "computers"

      claims = computers_claims(tokens["access_token"])
      assert claims["aud"] == @computers_mcp_resource
      assert claims["scope"] == "computers"
      assert claims["semaphore_user_id"] == user_id

      assert {200, refreshed} = refresh(tokens["refresh_token"], client.client_id)
      assert refreshed["scope"] == "computers"
      assert computers_claims(refreshed["access_token"])["aud"] == @computers_mcp_resource

      System.put_env("COMPUTERS_MCP_RESOURCES", "https://other.computer.test/mcp")

      assert {400, %{"error" => "invalid_grant"}} =
               refresh(refreshed["refresh_token"], client.client_id)
    end

    test "gives a code for its MCP server for that server alone", %{user_id: user_id} do
      {_consent, answer} =
        resource_flow(create_test_client(), user_id, @computers_mcp_resource, %{
          "resource" => "https://other.computer.test/mcp"
        })

      assert {400, %{"error" => "invalid_target"}} = answer
    end

    test "leaves a client that asks for any other resource as it was", %{user_id: user_id} do
      {consent, {200, tokens}} =
        resource_flow(create_test_client(), user_id, "https://mcp.semaphoreci.com/mcp")

      assert consent =~ "wants to access your Semaphore account via MCP."
      assert tokens["scope"] == "mcp"

      signer = Joken.Signer.create("HS256", System.get_env("MCP_OAUTH_JWT_KEYS"))
      assert {:ok, claims} = Joken.verify(tokens["access_token"], signer)
      assert claims["aud"] == Guard.McpOAuth.JWT.audience()
    end

    test "leaves MCP clients as they were: consent, and MCP tokens", %{user_id: user_id} do
      claims = complete_oauth_flow(create_test_client(), user_id)

      assert claims["scope"] == "mcp"
      assert claims["aud"] == Guard.McpOAuth.JWT.audience()
    end
  end

  # ====================
  # Client ID Metadata Documents
  # ====================

  describe "a client with a metadata document" do
    setup do
      bypass = Bypass.open()
      System.put_env("MCP_OAUTH_CIMD_LOCAL_HOSTS", "localhost:#{bypass.port}")
      Cachex.clear(Guard.McpOAuth.ClientDocument.cache())

      on_exit(fn -> System.delete_env("MCP_OAUTH_CIMD_LOCAL_HOSTS") end)

      path = "/clients/" <> String.duplicate("a", 300) <> ".json"
      {:ok, bypass: bypass, path: path, client_id: "http://localhost:#{bypass.port}#{path}"}
    end

    defp document(client_id, changes \\ %{}) do
      Map.merge(
        %{
          "client_id" => client_id,
          "client_name" => "Document Client",
          "redirect_uris" => [@redirect_uri],
          "token_endpoint_auth_method" => "none"
        },
        changes
      )
    end

    defp serve(bypass, path, body, headers \\ [{"cache-control", "max-age=600"}]) do
      Bypass.expect(bypass, "GET", path, fn conn ->
        headers
        |> Enum.reduce(conn, fn {name, value}, conn ->
          Plug.Conn.put_resp_header(conn, name, value)
        end)
        |> Plug.Conn.resp(200, if(is_binary(body), do: body, else: Jason.encode!(body)))
      end)
    end

    defp authorize_document(client_id, user_id) do
      {:ok, response} =
        HTTPoison.get(
          mcp_oauth_url("/authorize#{authorize_query(client_id)}"),
          session_headers(user_id)
        )

      response
    end

    defp refused(response) do
      assert response.status_code == 400
      Jason.decode!(response.body)
    end

    test "signs in without registering, on a consent page that names its host", %{
      bypass: bypass,
      path: path,
      client_id: client_id,
      user_id: user_id
    } do
      serve(bypass, path, document(client_id))

      response = authorize_document(client_id, user_id)
      assert response.status_code == 200
      assert response.body =~ "Document Client"
      assert response.body =~ "Its details come from localhost."
      assert response.body =~ "you go back to a program on this computer"

      claims = complete_oauth_flow(%{client_id: client_id}, user_id)
      assert claims["sub"] == user_id
      refute Repo.exists?(from(c in Guard.Repo.McpOAuthClient, where: c.client_id == ^client_id))
    end

    test "is read once while its Cache-Control allows", %{
      bypass: bypass,
      path: path,
      client_id: client_id,
      user_id: user_id
    } do
      Bypass.expect_once(bypass, "GET", path, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("cache-control", "public, max-age=600")
        |> Plug.Conn.resp(200, Jason.encode!(document(client_id)))
      end)

      assert authorize_document(client_id, user_id).status_code == 200
      assert authorize_document(client_id, user_id).status_code == 200
    end

    test "is refused when it names another client_id", %{
      bypass: bypass,
      path: path,
      client_id: client_id,
      user_id: user_id
    } do
      serve(
        bypass,
        path,
        document(client_id, %{"client_id" => "https://evil.example/client.json"})
      )

      assert refused(authorize_document(client_id, user_id)) == %{
               "error" => "invalid_client",
               "error_description" => "client_id's metadata document names another client_id"
             }
    end

    test "takes a loopback redirect_uri on any port when it lists one without a port", %{
      bypass: bypass,
      path: path,
      client_id: client_id,
      user_id: user_id
    } do
      serve(
        bypass,
        path,
        document(client_id, %{"redirect_uris" => ["http://localhost/callback"]})
      )

      assert authorize_document(client_id, user_id).status_code == 200

      {:ok, response} =
        HTTPoison.get(
          mcp_oauth_url(
            "/authorize#{authorize_query(client_id, redirect_uri: "http://localhost:3000/other")}"
          ),
          session_headers(user_id)
        )

      assert refused(response)["error_description"] ==
               "redirect_uri does not match registered URIs"
    end

    test "is refused for a redirect_uri it does not list", %{
      bypass: bypass,
      path: path,
      client_id: client_id,
      user_id: user_id
    } do
      serve(
        bypass,
        path,
        document(client_id, %{"redirect_uris" => ["http://localhost:4000/callback"]})
      )

      assert refused(authorize_document(client_id, user_id))["error_description"] ==
               "redirect_uri does not match registered URIs"
    end

    test "is refused for a confidential client", %{
      bypass: bypass,
      path: path,
      client_id: client_id,
      user_id: user_id
    } do
      serve(
        bypass,
        path,
        document(client_id, %{"token_endpoint_auth_method" => "private_key_jwt"})
      )

      assert refused(authorize_document(client_id, user_id))["error_description"] =~
               "token_endpoint_auth_method must be none"
    end

    test "is refused when it redirects", %{
      bypass: bypass,
      path: path,
      client_id: client_id,
      user_id: user_id
    } do
      Bypass.expect_once(bypass, "GET", path, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("location", "http://localhost:#{bypass.port}/elsewhere.json")
        |> Plug.Conn.resp(302, "")
      end)

      assert refused(authorize_document(client_id, user_id))["error_description"] ==
               "client_id's metadata document redirects"
    end

    test "is refused when it is over 5 KiB", %{
      bypass: bypass,
      path: path,
      client_id: client_id,
      user_id: user_id
    } do
      serve(bypass, path, document(client_id, %{"client_name" => String.duplicate("x", 6_000)}))

      assert refused(authorize_document(client_id, user_id))["error_description"] ==
               "client_id's metadata document is over 5120 bytes"
    end

    test "is refused on a private address, or over http, unless its host is local", %{
      bypass: bypass,
      path: path,
      user_id: user_id
    } do
      for {client_id, reason} <- [
            {"https://127.0.0.1:#{bypass.port}#{path}", "is on a private address"},
            {"https://localhost#{path}", "is on a private address"},
            {"https://[::1]:#{bypass.port}#{path}", "is on a private address"},
            {"http://127.0.0.1:#{bypass.port}#{path}", "is not at an https URL"},
            {"https://localhost:#{bypass.port}/", "is not at a URL with a path"},
            {"https://localhost:#{bypass.port}/a/../b.json", "is at a URL with a . or .. segment"}
          ] do
        assert refused(authorize_document(client_id, user_id))["error_description"] ==
                 "client_id's metadata document #{reason}"
      end
    end

    test "refreshes while the document describes it, and not once it is gone", %{
      bypass: bypass,
      path: path,
      client_id: client_id,
      user_id: user_id
    } do
      serve(bypass, path, document(client_id))
      tokens = exchange_code(%{client_id: client_id}, user_id)
      assert {200, refreshed} = refresh(tokens["refresh_token"], client_id)

      Cachex.clear(Guard.McpOAuth.ClientDocument.cache())
      Bypass.down(bypass)

      assert {400, %{"error" => "invalid_grant"}} = refresh(refreshed["refresh_token"], client_id)
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
