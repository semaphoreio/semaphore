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

    # Each session user needs a row in BOTH stores: the RBAC user satisfies the
    # oidc_sessions.user_id foreign key, and the front user is what the OAuth
    # identity actually resolves against (Guard.FrontRepo.User.active_user_by_id/1),
    # so it must exist there and be unblocked. A salt is stored so the same user
    # can also authenticate through a legacy warden session.
    user_id = Ecto.UUID.generate()
    user_name = "session-user-#{System.unique_integer([:positive])}"
    user_salt = "salt-#{System.unique_integer([:positive])}"
    {:ok, _rbac_user} = Support.Factories.RbacUser.insert(user_id, user_name)

    {:ok, _user} =
      Support.Factories.FrontUser.insert(id: user_id, name: user_name, salt: user_salt)

    other_user_id = Ecto.UUID.generate()
    other_user_name = "other-user-#{System.unique_integer([:positive])}"
    other_user_salt = "salt-#{System.unique_integer([:positive])}"
    {:ok, _other_rbac_user} = Support.Factories.RbacUser.insert(other_user_id, other_user_name)

    {:ok, _other_user} =
      Support.Factories.FrontUser.insert(
        id: other_user_id,
        name: other_user_name,
        salt: other_user_salt
      )

    System.put_env("MCP_OAUTH_JWT_KEYS", "test-secret-key-for-mcp-oauth-tests")

    on_exit(fn ->
      System.delete_env("MCP_OAUTH_JWT_KEYS")
    end)

    {:ok,
     user_id: user_id,
     user_name: user_name,
     user_salt: user_salt,
     other_user_id: other_user_id,
     other_user_name: other_user_name,
     other_user_salt: other_user_salt}
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

  # Builds a genuine legacy Devise/warden authenticated session for user_id
  # (session key [[user_id], salt], exactly as Guard.Session.serialize_into_session
  # writes it) and returns the request headers carrying its signed+encrypted
  # session cookie.
  defp warden_session_headers(user_id, salt, extra_headers \\ []) do
    value =
      %{"warden.user.user.key" => [[user_id], salt]}
      |> Guard.Session.encrypt_cookie()

    cookie = {"cookie", "#{Application.get_env(:guard, :session_key)}=#{value}"}
    [cookie | extra_headers ++ default_headers()]
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

    # get_lazy: the default must NOT be built when :auth_headers is supplied,
    # otherwise a caller driving a warden session would also create an unused
    # OIDC session.
    auth_headers =
      Keyword.get_lazy(opts, :auth_headers, fn -> session_headers(session_user_id) end)

    {:ok, authorize_resp} =
      HTTPoison.get(
        mcp_oauth_url("/authorize#{authorize_query(client.client_id)}"),
        auth_headers
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
      assert result["grant_types"] == ["authorization_code"]
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

    test "a blocked user with a live OIDC session is not authenticated and gets no code" do
      blocked_id = Ecto.UUID.generate()
      # Exists in RBAC (so a real session row can reference it) but is blocked
      # in the front users table.
      {:ok, _} = Support.Factories.RbacUser.insert(blocked_id, "blocked-user")

      {:ok, _} =
        Support.Factories.FrontUser.insert(
          id: blocked_id,
          name: "blocked-user",
          blocked_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      client = create_test_client()
      query = authorize_query(client.client_id)

      {:ok, response} =
        HTTPoison.get(mcp_oauth_url("/authorize#{query}"), session_headers(blocked_id),
          follow_redirect: false
        )

      # A blocked account resolves to not-authenticated even with a live session
      # cookie: redirected to login, no authorization code minted.
      assert response.status_code == 302
      location = get_header(response, "location")
      assert location =~ "/login"
      refute location =~ "code="
      refute location =~ @redirect_uri
    end

    test "a deactivated user with a live OIDC session is not authenticated and gets no code" do
      deactivated_id = Ecto.UUID.generate()
      {:ok, _} = Support.Factories.RbacUser.insert(deactivated_id, "deactivated-user")

      {:ok, _} =
        Support.Factories.FrontUser.insert(
          id: deactivated_id,
          name: "deactivated-user",
          deactivated: true,
          deactivated_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      client = create_test_client()
      query = authorize_query(client.client_id)

      {:ok, response} =
        HTTPoison.get(mcp_oauth_url("/authorize#{query}"), session_headers(deactivated_id),
          follow_redirect: false
        )

      assert response.status_code == 302
      location = get_header(response, "location")
      assert location =~ "/login"
      refute location =~ "code="
      refute location =~ @redirect_uri
    end

    test "a legacy warden session with the correct salt returns the consent page", %{
      user_id: user_id,
      user_name: user_name,
      user_salt: user_salt
    } do
      client = create_test_client()
      query = authorize_query(client.client_id)

      {:ok, response} =
        HTTPoison.get(
          mcp_oauth_url("/authorize#{query}"),
          warden_session_headers(user_id, user_salt)
        )

      assert response.status_code == 200
      assert_content_type(response, "text/html")
      assert response.body =~ "Authorize MCP Access"
      assert response.body =~ user_name
    end

    test "a warden session with a stale salt is not authenticated and gets no code", %{
      user_id: user_id
    } do
      client = create_test_client()
      query = authorize_query(client.client_id)

      {:ok, response} =
        HTTPoison.get(
          mcp_oauth_url("/authorize#{query}"),
          warden_session_headers(user_id, "stale-salt-does-not-match"),
          follow_redirect: false
        )

      # The stored session salt no longer matches (password reset /
      # sign-out-everywhere): the warden session is rejected, no code minted.
      assert response.status_code == 302
      location = get_header(response, "location")
      assert location =~ "/login"
      refute location =~ "code="
      refute location =~ @redirect_uri
    end

    test "a warden session for a user with no stored salt is not authenticated (fails closed, no crash)" do
      # A legacy/OIDC-only account can have a nil salt. A salt-bearing warden
      # session for it must fail closed (login redirect), never raise a 500 in
      # the secure_compare.
      nil_salt_id = Ecto.UUID.generate()
      {:ok, _} = Support.Factories.RbacUser.insert(nil_salt_id, "nil-salt-user")
      {:ok, _} = Support.Factories.FrontUser.insert(id: nil_salt_id, name: "nil-salt-user")

      client = create_test_client()
      query = authorize_query(client.client_id)

      {:ok, response} =
        HTTPoison.get(
          mcp_oauth_url("/authorize#{query}"),
          warden_session_headers(nil_salt_id, "any-salt-here"),
          follow_redirect: false
        )

      assert response.status_code == 302
      location = get_header(response, "location")
      assert location =~ "/login"
      refute location =~ "code="
      refute location =~ @redirect_uri
    end

    test "a revoked OIDC session (refresh token nulled) is not authenticated and gets no code", %{
      user_id: user_id
    } do
      session = create_oidc_session(user_id)

      # Revocation as production records it (Guard.Store.OIDCSession.remove_refresh_token/1):
      # the refresh token is nulled, expires_at is left in the future. This is how
      # "sign out everywhere" and the refresh-resolved-to-a-different-user path
      # revoke a session. AuthServer rejects it; the MCP flow must too.
      {:ok, _} = Guard.Store.OIDCSession.remove_refresh_token(session)
      {:ok, revoked} = Guard.Store.OIDCSession.get(session.id)
      # Guard against a false pass: the session is genuinely NOT expired, so this
      # exercises the refresh-token check, not the expiry check.
      refute Guard.Store.OIDCSession.expired?(revoked)

      client = create_test_client()
      query = authorize_query(client.client_id)

      {:ok, response} =
        HTTPoison.get(
          mcp_oauth_url("/authorize#{query}"),
          [session_cookie_header(session) | default_headers()],
          follow_redirect: false
        )

      assert response.status_code == 302
      location = get_header(response, "location")
      assert location =~ "/login"
      refute location =~ "code="
      refute location =~ @redirect_uri
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
  # Grant selection -> token: identity binding
  # ====================

  describe "authorize -> grant -> token identity binding" do
    test "an authenticated session mints a token bound to that session user", %{user_id: user_id} do
      client = create_test_client()

      claims = complete_oauth_flow(client, user_id)

      assert claims["sub"] == user_id
      assert claims["semaphore_user_id"] == user_id
    end

    test "a legacy warden session with the correct salt mints a token bound to that user", %{
      user_id: user_id,
      user_salt: user_salt
    } do
      client = create_test_client()

      claims =
        complete_oauth_flow(client, user_id,
          auth_headers: warden_session_headers(user_id, user_salt)
        )

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
