defmodule Guard.CLIAuth do
  @moduledoc """
  CLI signup support for `sem-ai`. Two coexisting flows, both server-side here;
  the CLI client lives in a separate repo.

    * **Loopback + PKCE (RFC 8252)** — for machines with a browser. The browser
      runs the normal Keycloak OIDC web flow in `Guard.Id.Api`; on success guard
      issues a short-lived, single-use authorization code bound to the CLI's PKCE
      challenge and loopback redirect_uri. The CLI exchanges that code (plus its
      verifier) at `POST /cli/token`.

    * **Device authorization grant (RFC 8628)** — for headless / agent
      environments. The CLI calls `POST /cli/device` to get a `device_code` and a
      human-typeable `user_code`. The human opens the verification page, signs in
      via the same OIDC web flow, sees a consent screen naming the requesting
      device, and approves. The CLI polls `POST /cli/token` with the device_code
      until it is approved.

  All records live in the `cli_auth_codes` table (see `Guard.Store.CliAuthCode`),
  NOT in memory — redemption is a SELECT-FOR-UPDATE transaction, so it is
  single-use and safe across guard's multiple pods.

  Token policy (#3390): mint-if-absent, else reject. A fresh signup has no token
  yet, so we mint the first one. An existing user already has a (hashed,
  unrecoverable) token; we refuse rather than rotate, since rotating would break
  every other client. They are told to `sem-ai connect` with a token from
  Settings. This holds for BOTH flows.
  """

  alias Guard.Store.CliAuthCode
  alias Guard.CLIAuth.DeviceRateLimiter
  alias Guard.McpOAuth.PKCE

  @loopback_ttl_seconds 300

  # RFC 8628 device flow parameters (industry-convergent values).
  @device_ttl_seconds 900
  @default_interval 5
  @slow_down_increment 5
  # A user_code can seed the sign-in/consent flow at most this many times before
  # it is burned; caps abuse of a leaked or shoulder-surfed code.
  @user_code_max_attempts 5

  # ── loopback (RFC 8252) ────────────────────────────────────────────────────

  @doc "Issue a one-time authorization code bound to {user_id, code_challenge, redirect_uri}."
  @spec issue_code(String.t(), String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def issue_code(user_id, code_challenge, redirect_uri) do
    code = CliAuthCode.generate_code()

    case CliAuthCode.create(%{
           flow_type: "loopback",
           status: "approved",
           code: code,
           user_id: user_id,
           code_challenge: code_challenge,
           redirect_uri: redirect_uri,
           expires_at: expires_in(@loopback_ttl_seconds)
         }) do
      {:ok, _} -> {:ok, code}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Atomically redeem a loopback code from POST /cli/token params (code,
  code_verifier, redirect_uri) AND mint the account token under the shared
  policy (see `mint_token/1`) — all inside one Guard.Repo transaction.

  The row stays locked (SELECT FOR UPDATE) for the duration of the mint, and
  the code is only marked consumed once the mint outcome is known: a fresh
  mint or an existing-user `:token_exists` both consume the code (both are
  terminal); a mint that errors on persist does NOT consume it, so the client
  can retry with the same code. This closes the "code burned, no token minted"
  gap that existed when redemption and minting were two independent calls.
  """
  @spec exchange(map()) ::
          {:ok, String.t()}
          | {:error, :token_exists | :user_not_found | :invalid_grant | String.t()}
  def exchange(params) do
    code = params["code"]
    verifier = params["code_verifier"]
    redirect_uri = params["redirect_uri"]

    if is_binary(code) and is_binary(verifier) and is_binary(redirect_uri) do
      result =
        Guard.Repo.transaction(fn ->
          with {:ok, auth_code} <- CliAuthCode.lock_loopback_code(code),
               true <- PKCE.verify(verifier, auth_code.code_challenge),
               true <- redirect_uri == auth_code.redirect_uri do
            mint_then_consume(auth_code)
          else
            _ -> Guard.Repo.rollback(:invalid_grant)
          end
        end)

      case result do
        {:ok, mint_result} -> mint_result
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

  # ── device (RFC 8628) ──────────────────────────────────────────────────────

  @doc """
  Handle a device authorization request (`POST /cli/device`). Creates a pending
  row capturing the requester's IP / coarse geo / user-agent (shown later on the
  consent screen) and returns the fields the CLI needs to poll and to instruct
  the human.
  """
  @spec request_device_authorization(map()) :: {:ok, map()} | {:error, term()}
  def request_device_authorization(context \\ %{}) do
    device_code = CliAuthCode.generate_device_code()
    user_code = CliAuthCode.generate_user_code()
    user_code_display = CliAuthCode.format_user_code(user_code)

    params = %{
      flow_type: "device",
      status: "pending",
      device_code_hash: CliAuthCode.hash(device_code),
      user_code_hash: CliAuthCode.hash(user_code),
      requester_ip: context[:ip],
      requester_geo: context[:geo],
      requester_user_agent: context[:user_agent],
      interval: @default_interval,
      expires_at: expires_in(@device_ttl_seconds)
    }

    case CliAuthCode.create(params) do
      {:ok, _row} ->
        {:ok,
         %{
           device_code: device_code,
           user_code: user_code_display,
           verification_uri: verification_uri(),
           verification_uri_complete: "#{verification_uri()}?user_code=#{user_code_display}",
           expires_in: @device_ttl_seconds,
           interval: @default_interval
         }}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Validate a user_code submitted on the verification page, before sign-in.

  Applies the rate limit (per-IP, under the global backstop — see
  `DeviceRateLimiter`), looks the code up, and enforces the per-code attempt
  cap (burning the code past the limit). On success returns the pending
  device row so the caller can start the OIDC sign-in that leads to consent.

  `ip` is the requester's address (from the conn); pass `nil` if unavailable
  to fall back to the global-only limit.
  """
  @spec verify_user_code(String.t(), String.t() | nil) ::
          {:ok, Guard.Repo.CliAuthCode.t()}
          | {:error, :rate_limited | :invalid_user_code | :too_many_attempts}
  def verify_user_code(raw_user_code, ip \\ nil) do
    with :ok <- DeviceRateLimiter.check(ip),
         normalized = CliAuthCode.normalize_user_code(raw_user_code),
         {:ok, row} <- lookup_user_code(normalized, ip) do
      if row.attempt_count >= @user_code_max_attempts do
        CliAuthCode.deny(row)
        {:error, :too_many_attempts}
      else
        CliAuthCode.increment_attempt(row)
        {:ok, row}
      end
    end
  end

  defp lookup_user_code(normalized, ip) do
    case CliAuthCode.find_pending_by_user_code(normalized) do
      {:ok, row} ->
        {:ok, row}

      {:error, :not_found} ->
        DeviceRateLimiter.record_failure(ip)
        {:error, :invalid_user_code}
    end
  end

  @doc "Record the human's consent decision for a device row (after sign-in)."
  @spec approve_device(binary(), binary()) :: {:ok, :approved} | {:error, term()}
  def approve_device(row_id, user_id) do
    Guard.Repo.transaction(fn ->
      with {:ok, row} <- CliAuthCode.lock_pending_device(row_id),
           {:ok, _} <- CliAuthCode.approve(row, user_id) do
        :approved
      else
        {:error, reason} -> Guard.Repo.rollback(reason)
      end
    end)
  end

  @spec deny_device(binary()) :: {:ok, :denied} | {:error, term()}
  def deny_device(row_id) do
    Guard.Repo.transaction(fn ->
      with {:ok, row} <- CliAuthCode.lock_pending_device(row_id),
           {:ok, _} <- CliAuthCode.deny(row) do
        :denied
      else
        {:error, reason} -> Guard.Repo.rollback(reason)
      end
    end)
  end

  @doc """
  Poll for a device grant at `POST /cli/token`. Enforces the RFC 8628 terminal
  states and, on approval, mints the token under the shared signup policy.

  Returns one of:
    * `{:ok, token}` — approved and a fresh token was minted
    * `{:error, :authorization_pending}` — still waiting for the human
    * `{:error, :slow_down}` — polled faster than the interval (interval bumped)
    * `{:error, :access_denied}` — the human denied it
    * `{:error, :expired_token}` — past expires_at
    * `{:error, :token_exists}` — approved, but the account already has a token
    * `{:error, :invalid_grant}` — unknown / already consumed device_code
    * `{:error, :user_not_found}` / `{:error, String.t()}` — mint failed to
      persist; the code is left unconsumed so the client can retry
  """
  @spec poll_device_token(String.t()) ::
          {:ok, String.t()}
          | {:error,
             :authorization_pending
             | :slow_down
             | :access_denied
             | :expired_token
             | :token_exists
             | :user_not_found
             | :invalid_grant
             | String.t()}
  def poll_device_token(device_code) when is_binary(device_code) do
    device_code_hash = CliAuthCode.hash(device_code)

    result =
      Guard.Repo.transaction(fn ->
        case CliAuthCode.lock_device_by_code_hash(device_code_hash) do
          {:error, :not_found} -> {:error, :invalid_grant}
          {:ok, row} -> resolve_device_poll(row)
        end
      end)

    case result do
      {:ok, outcome} -> outcome
      {:error, _} -> {:error, :invalid_grant}
    end
  end

  def poll_device_token(_), do: {:error, :invalid_grant}

  # Runs inside the SELECT FOR UPDATE transaction. Non-terminal branches
  # (pending / slow_down) intentionally commit their bookkeeping writes. The
  # approved branch mints the token in the same transaction as the lock (see
  # `mint_then_consume/1`) so consumption and minting share fate.
  defp resolve_device_poll(row) do
    cond do
      expired?(row) -> {:error, :expired_token}
      row.status == "denied" -> {:error, :access_denied}
      row.status == "consumed" -> {:error, :invalid_grant}
      row.status == "approved" and is_nil(row.user_id) -> {:error, :invalid_grant}
      row.status == "approved" -> mint_then_consume(row)
      row.status == "pending" -> throttle_pending(row)
      true -> {:error, :invalid_grant}
    end
  end

  defp throttle_pending(row) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    # Both `now` and `last_polled_at` are second-truncated, which can make a
    # compliant client's exact-interval poll look 1s too fast. Grace the
    # comparison by 1s so a poll at (or just past) the interval boundary is
    # never spuriously throttled.
    if row.last_polled_at && DateTime.diff(now, row.last_polled_at) < row.interval - 1 do
      {:ok, _} =
        CliAuthCode.update_row(row, %{
          interval: row.interval + @slow_down_increment,
          last_polled_at: now
        })

      {:error, :slow_down}
    else
      {:ok, _} = CliAuthCode.update_row(row, %{last_polled_at: now})
      {:error, :authorization_pending}
    end
  end

  # ── shared token policy ─────────────────────────────────────────────────────

  @doc """
  Mint the API token for a tokenless (new) account. An account that already has a
  token is rejected with `:token_exists` — signup is for new accounts; an existing
  account should authenticate with `sem-ai connect`. We can't return the existing
  token anyway (only its hash is stored).

  The write is a single atomic conditional UPDATE (see
  `Guard.FrontRepo.User.mint_token_if_absent/1`), not read-then-write: this is
  what makes the mint safe against two overlapping signups for the same fresh
  account.
  """
  @spec mint_token(String.t()) ::
          {:ok, String.t()} | {:error, :token_exists | :user_not_found | String.t()}
  def mint_token(user_id) do
    case Guard.Store.User.Front.find(user_id) do
      {:ok, _front_user} ->
        Guard.FrontRepo.User.mint_token_if_absent(user_id)

      {:error, :not_found} ->
        {:error, :user_not_found}
    end
  end

  @doc """
  Whether the account already holds an API token. Signup mints only for a
  tokenless account (see `mint_token/1`), so the device consent screen uses this
  to tell an existing user the truth ("already set up, use connect") instead of
  showing "authorized" for a flow that the terminal will reject with
  `:token_exists`.
  """
  @spec account_has_token?(String.t()) :: boolean()
  def account_has_token?(user_id) do
    case Guard.Store.User.Front.find(user_id) do
      {:ok, %{authentication_token: token}} -> not (is_nil(token) or token == "")
      _ -> false
    end
  end

  # Runs inside the caller's Guard.Repo transaction on the locked cli_auth_codes
  # row, but the mint itself touches Guard.FrontRepo — a different database, so
  # there is no single cross-DB transaction that could cover both writes (see
  # module doc / PR notes). Instead we resolve this by ORDERING: the row lock
  # (SELECT FOR UPDATE) is held for the duration of the mint call, and the code
  # is only marked consumed once the mint's outcome is known, so the two never
  # diverge:
  #   * mint succeeds            -> consume (this code is now spent)
  #   * mint says :token_exists  -> consume (existing-user path is terminal)
  #   * mint errors on persist   -> do NOT consume (client can retry the code)
  defp mint_then_consume(row) do
    case mint_token(row.user_id) do
      {:ok, token} ->
        {:ok, _} = CliAuthCode.mark_consumed(row)
        {:ok, token}

      {:error, :token_exists} ->
        {:ok, _} = CliAuthCode.mark_consumed(row)
        {:error, :token_exists}

      {:error, other} ->
        {:error, other}
    end
  end

  # ── helpers ─────────────────────────────────────────────────────────────────

  defp expires_in(seconds) do
    DateTime.utc_now()
    |> DateTime.add(seconds, :second)
    |> DateTime.truncate(:second)
  end

  defp expired?(row) do
    DateTime.compare(DateTime.utc_now(), row.expires_at) != :lt
  end

  defp verification_uri do
    "https://id.#{Application.get_env(:guard, :base_domain)}/device"
  end
end
