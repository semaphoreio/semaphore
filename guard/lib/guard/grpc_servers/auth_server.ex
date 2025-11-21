defmodule Guard.GrpcServers.AuthServer do
  use GRPC.Server, service: InternalApi.Auth.Authentication.Service

  require Logger

  alias InternalApi.Auth

  @spec authenticate(Auth.AuthenticateRequest.t(), GRPC.Server.Stream.t()) ::
          Auth.AuthenticateResponse.t()
  def authenticate(%Auth.AuthenticateRequest{token: token}, _stream) do
    observe("grpc.authentication.authenticate", fn ->
      case find_user_by_token(token) do
        {:ok, user} ->
          user
          |> tap(&log_service_account_access(&1))
          |> respond_with_user("API_TOKEN", "", "")

        {:error, :user, :not_found} ->
          respond_false()
      end
    end)
  end

  @spec authenticate_with_cookie(Auth.AuthenticateWithCookieRequest.t(), GRPC.Server.Stream.t()) ::
          Auth.AuthenticateResponse.t()
  def authenticate_with_cookie(%Auth.AuthenticateWithCookieRequest{cookie: cookie}, _stream) do
    cookie_hash =
      :crypto.hash(:md5, cookie)
      |> Base.encode16(case: :lower)

    Logger.debug("[AuthServer] authenticate_with_cookie start hash=#{cookie_hash}")

    observe("grpc.authentication.authenticate_with_cookie", fn ->
      case find_user_by_cookie(cookie) do
        {:ok, {user, id_provider, ip_address, user_agent}} ->
          Logger.debug(
            "[AuthServer] authenticate_with_cookie user_id=#{user.id} provider=#{id_provider} ip=#{ip_address}"
          )

          respond_with_user(user, id_provider, ip_address, user_agent)

        {:error, :user, :not_found} ->
          Logger.debug("[AuthServer] authenticate_with_cookie not found hash=#{cookie_hash}")
          respond_false()
      end
    end)
  end

  defp respond_false,
    do: Auth.AuthenticateResponse.new(authenticated: false)

  defp respond_with_user(user, id_provider, ip_address, user_agent) do
    Guard.FrontRepo.User.record_visit(user.id)

    Auth.AuthenticateResponse.new(
      authenticated: true,
      name: user.name,
      user_id: user.id,
      id_provider: map_provider(id_provider),
      ip_address: ip_address,
      user_agent: user_agent
    )
  end

  defp map_provider("GITHUB"), do: Auth.IdProvider.value(:ID_PROVIDER_GITHUB)
  defp map_provider("GITLAB"), do: Auth.IdProvider.value(:ID_PROVIDER_GITLAB)
  defp map_provider("BITBUCKET"), do: Auth.IdProvider.value(:ID_PROVIDER_BITBUCKET)
  defp map_provider("OKTA"), do: Auth.IdProvider.value(:ID_PROVIDER_OKTA)
  defp map_provider("API_TOKEN"), do: Auth.IdProvider.value(:ID_PROVIDER_API_TOKEN)
  defp map_provider("OIDC"), do: Auth.IdProvider.value(:ID_PROVIDER_OIDC)
  defp map_provider(_), do: Auth.IdProvider.value(:ID_PROVIDER_UNSPECIFIED)

  defp find_user_by_token(""), do: {:error, :user, :not_found}

  defp find_user_by_token(token) do
    digest = Guard.AuthenticationToken.hash_token(token)

    case Guard.FrontRepo.User.active_user_by_token(digest) do
      {:ok, user} -> {:ok, user}
      {:error, :not_found} -> {:error, :user, :not_found}
    end
  end

  defp find_user_by_cookie("") do
    Logger.debug("[AuthServer] find_user_by_cookie empty cookie")
    {:error, :user, :not_found}
  end

  defp find_user_by_cookie(cookie) do
    case Guard.Session.deserialize_from_cookie(cookie) do
      {:ok, {id_provider, user_data, session_data, extras}} ->
        Logger.debug(
          "[AuthServer] find_user_by_cookie deserialized provider=#{id_provider} session_keys=#{inspect(Map.keys(session_data))} extras=#{inspect(Map.keys(extras))}"
        )

        with {:ok, user_data, extras} <- process_session(session_data, user_data, extras),
             {:ok, user} <- get_user(user_data) do
          Logger.debug(
            "[AuthServer] find_user_by_cookie resolved user_id=#{user.id} provider=#{id_provider}"
          )

          {:ok, {user, id_provider, extras.ip_address, extras.user_agent}}
        else
          {:error, :user_not_found} ->
            Logger.debug("[AuthServer] find_user_by_cookie user not found after session processing")
            {:error, :user, :not_found}

          {:error, :session_process_error} ->
            Logger.debug("[AuthServer] find_user_by_cookie session processing error")
            {:error, :user, :not_found}
        end

      {:error, :invalid_cookie} ->
        Logger.debug("[AuthServer] find_user_by_cookie invalid cookie format")
        {:error, :user, :not_found}
    end
  end

  defp get_user(%{id: id, salt: salt}) do
    case Guard.FrontRepo.User.active_user_by_id_and_salt(id, salt) do
      {:ok, user} -> {:ok, user}
      {:error, :not_found} -> {:error, :user_not_found}
    end
  end

  defp get_user(%{id: id}) do
    case Guard.FrontRepo.User.active_user_by_id(id) do
      {:ok, user} -> {:ok, user}
      {:error, :not_found} -> {:error, :user_not_found}
    end
  end

  defp get_user(_), do: {:ok, nil}

  @spec process_session(Map.t(), Guard.Repo.RbacUser.t(), Map.t()) ::
          {:ok, Map.t(), Map.t()}
          | {:error, :session_process_error}
  defp process_session(%{id: session_id}, _, _) do
    Logger.debug("[AuthServer] process_session OIDC id=#{session_id}")

    case Guard.Store.OIDCSession.get(session_id) do
      {:error, :not_found} ->
        Logger.debug("[AuthServer] process_session session not found id=#{session_id}")
        {:error, :session_process_error}

      {:ok, %Guard.Repo.OIDCSession{refresh_token_enc: nil}} ->
        Logger.debug("[AuthServer] process_session refresh_token missing id=#{session_id}")
        {:error, :session_process_error}

      {:ok, session} ->
        extras = %{ip_address: session.ip_address, user_agent: session.user_agent}

        if Guard.Store.OIDCSession.expired?(session) do
          Logger.debug("[AuthServer] process_session expired id=#{session_id} user_id=#{session.user_id}")

          case refresh_session(session) do
            {:ok, session} -> {:ok, %{id: session.user_id}, extras}
            {:error, reason} ->
              Logger.debug(
                "[AuthServer] process_session refresh failed id=#{session_id} user_id=#{session.user_id} reason=#{inspect(reason)}"
              )

              {:error, :session_process_error}
          end
        else
          Logger.debug("[AuthServer] process_session valid id=#{session_id} user_id=#{session.user_id}")
          {:ok, %{id: session.user_id}, extras}
        end
    end
  end

  defp process_session(%{}, user_data, extras)do
    Logger.debug("[AuthServer] process_session no session_id, skipping")
    {:ok, user_data, extras}
  end

  defp refresh_session(session) do
    Logger.debug("[AuthServer] refresh_session id=#{session.id} user_id=#{session.user_id}")

    with {:ok, refresh_token} <-
           Guard.OIDC.Token.decrypt(session.refresh_token_enc, session.user_id),
         {:ok, tokens} <- refresh_token(refresh_token, session.user),
         {:ok, new_id_token_enc} <- Guard.OIDC.Token.encrypt(tokens[:id_token], session.user.id),
         {:ok, new_refresh_token_enc} <-
           Guard.OIDC.Token.encrypt(tokens[:refresh_token], session.user.id) do
      update_session(session, new_id_token_enc, new_refresh_token_enc, tokens[:expires_at])
    else
      {:error, :decrypt_error} ->
        {:error, :session_process_error}

      {:error, :invalid_refresh_token_user} ->
        {:ok, _} = Guard.Store.OIDCSession.remove_refresh_token(session)
        {:error, :session_process_error}

      {:error, :refresh_token_error} ->
        {:ok, _} = Guard.Store.OIDCSession.remove_refresh_token(session)
        Guard.Store.OIDCSession.expire(session)
        {:error, :session_process_error}

      {:error, :session_update_error} ->
        {:error, :session_process_error}
    end
  end

  defp refresh_token(refresh_token, user) do
    case Guard.OIDC.refresh_token(refresh_token) do
      {:ok, {%{oidc_user_id: oidc_user_id}, tokens}} ->
        if same_user?(user, oidc_user_id) do
          {:ok, tokens}
        else
          {:error, :invalid_refresh_token_user}
        end

      {:error, e} ->
        Logger.error("Failed to refresh token for user #{user.id}: #{inspect(e)}")
        {:error, :refresh_token_error}
    end
  end

  defp same_user?(user, oidc_user_id) do
    case Guard.Store.RbacUser.fetch_by_oidc_id(oidc_user_id) do
      {:ok, %{id: user_id}} when user_id == user.id -> true
      {:ok, _} -> false
      {:error, :not_found} -> false
    end
  end

  defp update_session(session, _, nil, _) do
    case Guard.Store.OIDCSession.remove_refresh_token(session) do
      {:ok, session} -> {:ok, session}
      {:error, _} -> {:error, :session_update_error}
    end
  end

  defp update_session(session, id_token_enc, refresh_token_enc, expires_at) do
    case Guard.Store.OIDCSession.update(session, id_token_enc, refresh_token_enc, expires_at) do
      {:ok, session} -> {:ok, session}
      {:error, _} -> {:error, :session_update_error}
    end
  end

  defp observe(name, f) do
    Watchman.benchmark("#{name}.duration", fn ->
      try do
        case f.() do
          result when result.authenticated == true ->
            Watchman.increment({name, ["OK"]})

            result

          result ->
            Watchman.increment({name, ["UNAUTHENTICATED"]})

            result
        end
      rescue
        e ->
          Watchman.increment({name, ["ERROR"]})

          reraise e, __STACKTRACE__
      end
    end)
  end

  defp log_service_account_access(%{service_account: nil} = _user), do: :ok

  defp log_service_account_access(%{service_account: _} = user) do
    Watchman.increment({"service_account.access", [user.org_id]})
    :ok
  end
end
