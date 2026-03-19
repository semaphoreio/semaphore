defmodule Front.DashboardPage.Model do
  use TypedStruct

  @cache_prefix "dashboard_page_model"
  @cache_version :crypto.hash(:md5, File.read(__ENV__.file) |> elem(1)) |> Base.encode64()
  @registry_orgs_suffix "registry/org_ids"
  @cache_ttl Application.compile_env(:front, :dashboard_page_cache_ttl, :timer.minutes(5))

  defmodule LoadParams do
    use TypedStruct

    typedstruct do
      field(:organization_id, String.t(), enforce: true)
      field(:user_id, String.t(), enforce: true)
      field(:requester, boolean(), default: false)
      field(:page_token, String.t(), default: "")
      field(:direction, String.t(), default: "")
    end
  end

  def encode(model), do: :erlang.term_to_binary(model)
  def decode(model), do: Plug.Crypto.non_executable_binary_to_term(model, [:safe])

  def cache_prefix, do: @cache_prefix
  def cache_version, do: @cache_version

  @spec get(LoadParams.t(), (() -> {:ok, list(), String.t(), String.t()} | {:error, any()})) ::
          {:ok, {list(), String.t(), String.t()}, :from_cache | :from_api} | {:error, any()}
  def get(params, fetch_fun) when is_function(fetch_fun, 0) do
    if cacheable?(params) do
      case Cacheman.get(:front, cache_key(params)) do
        {:ok, nil} ->
          Watchman.increment({"dashboard_page_model.cache.miss", []})
          fetch_and_maybe_cache(params, fetch_fun)

        {:ok, cached} ->
          Watchman.increment({"dashboard_page_model.cache.hit", []})
          {:ok, decode(cached), :from_cache}

        _ ->
          Watchman.increment({"dashboard_page_model.cache.miss", []})
          fetch_and_maybe_cache(params, fetch_fun)
      end
    else
      fetch_and_maybe_cache(params, fetch_fun)
    end
  end

  @spec cache_key(LoadParams.t()) :: String.t()
  def cache_key(params) do
    [
      cache_prefix(),
      cache_version(),
      "organization_id=#{params.organization_id}",
      "user_id=#{params.user_id}",
      "requester=#{params.requester}"
    ]
    |> Enum.join("/")
    |> Kernel.<>("/")
  end

  @spec invalidate_org(String.t()) :: :ok
  def invalidate_org(org_id) when is_binary(org_id) do
    registry_key = org_registry_key(org_id)

    registry_key
    |> read_registry_values()
    |> Enum.each(fn cache_key ->
      Cacheman.delete(:front, cache_key)
    end)

    Cacheman.delete(:front, registry_key)
    remove_org_from_registry(org_id)

    :ok
  end

  @spec invalidate_all() :: :ok
  def invalidate_all do
    global_orgs_registry_key()
    |> read_registry_values()
    |> Enum.each(&invalidate_org/1)

    Cacheman.delete(:front, global_orgs_registry_key())
    :ok
  end

  # Private

  defp fetch_and_maybe_cache(params, fetch_fun) do
    case fetch_fun.() do
      {:ok, workflows, next_page_token, previous_page_token} ->
        payload = {workflows, next_page_token, previous_page_token}

        if cacheable?(params) do
          Cacheman.put(:front, cache_key(params), encode(payload), ttl: @cache_ttl)
          store_registry_entries(params.organization_id, cache_key(params))
        end

        {:ok, payload, :from_api}

      error ->
        error
    end
  end

  defp cacheable?(params), do: (params.page_token || "") == ""

  defp org_registry_key(org_id) do
    "#{cache_prefix()}/#{cache_version()}/registry/org_id=#{org_id}"
  end

  defp global_orgs_registry_key do
    "#{cache_prefix()}/#{cache_version()}/#{@registry_orgs_suffix}"
  end

  defp store_registry_entries(org_id, cache_key) do
    org_cache_keys =
      org_registry_key(org_id)
      |> read_registry_values()
      |> List.insert_at(0, cache_key)
      |> Enum.uniq()

    global_org_ids =
      global_orgs_registry_key()
      |> read_registry_values()
      |> List.insert_at(0, org_id)
      |> Enum.uniq()

    Cacheman.put(:front, org_registry_key(org_id), encode(org_cache_keys))
    Cacheman.put(:front, global_orgs_registry_key(), encode(global_org_ids))
  end

  defp remove_org_from_registry(org_id) do
    org_ids =
      global_orgs_registry_key()
      |> read_registry_values()
      |> Enum.reject(fn id -> id == org_id end)

    if Enum.empty?(org_ids) do
      Cacheman.delete(:front, global_orgs_registry_key())
    else
      Cacheman.put(:front, global_orgs_registry_key(), encode(org_ids))
    end
  end

  defp read_registry_values(key) do
    case Cacheman.get(:front, key) do
      {:ok, nil} ->
        []

      {:ok, values} ->
        decode(values)

      _ ->
        []
    end
  end
end
