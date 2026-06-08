defmodule Guard.CLIAuth do
  @moduledoc """
  CLI loopback + PKCE login support (RFC 8252) for `sem-ai login`.

  The browser runs the normal Keycloak OIDC web flow in `Guard.Id.Api`; on
  success guard issues a short-lived, single-use authorization code bound to the
  CLI's PKCE challenge and loopback redirect_uri. The CLI exchanges that code
  (plus its verifier) at `POST /cli/token` for the Semaphore API token.

  Codes are stored in the `cli_auth_codes` table (see Guard.Store.CliAuthCode),
  NOT in memory — redemption is a SELECT-FOR-UPDATE transaction, so it is
  single-use and safe across guard's multiple pods.

  Token policy (#3390): mint-if-absent, else reject. A fresh signup has no token
  yet, so we mint the first one. An existing user already has a (hashed,
  unrecoverable) token; we refuse rather than rotate, since rotating would break
  every other client. They are told to `sem-ai connect` with a token from Settings.
  """
  require Logger

  alias Guard.Store.CliAuthCode
  alias Guard.McpOAuth.PKCE

  @code_ttl_seconds 300

  @doc "Issue a one-time authorization code bound to {user_id, code_challenge, redirect_uri}."
  @spec issue_code(String.t(), String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def issue_code(user_id, code_challenge, redirect_uri) do
    code = CliAuthCode.generate_code()

    expires_at =
      DateTime.utc_now()
      |> DateTime.add(@code_ttl_seconds, :second)
      |> DateTime.truncate(:second)

    case CliAuthCode.create(%{
           code: code,
           user_id: user_id,
           code_challenge: code_challenge,
           redirect_uri: redirect_uri,
           expires_at: expires_at
         }) do
      {:ok, _} -> {:ok, code}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Atomically redeem a code from POST /cli/token params (code, code_verifier,
  redirect_uri). Locks the row, verifies PKCE and the redirect_uri binding, marks
  it used — all in one transaction. Returns the bound user_id.
  """
  @spec exchange(map()) :: {:ok, String.t()} | {:error, :invalid_grant}
  def exchange(params) do
    code = params["code"]
    verifier = params["code_verifier"]
    redirect_uri = params["redirect_uri"]

    if is_binary(code) and is_binary(verifier) and is_binary(redirect_uri) do
      result =
        Guard.Repo.transaction(fn ->
          with {:ok, auth_code} <- CliAuthCode.lock_code(code),
               true <- PKCE.verify(verifier, auth_code.code_challenge),
               true <- redirect_uri == auth_code.redirect_uri,
               {:ok, used} <- CliAuthCode.mark_code_used(auth_code) do
            used.user_id
          else
            _ -> Guard.Repo.rollback(:invalid_grant)
          end
        end)

      case result do
        {:ok, user_id} -> {:ok, user_id}
        {:error, _} -> {:error, :invalid_grant}
      end
    else
      {:error, :invalid_grant}
    end
  end

  @doc "Only http loopback redirect_uris are allowed (open-redirect guard)."
  @spec loopback_redirect?(String.t()) :: boolean()
  def loopback_redirect?(uri) when is_binary(uri) do
    case URI.parse(uri) do
      %URI{scheme: "http", host: host} when host in ["127.0.0.1", "localhost", "::1"] -> true
      _ -> false
    end
  end

  def loopback_redirect?(_), do: false

  @doc """
  Mint the API token for a tokenless (new) account. An account that already has a
  token is rejected with `:token_exists` — signup is for new accounts; an existing
  account should authenticate with `sem-ai connect`. We can't return the existing
  token anyway (only its hash is stored).
  """
  @spec mint_token(String.t()) ::
          {:ok, String.t()} | {:error, :token_exists | :user_not_found | String.t()}
  def mint_token(user_id) do
    case Guard.Store.User.Front.find(user_id) do
      {:ok, front_user} ->
        case front_user.authentication_token do
          token when is_nil(token) or token == "" ->
            Guard.FrontRepo.User.reset_auth_token(front_user)

          _ ->
            {:error, :token_exists}
        end

      {:error, :not_found} ->
        {:error, :user_not_found}
    end
  end
end
