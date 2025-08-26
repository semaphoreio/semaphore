defmodule Guard.GrpcServers.AuthServerTest do
  use Guard.RepoCase, async: false

  import Mock

  alias InternalApi.Auth
  alias InternalApi.Auth.Authentication.Stub
  alias InternalApi.Auth.AuthenticateRequest
  alias InternalApi.Auth.AuthenticateWithCookieRequest

  setup do
    token1 = Guard.AuthenticationToken.new()
    token_hash1 = Guard.AuthenticationToken.hash_token(token1)

    token2 = Guard.AuthenticationToken.new()
    token_hash2 = Guard.AuthenticationToken.hash_token(token2)

    id_token = "id_token"
    refresh_token = "refresh_token"

    expires_at = DateTime.utc_now() |> DateTime.add(5, :minute)

    {:ok, blocked} =
      Guard.Store.User.Front.create(%{
        "email" => "blocked@example.com",
        "name" => "John Doe",
        "blocked_at" => DateTime.utc_now(),
        "salt" => "pepper",
        "authentication_token" => token_hash1
      })

    Support.Factories.RbacUser.insert(blocked.id, blocked.name, blocked.email)
    {:ok, _} = Support.Factories.OIDCUser.insert(blocked.id)

    {:ok, user} =
      Guard.Store.User.Front.create(%{
        "email" => "john@example.com",
        "name" => "John Doe",
        "blocked_at" => nil,
        "salt" => "pepper",
        "authentication_token" => token_hash2
      })

    Support.Factories.RbacUser.insert(user.id, user.name, user.email)
    {:ok, _} = Support.Factories.OIDCUser.insert(user.id)

    {:ok, another} =
      Guard.Store.User.Front.create(%{
        "email" => "another@example.com",
        "name" => "Another Doe",
        "blocked_at" => nil,
        "salt" => "pepper"
      })

    Support.Factories.RbacUser.insert(another.id, another.name, another.email)
    {:ok, _} = Support.Factories.OIDCUser.insert(another.id)

    {:ok, id_token_enc} =
      Guard.Encryptor.encrypt(
        Guard.OIDC.TokenEncryptor,
        id_token,
        "semaphore-#{blocked.id}"
      )

    {:ok, refresh_token_enc} =
      Guard.Encryptor.encrypt(
        Guard.OIDC.TokenEncryptor,
        refresh_token,
        "semaphore-#{blocked.id}"
      )

    {:ok, blocked_session} =
      Guard.Store.OIDCSession.create(%{
        user_id: blocked.id,
        id_token_enc: id_token_enc,
        refresh_token_enc: refresh_token_enc,
        expires_at: expires_at,
        ip_address: "1.1.1.1",
        user_agent: "blocked-test-agent"
      })

    {:ok, id_token_enc} =
      Guard.Encryptor.encrypt(
        Guard.OIDC.TokenEncryptor,
        id_token,
        "semaphore-#{user.id}"
      )

    {:ok, refresh_token_enc} =
      Guard.Encryptor.encrypt(
        Guard.OIDC.TokenEncryptor,
        refresh_token,
        "semaphore-#{user.id}"
      )

    {:ok, session} =
      Guard.Store.OIDCSession.create(%{
        user_id: user.id,
        id_token_enc: id_token_enc,
        refresh_token_enc: refresh_token_enc,
        expires_at: expires_at,
        ip_address: "1.1.1.1",
        user_agent: "test-agent"
      })

    {:ok, id_token_enc} =
      Guard.Encryptor.encrypt(
        Guard.OIDC.TokenEncryptor,
        id_token,
        "semaphore-#{another.id}"
      )

    {:ok, refresh_token_enc} =
      Guard.Encryptor.encrypt(
        Guard.OIDC.TokenEncryptor,
        refresh_token,
        "semaphore-#{another.id}"
      )

    {:ok, another_session} =
      Guard.Store.OIDCSession.create(%{
        user_id: another.id,
        id_token_enc: id_token_enc,
        refresh_token_enc: refresh_token_enc,
        expires_at: expires_at,
        ip_address: "1.1.1.1",
        user_agent: "another-test-agent"
      })

    bypass = Guard.Mocks.OpenIDConnect.discovery_document_server()
    disc_url = "http://localhost:#{bypass.port}/.well-known/openid-configuration"

    oidc = Application.get_env(:guard, :oidc)

    Application.put_env(:guard, :oidc, %{
      discovery_url: disc_url,
      client_id: "test_client_id",
      client_secret: "test_client_secret"
    })

    on_exit(fn ->
      Application.put_env(:guard, :oidc, oidc)
    end)

    %{
      bypass: bypass,
      client_id: "test_client_id",
      blocked_session: blocked_session,
      blocked_token: token1,
      blocked: blocked,
      session: session,
      token: token2,
      user: user,
      another: another,
      another_session: another_session
    }
  end

  describe "authenticate" do
    test "return false for empty token" do
      request = AuthenticateRequest.new(token: "")

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = channel |> Stub.authenticate(request)

      assert_response(response)
    end

    test "return false for invalid token" do
      request = AuthenticateRequest.new(token: "invalid_token")

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = channel |> Stub.authenticate(request)

      assert_response(response)
    end

    test "return false for valid token but blocked user", %{blocked_token: token} do
      request = AuthenticateRequest.new(token: token)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = channel |> Stub.authenticate(request)

      assert_response(response)
    end

    test "return true for valid token", %{token: token, user: user} do
      request = AuthenticateRequest.new(token: token)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = channel |> Stub.authenticate(request)

      assert_response(response, user)
    end

    test "logs service account access metric for service account authentication" do
      org_id = Ecto.UUID.generate()

      {:ok, %{user: sa_user}} = Support.Factories.ServiceAccountFactory.insert(org_id: org_id)

      token = Guard.AuthenticationToken.new()
      token_hash = Guard.AuthenticationToken.hash_token(token)

      sa_user
      |> Ecto.Changeset.change(authentication_token: token_hash)
      |> Guard.FrontRepo.update()

      with_mock Watchman, [:passthrough], increment: fn _ -> :ok end do
        # Authenticate with service account token
        request = AuthenticateRequest.new(token: token)
        {:ok, channel} = GRPC.Stub.connect("localhost:50051")
        {:ok, response} = channel |> Stub.authenticate(request)

        assert response.authenticated == true
        assert response.user_id == sa_user.id

        # Verify service account access metric was logged
        assert called(Watchman.increment({"service_account.access", [org_id]}))
      end
    end

    test "does not log service account metric for regular users", %{token: token, user: user} do
      with_mock Watchman, [:passthrough], increment: fn _ -> :ok end do
        # Authenticate with regular user token
        request = AuthenticateRequest.new(token: token)
        {:ok, channel} = GRPC.Stub.connect("localhost:50051")
        {:ok, response} = channel |> Stub.authenticate(request)

        assert response.authenticated == true
        assert response.user_id == user.id

        # Verify no service account metric was logged
        assert_not_called(Watchman.increment({"service_account.access", :_}))
      end
    end
  end

  describe "authenticate_with_cookie" do
    test "return false for empty cookie" do
      request = AuthenticateWithCookieRequest.new(cookie: "")

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = channel |> Stub.authenticate_with_cookie(request)

      assert_response(response)
    end

    test "return false for invalid cookie" do
      request = AuthenticateWithCookieRequest.new(cookie: "invalid_cookie")

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = channel |> Stub.authenticate_with_cookie(request)

      assert_response(response)
    end

    test "return false for invalid session" do
      cookie = invalid_session()
      request = AuthenticateWithCookieRequest.new(cookie: cookie)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = channel |> Stub.authenticate_with_cookie(request)

      assert_response(response)
    end

    test "return false for valid legacy cookie but blocked user", %{blocked: user} do
      cookie = legacy_session(user)
      request = AuthenticateWithCookieRequest.new(cookie: cookie)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = channel |> Stub.authenticate_with_cookie(request)

      assert_response(response)
    end

    test "return false for valid oidc mixed cookie but blocked user", %{
      blocked: user,
      blocked_session: session
    } do
      cookie = mixed_session(session, user, "OIDC")
      request = AuthenticateWithCookieRequest.new(cookie: cookie)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = channel |> Stub.authenticate_with_cookie(request)

      assert_response(response)
    end

    test "return false for valid github mixed cookie but blocked user", %{
      blocked: user,
      blocked_session: session
    } do
      cookie = mixed_session(session, user, "GITHUB")
      request = AuthenticateWithCookieRequest.new(cookie: cookie)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = channel |> Stub.authenticate_with_cookie(request)

      assert_response(response)
    end

    test "return false for valid oidc cookie but blocked user", %{
      blocked_session: session
    } do
      cookie = oidc_session(session)
      request = AuthenticateWithCookieRequest.new(cookie: cookie)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = channel |> Stub.authenticate_with_cookie(request)

      assert_response(response)
    end

    test "return true for valid legacy cookie", %{user: user} do
      cookie = legacy_session(user)
      request = AuthenticateWithCookieRequest.new(cookie: cookie)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = channel |> Stub.authenticate_with_cookie(request)

      assert_response(response, user, "GITHUB")
    end

    test "return true for valid oidc mixed cookie", %{user: user, session: session} do
      cookie = mixed_session(session, user, "OIDC")
      request = AuthenticateWithCookieRequest.new(cookie: cookie)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = channel |> Stub.authenticate_with_cookie(request)

      assert_response(response, user, "OIDC")
    end

    test "return true for valid github mixed cookie", %{user: user, session: session} do
      cookie = mixed_session(session, user, "GITHUB")
      request = AuthenticateWithCookieRequest.new(cookie: cookie)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = channel |> Stub.authenticate_with_cookie(request)

      assert_response(response, user, "GITHUB")
    end

    test "return true for valid oidc cookie", %{user: user, session: session} do
      cookie = oidc_session(session)
      request = AuthenticateWithCookieRequest.new(cookie: cookie)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = channel |> Stub.authenticate_with_cookie(request)

      assert_response(response, user, "OIDC")
    end

    test "return true for valid oidc cookie when session expire but can be refreshed", %{
      bypass: bypass,
      client_id: client_id,
      user: user,
      session: session
    } do
      {:ok, session} = Guard.Store.OIDCSession.expire(session)
      :ok = expect_fetch_token(bypass, client_id, session)

      cookie = oidc_session(session)
      request = AuthenticateWithCookieRequest.new(cookie: cookie)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = channel |> Stub.authenticate_with_cookie(request)
      {:ok, new_session} = Guard.Store.OIDCSession.get(session.id)

      refute new_session.refresh_token_enc == session.refresh_token_enc
      assert_response(response, user, "OIDC")
    end

    test "return false for valid oidc cookie when session expire but refresh token is for different user",
         %{
           bypass: bypass,
           client_id: client_id,
           another_session: another_session,
           session: session
         } do
      :ok = expect_fetch_token(bypass, client_id, another_session)
      {:ok, session} = Guard.Store.OIDCSession.expire(session)

      cookie = oidc_session(session)
      request = AuthenticateWithCookieRequest.new(cookie: cookie)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = channel |> Stub.authenticate_with_cookie(request)

      {:ok, %Guard.Repo.OIDCSession{refresh_token_enc: nil}} =
        Guard.Store.OIDCSession.get(session.id)

      assert_response(response)
    end

    test "return false for valid oidc cookie when session was deleted from database", %{
      session: session
    } do
      cookie = oidc_session(session)
      {:ok, _} = Guard.Store.OIDCSession.delete(session)
      request = AuthenticateWithCookieRequest.new(cookie: cookie)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = channel |> Stub.authenticate_with_cookie(request)
      {:error, :not_found} = Guard.Store.OIDCSession.get(session.id)

      assert_response(response)
    end

    test "return false for valid oidc cookie when session expire and refresh token is nil in database",
         %{
           session: session
         } do
      {:ok, session} = Guard.Store.OIDCSession.expire(session)
      cookie = oidc_session(session)
      {:ok, _} = Guard.Store.OIDCSession.remove_refresh_token(session)
      request = AuthenticateWithCookieRequest.new(cookie: cookie)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = channel |> Stub.authenticate_with_cookie(request)

      {:ok, %Guard.Repo.OIDCSession{refresh_token_enc: nil}} =
        Guard.Store.OIDCSession.get(session.id)

      assert_response(response)
    end

    test "return false for valid oidc cookie when session expire and was deleted from database",
         %{
           session: session
         } do
      {:ok, session} = Guard.Store.OIDCSession.expire(session)
      cookie = oidc_session(session)
      {:ok, _} = Guard.Store.OIDCSession.delete(session)
      request = AuthenticateWithCookieRequest.new(cookie: cookie)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = channel |> Stub.authenticate_with_cookie(request)
      {:error, :not_found} = Guard.Store.OIDCSession.get(session.id)

      assert_response(response)
    end

    test "return false for valid oidc cookie when session expire and can't be refreshed", %{
      bypass: bypass,
      session: session
    } do
      Guard.Mocks.OpenIDConnect.expect_fetch_token_failure(bypass, %{"error" => "unauthorized"})
      {:ok, session} = Guard.Store.OIDCSession.expire(session)
      refute session.refresh_token_enc == nil

      cookie = oidc_session(session)
      request = AuthenticateWithCookieRequest.new(cookie: cookie)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = channel |> Stub.authenticate_with_cookie(request)
      {:ok, session} = Guard.Store.OIDCSession.get(session.id)
      assert Guard.Store.OIDCSession.expired?(session) == true
      assert session.refresh_token_enc == nil

      assert_response(response)
    end

    test "return false for valid oidc cookie when session expire and refresh token can't be decrypted",
         %{
           session: session
         } do
      encryptor = Application.get_env(:guard, Guard.OIDC.TokenEncryptor)

      Application.put_env(:guard, Guard.OIDC.TokenEncryptor,
        module: {Guard.FailingDecryptEncryptor, []}
      )

      {:ok, session} = Guard.Store.OIDCSession.expire(session)

      cookie = oidc_session(session)
      request = AuthenticateWithCookieRequest.new(cookie: cookie)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = channel |> Stub.authenticate_with_cookie(request)
      {:ok, _} = Guard.Store.OIDCSession.get(session.id)

      Application.put_env(:guard, Guard.OIDC.TokenEncryptor, encryptor)

      assert_response(response)
    end

    test "return true for valid oidc cookie when session expire and refresh token can't be encrypted again",
         %{
           bypass: bypass,
           client_id: client_id,
           user: user,
           session: session
         } do
      :ok = expect_fetch_token(bypass, client_id, session)

      encryptor = Application.get_env(:guard, Guard.OIDC.TokenEncryptor)

      Application.put_env(:guard, Guard.OIDC.TokenEncryptor,
        module: {Guard.FailingEncryptEncryptor, []}
      )

      {:ok, session} = Guard.Store.OIDCSession.expire(session)

      cookie = oidc_session(session)
      request = AuthenticateWithCookieRequest.new(cookie: cookie)

      {:ok, channel} = GRPC.Stub.connect("localhost:50051")
      {:ok, response} = channel |> Stub.authenticate_with_cookie(request)
      {:ok, session} = Guard.Store.OIDCSession.get(session.id)

      Application.put_env(:guard, Guard.OIDC.TokenEncryptor, encryptor)

      assert session.refresh_token_enc == nil
      assert_response(response, user, "OIDC")
    end
  end

  defp expect_fetch_token(bypass, client_id, session) do
    user = Guard.Store.RbacUser.fetch(session.user_id) |> Guard.Repo.preload(:oidc_users)
    oidc_user = user.oidc_users |> List.first()

    {token, _claims} =
      Guard.Mocks.OpenIDConnect.generate_openid_connect_token(%{client_id: client_id}, %{
        email: user.email,
        id: oidc_user.oidc_user_id,
        name: user.name
      })

    Guard.Mocks.OpenIDConnect.expect_fetch_token(bypass, %{
      "token_type" => "Bearer",
      "id_token" => token,
      "access_token" => "MY_ACCESS_TOKEN",
      "refresh_token" => "OTHER_REFRESH_TOKEN",
      "expires_in" => nil
    })

    :ok
  end

  defp invalid_session do
    %{"foo" => "bar"}
    |> Guard.Session.encrypt_cookie()
  end

  defp legacy_session(user) do
    %{
      "id_provider" => "GITHUB",
      "ip_address" => "127.0.0.1",
      "user_agent" => "Mozilla/5.0",
      "warden.user.user.key" => [[user.id], user.salt]
    }
    |> Guard.Session.encrypt_cookie()
  end

  defp mixed_session(session, user, id_provider) do
    %{
      "oidc_session_id" => session.id,
      "id_provider" => id_provider,
      "ip_address" => "127.0.0.1",
      "user_agent" => "Mozilla/5.0",
      "warden.user.user.key" => [[user.id], user.salt]
    }
    |> Guard.Session.encrypt_cookie()
  end

  defp oidc_session(session) do
    %{
      "id_provider" => "OIDC",
      "oidc_session_id" => session.id
    }
    |> Guard.Session.encrypt_cookie()
  end

  def assert_response(response, user \\ nil)

  def assert_response(response, nil) do
    assert response.authenticated == false
    assert response.name == ""
    assert response.user_id == ""
    assert response.id_provider == Auth.IdProvider.value(:ID_PROVIDER_UNSPECIFIED)
    assert response.ip_address == ""
    assert response.user_agent == ""
  end

  def assert_response(response, user) do
    assert response.authenticated == true
    assert response.name == user.name
    assert response.user_id == user.id
    assert response.id_provider == Auth.IdProvider.value(:ID_PROVIDER_API_TOKEN)
    assert response.ip_address == ""
    assert response.user_agent == ""
  end

  def assert_response(response, user, "GITHUB") do
    assert response.authenticated == true
    assert response.name == user.name
    assert response.user_id == user.id
    assert response.id_provider == Auth.IdProvider.value(:ID_PROVIDER_GITHUB)
    assert response.ip_address == "127.0.0.1"
    assert response.user_agent == "Mozilla/5.0"
  end

  def assert_response(response, user, "OIDC") do
    assert response.authenticated == true
    assert response.name == user.name
    assert response.user_id == user.id
    assert response.id_provider == Auth.IdProvider.value(:ID_PROVIDER_OIDC)
    assert response.ip_address == "1.1.1.1"
    assert response.user_agent == "test-agent"
  end
end
