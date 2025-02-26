defmodule Front.Models.User do
  use Ecto.Schema

  require Logger

  @fields [
    :id,
    :name,
    :avatar_url,
    :email,
    :company,
    :created_at,
    :github_scope,
    :github_login,
    :github_uid,
    :bitbucket_scope,
    :bitbucket_login,
    :bitbucket_uid,
    :gitlab_scope,
    :gitlab_login,
    :gitlab_uid
  ]

  @required_fields [:name]
  @cache_prefix "user-v1-"

  @cacheble_fields %{
    :name => :timer.minutes(60),
    :email => :timer.minutes(60),
    :company => :timer.minutes(60),
    :created_at => :timer.minutes(60)
  }

  embedded_schema do
    field(:email, :string)
    field(:name, :string)
    field(:avatar_url, :string)
    field(:created_at, :string)
    field(:company, :string)
    field(:github_scope, :string)
    field(:github_login, :string)
    field(:github_uid, :string)
    field(:bitbucket_scope, :string)
    field(:bitbucket_login, :string)
    field(:bitbucket_uid, :string)
    field(:gitlab_scope, :string)
    field(:gitlab_login, :string)
    field(:gitlab_uid, :string)

    field(:single_org_user, :boolean)
    field(:org_id, :string)
  end

  def find_with_opts(id, opts \\ []) when is_list(opts) do
    Watchman.benchmark("fetch_user.duration", fn ->
      metadata = Keyword.get(opts, :metadata, nil)
      fields = Keyword.get(opts, :fields, @fields)
      use_cache = Keyword.get(opts, :use_cache, true)
      organization_id = Keyword.get(opts, :organization_id, "")

      find_(id, metadata, fields, use_cache, organization_id: organization_id)
    end)
  end

  def find(id, metadata \\ nil, fields \\ @fields, use_cache \\ true, opts \\ []) do
    Watchman.benchmark("fetch_user.duration", fn ->
      find_(id, metadata, fields, use_cache, opts)
    end)
  end

  defp find_(id, metadata, fields, true, opts) do
    cache_keys = Enum.map(fields, fn f -> cache_key(id, f) end)

    case Front.Cache.get_all(cache_keys) do
      {:ok, values} ->
        user = Enum.zip(fields, values)

        struct!(__MODULE__, user)

      {:not_cached, _} ->
        find(id, metadata, fields, false, opts)
    end
  end

  defp find_(id, metadata, _fields, false, opts) do
    alias InternalApi.User.UserService.Stub
    req = InternalApi.User.DescribeRequest.new(user_id: id)

    {:ok, channel} = build_user_channel(opts)

    case Stub.describe(channel, req, metadata: metadata, timeout: 30_000) do
      {:ok, res} ->
        user = construct_from_describe(res)

        Enum.each(@cacheble_fields, fn {f, timeout} ->
          Front.Cache.set(cache_key(id, f), Map.get(user, f), timeout)
        end)

        user

      {:error, msg} ->
        Logger.info("[User Model] Error while fetching user #{inspect(msg)}")
        nil
    end
  end

  def find_user_with_providers(user_id, organization_id \\ nil) do
    alias Front.Async

    fetch_user = Async.run(fn -> find(user_id) end)

    fetch_github_provider =
      Async.run(fn -> refresh_repository_provider(user_id, "github", organization_id) end)

    fetch_bb_provider =
      Async.run(fn -> refresh_repository_provider(user_id, "bitbucket", organization_id) end)

    fetch_gitlab_provider =
      Async.run(fn -> refresh_repository_provider(user_id, "gitlab", organization_id) end)

    {:ok, user} = Async.await(fetch_user)
    {:ok, github_provider} = Async.await(fetch_github_provider)
    {:ok, bitbucket_provider} = Async.await(fetch_bb_provider)
    {:ok, gitlab_provider} = Async.await(fetch_gitlab_provider)

    user
    |> merge_provider(github_provider, "github")
    |> merge_provider(bitbucket_provider, "bitbucket")
    |> merge_provider(gitlab_provider, "gitlab")
  end

  def star(user_id, organization_id, favorite_id, kind, metadata \\ nil) do
    Watchman.benchmark("create_favorite.duration", fn ->
      kind =
        kind
        |> String.upcase()
        |> String.to_atom()
        |> InternalApi.User.Favorite.Kind.value()

      favorite =
        InternalApi.User.Favorite.new(
          user_id: user_id,
          organization_id: organization_id,
          favorite_id: favorite_id,
          kind: kind
        )

      {:ok, channel} = build_user_channel(organization_id: organization_id)

      {:ok, _} =
        InternalApi.User.UserService.Stub.create_favorite(channel, favorite,
          metadata: metadata,
          timeout: 30_000
        )
    end)
  end

  def unstar(user_id, organization_id, favorite_id, kind, metadata \\ nil) do
    Watchman.benchmark("delete_favorite.duration", fn ->
      kind =
        kind
        |> String.upcase()
        |> String.to_atom()
        |> InternalApi.User.Favorite.Kind.value()

      favorite =
        InternalApi.User.Favorite.new(
          user_id: user_id,
          organization_id: organization_id,
          favorite_id: favorite_id,
          kind: kind
        )

      {:ok, channel} = build_user_channel(organization_id: organization_id)

      {:ok, _} =
        InternalApi.User.UserService.Stub.delete_favorite(channel, favorite,
          metadata: metadata,
          timeout: 30_000
        )
    end)
  end

  def list_favorites(user_id, organization_id, metadata \\ nil) do
    Watchman.benchmark("list_favorites.duration", fn ->
      request =
        InternalApi.User.ListFavoritesRequest.new(
          user_id: user_id,
          organization_id: organization_id
        )

      {:ok, channel} = build_user_channel(organization_id: organization_id)

      {:ok, response} =
        InternalApi.User.UserService.Stub.list_favorites(channel, request,
          metadata: metadata,
          timeout: 30_000
        )

      response.favorites
    end)
  end

  def find_many(ids, tracing_headers \\ nil, organization_id \\ nil) do
    Watchman.benchmark("fetch_many_users.duration", fn ->
      request = InternalApi.User.DescribeManyRequest.new(user_ids: ids)

      Logger.debug("Sending request to User API")
      Logger.debug(inspect(request))

      {:ok, channel} = build_user_channel(organization_id: organization_id)

      {:ok, response} =
        InternalApi.User.UserService.Stub.describe_many(channel, request,
          metadata: tracing_headers,
          timeout: 30_000
        )

      Logger.debug("Received response for describe many from User API")
      Logger.debug(inspect(response))

      if response.status.code == InternalApi.ResponseStatus.Code.value(:OK) do
        construct_many(response)
      else
        nil
      end
    end)
  end

  def update(user, fields, metadata \\ nil, organization_id \\ nil) do
    alias Front.Form.RequiredParams, as: RP
    alias Google.Rpc.Status
    alias InternalApi.User.UpdateRequest, as: UpdateRequest
    alias InternalApi.User.UpdateResponse, as: UpdateResponse
    alias InternalApi.User.User, as: ApiUser

    Watchman.benchmark("update_user.duration", fn ->
      changeset = RP.create_changeset(fields, @required_fields, %__MODULE__{})

      with true <- changeset.valid?,
           req <-
             UpdateRequest.new(
               user:
                 ApiUser.new(
                   id: user.id,
                   email: user.email,
                   company: user.company,
                   name: fields[:name]
                 )
             ),
           {:ok, channel} <- build_user_channel(organization_id: organization_id),
           {:ok, res = %UpdateResponse{status: %Status{code: 0}}} <-
             InternalApi.User.UserService.Stub.update(channel, req,
               metadata: metadata,
               timeout: 30_000
             ) do
        {:ok, construct(res.user)}
      else
        false ->
          {:error, changeset}

        {:error, error} ->
          Logger.error("Updating user failed with: #{inspect(error)}")

          {:error, parse_error_response_message(user.id, "Updating user failed")}

        {:ok, response} ->
          {:error, parse_error_response_message(user.id, response.status.message)}
      end
    end)
  end

  def regenerate_token(user_id, metadata \\ nil, organization_id \\ nil) do
    Watchman.benchmark("regenerate_token.duration", fn ->
      req = InternalApi.User.RegenerateTokenRequest.new(user_id: user_id)

      {:ok, channel} = build_user_channel(organization_id: organization_id)

      {:ok, res} =
        InternalApi.User.UserService.Stub.regenerate_token(channel, req,
          metadata: metadata,
          timeout: 30_000
        )

      if res.status.code == Google.Rpc.Code.value(:OK) do
        {:ok, res.api_token}
      else
        {:error, res.status.message}
      end
    end)
  end

  def check_github_token(user_id, metadata \\ nil) do
    Watchman.benchmark("check_github_token.duration", fn ->
      alias InternalApi.User.UserService.Stub

      req = InternalApi.User.CheckGithubTokenRequest.new(user_id: user_id)

      {:ok, channel} = GRPC.Stub.connect(Application.fetch_env!(:front, :user_grpc_endpoint))

      case Stub.check_github_token(channel, req, metadata: metadata, timeout: 30_000) do
        {:ok, res} ->
          {:ok, %{revoked: res.revoked, private: res.repo, public: res.public_repo}}

        {:error, error} ->
          {:error, error}
      end
    end)
  end

  defp refresh_repository_provider(user_id, provider, organization_id) do
    Watchman.benchmark("refresh_repository_provider.duration", fn ->
      alias InternalApi.User.UserService.Stub

      type =
        provider
        |> String.upcase()
        |> String.to_atom()
        |> InternalApi.User.RepositoryProvider.Type.value()

      req =
        InternalApi.User.RefreshRepositoryProviderRequest.new(
          user_id: user_id,
          type: type
        )

      {:ok, channel} = build_user_channel(organization_id: organization_id)

      case Stub.refresh_repository_provider(channel, req, timeout: 30_000) do
        {:ok, res} ->
          res.repository_provider

        {:error, error} ->
          Logger.error(
            "Refresh reposiotry provider failed with error: #{user_id}, #{provider} #{inspect(error)}"
          )

          nil
      end
    end)
  end

  def construct(raw_user) do
    alias InternalApi.User.RepositoryProvider.Type

    user = %__MODULE__{
      :id => raw_user.id,
      :name => raw_user.name,
      :avatar_url => raw_user.avatar_url,
      :company => raw_user.company,
      :email => raw_user.email,
      :single_org_user => raw_user.single_org_user,
      :org_id => raw_user.org_id
    }

    github = Enum.find(raw_user.repository_providers, fn rp -> Type.key(rp.type) == :GITHUB end)

    bitbucket =
      Enum.find(raw_user.repository_providers, fn rp -> Type.key(rp.type) == :BITBUCKET end)

    gitlab = Enum.find(raw_user.repository_providers, fn rp -> Type.key(rp.type) == :GITLAB end)

    user
    |> merge_provider(github, "github")
    |> merge_provider(bitbucket, "bitbucket")
    |> merge_provider(gitlab, "gitlab")
  end

  defp construct_many(response) do
    response.users
    |> Enum.map(fn raw ->
      construct(raw)
    end)
  end

  alias InternalApi.User.RepositoryProvider

  def construct_from_describe(user) do
    alias InternalApi.User.RepositoryProvider.Type

    data = %__MODULE__{
      :id => user.user_id,
      :name => user.name,
      :avatar_url => user.avatar_url,
      :email => user.email,
      :company => user.company,
      :created_at => user.created_at.seconds,
      :single_org_user => user.user.single_org_user,
      :org_id => user.user.org_id
    }

    github = Enum.find(user.repository_providers, fn rp -> Type.key(rp.type) == :GITHUB end)
    bitbucket = Enum.find(user.repository_providers, fn rp -> Type.key(rp.type) == :BITBUCKET end)
    gitlab = Enum.find(user.repository_providers, fn rp -> Type.key(rp.type) == :GITLAB end)

    data
    |> merge_provider(github, "github")
    |> merge_provider(bitbucket, "bitbucket")
    |> merge_provider(gitlab, "gitlab")
  end

  def merge_provider(user, provider, prefix) do
    provider_map = provider |> map_provider()

    merge_with_prefix(user, provider_map, prefix)
  end

  defp merge_with_prefix(map1, map2, prefix) do
    map2 = Enum.map(map2, fn {k, v} -> {:"#{prefix}_#{k}", v} end) |> Map.new()

    Map.merge(map1, map2)
  end

  defp map_provider(provider) do
    %{
      :scope => map_repository_provider_scope(provider),
      :login => map_repository_provider_login(provider),
      :uid => map_repository_provider_uid(provider)
    }
  end

  defp map_repository_provider_scope(nil), do: :NONE
  defp map_repository_provider_scope(provider), do: RepositoryProvider.Scope.key(provider.scope)

  defp map_repository_provider_login(nil), do: nil
  defp map_repository_provider_login(provider), do: provider.login

  defp map_repository_provider_uid(nil), do: nil
  defp map_repository_provider_uid(provider), do: provider.uid

  def has_favorite(user_id, org_id, favorite_id) do
    list_favorites(user_id, org_id)
    |> Enum.any?(fn f -> f.favorite_id == favorite_id end)
  end

  defp cache_key(id, field) do
    "#{@cache_prefix}-#{id}-#{field}"
  end

  defp parse_error_response_message(user_id, msg) do
    if msg =~ "name" do
      %{errors: %{name: msg}}
    else
      Watchman.increment("user.update.failed")

      Logger.error(
        "User update failed with unprocessed error in form: #{user_id}, #{inspect(msg)}"
      )

      %{errors: %{other: msg}}
    end
  end

  def build_user_channel(opts \\ []) do
    organization_id = Keyword.get(opts, :organization_id, "") || ""

    cond do
      organization_id == "" ->
        GRPC.Stub.connect(Application.fetch_env!(:front, :user_grpc_endpoint))

      FeatureProvider.feature_enabled?(:use_new_user_api, param: organization_id) ->
        GRPC.Stub.connect(Application.fetch_env!(:front, :guard_user_grpc_endpoint))

      true ->
        GRPC.Stub.connect(Application.fetch_env!(:front, :user_grpc_endpoint))
    end
  end
end
