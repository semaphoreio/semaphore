defmodule CanvasFront.Models.User do
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

      find_(id, metadata, fields, use_cache)
    end)
  end

  def find(id, metadata \\ nil, fields \\ @fields, use_cache \\ true) do
    Watchman.benchmark("fetch_user.duration", fn ->
      find_(id, metadata, fields, use_cache)
    end)
  end

  defp find_(id, metadata, fields, true) do
    cache_keys = Enum.map(fields, fn f -> cache_key(id, f) end)

    case CanvasFront.Cache.get_all(cache_keys) do
      {:ok, values} ->
        user = Enum.zip(fields, values)

        struct!(__MODULE__, user)

      {:not_cached, _} ->
        find(id, metadata, fields, false)
    end
  end

  defp find_(id, metadata, _fields, false) do
    alias InternalApi.User.UserService.Stub
    req = %InternalApi.User.DescribeRequest{user_id: id}

    {:ok, channel} = channel()

    case Stub.describe(channel, req, metadata: metadata, timeout: 30_000) do
      {:ok, res} ->
        user = construct(res)

        Enum.each(@cacheble_fields, fn {f, timeout} ->
          CanvasFront.Cache.set(cache_key(id, f), Map.get(user, f), timeout)
        end)

        user

      {:error, msg} ->
        Logger.info("[User Model] Error while fetching user #{inspect(msg)}")
        nil
    end
  end

  def construct(user) do
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

    github = Enum.find(user.repository_providers, fn rp -> rp.type == :GITHUB end)
    bitbucket = Enum.find(user.repository_providers, fn rp -> rp.type == :BITBUCKET end)
    gitlab = Enum.find(user.repository_providers, fn rp -> rp.type == :GITLAB end)

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
  defp map_repository_provider_scope(provider), do: provider.scope

  defp map_repository_provider_login(nil), do: nil
  defp map_repository_provider_login(provider), do: provider.login

  defp map_repository_provider_uid(nil), do: nil
  defp map_repository_provider_uid(provider), do: provider.uid

  defp cache_key(id, field) do
    "#{@cache_prefix}-#{id}-#{field}"
  end

  def channel do
    GRPC.Stub.connect(Application.fetch_env!(:canvas_front, :guard_user_grpc_endpoint))
  end
end
