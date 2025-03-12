defmodule Guard.Store.User do
  require Logger
  import Ecto.Query, only: [where: 3]
  import Guard.Utils, only: [valid_uuid?: 1]

  defmodule Front do
    alias Ecto.Changeset
    alias Guard.FrontRepo, as: Repo
    import Ecto.Query

    def fetch_user_with_repo_account_details(user_id) when is_binary(user_id) do
      user =
        if valid_uuid?(user_id) do
          get_user_with_repo_account_details_by_id(user_id)
        else
          get_user_with_repo_account_details_by_login_and_host(user_id, "github")
        end

      normalize_providers(user)
    end

    def fetch_users_with_repo_account_details(user_ids) when is_list(user_ids) do
      get_users_with_repo_account_details_by_id(user_ids)
      |> Enum.map(&normalize_providers/1)
    end

    def fetch_user_by_email(email) do
      get_user_with_repo_account_details_by_email(email)
      |> normalize_providers()
    end

    def fetch_user_with_repository_provider(provider) do
      repo_host =
        provider.type
        |> to_string()
        |> String.downcase()

      user = get_user_by_provider_uid(provider.uid, repo_host)

      normalize_providers(user)
    end

    def search_users_with_query(query, limit) do
      users =
        if valid_uuid?(query) do
          [get_user_with_repo_account_details_by_id(query)]
        else
          search_users_by_query_and_limit(query, limit)
        end

      users |> Enum.map(&normalize_providers/1)
    end

    defp search_users_by_query_and_limit(query, limit) do
      search_query = "%#{query}%"

      subquery =
        from(rha in Repo.RepoHostAccount,
          where: ilike(rha.login, ^search_query),
          select: rha.user_id
        )

      build_full_front_user_query()
      |> join(:left, [u], r in Repo.RepoHostAccount, on: u.id == r.user_id)
      |> where(
        [u, _r],
        u.id in subquery(subquery) or ilike(u.email, ^search_query) or
          ilike(u.name, ^search_query)
      )
      |> select_merge_json_providers()
      |> order_by([u, _r], u.id)
      |> limit(^limit)
      |> Repo.all()
    end

    defp get_user_by_provider_uid(provider_uid, repo_host) do
      subquery =
        from(rha in Repo.RepoHostAccount,
          where: rha.github_uid == ^provider_uid and rha.repo_host == ^repo_host,
          select: rha.user_id,
          limit: 1
        )

      build_full_front_user_query()
      |> join(:inner, [u], r in Repo.RepoHostAccount, on: u.id == r.user_id)
      |> where([u, r], u.id == subquery(subquery))
      |> select_merge_json_providers()
      |> Repo.one()
    end

    defp get_user_with_repo_account_details_by_id(user_id) do
      build_full_front_user_query()
      |> join(:left, [u], r in Repo.RepoHostAccount, on: u.id == r.user_id)
      |> select_merge_json_providers()
      |> where([u], u.id == ^user_id)
      |> Repo.one()
    end

    defp get_user_with_repo_account_details_by_email(email) do
      build_full_front_user_query()
      |> join(:left, [u], r in Repo.RepoHostAccount, on: u.id == r.user_id)
      |> select_merge_json_providers()
      |> where([u], u.email == ^email)
      |> Repo.one()
    end

    defp get_users_with_repo_account_details_by_id(user_ids) do
      build_full_front_user_query()
      |> join(:left, [u], r in Repo.RepoHostAccount, on: u.id == r.user_id)
      |> select_merge_json_providers()
      |> where([u, _r], u.id in ^user_ids)
      |> order_by([u, _r], asc: u.id)
      |> Repo.all()
    end

    defp get_user_with_repo_account_details_by_login_and_host(login, repo_host) do
      subquery =
        from(rha in Repo.RepoHostAccount,
          where: rha.login == ^login and rha.repo_host == ^repo_host,
          select: rha.user_id,
          limit: 1
        )

      build_full_front_user_query()
      |> join(:inner, [u], r in Repo.RepoHostAccount, on: u.id == r.user_id)
      # Bind subquery correctly to `u.id`
      |> where([u, r], u.id == subquery(subquery))
      |> select_merge_json_providers()
      |> Repo.one()
    end

    defp build_full_front_user_query do
      from(u in Repo.User,
        group_by: u.id,
        select: %{
          id: u.id,
          name: u.name,
          email: u.email,
          created_at: u.created_at,
          company: u.company,
          authentication_token: u.authentication_token,
          blocked_at: u.blocked_at,
          visited_at: u.visited_at,
          deactivated: u.deactivated,
          single_org_user: u.single_org_user,
          org_id: u.org_id,
          creation_source: u.creation_source
        }
      )
    end

    defp select_merge_json_providers(query) do
      query
      |> select_merge([_u, r], %{
        providers:
          fragment(
            "json_agg(jsonb_build_object('uid', ?, 'token', ?, 'login', ?, 'scope', ?, 'revoked', ?, 'provider', ?, 'created_at', ?))",
            r.github_uid,
            r.token,
            r.login,
            r.permission_scope,
            r.revoked,
            r.repo_host,
            r.created_at
          )
      })
    end

    defp normalize_providers(nil), do: nil

    defp normalize_providers(user) do
      Map.update(user, :providers, [], fn providers ->
        providers
        |> Enum.reject(fn p -> Map.get(p, "uid") == nil end)
      end)
    end

    def find(user_id) do
      case Repo.get(Repo.User, user_id) do
        nil -> {:error, :not_found}
        user -> {:ok, user}
      end
    end

    def find_by_email(email) do
      case Repo.User |> where([u], u.email == ^email) |> Repo.one() do
        nil -> {:error, :not_found}
        user -> {:ok, user}
      end
    end

    def find_by_idempotency_token(idempotency_token) do
      case Repo.User |> where([u], u.idempotency_token == ^idempotency_token) |> Repo.one() do
        nil -> {:error, :not_found}
        user -> {:ok, user}
      end
    end

    def add_idempotency_token(user_id, idempotency_token) do
      Repo.User
      |> where([u], u.id == ^user_id)
      |> Repo.update_all(set: [idempotency_token: idempotency_token])
    end

    def create(params) do
      changeset = Repo.User.changeset(%Repo.User{}, params)

      case Repo.insert(changeset) do
        {:ok, u} ->
          {:ok, u}

        {:error, changeset} ->
          {:error, changeset.errors}
      end
    end

    @spec update(String.t(), map()) ::
            {:ok, Repo.User.t()}
            | {:error, :user_not_found}
            | {:error, :internal_error}
            | {:error, [{atom(), Changeset.error()}]}
    def update(user_id, params) do
      user = Repo.get!(Repo.User, user_id)
      user = Repo.User.changeset(user, params)

      case Repo.update(user) do
        {:ok, u} ->
          {:ok, u}

        {:error, changeset} ->
          {:error, changeset.errors}
      end
    rescue
      _ in Ecto.NoResultsError ->
        {:error, :user_not_found}

      e ->
        Logger.error("Error during user update #{inspect(user_id)} error: #{inspect(e)}")

        {:error, :internal_error}
    end

    def unblock(user_id) do
      {:ok, _} = __MODULE__.update(user_id, %{blocked_at: nil})
    end

    def delete_with_owned_orgs(user_id) do
      result =
        Ecto.Multi.new()
        |> Ecto.Multi.run(:get_user, fn repo, _changes ->
          case repo.get(Repo.User, user_id) do
            nil -> {:error, :user_not_found}
            user -> {:ok, user}
          end
        end)
        |> Ecto.Multi.run(:delete_related_data, fn repo, _changes ->
          from(o in Repo.Organization, where: o.creator_id == ^user_id)
          |> repo.all()
          |> Enum.each(fn org ->
            :ok = Guard.Api.Project.destroy_all_projects_by_org_id(org.id)

            repo.delete_all(from(m in Repo.Member, where: m.organization_id == ^org.id))

            repo.delete_all(
              from(s in Repo.OrganizationSuspension, where: s.organization_id == ^org.id)
            )

            repo.delete_all(
              from(c in Repo.OrganizationContact, where: c.organization_id == ^org.id)
            )
          end)

          {:ok, :deleted_related_data}
        end)
        |> Ecto.Multi.delete_all(:delete_organizations, fn _changes ->
          from(o in Repo.Organization, where: o.creator_id == ^user_id)
        end)
        |> Ecto.Multi.delete(:delete_user, fn %{get_user: user} -> user end)
        |> Repo.transaction()

      case result do
        {:ok, _changes} -> {:ok, :deleted}
        {:error, :get_user, :user_not_found, _changes} -> {:error, :user_not_found}
        _ -> {:error, :internal_error}
      end
    end
  end

  alias Guard.Repo
  import Ecto.Query

  def find(user_id) do
    Watchman.benchmark("store_find_user.duration", fn ->
      case Repo.User |> where(user_id: ^user_id) |> Repo.one() do
        nil ->
          nil

        user ->
          %{
            user_id: user.user_id,
            github_token: nil,
            github_uid: user.github_uid,
            provider: user.provider
          }
      end
    end)
  end

  def remove_provider(user_id, provider, provider_id) do
    from(
      u in Repo.User,
      where: u.user_id == ^user_id and u.provider == ^provider and u.github_uid == ^provider_id
    )
    |> Repo.delete_all()
  end

  def remove_provider(provider, provider_id) do
    from(
      u in Repo.User,
      where: u.provider == ^provider and u.github_uid == ^provider_id
    )
    |> Repo.delete_all()
  end

  def add_provider(user_id, provider, provider_id) do
    changeset =
      Repo.User.changeset(%Repo.User{}, %{
        user_id: user_id,
        provider: provider,
        github_uid: provider_id
      })

    case Repo.insert(changeset) do
      {:ok, u} ->
        {:ok, u}

      e ->
        e
    end
  end

  def fetch_providers(user_id) do
    from(
      u in Repo.User,
      where: u.user_id == ^user_id
    )
    |> select([u], %{type: u.provider, uid: u.github_uid})
    |> Repo.all()
  end

  def update(user_id, provider, provider_id, "none"),
    do: remove_provider(user_id, provider, provider_id)

  def update(user_id, provider, provider_id, _), do: add_provider(user_id, provider, provider_id)

  def update(user_data) do
    changes = %{
      user_id: user_data.id,
      github_uid: user_data.github_uid
    }

    result =
      case Repo.get_by(Repo.User, user_id: user_data.id) do
        nil -> %Repo.User{user_id: user_data.id}
        user -> user
      end
      |> Repo.User.changeset(changes)
      |> Repo.insert_or_update()

    case result do
      {:ok, u} -> {:ok, u}
      e -> e
    end
  end

  def find_id_by_provider_uid(provider_uid, provider) do
    case Repo.User
         |> where(github_uid: ^provider_uid, provider: ^provider)
         |> select([:user_id])
         |> last(:inserted_at)
         |> Repo.one() do
      nil -> nil
      one -> one.user_id
    end
  end
end
