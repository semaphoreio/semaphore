defmodule Rbac.OIDC do
  require Logger

  @default_id_token_expires_in 300

  def enabled? do
    oidc_config = oidc_config()
    oidc_config[:discovery_url] != nil
  end

  def get_api_token do
    params = %{grant_type: "client_credentials"}

    case OpenIDConnect.fetch_tokens(manage_config(), params) do
      {:ok, %{"access_token" => token}} ->
        {:ok, token}

      {:error, error} ->
        {:error, error}
    end
  end

  def get_api_token! do
    {:ok, token} = get_api_token()
    token
  end

  def authorization_uri(redirect_uri) do
    {state, verifier, params} = security_params()

    case OpenIDConnect.authorization_uri(config(), redirect_uri, params) do
      {:ok, url} -> {:ok, {state, verifier, url}}
      {:error, error} -> {:error, error}
    end
  end

  def end_session_uri(id_token, redirect_uri) do
    case OpenIDConnect.end_session_uri(config(), %{
           id_token_hint: id_token,
           post_logout_redirect_uri: redirect_uri
         }) do
      {:ok, end_session_uri} ->
        {:ok, end_session_uri}

      {:error, _reason} ->
        {:ok, redirect_uri}
    end
  end

  def exchange_code(code, verifier, callback) do
    %{
      grant_type: "authorization_code",
      redirect_uri: callback,
      code: code,
      code_verifier: verifier
    }
    |> fetch_tokens()
  end

  def refresh_token(refresh_token) do
    %{
      grant_type: "refresh_token",
      refresh_token: refresh_token
    }
    |> fetch_tokens()
  end

  defp fetch_tokens(params) do
    case OpenIDConnect.fetch_tokens(config(), params) do
      {:ok, oidc_tokens} ->
        id_token = Map.get(oidc_tokens, "id_token", "")
        access_token = Map.get(oidc_tokens, "access_token", "")
        refresh_token = Map.get(oidc_tokens, "refresh_token", "")
        expires_in = Map.get(oidc_tokens, "expires_in") || @default_id_token_expires_in

        case OpenIDConnect.verify(config(), id_token) do
          {:ok, claims} ->
            expires_at = DateTime.utc_now() |> DateTime.add(expires_in, :second)

            user_data = %{
              oidc_user_id: claims["sub"],
              email: claims["email"],
              name: claims["name"]
            }

            tokens = %{
              id_token: id_token,
              access_token: access_token,
              refresh_token: refresh_token,
              expires_at: expires_at
            }

            {:ok, {user_data, tokens}}

          {:error, error} ->
            {:error, error}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  def state_match?(state, another_state) do
    if Plug.Crypto.secure_compare(state, another_state) do
      :ok
    else
      {:error, :invalid_state}
    end
  end

  defp config do
    oidc_config = oidc_config()

    %{
      discovery_document_uri: oidc_config[:discovery_url],
      client_id: oidc_config[:client_id],
      client_secret: oidc_config[:client_secret],
      response_type: "code",
      scope: "openid email profile"
    }
  end

  defp manage_config do
    oidc_config = oidc_config()

    %{
      discovery_document_uri: oidc_config[:discovery_url],
      client_id: oidc_config[:manage_client_id],
      client_secret: oidc_config[:manage_client_secret],
      response_type: "",
      scope: ""
    }
  end

  defp security_params do
    state = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    verifier = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    challenge = :crypto.hash(:sha256, verifier) |> Base.url_encode64(padding: false)

    params = %{
      state: state,
      code_challenge_method: :S256,
      code_challenge: challenge
    }

    {state, verifier, params}
  end

  defp oidc_config do
    Application.get_env(:rbac, :oidc)
  end
end
