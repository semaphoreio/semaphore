defmodule Guard.FrontRepo.RepoHostAccount do
  use Ecto.Schema

  require Logger

  import Ecto.Query

  alias Guard.FrontRepo

  @register_scope "user:email"
  @public_scope "public_repo,user:email"
  @private_scope "repo,user:email"

  def register_scope, do: @register_scope

  @scopes_in_order [
    @register_scope,
    @public_scope,
    @private_scope
  ]

  @type repo_host :: :github | :bitbucket | :gitlab

  @type t :: %__MODULE__{
          login: String.t(),
          github_uid: String.t(),
          repo_host: String.t(),
          user_id: String.t(),
          name: String.t(),
          permission_scope: String.t(),
          refresh_token: String.t(),
          token: String.t(),
          revoked: boolean(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}

  @derive {Inspect, except: [:token, :refresh_token]}

  schema "repo_host_accounts" do
    field(:login, :string)
    field(:github_uid, :string)
    field(:repo_host, :string)
    field(:user_id, :binary_id)
    field(:name, :string)
    field(:permission_scope, :string)
    field(:token, :string, redact: true)
    field(:refresh_token, :string, redact: true)
    field(:token_expires_at, :utc_datetime)
    field(:revoked, :boolean, default: false)

    timestamps(inserted_at: :created_at, updated_at: :updated_at, type: :utc_datetime)
  end

  @spec count(String.t() | nil) :: integer()
  def count(user_id \\ nil)
  def count(nil), do: from(r in __MODULE__) |> FrontRepo.aggregate(:count, :id)

  def count(user_id),
    do: from(r in __MODULE__, where: r.user_id == ^user_id) |> FrontRepo.aggregate(:count, :id)

  def create(data) do
    result =
      %__MODULE__{}
      |> Ecto.Changeset.cast(data, [
        :login,
        :github_uid,
        :repo_host,
        :user_id,
        :name,
        :permission_scope,
        :token,
        :refresh_token,
        :token_expires_at
      ])
      |> Ecto.Changeset.validate_required([
        :login,
        :github_uid,
        :repo_host,
        :user_id,
        :name,
        :permission_scope
      ])
      |> FrontRepo.insert()

    case result do
      {:ok, account} ->
        Logger.info(
          "Successfully created RepoHostAccount for #{account.user_id} #{account.repo_host} with login #{account.login}, github_uid #{account.github_uid}, and scope #{account.permission_scope}"
        )

        {:ok, account}

      {:error, error} ->
        Logger.error(
          "Failed to create RepoHostAccount for #{data.user_id} #{data.repo_host} with login #{data.login} and github_uid #{data.github_uid} errors=#{changeset_error_fields(error)}"
        )

        {:error, error}
    end
  end

  @spec list_for_user(String.t()) :: {:ok, [Guard.FrontRepo.RepoHostAccount.t()]}
  def list_for_user(user_id) do
    accounts =
      FrontRepo.RepoHostAccount
      |> where([rha], rha.user_id == ^user_id)
      |> FrontRepo.all()

    {:ok, accounts}
  end

  @spec get_for_github_user(String.t()) ::
          {:ok, Guard.FrontRepo.RepoHostAccount.t()} | {:error, :not_found}
  def get_for_github_user(user_id), do: get_for_user_by_repo_host(user_id, "github")

  @spec get_for_user_by_repo_host(String.t(), String.t()) ::
          {:ok, Guard.FrontRepo.RepoHostAccount.t()} | {:error, :not_found}
  def get_for_user_by_repo_host(user_id, repo_host) do
    account =
      FrontRepo.RepoHostAccount
      |> where([rha], rha.user_id == ^user_id)
      |> where([rha], rha.repo_host == ^repo_host)
      |> FrontRepo.one()

    case account do
      nil -> {:error, :not_found}
      account -> {:ok, account}
    end
  end

  @spec get_github_token(String.t()) :: {:ok, String.t()} | {:error, :not_found}
  def get_github_token(user_id) when is_binary(user_id) do
    token =
      Guard.FrontRepo.RepoHostAccount
      |> where([rha], rha.user_id == ^user_id)
      |> where([rha], rha.repo_host == "github")
      |> select([rha], rha.token)
      |> Guard.FrontRepo.one()

    case token do
      nil -> {:error, :not_found}
      token -> {:ok, token}
    end
  end

  # `revoked` must never gate the fetch. The column carries a backlog of
  # false positives from an older write path that latched it on any 4xx
  # (transient WAF/edge 403s included); those rows still hold working
  # credentials, so gating here turns them into hard failures. Always ask
  # the provider and let the live response decide.
  def get_github_token(%__MODULE__{} = rha) do
    with_negative_cache(rha, fn ->
      case Guard.Api.Github.user_token(rha) do
        {:ok, {_token, _expires_at}} = token_tuple ->
          token_tuple

        {:error, :revoked} ->
          revoke_or_recover(rha)

        {:error, reason} ->
          {:error, reason}
      end
    end)
  end

  def get_bitbucket_token(rha) do
    with_negative_cache(rha, fn ->
      case Guard.Api.Bitbucket.user_token(rha) do
        {:ok, {_token, _expires_at}} = token_tuple ->
          token_tuple

        {:error, :revoked} ->
          revoke_or_recover(rha)

        {:error, reason} ->
          {:error, reason}
      end
    end)
  end

  def get_gitlab_token(rha) do
    with_negative_cache(rha, fn ->
      case Guard.Api.Gitlab.user_token(rha) do
        {:ok, {_token, _expires_at}} = token_tuple ->
          token_tuple

        {:error, :revoked} ->
          revoke_or_recover(rha)

        {:error, reason} ->
          {:error, reason}
      end
    end)
  end

  # A provider classified the refresh as a genuine revocation (invalid_grant).
  # Under single-use refresh-token rotation this can be a FALSE revoke: the
  # loser of a concurrent refresh reuses the token the winner already rotated,
  # and the provider answers invalid_grant even though a sibling worker just
  # stored a healthy token. Blindly flipping `revoked: true` here would
  # disconnect that healthy account (the mass-disconnect failure class).
  #
  # So re-read the row first and decide:
  #   - the stored token CHANGED vs the snapshot we refreshed with -> a
  #     concurrent winner rotated it; do NOT revoke. Return the winner's token
  #     if it is usable, else :transient (the caller refreshes with the new
  #     refresh_token next time).
  #   - the stored token is UNCHANGED (still the one the provider just
  #     rejected) -> a genuine revocation; flip `revoked: true` under an
  #     optimistic lock so a winner committing between our reload and our write
  #     cannot be clobbered by a stale revoke.
  defp revoke_or_recover(%__MODULE__{} = rha) do
    case reload(rha) do
      %__MODULE__{} = fresh ->
        if token_rotated_by_winner?(rha, fresh) do
          recover_after_winner(fresh)
        else
          revoke_unrotated(rha, fresh)
        end

      nil ->
        {:error, :revoked}
    end
  end

  # No winner seen at reload: write revoked:true on the FRESH struct under an
  # optimistic lock. If a winner commits in the gap, the locked write raises
  # StaleEntryError (surfaced as {:error, :stale}) and we re-evaluate ONCE
  # (no loop): recover if a rotation is now visible, otherwise degrade to
  # :transient so the next request re-decides cleanly - never a blind revoke.
  defp revoke_unrotated(%__MODULE__{} = rha, %__MODULE__{} = fresh) do
    case update_account(%{revoked: true}, fresh, lock: true) do
      {:ok, _} ->
        {:error, :revoked}

      {:error, :stale} ->
        case reload(rha) do
          %__MODULE__{} = refreshed ->
            if token_rotated_by_winner?(rha, refreshed) do
              recover_after_winner(refreshed)
            else
              {:error, :transient}
            end

          nil ->
            {:error, :revoked}
        end

      {:error, reason} ->
        # The revoke write itself failed to persist. Do NOT report {:error,
        # :revoked}: that signals a permanent revocation (gRPC NOT_FOUND ->
        # repohub disconnect) the DB never actually recorded. Degrade to
        # :transient so the caller retries and re-decides cleanly.
        Logger.error(
          "Failed to persist revoke for rha=#{rha.id} user=#{rha.user_id} " <>
            "#{rha.repo_host}: errors=#{changeset_error_fields(reason)}"
        )

        {:error, :transient}
    end
  end

  defp token_rotated_by_winner?(%__MODULE__{} = rha, %__MODULE__{} = fresh) do
    fresh.token != rha.token or fresh.refresh_token != rha.refresh_token
  end

  # NOTE (GitLab caveat): a token recovered here may still be dead. GitLab's
  # token-family reuse-detection can revoke the WHOLE family when the burned
  # token is replayed, so the winner's rotated token could already be
  # family-revoked; that surfaces on the next validate/refresh. The real fix
  # (single-flight before the refresh POST) is tracked separately.
  defp recover_after_winner(%__MODULE__{} = fresh) do
    nil_valid = fresh.repo_host == "github"

    if not is_nil(fresh.token) and
         Guard.Utils.OAuth.valid_token?(fresh.token_expires_at, nil_valid: nil_valid) do
      Logger.info(
        "OAuth refresh classified revoked but a concurrent winner rotated the token; " <>
          "recovering rha=#{fresh.id} user=#{fresh.user_id} provider=#{fresh.repo_host}"
      )

      {:ok, {fresh.token, fresh.token_expires_at}}
    else
      Logger.info(
        "OAuth refresh classified revoked, winner rotated but token not yet usable " <>
          "rha=#{fresh.id} user=#{fresh.user_id} provider=#{fresh.repo_host}; retrying"
      )

      {:error, :transient}
    end
  end

  # Negative cache for a row that is NOT yet revoked but just failed a
  # refresh (transient upstream failure or network error). Without this, a
  # bare-403/429 storm re-hammers the shared OAuth consumer credential on
  # every lookup - and it's worse than a plain retry loop: :transient/
  # :network_error surface as gRPC UNAVAILABLE (see user_server.ex
  # handle_token_error/3), which repohub auto-retries, so each failure can
  # trigger another failure almost immediately. A short TTL cache absorbs
  # that amplification without needing new persisted state.
  @oauth_refresh_failure_cache :oauth_refresh_failure_cache
  @oauth_refresh_failure_cache_ttl :timer.seconds(60)

  defp with_negative_cache(rha, fetch_fun) do
    case Cachex.get(@oauth_refresh_failure_cache, rha.id) do
      {:ok, {:error, _reason} = cached_error} ->
        cached_error

      _ ->
        case fetch_fun.() do
          {:error, _reason} = error ->
            Cachex.put(
              @oauth_refresh_failure_cache,
              rha.id,
              error,
              ttl: @oauth_refresh_failure_cache_ttl
            )

            error

          ok ->
            ok
        end
    end
  end

  @doc """
  Persist a freshly-refreshed token.

  `refresh_token` may be `nil` (the provider returned a 2xx WITHOUT rotating
  it - e.g. GitHub, or an unchanged token). In that case the stored
  `refresh_token` is left UNTOUCHED rather than overwritten with a snapshot
  value, which would risk clobbering a newer rotated token written by a
  concurrent worker. `token`/`expires_at` are written only when present.

  The write is optimistic-locked on `:updated_at` (single-use refresh-token
  rotation means the losing side of a concurrent refresh must not overwrite
  the winner's freshly-rotated token). On a lost race the caller gets
  `{:error, :stale}` and MUST discard its own (older) refresh response.
  """
  def update_token(rha, token, refresh_token, expires_at) do
    write_token(rha, token, refresh_token, expires_at, lock: true)
  end

  defp write_token(rha, token, refresh_token, expires_at, opts) do
    params =
      %{
        # A successful token fetch is proof the account is not revoked -
        # self-heal a row that got latched `revoked: true` by a past
        # transient failure now correctly classified as such.
        revoked: false
      }
      |> put_present(:token, token)
      |> put_present(:refresh_token, refresh_token)
      |> put_present(:token_expires_at, expires_at)

    update_account(params, rha, opts)
  end

  # Bound the re-apply retries so a pathological stream of unrelated writes
  # cannot spin here; after this many lost locks we persist unconditionally.
  @max_token_persist_attempts 3

  @doc """
  Concurrency-safe persistence of a freshly-refreshed (possibly rotated) token.

  The write carries an optimistic lock on `:updated_at`, but losing that lock
  must NEVER discard a just-rotated single-use refresh_token. On a lost race we
  re-read and decide by comparing the stored credential against the snapshot we
  refreshed with:

    - the credential CHANGED -> an independent writer (a reconnect, or a
      sibling refresh) rotated it; ours is superseded, so recover the winner's
      token instead.
    - the credential is UNCHANGED -> only an UNRELATED column write (profile
      sync, revoke flip, ...) advanced `:updated_at`. Our rotation is still the
      newest credential, so re-apply it onto the fresh row. After
      `@max_token_persist_attempts` lost locks we persist via a credential
      compare-and-set (write only while the stored credential is still the one
      we reloaded), so an unrelated concurrent write can never strand the
      rotated token while a concurrent reconnect still wins.

  Returns `{:ok, {token, expires_at}}` (ours or the recovered winner's) or
  `{:error, :transient}`.
  """
  @spec persist_refreshed_token(t(), String.t(), String.t() | nil, DateTime.t() | nil) ::
          {:ok, {String.t(), DateTime.t() | nil}} | {:error, :transient}
  def persist_refreshed_token(%__MODULE__{} = rha, token, refresh_token, expires_at) do
    do_persist_refreshed_token(rha, token, refresh_token, expires_at, 1)
  end

  defp do_persist_refreshed_token(rha, token, refresh_token, expires_at, attempt) do
    case write_token(rha, token, refresh_token, expires_at, lock: true) do
      {:ok, account} ->
        {:ok, {account.token, account.token_expires_at}}

      {:error, :stale} ->
        resolve_lost_token_write(rha, token, refresh_token, expires_at, attempt)

      {:error, reason} ->
        Logger.error(
          "Failed to persist refreshed token rha=#{rha.id} user=#{rha.user_id} " <>
            "#{rha.repo_host}: errors=#{changeset_error_fields(reason)}"
        )

        {:error, :transient}
    end
  end

  defp resolve_lost_token_write(snapshot, token, refresh_token, expires_at, attempt) do
    case reload(snapshot) do
      %__MODULE__{} = fresh ->
        cond do
          token_rotated_by_winner?(snapshot, fresh) ->
            # An independent writer rotated the credential; ours is superseded.
            recover_after_winner(fresh)

          attempt >= @max_token_persist_attempts ->
            persist_rotated_token_unlocked(fresh, token, refresh_token, expires_at)

          true ->
            # Only an unrelated column write bumped :updated_at; our rotation is
            # still authoritative. Re-apply it onto the fresh row.
            do_persist_refreshed_token(fresh, token, refresh_token, expires_at, attempt + 1)
        end

      nil ->
        {:error, :transient}
    end
  end

  # Terminal fallback after repeated UNRELATED write races. The credential was
  # verified unchanged vs the preceding reload, so our rotation is still the
  # newest credential. Persist it with a COMPARE-AND-SET scoped to the
  # credential columns: write only while the stored token AND refresh_token are
  # still the ones we just reloaded. This closes the write without the
  # optimistic lock on :updated_at (an unrelated column write cannot strand us)
  # while STILL yielding to a reconnect: if reset_account/update_existing_account
  # wrote a new authorization_code credential in the gap, the CAS matches zero
  # rows and we recover the winner's token instead of clobbering it with our
  # now-superseded (old-family) token.
  defp persist_rotated_token_unlocked(fresh, token, refresh_token, expires_at) do
    Logger.warning(
      "Persisting rotated token via credential compare-and-set after repeated " <>
        "unrelated write races rha=#{fresh.id} user=#{fresh.user_id} #{fresh.repo_host}"
    )

    case FrontRepo.update_all(credential_cas_query(fresh),
           set: token_cas_set(token, refresh_token, expires_at)
         ) do
      {1, _} ->
        Cachex.del(@oauth_refresh_failure_cache, fresh.id)

        Logger.info(
          "Persisted rotated token via compare-and-set rha=#{fresh.id} " <>
            "user=#{fresh.user_id} #{fresh.repo_host}"
        )

        {:ok, {token, expires_at}}

      {0, _} ->
        # A concurrent reconnect committed a new credential between our reload
        # and this CAS. Do NOT clobber it and do NOT strand ours as :transient
        # (our refresh token is already burned upstream) - yield to the winner.
        Logger.info(
          "Compare-and-set missed - a concurrent credential write won; recovering " <>
            "rha=#{fresh.id} user=#{fresh.user_id} #{fresh.repo_host}"
        )

        case reload(fresh) do
          %__MODULE__{} = winner -> recover_after_winner(winner)
          nil -> {:error, :transient}
        end
    end
  end

  # WHERE id = ? AND token <=> fresh.token AND refresh_token <=> fresh.refresh_token
  # (nil-safe: a nil credential column matches with IS NULL, not `= NULL`).
  defp credential_cas_query(%__MODULE__{} = fresh) do
    from(r in __MODULE__, where: r.id == ^fresh.id)
    |> cas_where(:token, fresh.token)
    |> cas_where(:refresh_token, fresh.refresh_token)
  end

  defp cas_where(query, field, nil), do: from(r in query, where: is_nil(field(r, ^field)))
  defp cas_where(query, field, value), do: from(r in query, where: field(r, ^field) == ^value)

  # Mirror write_token's put_present semantics: always self-heal `revoked` and
  # bump `updated_at` (update_all does not touch timestamps automatically);
  # write token/refresh_token/token_expires_at only when present.
  defp token_cas_set(token, refresh_token, expires_at) do
    [revoked: false, updated_at: DateTime.utc_now() |> DateTime.truncate(:second)]
    |> put_set(:token, token)
    |> put_set(:refresh_token, refresh_token)
    |> put_set(:token_expires_at, expires_at)
  end

  defp put_set(set, _key, nil), do: set
  defp put_set(set, _key, ""), do: set
  defp put_set(set, key, value), do: set ++ [{key, value}]

  defp put_present(map, _key, nil), do: map
  defp put_present(map, _key, ""), do: map
  defp put_present(map, key, value), do: Map.put(map, key, value)

  @doc """
  Re-read the row from the DB by id. Used to recover the winner's freshly
  rotated token after losing an optimistic-lock race on the token write.
  """
  @spec reload(t()) :: t() | nil
  def reload(%__MODULE__{id: id}), do: FrontRepo.get(__MODULE__, id)

  @doc """
  Write `:login` and/or `:name` only; other keys dropped. Strict writer:
  any supplied key must carry a non-blank value or the changeset fails with
  a `:required` error. Callers that want "drop nil/blank as no-opinion"
  semantics must filter before calling.

  Guards against concurrent writers via an optimistic lock on `:updated_at`.
  When another writer commits between this caller's read and write, returns
  `{:error, :stale}` instead of overwriting with the stale snapshot's view.
  """
  @spec update_profile(t(), map()) :: {:ok, t()} | {:error, Ecto.Changeset.t() | :stale}
  def update_profile(%__MODULE__{} = rha, attrs) when is_map(attrs) do
    rha
    |> Ecto.Changeset.cast(attrs, [:login, :name])
    |> then(&Ecto.Changeset.validate_required(&1, Map.keys(&1.changes)))
    |> maybe_lock_on_updated_at()
    |> FrontRepo.update()
  rescue
    Ecto.StaleEntryError -> {:error, :stale}
  end

  defp maybe_lock_on_updated_at(%Ecto.Changeset{changes: changes} = cs) when changes == %{},
    do: cs

  defp maybe_lock_on_updated_at(cs),
    do: Ecto.Changeset.optimistic_lock(cs, :updated_at, &bump_updated_at/1)

  # Force monotonic increment so the optimistic lock works even when two
  # writes land in the same wall-clock second. The `:utc_datetime` schema
  # type stores second precision, so plain `now()` can match the stale
  # snapshot's `updated_at` and let a second writer through.
  defp bump_updated_at(current) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    if DateTime.compare(now, current) == :gt do
      now
    else
      DateTime.add(current, 1, :second)
    end
  end

  @spec get_uid_by_login(String.t(), String.t()) :: {:ok, String.t()} | {:error, :not_found}
  def get_uid_by_login(login, repo_host) do
    uid =
      Guard.FrontRepo.RepoHostAccount
      |> where([rha], rha.login == ^login)
      |> where([rha], rha.repo_host == ^repo_host)
      |> select([rha], rha.github_uid)
      |> Guard.FrontRepo.one()

    case uid do
      nil -> {:error, :not_found}
      uid -> {:ok, uid}
    end
  end

  @spec update_repo_host_account(String.t(), repo_host, map(), Keyword.t()) ::
          {:ok, Guard.FrontRepo.RepoHostAccount.t()}
          | {:error, :invalid_data | Ecto.Changeset.t()}
  def update_repo_host_account(user_id, _, %{github_uid: uid, login: login}, _opts)
      when is_nil(uid) or is_nil(login) do
    Logger.error(
      "Cannot update RepoHostAccount for #{user_id}: missing required fields (login_present=#{not is_nil(login)}, uid_present=#{not is_nil(uid)})"
    )

    {:error, :invalid_data}
  end

  def update_repo_host_account(user_id, repo_host, data, opts) do
    data = data |> adjust_scope(user_id)
    repo_host = repo_host |> Atom.to_string()

    Logger.debug("Updating RepoHostAccount for #{user_id} repo_host=#{repo_host}")

    case get_for_user_by_repo_host(user_id, repo_host) do
      {:ok, account} ->
        update_existing_account(account, data, opts)

      {:error, :not_found} ->
        create(data |> Map.merge(%{user_id: user_id, repo_host: repo_host}))
    end
  end

  def update_revoke_status(rha, revoked) do
    update_account(%{revoked: revoked}, rha)
  end

  defp adjust_scope(%{permission_scope: scope} = data, _) when scope in @scopes_in_order, do: data

  defp adjust_scope(data, user_id) when is_binary(user_id) and user_id != "",
    do: data |> Map.put(:permission_scope, @private_scope)

  defp adjust_scope(data, _), do: data |> Map.put(:permission_scope, @register_scope)

  def private_scope?(rha),
    do: not rha.revoked and String.starts_with?(rha.permission_scope, "repo")

  def public_scope?(rha),
    do:
      not rha.revoked and
        (String.starts_with?(rha.permission_scope, "public_repo") or private_scope?(rha))

  defp update_existing_account(account, data, opts) when account.github_uid != data.github_uid,
    do: reset_account(account, data |> Map.merge(%{revoked: true}), opts)

  defp update_existing_account(account, data, _opts) do
    data
    |> filter_update_data(account)
    |> update_account(account)
  end

  defp filter_update_data(data, account) do
    data
    |> Map.drop([:github_uid])
    |> Map.put(:revoked, false)
    |> drop_if_skip_credentials(account.permission_scope)
    |> drop_if_same(:login, account.login)
    |> drop_if_same(:name, account.name)
    |> drop_if_same(:permission_scope, account.permission_scope)
    |> drop_if_same(:token, account.token)
    |> drop_if_same(:refresh_token, account.refresh_token)
    |> drop_if_same(:revoked, account.revoked)
    |> drop_if_empty(:name)
  end

  defp drop_if_skip_credentials(data, permission_scope) do
    if skip_credentials?(permission_scope, Map.get(data, :permission_scope)) do
      Map.drop(data, [:permission_scope, :token, :refresh_token, :token_expires_at, :revoked])
    else
      data
    end
  end

  defp drop_if_same(data, key, value) do
    if Map.get(data, key) == value do
      Map.drop(data, [key])
    else
      data
    end
  end

  defp drop_if_empty(data, key) do
    if Map.get(data, key) == "" or Map.get(data, key) == nil do
      Map.drop(data, [key])
    else
      data
    end
  end

  @required_on_write [:github_uid, :login, :name, :permission_scope]

  # `lock: true` guards against a concurrent writer clobbering a
  # freshly-rotated token: the write carries an optimistic lock on
  # `:updated_at`, and if another writer committed first the update raises
  # `Ecto.StaleEntryError`, which we surface as `{:error, :stale}` so the
  # losing caller can discard its own (older) response. Unlocked callers
  # (revoke flips, reconnect, profile-less writes) never raise it.
  defp update_account(data, account, opts \\ [])

  defp update_account(data, account, _opts) when data == %{} do
    Logger.debug("Account for #{account.user_id} already up to date")

    {:ok, account}
  end

  defp update_account(data, account, opts) do
    # Validate only the required-schema keys the caller is actually writing.
    # The full @required_on_write list is checked at create/reset time; on a
    # partial update (e.g., flipping :revoked) we must not refuse the write
    # because an *untouched* legacy field happens to be nil.
    required_now = Map.keys(data) |> Enum.filter(&(&1 in @required_on_write))

    changeset =
      account
      |> Ecto.Changeset.cast(
        data,
        [
          :github_uid,
          :login,
          :name,
          :revoked,
          :token,
          :refresh_token,
          :token_expires_at,
          :permission_scope
        ]
      )
      |> Ecto.Changeset.validate_required(required_now)

    changeset =
      if Keyword.get(opts, :lock, false),
        do: maybe_lock_on_updated_at(changeset),
        else: changeset

    case FrontRepo.update(changeset) do
      {:ok, account} ->
        Logger.info(
          "Successfully updated RepoHostAccount rha=#{account.id} user=#{account.user_id} #{account.repo_host} login=#{account.login}"
        )

        maybe_invalidate_negative_cache(data, account)
        {:ok, account}

      {:error, error} ->
        Logger.error(
          "Failed to update RepoHostAccount rha=#{account.id} user=#{account.user_id} #{account.repo_host} login=#{account.login} errors=#{changeset_error_fields(error)}"
        )

        {:error, error}
    end
  rescue
    error in [Ecto.StaleEntryError] ->
      # Only the locked callers (token write, unrotated revoke) expect and
      # handle {:error, :stale}. An UNLOCKED write raises StaleEntryError only
      # when the row was deleted between read and write; converting that to
      # {:error, :stale} here would hand every unlocked caller
      # (update_revoke_status, update_existing_account) an undeclared error they
      # pattern-match as a changeset. Scope the translation to the locked path
      # and re-raise otherwise, preserving those callers' contract.
      if Keyword.get(opts, :lock, false) do
        Logger.warning(
          "Lost optimistic-lock race writing token for rha=#{account.id} user=#{account.user_id} #{account.repo_host}; discarding stale response"
        )

        {:error, :stale}
      else
        reraise error, __STACKTRACE__
      end
  end

  # update_account/2 is the single write chokepoint for both self-heal
  # (update_token/4, on a successful refresh) and reconnect
  # (update_existing_account/3, driven by id/api.ex). Either one landing a
  # fresh token or explicitly clearing :revoked means any cached refresh
  # failure for this row is stale - purge it immediately instead of
  # letting a user who just reconnected (or a refresh that just recovered)
  # keep seeing the cached error for up to @oauth_refresh_failure_cache_ttl.
  # A stray extra purge on an unrelated field-only update is harmless.
  defp maybe_invalidate_negative_cache(data, account) do
    if Map.has_key?(data, :token) or data[:revoked] == false do
      Cachex.del(@oauth_refresh_failure_cache, account.id)
    end
  end

  defp reset_account(account, data, reset: reset)
       when account.github_uid == data.github_uid or reset == false do
    Logger.debug(
      "Skipping reset account for #{account.user_id} #{account.repo_host} reset=#{reset}"
    )

    {:ok, account}
  end

  defp reset_account(account, data, _opts) do
    result =
      account
      |> Ecto.Changeset.cast(
        data,
        [
          :github_uid,
          :name,
          :login,
          :revoked,
          :token,
          :refresh_token,
          :token_expires_at,
          :permission_scope
        ]
      )
      |> Ecto.Changeset.validate_required([:github_uid, :login, :name])
      |> FrontRepo.update()

    case result do
      {:ok, account} ->
        Logger.warning(
          "Successfully reset RepoHostAccount for #{account.user_id} #{account.repo_host} login=#{account.login}"
        )

        {:ok, account}

      {:error, error} ->
        Logger.error(
          "Failed to reset RepoHostAccount for #{account.user_id} #{account.repo_host} login=#{account.login} errors=#{changeset_error_fields(error)}"
        )

        {:error, error}
    end
  end

  def skip_credentials?(_, ""), do: true
  def skip_credentials?("", _to), do: false
  def skip_credentials?(from, to) when from == to, do: false

  def skip_credentials?(from, to) do
    order_index = fn scope -> Enum.find_index(@scopes_in_order, &(&1 == to_string(scope))) end
    order_index.(from) > order_index.(to)
  end

  defp changeset_error_fields(%Ecto.Changeset{errors: errors}) do
    Enum.map_join(errors, ",", fn {field, {msg, _opts}} -> "#{field}:#{msg}" end)
  end

  defp changeset_error_fields(atom) when is_atom(atom), do: "#{atom}"
  defp changeset_error_fields(_other), do: "opaque"
end
