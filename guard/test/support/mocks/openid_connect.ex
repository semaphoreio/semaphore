defmodule Guard.Mocks.OpenIDConnect do
  def stub_oidc_connection do
    # Use this to clear the oidc setting in tests
    # oidc_env = Application.get_env(:guard, :oidc)
    # on_exit(fn ->
    #   Application.put_env(:guard, :oidc, oidc_env)
    # end)
    #

    bypass = Guard.Mocks.OpenIDConnect.discovery_document_server()
    disc_url = "http://localhost:#{bypass.port}/.well-known/openid-configuration"
    manage_url = "http://localhost/manage/"

    Application.put_env(:guard, :oidc, %{
      discovery_url: disc_url,
      client_id: "test_client_id",
      client_secret: "test_client_secret",
      manage_url: manage_url
    })

    {token, _claims} =
      Guard.Mocks.OpenIDConnect.generate_openid_connect_token(%{client_id: "test_client_id"}, %{
        id: Ecto.UUID.generate(),
        name: "test",
        email: "email@email.com"
      })

    Guard.Mocks.OpenIDConnect.expect_fetch_token(bypass, %{
      "token_type" => "Bearer",
      "id_token" => token,
      "access_token" => "MY_ACCESS_TOKEN",
      "refresh_token" => "OTHER_REFRESH_TOKEN",
      "expires_in" => 300
    })
  end

  def discovery_document_server do
    bypass = Bypass.open()
    endpoint = "http://localhost:#{bypass.port}"
    test_pid = self()

    Bypass.stub(bypass, "GET", "/protocol/openid-connect/certs", fn conn ->
      attrs = %{"keys" => [jwks()]}
      Plug.Conn.resp(conn, 200, Jason.encode!(attrs))
    end)

    Bypass.stub(bypass, "GET", "/.well-known/openid-configuration", fn conn ->
      conn = fetch_conn_params(conn)
      send(test_pid, {:request, conn})

      attrs = %{
        "issuer" => "#{endpoint}/",
        "authorization_endpoint" => "#{endpoint}/protocol/openid-connect/auth",
        "token_endpoint" => "#{endpoint}/protocol/openid-connect/token",
        "introspection_endpoint" => "#{endpoint}/protocol/openid-connect/token/introspect",
        "userinfo_endpoint" => "#{endpoint}/protocol/openid-connect/userinfo",
        "end_session_endpoint" => "#{endpoint}/protocol/openid-connect/logout",
        "frontchannel_logout_session_supported" => true,
        "frontchannel_logout_supported" => true,
        "jwks_uri" => "#{endpoint}/protocol/openid-connect/certs",
        "check_session_iframe" => "#{endpoint}/protocol/openid-connect/login-status-iframe.html",
        "grant_types_supported" => [
          "authorization_code",
          "implicit",
          "refresh_token",
          "password",
          "client_credentials",
          "urn:openid:params:grant-type:ciba",
          "urn:ietf:params:oauth:grant-type:device_code"
        ],
        "acr_values_supported" => [
          "0",
          "1"
        ],
        "response_types_supported" => [
          "code",
          "none",
          "id_token",
          "token",
          "id_token token",
          "code id_token",
          "code token",
          "code id_token token"
        ],
        "subject_types_supported" => [
          "public",
          "pairwise"
        ],
        "id_token_signing_alg_values_supported" => [
          "PS384",
          "RS384",
          "EdDSA",
          "ES384",
          "HS256",
          "HS512",
          "ES256",
          "RS256",
          "HS384",
          "ES512",
          "PS256",
          "PS512",
          "RS512"
        ],
        "id_token_encryption_alg_values_supported" => [
          "RSA-OAEP",
          "RSA-OAEP-256",
          "RSA1_5"
        ],
        "id_token_encryption_enc_values_supported" => [
          "A256GCM",
          "A192GCM",
          "A128GCM",
          "A128CBC-HS256",
          "A192CBC-HS384",
          "A256CBC-HS512"
        ],
        "userinfo_signing_alg_values_supported" => [
          "PS384",
          "RS384",
          "EdDSA",
          "ES384",
          "HS256",
          "HS512",
          "ES256",
          "RS256",
          "HS384",
          "ES512",
          "PS256",
          "PS512",
          "RS512",
          "none"
        ],
        "userinfo_encryption_alg_values_supported" => [
          "RSA-OAEP",
          "RSA-OAEP-256",
          "RSA1_5"
        ],
        "userinfo_encryption_enc_values_supported" => [
          "A256GCM",
          "A192GCM",
          "A128GCM",
          "A128CBC-HS256",
          "A192CBC-HS384",
          "A256CBC-HS512"
        ],
        "request_object_signing_alg_values_supported" => [
          "PS384",
          "RS384",
          "EdDSA",
          "ES384",
          "HS256",
          "HS512",
          "ES256",
          "RS256",
          "HS384",
          "ES512",
          "PS256",
          "PS512",
          "RS512",
          "none"
        ],
        "request_object_encryption_alg_values_supported" => [
          "RSA-OAEP",
          "RSA-OAEP-256",
          "RSA1_5"
        ],
        "request_object_encryption_enc_values_supported" => [
          "A256GCM",
          "A192GCM",
          "A128GCM",
          "A128CBC-HS256",
          "A192CBC-HS384",
          "A256CBC-HS512"
        ],
        "response_modes_supported" => [
          "query",
          "fragment",
          "form_post",
          "query.jwt",
          "fragment.jwt",
          "form_post.jwt",
          "jwt"
        ],
        "registration_endpoint" => "#{endpoint}/clients-registrations/openid-connect",
        "token_endpoint_auth_methods_supported" => [
          "private_key_jwt",
          "client_secret_basic",
          "client_secret_post",
          "tls_client_auth",
          "client_secret_jwt"
        ],
        "token_endpoint_auth_signing_alg_values_supported" => [
          "PS384",
          "RS384",
          "EdDSA",
          "ES384",
          "HS256",
          "HS512",
          "ES256",
          "RS256",
          "HS384",
          "ES512",
          "PS256",
          "PS512",
          "RS512"
        ],
        "introspection_endpoint_auth_methods_supported" => [
          "private_key_jwt",
          "client_secret_basic",
          "client_secret_post",
          "tls_client_auth",
          "client_secret_jwt"
        ],
        "introspection_endpoint_auth_signing_alg_values_supported" => [
          "PS384",
          "RS384",
          "EdDSA",
          "ES384",
          "HS256",
          "HS512",
          "ES256",
          "RS256",
          "HS384",
          "ES512",
          "PS256",
          "PS512",
          "RS512"
        ],
        "authorization_signing_alg_values_supported" => [
          "PS384",
          "RS384",
          "EdDSA",
          "ES384",
          "HS256",
          "HS512",
          "ES256",
          "RS256",
          "HS384",
          "ES512",
          "PS256",
          "PS512",
          "RS512"
        ],
        "authorization_encryption_alg_values_supported" => [
          "RSA-OAEP",
          "RSA-OAEP-256",
          "RSA1_5"
        ],
        "authorization_encryption_enc_values_supported" => [
          "A256GCM",
          "A192GCM",
          "A128GCM",
          "A128CBC-HS256",
          "A192CBC-HS384",
          "A256CBC-HS512"
        ],
        "claims_supported" => [
          "aud",
          "sub",
          "iss",
          "auth_time",
          "name",
          "given_name",
          "family_name",
          "preferred_username",
          "email",
          "acr"
        ],
        "claim_types_supported" => [
          "normal"
        ],
        "claims_parameter_supported" => true,
        "scopes_supported" => [
          "openid",
          "phone",
          "profile",
          "email",
          "microprofile-jwt",
          "web-origins",
          "offline_access",
          "roles",
          "address",
          "acr"
        ],
        "request_parameter_supported" => true,
        "request_uri_parameter_supported" => true,
        "require_request_uri_registration" => true,
        "code_challenge_methods_supported" => [
          "plain",
          "S256"
        ],
        "tls_client_certificate_bound_access_tokens" => true,
        "revocation_endpoint" => "#{endpoint}/protocol/openid-connect/revoke",
        "revocation_endpoint_auth_methods_supported" => [
          "private_key_jwt",
          "client_secret_basic",
          "client_secret_post",
          "tls_client_auth",
          "client_secret_jwt"
        ],
        "revocation_endpoint_auth_signing_alg_values_supported" => [
          "PS384",
          "RS384",
          "EdDSA",
          "ES384",
          "HS256",
          "HS512",
          "ES256",
          "RS256",
          "HS384",
          "ES512",
          "PS256",
          "PS512",
          "RS512"
        ],
        "backchannel_logout_supported" => true,
        "backchannel_logout_session_supported" => true,
        "device_authorization_endpoint" => "#{endpoint}/protocol/openid-connect/auth/device",
        "backchannel_token_delivery_modes_supported" => [
          "poll",
          "ping"
        ],
        "backchannel_authentication_endpoint" =>
          "#{endpoint}/protocol/openid-connect/ext/ciba/auth",
        "backchannel_authentication_request_signing_alg_values_supported" => [
          "PS384",
          "RS384",
          "EdDSA",
          "ES384",
          "ES256",
          "RS256",
          "ES512",
          "PS256",
          "PS512",
          "RS512"
        ],
        "require_pushed_authorization_requests" => false,
        "pushed_authorization_request_endpoint" =>
          "#{endpoint}/protocol/openid-connect/ext/par/request",
        "mtls_endpoint_aliases" => %{
          "token_endpoint" => "#{endpoint}/protocol/openid-connect/token",
          "revocation_endpoint" => "#{endpoint}/protocol/openid-connect/revoke",
          "introspection_endpoint" => "#{endpoint}/protocol/openid-connect/token/introspect",
          "device_authorization_endpoint" => "#{endpoint}/protocol/openid-connect/auth/device",
          "registration_endpoint" => "#{endpoint}/clients-registrations/openid-connect",
          "userinfo_endpoint" => "#{endpoint}/protocol/openid-connect/userinfo",
          "pushed_authorization_request_endpoint" =>
            "#{endpoint}/protocol/openid-connect/ext/par/request",
          "backchannel_authentication_endpoint" =>
            "#{endpoint}/protocol/openid-connect/ext/ciba/auth"
        },
        "authorization_response_iss_parameter_supported" => true
      }

      Plug.Conn.resp(conn, 200, Jason.encode!(attrs))
    end)

    bypass
  end

  def expect_fetch_token(bypass, attrs \\ %{}) do
    test_pid = self()

    Bypass.expect(bypass, "POST", "/protocol/openid-connect/token", fn conn ->
      conn = fetch_conn_params(conn)
      send(test_pid, {:request, conn})
      Plug.Conn.resp(conn, 200, Jason.encode!(attrs))
    end)

    bypass
  end

  def expect_fetch_token_failure(bypass, attrs \\ %{}) do
    test_pid = self()

    Bypass.expect(bypass, "POST", "/protocol/openid-connect/token", fn conn ->
      conn = fetch_conn_params(conn)
      send(test_pid, {:request, conn})
      Plug.Conn.resp(conn, 401, Jason.encode!(attrs))
    end)

    bypass
  end

  def generate_openid_connect_token(provider, identity, claims \\ %{}) do
    claims =
      Map.merge(
        %{
          "email" => identity.email,
          "sub" => identity.id,
          "name" => identity.name,
          "aud" => provider.client_id,
          "exp" => DateTime.utc_now() |> DateTime.add(10, :second) |> DateTime.to_unix()
        },
        claims
      )
      |> Map.filter(fn {_, v} -> not is_nil(v) end)

    {sign_openid_connect_token(claims), claims}
  end

  def sign_openid_connect_token(claims) do
    {_alg, token} =
      jwks()
      |> JOSE.JWK.from()
      |> JOSE.JWS.sign(Jason.encode!(claims), %{"alg" => "RS256"})
      |> JOSE.JWS.compact()

    token
  end

  def jwks do
    %{
      "alg" => "RS256",
      "d" =>
        "jzeDDjWWX-SHWXPKIRLx2q3Qlcy_EHnxSHiNzH3kkRobzdOnUkOMYTY3MrJXJgbSbcRawdANaf6Fc4GVOdxBPVClr9NHjjJudTE-x2bBEGCh95RJBhRvZLxEJZlCpRF5C10LTpCKxaK743eI7gWGj6AVnWa6aUxx9Hx4ognHkvbokYPu1CvolN8WJiFQWPuCclYIZcOoTPwqmqFpjmUtZuL_U3XqJWALL_3lUKNb5Kws-lTZXX7b8oWKJV4hRdtMPSUK_QZu3cyV0UP58gc-z2HAD0aHdnid-wqwb4HpDnN7nACm5tXuO0J-sQOozgap80Uc4tOHhlFX9SiK477P8Q",
      "e" => "AQAB",
      "kid" => "OlVfjY8MJWkoC2wEIESrxLnzI2CFQo5tar7PHnwf9Yw",
      "kty" => "RSA",
      "n" =>
        "tL1oOb0lu9FmyZFeEPkZIl9ibYNam4PDOEfYeDjVd5xT3MKqmpPQFn3qEVSMD-ceFp72ineUMIHS3VNCisu3iteWRZnihK9_ZO62MSflz0EjAZp2c16_5WXqEohOHckLkGdbkNOV9vx5FQ-49kavCWTkCCAt-83fOP5QjW7Kj8vJ0GWNgiChKf42wpK6H5DTTfolSeO6PT1XgW8D_o7ErJdYFaNQlL4nNU_S_YSRd2iaDytiQwEJK9vh8DME9AggZVJTWlt_ZP1n5ai9T60Rq_hRbsO6Ag6Yw5AKYj9mfiu-qScpeUXpQNv7FtnvwJuepXMlicvHxPC_Ga1Iy7NPdw",
      "use" => "sig",
      "x5c" => [
        "MIICoTCCAYkCBgGPV6MUHTANBgkqhkiG9w0BAQsFADAUMRIwEAYDVQQDDAlzZW1hcGhvcmUwHhcNMjQwNTA4MDk1NTU2WhcNMzQwNTA4MDk1NzM2WjAUMRIwEAYDVQQDDAlzZW1hcGhvcmUwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDCMZLhbIbTl+VqVO7mqnQ82sAd+rcoG4mhhrOYufZ7OLzTlXPebGu963/ZTr08j8ifjlz8eeIqe3/2m4wvuGxM/oh7gW020xMv7BdAtg0L5upvrBLOmJcb7Vt3an8arCz4l9uXufQyyWxcpx1p/Zw050QJTLqKFLheI9i4OpQJo3gW19xbuFFrcNJU+auEZPudjIxuDDAnGFZi7XC0wFKtg84opf/JCz8L/XmtiKpMgGJDIdRjCNdlHiJ1jPUIEsaC7ExT8SY6R6oCFKkfgBU2niH/QfXoOfVJ1QPLatD1eK+LiSMmhe2MxxoUGddP6GTJ2mR8rnrmIhoBpKZLEMt1AgMBAAEwDQYJKoZIhvcNAQELBQADggEBAHr5WDvzHd9AeZ3h3eBuw63G0rdRBqJjSjwQhtKIBC+IqgwicLbBOo+YFpj4XBs1G/QzbAHhlD7YkW5pR3co+ca8nOSbloA2xIVSvg69iOsGFSyffwaei8X1leiqiZko+uzVvIkts7WIyngVByQQtYV6HAhr0WXlbamNIDjLd7VdKZv6YVJuZ6cJS3lVPiwiL7rwmjW8PvJukp+dPaA2HyHpThgeW//G8DWV28GMvNyS9oLzckzg/3g5lDgU8NzVwjdMeGcZqUynozD6ue90xDSletqhhOb5P7ZMx08QiIjyt0/ro3dI90OCKnDZjmRGt3sbJiLRIwh6fDQ3Vgg5rsU="
      ],
      "x5t" => "bDVhpmXL5oWKJm1BDu6_Y9QXnKw",
      "x5t#S256" => "o52lv-Y7O5bmEiY6p3iF2WXjep6GFIoAk7C9VWkB58A"
    }
  end

  defp fetch_conn_params(conn) do
    opts = Plug.Parsers.init(parsers: [:urlencoded, :json], pass: ["*/*"], json_decoder: Jason)

    conn
    |> Plug.Conn.fetch_query_params()
    |> Plug.Parsers.call(opts)
  end
end
