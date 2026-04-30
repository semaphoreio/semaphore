defmodule Front.DashboardPage.Model do
  use TypedStruct

  @cache_prefix "dashboard_page_model"
  @cache_version :crypto.hash(:md5, File.read(__ENV__.file) |> elem(1)) |> Base.encode64()
  @cache_ttl Application.compile_env(:front, :dashboard_page_cache_ttl, :timer.minutes(15))
  @index_ttl_seconds div(@cache_ttl * 2, 1000)

  @cache_and_track_script """
  redis.call('SET', KEYS[1], ARGV[1], 'PX', ARGV[2])
  redis.call('SADD', KEYS[2], ARGV[3])
  redis.call('EXPIRE', KEYS[2], ARGV[4])
  redis.call('SADD', KEYS[3], ARGV[5])
  redis.call('EXPIRE', KEYS[3], ARGV[4])
  return 1
  """

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
          (-> {:ok, list(), String.t(), String.t()} | {:error, any()}),
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
          cache_and_track(params, encode(payload))
        end

        {:ok, payload, :from_api}

      error ->
        error
    end
  end

  defp cacheable?(params), do: (params.page_token || "") == ""
  defp force_cold_boot?(opts), do: opts[:force_cold_boot] in [true, "true"]

  defp cache_and_track(params, encoded_payload) do
    case cacheman_state() do
      %{backend_pid: backend_pid, prefix: prefix} ->
        key = cache_key(params)

        redis_command(backend_pid, [
          "EVAL",
          @cache_and_track_script,
          "3",
          prefix <> key,
          prefix <> org_key_set_key(params.organization_id),
          prefix <> all_orgs_set_key(),
          encoded_payload,
          to_string(@cache_ttl),
          key,
          to_string(@index_ttl_seconds),
          params.organization_id
        ])

      _ ->
        :ok
    end
  end

  defp org_key_set_key(org_id) do
    "#{cache_prefix()}/#{cache_version()}/index/org=#{org_id}"
  end

  defp all_orgs_set_key do
    "#{cache_prefix()}/#{cache_version()}/index/all_orgs"
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
