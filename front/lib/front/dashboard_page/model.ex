defmodule Front.DashboardPage.Model do
  use TypedStruct

  @cache_prefix "dashboard_page_model"
  @cache_version :crypto.hash(:md5, File.read(__ENV__.file) |> elem(1)) |> Base.encode64()
  @cache_ttl Application.compile_env(:front, :dashboard_page_cache_ttl, :timer.minutes(15))
  @index_ttl_seconds div(@cache_ttl * 2, 1000)

  @invalidate_org_script """
  local members = redis.call('SMEMBERS', KEYS[1])
  for _, member in ipairs(members) do
    redis.call('DEL', ARGV[2] .. member)
  end
  redis.call('DEL', KEYS[1])
  redis.call('SREM', KEYS[2], ARGV[1])
  return #members
  """

  defmodule LoadParams do
    use TypedStruct

    typedstruct do
      field(:organization_id, String.t(), enforce: true)
      field(:user_id, String.t(), enforce: true)
      field(:requester, boolean(), default: false)
      field(:project_ids_fingerprint, String.t(), default: "")
      field(:page_token, String.t(), default: "")
      field(:direction, String.t(), default: "")
    end
  end

  def encode(model), do: :erlang.term_to_binary(model)
  def decode(model), do: Plug.Crypto.non_executable_binary_to_term(model, [:safe])

  def cache_prefix, do: @cache_prefix
  def cache_version, do: @cache_version

  @spec get(
          LoadParams.t(),
          (() -> {:ok, list(), String.t(), String.t()} | {:error, any()}),
          keyword()
        ) ::
          {:ok, {list(), String.t(), String.t()}, :from_cache | :from_api} | {:error, any()}
  def get(params, fetch_fun, opts \\ []) when is_function(fetch_fun, 0) do
    if force_cold_boot?(opts) do
      Watchman.increment({"dashboard_page_model.cache.miss", []})
      fetch_and_maybe_cache(params, fetch_fun)
    else
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
  end

  @spec cache_key(LoadParams.t()) :: String.t()
  def cache_key(params) do
    [
      cache_prefix(),
      cache_version(),
      "organization_id=#{params.organization_id}",
      "user_id=#{params.user_id}",
      "requester=#{params.requester}",
      "project_ids_fingerprint=#{params.project_ids_fingerprint || ""}"
    ]
    |> Enum.join("/")
    |> Kernel.<>("/")
  end

  @spec invalidate_org(String.t()) :: :ok
  def invalidate_org(org_id) when is_binary(org_id) do
    case cacheman_state() do
      %{backend_pid: backend_pid, prefix: prefix} ->
        org_set = prefix <> org_key_set_key(org_id)
        all_orgs = prefix <> all_orgs_set_key()

        redis_command(backend_pid, [
          "EVAL",
          @invalidate_org_script,
          "2",
          org_set,
          all_orgs,
          org_id,
          prefix
        ])

      _ ->
        :ok
    end

    :ok
  end

  @spec invalidate_all() :: :ok
  def invalidate_all do
    all_orgs_set_key()
    |> smembers()
    |> Enum.each(&invalidate_org/1)

    delete_redis_key(all_orgs_set_key())
    :ok
  end

  # Private

  defp fetch_and_maybe_cache(params, fetch_fun) do
    case fetch_fun.() do
      {:ok, workflows, next_page_token, previous_page_token} ->
        payload = {workflows, next_page_token, previous_page_token}

        if cacheable?(params) do
          Cacheman.put(:front, cache_key(params), encode(payload), ttl: @cache_ttl)
          track_cache_key(params.organization_id, cache_key(params))
        end

        {:ok, payload, :from_api}

      error ->
        error
    end
  end

  defp cacheable?(params), do: (params.page_token || "") == ""
  defp force_cold_boot?(opts), do: opts[:force_cold_boot] in [true, "true"]

  defp track_cache_key(org_id, cache_key) do
    sadd(org_key_set_key(org_id), cache_key)
    expire(org_key_set_key(org_id), @index_ttl_seconds)
    sadd(all_orgs_set_key(), org_id)
    expire(all_orgs_set_key(), @index_ttl_seconds)
  end

  defp org_key_set_key(org_id) do
    "#{cache_prefix()}/#{cache_version()}/index/org=#{org_id}"
  end

  defp all_orgs_set_key do
    "#{cache_prefix()}/#{cache_version()}/index/all_orgs"
  end

  defp sadd(set_key, member) do
    case cacheman_state() do
      %{backend_pid: backend_pid, prefix: prefix} ->
        redis_command(backend_pid, ["SADD", prefix <> set_key, member])

      _ ->
        :ok
    end
  end

  defp smembers(set_key) do
    case cacheman_state() do
      %{backend_pid: backend_pid, prefix: prefix} ->
        case redis_command(backend_pid, ["SMEMBERS", prefix <> set_key]) do
          {:ok, members} -> members
          _ -> []
        end

      _ ->
        []
    end
  end

  defp expire(set_key, ttl_seconds) do
    case cacheman_state() do
      %{backend_pid: backend_pid, prefix: prefix} ->
        redis_command(backend_pid, ["EXPIRE", prefix <> set_key, to_string(ttl_seconds)])

      _ ->
        :ok
    end
  end

  defp delete_redis_key(key) do
    case cacheman_state() do
      %{backend_pid: backend_pid, prefix: prefix} ->
        redis_command(backend_pid, ["DEL", prefix <> key])

      _ ->
        :ok
    end
  end

  defp cacheman_state do
    :sys.get_state(Cacheman.full_process_name(:front))
  rescue
    _ -> nil
  end

  defp redis_command(backend_pid, command) do
    :poolboy.transaction(backend_pid, fn conn ->
      Redix.command(conn, command)
    end)
  end
end
