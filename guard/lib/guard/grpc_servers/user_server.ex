defmodule Guard.GrpcServers.UserServer do
  use GRPC.Server, service: InternalApi.User.UserService.Service

  require Logger

  import Guard.Utils, only: [grpc_error!: 2, valid_uuid?: 1, validate_uuid!: 1]
  import Guard.GrpcServers.Utils, only: [observe_and_log: 3]

  alias Guard.Store.User.Front
  alias Guard.FrontRepo
  alias Google.Protobuf.Timestamp
  alias InternalApi.{User, RepositoryIntegrator}

  @user_exchange "user_exchange"
  @updated_routing_key "updated"
  @deleted_routing_key "deleted"

  @spec describe(User.DescribeRequest.t(), GRPC.Server.Stream.t()) :: User.DescribeResponse.t()
  def describe(%User.DescribeRequest{user_id: user_id}, _stream) do
    observe_and_log("grpc.user.describe", %{user_id: user_id}, fn ->
      result = Front.fetch_user_with_repo_account_details(user_id)

      case result do
        nil ->
          grpc_error!(:not_found, "User with id #{user_id} not found")

        user ->
          User.DescribeResponse.new(user_describe_ok_response(user))
      end
    end)
  end

  @spec describe_by_email(
          User.DescribeByEmailRequest.t(),
          GRPC.Server.Stream.t()
        ) :: User.User.t()
  def describe_by_email(%User.DescribeByEmailRequest{email: email}, _stream) do
    observe_and_log("grpc.user.describe_by_email", %{email: email}, fn ->
      case Front.fetch_user_by_email(email) do
        nil -> grpc_error!(:not_found, "User not found.")
        user -> map_user(user)
      end
    end)
  end

  @spec describe_by_repository_provider(
          User.DescribeByRepositoryProviderRequest.t(),
          GRPC.Server.Stream.t()
        ) :: User.User.t()
  def describe_by_repository_provider(
        %User.DescribeByRepositoryProviderRequest{
          provider: %{
            uid: uid,
            type: type
          }
        },
        _stream
      ) do
    observe_and_log("grpc.user.describe_by_repository_provider", %{uid: uid, type: type}, fn ->
      result =
        Front.fetch_user_with_repository_provider(%{
          type: User.RepositoryProvider.Type.key(type),
          uid: uid
        })

      case result do
        nil -> grpc_error!(:not_found, "User not found.")
        user -> map_user(user)
      end
    end)
  end

  @spec search_users(User.SearchUsersRequest.t(), GRPC.Server.Stream.t()) ::
          User.SearchUsersResponse
  def search_users(%User.SearchUsersRequest{query: query, limit: limit}, _stream) do
    observe_and_log("grpc.user.search_users", %{query: query, limit: limit}, fn ->
      query = String.trim(query)
      limit = abs(limit)

      users =
        if query == "" or limit == 0 do
          []
        else
          Front.search_users_with_query(query, limit)
          |> Enum.map(&map_user/1)
        end

      User.SearchUsersResponse.new(users: users)
    end)
  end

  @spec describe_many(User.DescribeManyRequest.t(), GRPC.Server.Stream.t()) ::
          User.DescribeManyResponse.t()
  def describe_many(%User.DescribeManyRequest{user_ids: user_ids}, _stream) do
    observe_and_log("grpc.user.describe_many", %{user_ids: user_ids}, fn ->
      user_ids
      |> Enum.filter(&valid_uuid?/1)
      |> handle_describe_many_response()
    end)
  end

  @spec create_favorite(User.Favorite.t(), GRPC.Server.Stream.t()) ::
          User.Favorite.t()
  def create_favorite(
        %User.Favorite{
          user_id: user_id,
          organization_id: organization_id,
          favorite_id: favorite_id,
          kind: kind
        },
        _stream
      ) do
    observe_and_log(
      "grpc.user.create_favorite",
      %{user_id: user_id, organization_id: organization_id, favorite_id: favorite_id, kind: kind},
      fn ->
        kind =
          User.Favorite.Kind.key(kind)
          |> to_string()

        validate_uuid!(user_id)
        validate_uuid!(organization_id)
        validate_uuid!(favorite_id)

        case FrontRepo.Favorite.find_or_create(%{
               user_id: user_id,
               organization_id: organization_id,
               favorite_id: favorite_id,
               kind: kind
             }) do
          {:ok, favorite, :created} ->
            favorite_pb = map_favorite(favorite)
            Guard.Events.FavoriteCreated.publish(favorite_pb, @user_exchange)
            favorite_pb

          {:ok, favorite, :found} ->
            map_favorite(favorite)

          {:error, _changeset} ->
            grpc_error!(:invalid_argument, "Invalid favorite.")
        end
      end
    )
  end

  @spec delete_favorite(User.Favorite.t(), GRPC.Server.Stream.t()) :: User.Favorite.t()
  def delete_favorite(
        %User.Favorite{
          user_id: user_id,
          organization_id: organization_id,
          favorite_id: favorite_id,
          kind: kind
        },
        _stream
      ) do
    observe_and_log(
      "grpc.user.delete_favorite",
      %{user_id: user_id, organization_id: organization_id, favorite_id: favorite_id, kind: kind},
      fn ->
        kind =
          User.Favorite.Kind.key(kind)
          |> to_string()

        validate_uuid!(user_id)
        validate_uuid!(organization_id)
        validate_uuid!(favorite_id)

        favorite =
          FrontRepo.Favorite.find_by(%{
            user_id: user_id,
            organization_id: organization_id,
            favorite_id: favorite_id,
            kind: kind
          })

        if is_nil(favorite) do
          grpc_error!(:not_found, "Favorite not found.")
        end

        case FrontRepo.Favorite.delete_favorite(favorite) do
          {:ok, favorite} ->
            favorite_pb = map_favorite(favorite)
            Guard.Events.FavoriteDeleted.publish(favorite_pb, @user_exchange)
            favorite_pb

          {:error, _changeset} ->
            grpc_error!(:invalid_argument, "Invalid favorite.")
        end
      end
    )
  end

  @spec list_favorites(User.ListFavoritesRequest.t(), GRPC.Server.Stream.t()) ::
          User.ListFavoritesResponse.t()
  def list_favorites(
        %User.ListFavoritesRequest{user_id: user_id, organization_id: organization_id},
        _stream
      ) do
    observe_and_log(
      "grpc.user.list_favorites",
      %{user_id: user_id, organization_id: organization_id},
      fn ->
        validate_uuid!(user_id)
        if organization_id != "", do: validate_uuid!(organization_id)

        favorites =
          FrontRepo.Favorite.list_favorite_by_user_id(user_id, organization_id: organization_id)

        User.ListFavoritesResponse.new(favorites: Enum.map(favorites, &map_favorite/1))
      end
    )
  end

  @spec block_account(User.BlockAccountRequest.t(), GRPC.Server.Stream.t()) ::
          User.User.t()
  def block_account(%User.BlockAccountRequest{user_id: user_id}, _stream) do
    observe_and_log("grpc.user.block_account", %{user_id: user_id}, fn ->
      result = FrontRepo.User.active_user_by_id(user_id)

      case result do
        {:error, _} -> grpc_error!(:not_found, "User: #{user_id} not found")
        {:ok, user} -> handle_block_user(user)
      end
    end)
  end

  @spec unblock_account(User.UnblockAccountRequest.t(), GRPC.Server.Stream.t()) ::
          User.User.t()
  def unblock_account(%User.UnblockAccountRequest{user_id: user_id}, _stream) do
    observe_and_log("grpc.user.unblock_account", %{user_id: user_id}, fn ->
      result = FrontRepo.User.blocked_user_by_id(user_id)

      case result do
        {:error, _} -> grpc_error!(:not_found, "User: #{user_id} not found")
        {:ok, user} -> handle_unblock_user(user)
      end
    end)
  end

  @spec refresh_repository_provider(
          User.RefreshRepositoryProviderRequest.t(),
          GRPC.Server.Stream.t()
        ) :: User.RefreshRepositoryProviderResponse.t()
  def refresh_repository_provider(
        %User.RefreshRepositoryProviderRequest{user_id: user_id, type: type},
        _stream
      ) do
    observe_and_log(
      "grpc.user.refresh_repository_provider",
      %{user_id: user_id, type: type},
      fn ->
        validate_uuid!(user_id)

        user =
          case Front.find(user_id) do
            {:error, :not_found} -> grpc_error!(:not_found, "User #{user_id} not found.")
            {:ok, user} -> user
          end

        provider =
          User.RepositoryProvider.Type.key(type)
          |> to_string()
          |> String.downcase()

        case FrontRepo.RepoHostAccount.get_for_user_by_repo_host(user.id, provider) do
          {:error, :not_found} ->
            Logger.error("User #{user_id} not found")
            grpc_error!(:not_found, "User not found.")

          {:ok, account} ->
            handle_update_repo_status(user, account)
        end
      end
    )
  end

  @spec update(User.UpdateRequest.t(), GRPC.Server.Stream.t()) :: User.UpdateResponse.t()
  def update(%User.UpdateRequest{user: user}, _stream) do
    observe_and_log("grpc.user.update", %{user: user}, fn ->
      if is_nil(user) do
        grpc_error!(:invalid_argument, "Invalid user.")
      end

      validate_uuid!(user.id)

      old_email =
        case Front.find(user.id) do
          {:error, :not_found} -> grpc_error!(:not_found, "User #{user.id} not found.")
          {:ok, user} -> user.email
        end

      case Front.update(user.id, %{
             name: user.name,
             email: user.email,
             company: user.company
           }) do
        {:ok, existing_user} ->
          Guard.Events.UserUpdated.publish(user.id, @user_exchange, @updated_routing_key)
          Guard.Events.WorkEmailAdded.publish(existing_user, old_email, @user_exchange)
          status = Google.Rpc.Status.new(code: Google.Rpc.Code.value(:OK))
          User.UpdateResponse.new(user: map_simple_user(existing_user), status: status)

        {:error, :user_not_found} ->
          grpc_error!(:not_found, "User #{user.id} not found.")

        {:error, _changeset} ->
          grpc_error!(:invalid_argument, "Invalid user.")
      end
    end)
  end

  @spec delete_with_owned_orgs(
          User.DeleteWithOwnedOrgsRequest.t(),
          GRPC.Server.Stream.t()
        ) :: User.User.t()
  def delete_with_owned_orgs(%User.DeleteWithOwnedOrgsRequest{user_id: user_id}, _stream) do
    observe_and_log("grpc.user.delete_with_owned_orgs", %{user_id: user_id}, fn ->
      validate_uuid!(user_id)

      case Front.find(user_id) do
        {:error, :not_found} ->
          Logger.info("User: #{user_id} already doesn't exist")
          User.User.new(id: user_id)

        {:ok, user} ->
          if Guard.Api.Project.user_has_any_project?(user_id) do
            grpc_error!(:invalid_argument, "User #{user_id} is owner of projects.")
          end

          handle_delete_with_owned_orgs(user.id)
      end
    end)
  end

  @spec create(User.CreateRequest.t(), GRPC.Server.Stream.t()) :: User.User.t()
  def create(
        %User.CreateRequest{
          email: email,
          name: name,
          password: password,
          repository_providers: providers,
          skip_password_change: skip_password_change
        },
        _stream
      ) do
    observe_and_log(
      "grpc.user.create",
      %{
        email: email,
        name: name,
        password: password,
        repository_providers: providers,
        skip_password_change: skip_password_change
      },
      fn ->
        case Guard.User.Actions.create(%{
               email: email,
               name: name,
               password: password,
               repository_providers: providers,
               skip_password_change: skip_password_change
             }) do
          {:ok, user} ->
            Front.fetch_user_with_repo_account_details(user.id)
            |> map_user()

          {:error, errors} ->
            Logger.error("Failed to create user: #{inspect(errors)}")
            grpc_error!(:invalid_argument, "Failed to create user")
        end
      end
    )
  end

  # ---------------------
  # Helper functions
  # ---------------------

  defp handle_update_repo_status(user, account) do
    {token, _expires_at} = get_token(account, user_id: user.id)

    account_update_result = handle_validate_token(user, account, token)

    repository_provider =
      case account_update_result do
        {:ok, updated_account} ->
          map_provider(updated_account)

        {:error, _} ->
          grpc_error!(:internal, "Error while updating repository provider for #{user.id}.")

        # Account already up to date
        _ ->
          map_provider(account)
      end

    User.RefreshRepositoryProviderResponse.new(
      user_id: user.id,
      repository_provider: repository_provider
    )
  end

  defp handle_validate_token(user, repo_account, token) do
    validation_result =
      case repo_account.repo_host do
        "github" -> Guard.Api.Github.validate_token(token)
        "bitbucket" -> Guard.Api.Bitbucket.validate_token(token)
        "gitlab" -> Guard.Api.Gitlab.validate_token(token)
        _ -> grpc_error!(:invalid_argument, "Invalid repository provider.")
      end

    case validation_result do
      {:ok, is_valid} ->
        Logger.info(
          "Token for #{user.id} is #{if is_valid, do: "valid", else: "invalid"}. Updating revoke status."
        )

        FrontRepo.RepoHostAccount.update_revoke_status(repo_account, not is_valid)

      {:error, _} ->
        grpc_error!(:internal, "Error while validating token for #{user.id}.")
    end
  end

  defp handle_delete_with_owned_orgs(user_id) do
    case Front.delete_with_owned_orgs(user_id) do
      {:ok, _} ->
        Guard.Events.UserDeleted.publish(user_id, @user_exchange, @deleted_routing_key)
        User.User.new(id: user_id)

      {:error, _} ->
        message = "Error while deleting user: #{user_id}"
        Logger.error(message)
        grpc_error!(:internal, message)
    end
  end

  defp handle_block_user(user) do
    case FrontRepo.User.block_user(user) do
      {:ok, user} ->
        map_simple_user(user)

      {:error, error} ->
        Logger.error("Exception while blocking user '#{user.id}': #{inspect(error)}")
        grpc_error!(:internal, "Exception while blocking user '#{user.id}'")
    end
  end

  defp handle_unblock_user(user) do
    case FrontRepo.User.unblock_user(user) do
      {:ok, user} ->
        map_simple_user(user)

      {:error, error} ->
        Logger.error("Exception while unblocking user '#{user.id}': #{inspect(error)}")
        grpc_error!(:internal, "Exception while unblocking user '#{user.id}'")
    end
  end

  defp map_simple_user(user) do
    repo_account =
      case FrontRepo.RepoHostAccount.get_for_github_user(user.id) do
        {:ok, account} -> account
        {:error, _} -> nil
      end

    params = %{
      id: user.id,
      avatar_url: Guard.Avatar.default_provider_avatar(),
      name: user.name,
      company: user.company || "",
      email: user.email,
      blocked_at: grpc_timestamp(user.blocked_at)
    }

    params =
      if repo_account do
        avatar_url =
          provider_avatar(%{
            uid: repo_account.github_uid || "",
            provider: "github"
          })

        Map.merge(params, %{
          github_uid: repo_account.github_uid || "",
          github_login: repo_account.login || "",
          avatar_url: avatar_url
        })
      else
        params
      end

    User.User.new(params)
  end

  defp map_favorite(favorite) do
    kind =
      favorite.kind
      |> String.upcase()
      |> String.to_atom()
      |> User.Favorite.Kind.value()

    User.Favorite.new(
      user_id: favorite.user_id,
      favorite_id: favorite.favorite_id,
      kind: kind,
      organization_id: favorite.organization_id
    )
  end

  defp handle_describe_many_response([]) do
    code = InternalApi.ResponseStatus.Code.value(:OK)
    status = InternalApi.ResponseStatus.new(code: code)

    User.DescribeManyResponse.new(
      status: status,
      users: []
    )
  end

  defp handle_describe_many_response(user_ids) do
    users = Front.fetch_users_with_repo_account_details(user_ids)
    code = InternalApi.ResponseStatus.Code.value(:OK)
    status = InternalApi.ResponseStatus.new(code: code)

    User.DescribeManyResponse.new(
      status: status,
      users: Enum.map(users, &map_user/1)
    )
  end

  defp user_describe_ok_response(user) do
    providers = Map.get(user, :providers, [])
    github = Enum.find(providers, fn p -> p["provider"] == "github" end)
    bitbucket = Enum.find(providers, fn p -> p["provider"] == "bitbucket" end)

    first =
      if github do
        github
      else
        Enum.min_by(providers, fn p -> p["created_at"] end, fn -> %{} end)
      end

    parsed_first = for {key, val} <- first, into: %{}, do: {String.to_atom(key), val}

    avatar_url = provider_avatar(parsed_first)

    code = InternalApi.ResponseStatus.Code.value(:OK)
    status = InternalApi.ResponseStatus.new(code: code)

    params = %{
      status: status,
      user_id: user.id,
      name: user.name || "",
      email: user.email || "",
      avatar_url: avatar_url,
      created_at: grpc_timestamp(user.created_at),
      company: user.company || "",
      blocked_at: grpc_timestamp(user.blocked_at),
      repository_providers: Enum.map(providers, &map_provider/1),
      repository_scopes:
        User.RepositoryScopes.new(
          github: repository_scope(github),
          bitbucket: repository_scope(bitbucket)
        ),
      user: map_user(user)
    }

    inject_github_info(params, github)
  end

  defp inject_github_info(params, github_info) do
    if github_info do
      params
      |> Map.merge(%{
        github_token: github_info["token"] || "",
        github_scope: github_scope(github_info["scope"] || "", github_info["revoked"] || false),
        github_uid: github_info["uid"] || "",
        github_login: github_info["login"] || ""
      })
    else
      params
    end
  end

  defp repository_scope(nil), do: nil

  defp repository_scope(%{"login" => login, "uid" => uid, "scope" => scope, "revoked" => revoked}) do
    User.RepositoryScopes.RepositoryScope.new(
      scope: scope(scope, revoked),
      login: to_string(login),
      uid: to_string(uid)
    )
  end

  defp scope(scope, revoked) do
    alias User.RepositoryScopes.RepositoryScope.Scope

    cond do
      revoked || is_nil(scope) -> Scope.value(:NONE)
      String.starts_with?(scope, "repo") -> Scope.value(:PRIVATE)
      String.starts_with?(scope, "public_repo") -> Scope.value(:PUBLIC)
      true -> Scope.value(:EMAIL)
    end
  end

  defp github_scope(scope, revoked) do
    alias InternalApi.User.DescribeResponse.RepoScope

    cond do
      revoked || is_nil(scope) ->
        RepoScope.value(:NONE)

      String.starts_with?(scope, "repo") ->
        RepoScope.value(:PRIVATE)

      String.starts_with?(scope, "public_repo") ->
        RepoScope.value(:PUBLIC)

      true ->
        RepoScope.value(:NONE)
    end
  end

  defp map_user(user) do
    providers = Map.get(user, :providers, [])
    github = Enum.find(providers, fn p -> p["provider"] == "github" end)

    first =
      if github do
        github
      else
        Enum.min_by(providers, fn p -> p["created_at"] end, fn -> %{} end)
      end

    parsed_first =
      if first do
        for {key, val} <- first, into: %{}, do: {String.to_atom(key), val}
      else
        nil
      end

    avatar_url = provider_avatar(parsed_first)

    params = %{
      id: user.id,
      name: user.name,
      company: user[:company] || "",
      avatar_url: avatar_url,
      email: user.email,
      blocked_at: grpc_timestamp(user[:blocked_at]),
      created_at: grpc_timestamp(user[:created_at]),
      visited_at: grpc_timestamp(user[:visited_at]),
      repository_providers: Enum.map(providers, &map_provider/1),
      single_org_user: user[:single_org_user] || false,
      org_id: user[:org_id] || "",
      creation_source: map_creation_source(user),
      deactivated: user[:deactivated] || false
    }

    User.User.new(params)
  end

  defp map_creation_source(user) do
    case user[:creation_source] do
      :okta -> User.User.CreationSource.value(:OKTA)
      :service_account -> User.User.CreationSource.value(:SERVICE_ACCOUNT)
      _ -> User.User.CreationSource.value(:NOT_SET)
    end
  end

  defp map_provider(%FrontRepo.RepoHostAccount{} = rha) do
    User.RepositoryProvider.new(
      type: provider_type(rha.repo_host),
      scope: provider_scope(rha.permission_scope || "", rha.revoked || false),
      login: rha.login || "",
      uid: rha.github_uid || ""
    )
  end

  defp map_provider(provider) do
    User.RepositoryProvider.new(
      type: provider_type(provider["provider"]),
      scope: provider_scope(provider["scope"] || "", provider["revoked"] || false),
      login: to_string(provider["login"]),
      uid: to_string(provider["uid"])
    )
  end

  defp provider_avatar(provider) do
    if provider && provider != %{} do
      Guard.Avatar.avatar_by_provider(provider.uid, provider.provider)
    else
      Guard.Avatar.default_provider_avatar()
    end
  end

  defp provider_type(provider) do
    case provider do
      "github" -> User.RepositoryProvider.Type.value(:GITHUB)
      "bitbucket" -> User.RepositoryProvider.Type.value(:BITBUCKET)
      "gitlab" -> User.RepositoryProvider.Type.value(:GITLAB)
      _ -> User.RepositoryProvider.Type.value(:GITHUB)
    end
  end

  defp provider_scope(scope, revoked) do
    alias User.RepositoryProvider.Scope

    cond do
      revoked || String.trim(scope) == "" -> Scope.value(:NONE)
      String.starts_with?(scope, "repo") -> Scope.value(:PRIVATE)
      String.starts_with?(scope, "public_repo") -> Scope.value(:PUBLIC)
      true -> Scope.value(:EMAIL)
    end
  end

  @spec get_repository_token(User.GetRepositoryTokenRequest.t(), GRPC.Stream.t()) ::
          User.GetRepositoryTokenResponse.t()
  def get_repository_token(
        %User.GetRepositoryTokenRequest{user_id: user_id, integration_type: integration_type},
        _stream
      ) do
    observe_and_log(
      "grpc.user.get_repository_token",
      %{user_id: user_id, integration_type: integration_type},
      fn ->
        parsed_integration_type = RepositoryIntegrator.IntegrationType.key(integration_type)
        check_integration!(parsed_integration_type)

        user =
          case Front.find(user_id) do
            {:error, :not_found} -> grpc_error!(:not_found, "User not found.")
            {:ok, user} -> user
          end

        provider = get_provider(parsed_integration_type)

        repo_host_account =
          case FrontRepo.RepoHostAccount.get_for_user_by_repo_host(user.id, provider) do
            {:error, :not_found} ->
              Logger.error(
                "Integration for User: '#{user.id}' and '#{parsed_integration_type}' not found."
              )

              grpc_error!(:not_found, "Integration '#{parsed_integration_type}' not found.")

            {:ok, account} ->
              account
          end

        {token, expires_at} = get_token(repo_host_account, user_id: user_id)

        User.GetRepositoryTokenResponse.new(token: token, expires_at: grpc_timestamp(expires_at))
      end
    )
  end

  @spec regenerate_token(User.RegenerateTokenRequest.t(), GRPC.Stream.t()) ::
          User.RegenerateTokenResponse.t()
  def regenerate_token(%User.RegenerateTokenRequest{user_id: user_id}, _stream) do
    observe_and_log("grpc.user.regenerate_token", %{user_id: user_id}, fn ->
      validate_uuid!(user_id)

      user =
        case Front.find(user_id) do
          {:error, :not_found} -> grpc_error!(:not_found, "User '#{user_id}' not found")
          {:ok, user} -> user
        end

      case FrontRepo.User.reset_auth_token(user) do
        {:ok, new_token} ->
          User.RegenerateTokenResponse.new(
            status: Google.Rpc.Status.new(code: Google.Rpc.Code.value(:OK)),
            api_token: new_token
          )

        {:error, message} ->
          grpc_error!(:resource_exhausted, message)
      end
    end)
  end

  defp get_token(%{repo_host: "github"} = repo_host_account, user_id: user_id) do
    case FrontRepo.RepoHostAccount.get_github_token(repo_host_account) do
      {:error, _} ->
        Logger.error("Token for User: '#{user_id}' and 'GITHUB' not found.")
        grpc_error!(:not_found, "Token for not found.")

      {:ok, {token, expires_at}} ->
        {token, expires_at}
    end
  end

  defp get_token(%{repo_host: "bitbucket"} = repo_host_account, user_id: user_id) do
    case FrontRepo.RepoHostAccount.get_bitbucket_token(repo_host_account) do
      {:error, _} ->
        Logger.error("Token for User: '#{user_id}' and 'BITBUCKET' not found.")
        grpc_error!(:not_found, "Token for not found.")

      {:ok, {token, expires_at}} ->
        {token, expires_at}
    end
  end

  defp get_token(%{repo_host: "gitlab"} = repo_host_account, user_id: user_id) do
    case FrontRepo.RepoHostAccount.get_gitlab_token(repo_host_account) do
      {:error, _} ->
        Logger.error("Token for User: '#{user_id}' and 'GITLAB' not found.")
        grpc_error!(:not_found, "Token for not found.")

      {:ok, {token, expires_at}} ->
        {token, expires_at}
    end
  end

  defp get_token(_repo_host_account, user_id: user_id) do
    not_found_message = "Token for User: '#{user_id}' not found."
    Logger.error(not_found_message)
    grpc_error!(:not_found, not_found_message)
  end

  defp check_integration!(integration_type) do
    unless integration_type_supported?(integration_type) do
      error_message = "Integration Type: '#{integration_type}' is not supported."
      Logger.error(error_message)
      grpc_error!(:invalid_argument, error_message)
    end
  end

  defp get_provider(:GITLAB), do: "gitlab"
  defp get_provider(:BITBUCKET), do: "bitbucket"
  defp get_provider(:GITHUB_OAUTH_TOKEN), do: "github"
  defp get_provider(_), do: ""

  defp integration_type_supported?(:GITHUB_APP), do: false
  defp integration_type_supported?(_), do: true

  defp grpc_timestamp(nil), do: nil

  defp grpc_timestamp(%DateTime{} = value) do
    unix_timestamp =
      value
      |> DateTime.to_unix(:second)

    Timestamp.new(seconds: unix_timestamp)
  end

  defp grpc_timestamp(value) when is_number(value) do
    Timestamp.new(seconds: value)
  end

  defp grpc_timestamp(_), do: nil
end
