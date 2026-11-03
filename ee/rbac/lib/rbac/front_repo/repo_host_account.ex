defmodule Rbac.FrontRepo.RepoHostAccount do
  use Ecto.Schema

  require Logger

  import Ecto.Query

  alias Rbac.FrontRepo

  # Mirrors guard's @revoked_claim_grace_seconds: a transient failure can
  # briefly latch a healthy link revoked, so it keeps blocking for a while.
  @revoked_claim_grace_seconds 2 * 60 * 60

  @register_scope "user:email"
  @public_scope "public_repo,user:email"
  @private_scope "repo,user:email"

  def register_scope, do: @register_scope

  @scopes_in_order [
    @register_scope,
    @public_scope,
    @private_scope
  ]

  @type repo_host :: :github | :bitbucket

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
    changeset =
      %__MODULE__{}
      |> Ecto.Changeset.cast(data, [
        :login,
        :github_uid,
        :repo_host,
        :user_id,
        :name,
        :permission_scope,
        :token,
        :refresh_token
      ])
      |> Ecto.Changeset.validate_required([
        :login,
        :github_uid,
        :repo_host,
        :user_id,
        :name,
        :permission_scope
      ])

    result = FrontRepo.insert(changeset)

    case result do
      {:ok, account} ->
        Logger.info(
          "Successfully created RepoHostAccount for #{account.user_id} #{account.repo_host} with login #{account.login}, github_uid #{account.github_uid}, and scope #{account.permission_scope}"
        )

        {:ok, account}

      {:error, error} ->
        Logger.error(
          "Failed to create RepoHostAccount for #{data.user_id} #{data.repo_host} with login #{data.login} and github_uid #{data.github_uid} #{inspect(error)}"
        )

        {:error, error}
    end
  end

  @spec list_for_user(String.t()) :: {:ok, [Rbac.FrontRepo.RepoHostAccount.t()]}
  def list_for_user(user_id) do
    accounts =
      FrontRepo.RepoHostAccount
      |> where([rha], rha.user_id == ^user_id)
      |> FrontRepo.all()

    {:ok, accounts}
  end

  @spec get_for_github_user(String.t()) ::
          {:ok, Rbac.FrontRepo.RepoHostAccount.t()} | {:error, :not_found}
  def get_for_github_user(user_id), do: get_for_user_by_repo_host(user_id, "github")

  @spec get_for_user_by_repo_host(String.t(), String.t()) ::
          {:ok, Rbac.FrontRepo.RepoHostAccount.t()} | {:error, :not_found}
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
  def get_github_token(user_id) do
    token =
      Rbac.FrontRepo.RepoHostAccount
      |> where([rha], rha.user_id == ^user_id)
      |> where([rha], rha.repo_host == "github")
      |> select([rha], rha.token)
      |> Rbac.FrontRepo.one()

    case token do
      nil -> {:error, :not_found}
      token -> {:ok, token}
    end
  end

  @spec update_repo_host_account(String.t() | nil, repo_host, map(), Keyword.t()) ::
          {:ok, Rbac.FrontRepo.RepoHostAccount.t()}
          | {:error, :invalid_data | :uid_taken | Ecto.Changeset.t()}
  def update_repo_host_account(user_id, _, %{github_uid: uid, login: login}, _opts)
      when is_nil(uid) or is_nil(login) do
    missing = for {key, nil} <- [github_uid: uid, login: login], do: key

    Logger.error("Cannot update RepoHostAccount for #{user_id}: missing #{inspect(missing)}")

    {:error, :invalid_data}
  end

  def update_repo_host_account(user_id, repo_host, data, opts) do
    data = data |> adjust_scope(user_id)
    repo_host = repo_host |> Atom.to_string()

    Logger.debug(
      "Updating RepoHostAccount for #{user_id} #{repo_host} with fields #{inspect(Map.keys(data))} and opts #{inspect(opts)}"
    )

    existing = get_for_user_by_repo_host(user_id, repo_host)

    if claiming_new_uid?(existing, data) do
      claim_uid(user_id, repo_host, data, existing, opts)
    else
      write_account(existing, user_id, repo_host, data, opts)
    end
  end

  # Pointing a user at a uid they do not already hold is a claim; re-syncing
  # the uid they already have is not. guard draws the same line by checking
  # only on create, an un-revoke and a reset, never on a refresh. Without it an
  # existing duplicate would make the legitimate owner's routine re-sync fail.
  defp claiming_new_uid?(_existing, data) when not is_map_key(data, :github_uid), do: false

  defp claiming_new_uid?(_existing, %{github_uid: uid}) when uid in [nil, ""], do: false

  defp claiming_new_uid?({:error, :not_found}, _data), do: true
  defp claiming_new_uid?({:ok, account}, %{github_uid: uid}), do: account.github_uid != uid

  # Same lock and key derivation as guard's claim_uid/2: the check is an exists
  # query, so without it two rbac syncs of one uid both read "free" and both
  # write.
  defp claim_uid(user_id, repo_host, data, existing, opts) do
    FrontRepo.transaction(fn ->
      lock_uid(repo_host, data[:github_uid])

      if uid_actively_held_by_other?(user_id, repo_host, data[:github_uid]) do
        Logger.warning(
          "Refusing to point #{repo_host} uid for #{user_id} at an identity another user holds"
        )

        # The OIDC caller discards this result, so without the counter a
        # refused link is invisible. Mirrors guard's
        # guard.repo_host_account.account_taken.
        Watchman.increment({"rbac.repo_host_account.account_taken", [repo_host, "oidc_sync"]})

        FrontRepo.rollback(:uid_taken)
      else
        case write_account(existing, user_id, repo_host, data, opts) do
          {:ok, account} -> account
          {:error, reason} -> FrontRepo.rollback(reason)
        end
      end
    end)
  end

  defp lock_uid("github", uid) when uid not in [nil, ""] do
    FrontRepo.query!("SELECT pg_advisory_xact_lock($1)", [uid_lock_key("github", uid)])
    :ok
  end

  defp lock_uid(_repo_host, _uid), do: :ok

  # Must match guard's derivation exactly - the two services claim the same
  # uids in the same database, so a different key would not exclude them.
  defp uid_lock_key(repo_host, uid) do
    <<key::signed-integer-64, _rest::binary>> = :crypto.hash(:sha256, "#{repo_host}:#{uid}")
    key
  end

  defp write_account({:ok, account}, _user_id, _repo_host, data, opts),
    do: update_existing_account(account, data, opts)

  defp write_account({:error, :not_found}, user_id, repo_host, data, _opts),
    do: create(data |> Map.merge(%{user_id: user_id, repo_host: repo_host}))

  # guard enforces one user per GitHub identity on its own write paths, but
  # rbac's OIDC signup is the main account-creation path on Enterprise and
  # reaches this function instead, so the same rule has to hold here or that
  # path still creates the duplicate.
  #
  # Only guard releases losing rows, so this refuses rather than claiming. A
  # revoked row stops blocking once it has been quiet for the same grace guard
  # uses, so a link latched revoked by a transient failure is not given away
  # while it may still self-heal.
  defp uid_actively_held_by_other?(_user_id, _repo_host, uid) when uid in [nil, ""], do: false

  defp uid_actively_held_by_other?(user_id, "github" = repo_host, uid) do
    from(r in __MODULE__,
      where: r.repo_host == ^repo_host and r.github_uid == ^uid,
      where: r.user_id != ^user_id,
      where:
        coalesce(r.revoked, false) == false or
          r.updated_at > ago(^@revoked_claim_grace_seconds, "second")
    )
    |> FrontRepo.exists?()
  end

  defp uid_actively_held_by_other?(_user_id, _repo_host, _uid), do: false

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
      Map.drop(data, [:permission_scope, :token, :refresh_token, :revoked])
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

  defp update_account(data, account) when data == %{},
    do: Logger.debug("Account for #{account.user_id} already up to date")

  defp update_account(data, account) do
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
          :permission_scope
        ]
      )
      |> Ecto.Changeset.validate_required([:github_uid, :login, :name, :permission_scope])

    result = FrontRepo.update(changeset)

    case result do
      {:ok, updated} ->
        Logger.info(
          "Successfully updated RepoHostAccount for #{updated.user_id} fields #{inspect(Map.keys(data))}"
        )

        {:ok, updated}

      {:error, error} ->
        Logger.error(
          "Failed to update RepoHostAccount for #{account.user_id} fields #{inspect(Map.keys(data))}: #{inspect(error.errors)}"
        )

        {:error, error}
    end
  end

  defp reset_account(account, data, reset: reset)
       when account.github_uid == data.github_uid or reset == false do
    Logger.debug(
      "Skipping reset account for #{account.user_id}, uid #{account.github_uid}, reset: #{reset}"
    )

    {:ok, account}
  end

  defp reset_account(account, data, _opts) do
    changeset =
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
          :permission_scope
        ]
      )
      |> Ecto.Changeset.validate_required([:github_uid, :login, :name])

    result = FrontRepo.update(changeset)

    case result do
      {:ok, updated} ->
        Logger.warning(
          "Successfully reset RepoHostAccount for #{updated.user_id}: " <>
            "uid #{account.github_uid} -> #{updated.github_uid}, " <>
            "login #{account.login} -> #{updated.login}"
        )

        {:ok, updated}

      {:error, error} ->
        Logger.error(
          "Failed to reset RepoHostAccount for #{account.user_id}: " <>
            "uid #{account.github_uid} -> #{Map.get(data, :github_uid)}, " <>
            "login #{account.login} -> #{Map.get(data, :login)}: #{inspect(error.errors)}"
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
end
