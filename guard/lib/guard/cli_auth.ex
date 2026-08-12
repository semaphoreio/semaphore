defmodule Guard.CLIAuth do
  @moduledoc """
  Server side of the unified `sem-ai signin` flow (the CLI client lives in a
  separate repo): a device authorization grant (RFC 8628).

  The CLI calls `POST /cli/device` to get a `device_code` and a human-typeable
  `user_code`. The human opens the verification page, enters the code, signs in
  via the normal OIDC web flow (which routes a new user through web signup),
  sees a consent screen naming the requesting device, and approves. The CLI
  polls `POST /cli/token` with the device_code until it is approved.

  All records live in the `cli_auth_codes` table (see `Guard.Store.CliAuthCode`),
  NOT in memory — redemption is a SELECT-FOR-UPDATE transaction, so it is
  single-use and safe across guard's multiple pods.
  """

  alias Guard.Store.CliAuthCode
  alias Guard.CLIAuth.DeviceRateLimiter

  # RFC 8628 device flow parameters. The TTL is 30 minutes — deliberately
  # above the industry-typical 15 — because a brand-new user detours through
  # the full web signup (registration, possibly email verification) between
  # entering the user_code and approving on the consent screen, and the code
  # must survive that detour. If it still expires mid-detour, every surface
  # degrades cleanly to a re-prompt: the consent page shows "request expired,
  # start again from your terminal" and the CLI poll gets :expired_token.
  @device_ttl_seconds 1800
  @default_interval 5
  @slow_down_increment 5
  # A user_code can seed the sign-in/consent flow at most this many times before
  # it is burned; caps abuse of a leaked or shoulder-surfed code.
  @user_code_max_attempts 5

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
    with :ok <- DeviceRateLimiter.check(ip) do
      normalized = CliAuthCode.normalize_user_code(raw_user_code)

      # The cap check and the attempt increment run inside ONE SELECT FOR
      # UPDATE transaction: concurrent entries of the same code serialize on
      # the row lock, so no two of them can both read attempt_count == max - 1
      # and slip past the cap. The deny (burning the code) commits with the
      # transaction.
      result =
        Guard.Repo.transaction(fn ->
          case CliAuthCode.lock_pending_by_user_code(normalized) do
            {:error, :not_found} ->
              {:error, :invalid_user_code}

            {:ok, row} ->
              if row.attempt_count >= @user_code_max_attempts do
                {:ok, _} = CliAuthCode.deny(row)
                {:error, :too_many_attempts}
              else
                {:ok, row} = CliAuthCode.increment_attempt(row)
                {:ok, row}
              end
          end
        end)

      case result do
        {:ok, {:ok, row}} ->
          {:ok, row}

        {:ok, {:error, :invalid_user_code}} ->
          DeviceRateLimiter.record_failure(ip)
          {:error, :invalid_user_code}

        {:ok, {:error, reason}} ->
          {:error, reason}

        {:error, _} ->
          {:error, :invalid_user_code}
      end
    end
  end

  @doc """
  Record the human's consent decision for a device row (after sign-in), along
  with WHAT was consented to: `"mint"` (fresh account, no token yet) or
  `"rotate"` (the account already had a token and the user explicitly agreed
  to reset it on the consent screen). The poll that redeems the device_code
  executes exactly this recorded action — never more.
  """
  @spec approve_device(binary(), binary(), String.t()) ::
          {:ok, :approved} | {:error, term()}
  def approve_device(row_id, user_id, token_action) when token_action in ["mint", "rotate"] do
    Guard.Repo.transaction(fn ->
      with {:ok, row} <- CliAuthCode.lock_pending_device(row_id),
           {:ok, _} <- CliAuthCode.approve(row, user_id, token_action) do
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
  states and, on approval, executes the token action the human consented to
  (see `approve_device/3`).

  Returns one of:
    * `{:ok, token, "minted"}` — fresh account, first token minted
    * `{:ok, token, "rotated"}` — existing account, token reset with consent
    * `{:error, :authorization_pending}` — still waiting for the human
    * `{:error, :slow_down}` — polled faster than the interval (interval bumped)
    * `{:error, :access_denied}` — the human denied it
    * `{:error, :expired_token}` — past expires_at
    * `{:error, :token_exists}` — consent said "mint" but a token appeared on
      the account in the meantime; re-run sign-in to get the reset consent
    * `{:error, :invalid_grant}` — unknown / already consumed device_code
    * `{:error, :user_not_found}` / `{:error, String.t()}` — the token write
      failed to persist; the code is left unconsumed so the client can retry
  """
  @spec poll_device_token(String.t()) ::
          {:ok, String.t(), String.t()}
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
  # approved branch writes the token in the same transaction as the lock (see
  # `execute_token_action/1`) so consumption and the token write share fate.
  defp resolve_device_poll(row) do
    cond do
      expired?(row) -> {:error, :expired_token}
      row.status == "denied" -> {:error, :access_denied}
      row.status == "consumed" -> {:error, :invalid_grant}
      row.status == "approved" and is_nil(row.user_id) -> {:error, :invalid_grant}
      row.status == "approved" -> execute_token_action(row)
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

  # ── token policy ────────────────────────────────────────────────────────────

  @doc """
  Mint the API token for a tokenless (new) account. An account that already
  holds a token is rejected with `:token_exists` — replacing a token requires
  the explicit "rotate" consent recorded at approval (see `approve_device/3`);
  minting never overwrites. We can't return the existing token anyway (only
  its hash is stored).

  The write is a single atomic conditional UPDATE (see
  `Guard.FrontRepo.User.mint_token_if_absent/1`), not read-then-write: this is
  what makes the mint safe against two overlapping sign-ins for the same fresh
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
  Rotate (reset) the account's API token. Only reachable from a device row
  whose approval recorded the explicit "rotate" consent — the authenticated
  browser page is where that consent was given.
  """
  @spec rotate_token(String.t()) ::
          {:ok, String.t()} | {:error, :user_not_found | String.t()}
  def rotate_token(user_id) do
    case Guard.Store.User.Front.find(user_id) do
      {:ok, _front_user} ->
        Guard.FrontRepo.User.rotate_token(user_id)

      {:error, :not_found} ->
        {:error, :user_not_found}
    end
  end

  @doc """
  Whether the account already holds an API token. The consent screen branches
  on this: a tokenless account gets the plain "authorize this tool" consent,
  an account with a token gets the explicit "reset your API token" consent.
  """
  @spec account_has_token?(String.t()) :: boolean()
  def account_has_token?(user_id) do
    case Guard.Store.User.Front.find(user_id) do
      {:ok, %{authentication_token: token}} -> not (is_nil(token) or token == "")
      _ -> false
    end
  end

  @doc """
  The token action sign-in would take for this account right now: `"rotate"`
  when a token already exists (needs explicit reset consent), `"mint"` when
  the account has none. Computed when rendering the consent screen and
  re-checked when the decision is submitted, so the consent the user gave
  always matches the action recorded on the row.
  """
  @spec intended_token_action(String.t()) :: String.t()
  def intended_token_action(user_id) do
    if account_has_token?(user_id), do: "rotate", else: "mint"
  end

  # Runs inside the caller's Guard.Repo transaction on the locked cli_auth_codes
  # row, but the token write itself touches Guard.FrontRepo — a different
  # database, so there is no single cross-DB transaction that could cover both
  # writes. Instead we resolve this by ORDERING: the row lock (SELECT FOR
  # UPDATE) is held for the duration of the token write, and the code is only
  # marked consumed once the write's outcome is known, so the two never
  # diverge:
  #   * write succeeds            -> consume (this code is now spent)
  #   * mint says :token_exists   -> consume (terminal: consent said "mint" but
  #     a token appeared meanwhile; never escalate a mint consent into a
  #     rotation — the client is told to re-run sign-in)
  #   * write errors on persist   -> do NOT consume (client can retry the code)
  defp execute_token_action(row) do
    case consented_token_write(row) do
      {:ok, token, action} ->
        {:ok, _} = CliAuthCode.mark_consumed(row)
        {:ok, token, action}

      {:error, :token_exists} ->
        {:ok, _} = CliAuthCode.mark_consumed(row)
        {:error, :token_exists}

      {:error, other} ->
        {:error, other}
    end
  end

  defp consented_token_write(%{token_action: "rotate"} = row) do
    case rotate_token(row.user_id) do
      {:ok, token} -> {:ok, token, "rotated"}
      {:error, error} -> {:error, error}
    end
  end

  # "mint" — also the default for any legacy approved row without a recorded
  # action, since mint-if-absent is the non-destructive choice.
  defp consented_token_write(row) do
    case mint_token(row.user_id) do
      {:ok, token} -> {:ok, token, "minted"}
      {:error, error} -> {:error, error}
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
