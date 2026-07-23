defmodule Rbac.FrontRepo.RepoHostAccount do
  use Ecto.Schema

  require Logger

  import Ecto.Query

  alias Rbac.FrontRepo

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

  @uid_taken_message "is already connected to another Semaphore user"

  # A revoked link is not claimable until it has been revoked for this long.
  # `revoked` is written by token-health checks, so a transient upstream
  # failure can briefly mark a healthy link revoked; the grace period gives it
  # time to self-heal or be reconnected before another user can claim (and
  # thereby delete) it. `updated_at` approximates the revocation time: it is
  # bumped when the flag flips and revoked rows receive no further writes.
  @revoked_claim_grace_seconds 2 * 60 * 60

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
    field(:token, :string)
    field(:refresh_token, :string)
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
      |> validate_github_uid_not_taken()
      |> FrontRepo.insert()

    case result do
      {:ok, account} ->
        release_revoked_uid_rows(account)

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
          | {:error, :invalid_data | Ecto.Changeset.t()}
  def update_repo_host_account(user_id, _, %{github_uid: uid, login: login} = data, _opts)
      when is_nil(uid) or is_nil(login) do
    Logger.error("Cannot update RepoHostAccount for #{user_id} with data #{inspect(data)}")

    {:error, :invalid_data}
  end

  def update_repo_host_account(user_id, repo_host, data, opts) do
    data = data |> adjust_scope(user_id)
    repo_host = repo_host |> Atom.to_string()

    Logger.debug(
      "Updating RepoHostAccount for #{user_id} with data #{inspect(data)} and opts #{inspect(opts)} #{inspect(repo_host)}"
    )

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

  @doc """
  Returns true when the changeset failed because the GitHub account is
  already connected to another user.
  """
  @spec uid_taken_error?(term()) :: boolean()
  def uid_taken_error?(%Ecto.Changeset{errors: errors}) do
    Enum.any?(errors, fn
      {:github_uid, {_msg, opts}} -> opts[:validation] == :unsafe_unique
      _ -> false
    end)
  end

  def uid_taken_error?(_), do: false

  # A GitHub identity may be actively linked to at most one user. Revoked
  # links don't block a claim — they are deleted once the claim succeeds
  # (see release_revoked_uid_rows/1), otherwise the old owner reconnecting
  # would revive the row and recreate the duplicate. The row being changed
  # is excluded, so reconnecting the same account for the same user stays
  # valid.
  defp validate_github_uid_not_taken(changeset) do
    repo_host = Ecto.Changeset.get_field(changeset, :repo_host)
    uid = Ecto.Changeset.get_field(changeset, :github_uid)

    if repo_host == "github" and uid not in [nil, ""] and
         uid_actively_held_by_other?(changeset, repo_host, uid) do
      Ecto.Changeset.add_error(changeset, :github_uid, @uid_taken_message,
        validation: :unsafe_unique
      )
    else
      changeset
    end
  end

  # Re-activating a revoked link must re-check uniqueness: another user may
  # have actively linked the same account while this row sat revoked. Only a
  # real true→false transition is checked — writes that don't flip `revoked`
  # (token refreshes, profile syncs) stay unchecked, so rows that already
  # share a uid keep working.
  defp maybe_validate_uid_on_unrevoke(changeset) do
    if unrevoke_transition?(changeset) do
      validate_github_uid_not_taken(changeset)
    else
      changeset
    end
  end

  defp unrevoke_transition?(changeset) do
    Ecto.Changeset.get_change(changeset, :revoked) == false and changeset.data.revoked == true
  end

  defp uid_actively_held_by_other?(changeset, repo_host, uid) do
    query =
      from(r in __MODULE__,
        where: r.repo_host == ^repo_host and r.github_uid == ^uid,
        where:
          coalesce(r.revoked, false) == false or
            r.updated_at > ago(^@revoked_claim_grace_seconds, "second")
      )

    query =
      case changeset.data.id do
        nil -> query
        id -> from(r in query, where: r.id != ^id)
      end

    FrontRepo.exists?(query)
  end

  defp release_revoked_uid_rows(%__MODULE__{repo_host: "github"} = account) do
    {count, released_user_ids} =
      from(r in __MODULE__,
        where: r.repo_host == ^account.repo_host and r.github_uid == ^account.github_uid,
        where: r.id != ^account.id,
        where: r.revoked == true,
        where: r.updated_at <= ago(^@revoked_claim_grace_seconds, "second"),
        select: r.user_id
      )
      |> FrontRepo.delete_all()

    if count > 0 do
      Watchman.increment({"rbac.repo_host_account.revoked_link_claimed", [account.repo_host]})

      Logger.info(
        "Released #{count} revoked repo_host_account row(s) for github uid #{account.github_uid} claimed by user #{account.user_id} from users #{inspect(released_user_ids)}"
      )

      Rbac.OIDC.FederatedIdentitySync.sync_github_claim(account, released_user_ids)
    end

    account
  end

  defp release_revoked_uid_rows(account), do: account

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
      |> maybe_validate_uid_on_unrevoke()

    unrevoke? = unrevoke_transition?(changeset)
    result = FrontRepo.update(changeset)

    case result do
      {:ok, account} ->
        account = if unrevoke?, do: release_revoked_uid_rows(account), else: account

        Logger.info(
          "Successfully updated RepoHostAccount for #{account.user_id} from #{inspect(account)} to #{inspect(data)}"
        )

        {:ok, account}

      {:error, error} ->
        Logger.error(
          "Failed to update RepoHostAccount for #{account.user_id} from #{inspect(account)} to #{inspect(data)} #{inspect(error)}"
        )

        {:error, error}
    end
  end

  defp reset_account(account, data, reset: reset)
       when account.github_uid == data.github_uid or reset == false do
    Logger.debug(
      "Skipping reset account for #{account.user_id} from #{inspect(account)} to #{inspect(data)}"
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
          :permission_scope
        ]
      )
      |> Ecto.Changeset.validate_required([:github_uid, :login, :name])
      |> validate_github_uid_not_taken()
      |> FrontRepo.update()

    case result do
      {:ok, account} ->
        release_revoked_uid_rows(account)

        Logger.warning(
          "Successfully reset RepoHostAccount for #{account.user_id} from #{inspect(account)} to #{inspect(data)}"
        )

        {:ok, account}

      {:error, error} ->
        Logger.error(
          "Failed to reset RepoHostAccount for #{account.user_id} from #{inspect(account)} to #{inspect(data)} #{inspect(error)}"
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
