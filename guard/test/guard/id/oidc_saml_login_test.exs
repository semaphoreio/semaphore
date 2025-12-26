defmodule Guard.Id.OIDCSamlLoginTest do
  use Guard.RepoCase, async: false
  doctest Guard.Id.Api, import: true

  use Plug.Test
  import Support.ApiTestHelpers

  setup do
    FunRegistry.clear!()
    Guard.FakeServers.setup_responses_for_development()

    Support.Guard.Store.clear!()
    Guard.FrontRepo.delete_all(Guard.FrontRepo.User)

    original_login_method = Application.get_env(:guard, :default_login_method)

    # Set SAML as default login method for tests
    Application.put_env(:guard, :default_login_method, "saml")

    # Set up a bypass for OpenID Connect
    bypass = Guard.Mocks.OpenIDConnect.discovery_document_server()
    disc_url = "http://localhost:#{bypass.port}/.well-known/openid-configuration"

    oidc = Application.get_env(:guard, :oidc)

    # Configure OIDC for tests
    Application.put_env(:guard, :oidc, %{
      discovery_url: disc_url,
      client_id: "test_client_id",
      client_secret: "test_client_secret"
    })

    on_exit(fn ->
      # Restore original settings
      Application.put_env(:guard, :default_login_method, original_login_method)
      Application.put_env(:guard, :oidc, oidc)
    end)

    %{bypass: bypass, client_id: "test_client_id"}
  end

  describe "OIDC login when SAML is default login method" do
    test "root user can log in via OIDC", %{bypass: bypass, client_id: client_id} do
      # Create a root user (not a single org user, no creation source)
      {:ok, user} = Support.Factories.RbacUser.insert()
      user_id = user.id
      oidc_user_id = Ecto.UUID.generate()

      # Register the user in OIDC
      {:ok, _oidc_user} = Support.Factories.OIDCUser.insert(user_id, oidc_user_id)

      # Create front repo user with root attributes
      {:ok, _front_user} =
        Support.Members.insert_user(
          id: user_id,
          email: user.email,
          name: user.name,
          single_org_user: false,
          creation_source: nil
        )

      # Create a JWT token for authentication
      {token, _claims} =
        Guard.Mocks.OpenIDConnect.generate_openid_connect_token(
          %{client_id: client_id},
          %{
            id: oidc_user_id,
            name: user.name,
            email: user.email
          }
        )

      # Mock the token exchange response
      Guard.Mocks.OpenIDConnect.expect_fetch_token(bypass, %{
        "token_type" => "Bearer",
        "id_token" => token,
        "access_token" => "MY_ACCESS_TOKEN",
        "refresh_token" => "OTHER_REFRESH_TOKEN",
        "expires_in" => 300
      })

      # Initiate login flow
      {:ok, response} = send_login_request(path: "/oidc/login")
      {_, cookie} = Enum.find(response.headers, fn h -> elem(h, 0) == "set-cookie" end)

      {:ok, state} = extract_state_from_body(response.body)

      # Complete login flow
      {:ok, response} =
        send_login_request(
          path: "/oidc/callback",
          headers: [{"cookie", cookie}],
          query: %{state: state}
        )

      # Check that login was successful
      assert response.status_code == 302
      {_, location} = Enum.find(response.headers, fn h -> elem(h, 0) == "location" end)
      {_, cookie} = Enum.find(response.headers, fn h -> elem(h, 0) == "set-cookie" end)

      %{
        "id_provider" => "OIDC",
        "oidc_session_id" => session_id
      } = extarct_session_data_from_cookie(cookie)

      {:ok, session} = Guard.Store.OIDCSession.get(session_id)

      # Verify the session is created and user is logged in
      assert session.user_id == user_id
      assert location == "https://me.localhost"
    end

    test "non-root user cannot log in via OIDC when SAML is default", %{
      bypass: bypass,
      client_id: client_id
    } do
      # Create a regular user (single org user with creation source)
      {:ok, user} = Support.Factories.RbacUser.insert()
      user_id = user.id
      oidc_user_id = Ecto.UUID.generate()

      # Register the user in OIDC
      {:ok, _oidc_user} = Support.Factories.OIDCUser.insert(user_id, oidc_user_id)

      # Create front repo user with non-root attributes
      {:ok, _front_user} =
        Support.Members.insert_user(
          id: user_id,
          email: user.email,
          name: user.name,
          single_org_user: true,
          creation_source: :okta
        )

      # Create a JWT token for authentication
      {token, _claims} =
        Guard.Mocks.OpenIDConnect.generate_openid_connect_token(
          %{client_id: client_id},
          %{
            id: oidc_user_id,
            name: user.name,
            email: user.email
          }
        )

      # Mock the token exchange response
      Guard.Mocks.OpenIDConnect.expect_fetch_token(bypass, %{
        "token_type" => "Bearer",
        "id_token" => token,
        "access_token" => "MY_ACCESS_TOKEN",
        "refresh_token" => "OTHER_REFRESH_TOKEN",
        "expires_in" => 300
      })

      # Initiate login flow
      {:ok, response} = send_login_request(path: "/oidc/login")
      {_, cookie} = Enum.find(response.headers, fn h -> elem(h, 0) == "set-cookie" end)

      {:ok, state} = extract_state_from_body(response.body)

      # Complete login flow
      {:ok, response} =
        send_login_request(
          path: "/oidc/callback",
          headers: [{"cookie", cookie}],
          query: %{state: state}
        )

      # Check that login was rejected with error message
      assert response.status_code == 302
      {_, location} = Enum.find(response.headers, fn h -> elem(h, 0) == "location" end)

      schema = URI.parse(location)
      query = URI.decode_query(schema.query)

      assert query["status"] == "error"

      assert query["message"] =~
               "Login is not allowed when using SAML as the default authentication method"

      # Verify no session cookie is set (there may be cleanup cookies, but no _sxtesting_session cookie)
      session_cookie =
        Enum.find(response.headers, fn {key, value} ->
          key == "set-cookie" && String.contains?(value, "_sxtesting_session=")
        end)

      assert session_cookie == nil
    end

    test "user without OIDC account cannot log in", %{bypass: bypass, client_id: client_id} do
      # Create token for non-existent user
      oidc_user_id = Ecto.UUID.generate()

      # Create a JWT token for authentication
      {token, _claims} =
        Guard.Mocks.OpenIDConnect.generate_openid_connect_token(
          %{client_id: client_id},
          %{
            id: oidc_user_id,
            name: "Test User",
            email: "test@example.com"
          }
        )

      # Mock the token exchange response
      Guard.Mocks.OpenIDConnect.expect_fetch_token(bypass, %{
        "token_type" => "Bearer",
        "id_token" => token,
        "access_token" => "MY_ACCESS_TOKEN",
        "refresh_token" => "OTHER_REFRESH_TOKEN",
        "expires_in" => 300
      })

      # Initiate login flow
      {:ok, response} = send_login_request(path: "/oidc/login")
      {_, cookie} = Enum.find(response.headers, fn h -> elem(h, 0) == "set-cookie" end)

      {:ok, state} = extract_state_from_body(response.body)

      # Complete login flow
      {:ok, response} =
        send_login_request(
          path: "/oidc/callback",
          headers: [{"cookie", cookie}],
          query: %{state: state}
        )

      # Check that login was rejected with error message
      assert response.status_code == 302
      {_, location} = Enum.find(response.headers, fn h -> elem(h, 0) == "location" end)

      schema = URI.parse(location)
      query = URI.decode_query(schema.query)

      assert query["status"] == "error"

      assert query["message"] =~
               "Login is not allowed when using SAML as the default authentication method"
    end
  end

  # Helper functions copied from api_test.exs
  defp extarct_session_data_from_cookie(cookie) do
    case Regex.named_captures(~r/_sxtesting_session=(?<session>[\w%-]+);/, cookie) do
      nil -> %{}
      %{"session" => session} -> Guard.Session.decrypt_cookie(session)
    end
  end

  defp extract_state_from_body(body) do
    case Regex.named_captures(~r/state=(?<state>[\w-]+)&/, body) do
      nil -> {:error, nil}
      %{"state" => state} -> {:ok, state}
    end
  end
end
