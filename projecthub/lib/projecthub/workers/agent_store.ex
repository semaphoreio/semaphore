defmodule Projecthub.Workers.AgentStore do
  use Agent

  @type cache_key :: any()
  @type cache_value :: any()
  @type cache_entry :: {cache_value(), DateTime.t()}
  @type cache_name :: atom()

  @type store :: %{
          items: %{
            (cache_key :: any()) => cache_value :: any()
          }
        }

  @type option :: {:name, cache_name()}
  @type start_opts :: [option()]

  @type cache_result :: :not_found | {:expired, cache_value()} | cache_value()

  @spec start_link(start_opts()) :: Agent.on_start()
  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    initial_state = Keyword.get(opts, :initial_state, %{})

    zero_state = %{
      items: initial_state
    }

    Agent.start_link(fn -> zero_state end, name: name)
  end

  @spec get(cache_name(), cache_key()) :: cache_result()
  def get(cache_name \\ __MODULE__, key, opts \\ []) do
    store = Agent.get(cache_name, & &1)
    item_ttl_ms = Keyword.get(opts, :item_ttl_ms, :timer.minutes(15))

    find_value(store, key, item_ttl_ms)
  end

  @spec store(cache_name(), cache_key(), cache_value()) :: cache_value()
  def store(cache_name \\ __MODULE__, key, value) do
    Agent.update(cache_name, fn store ->
      store
      |> Map.put(:items, Map.put(store.items, key, {value, DateTime.utc_now()}))
    end)

    value
  end

  @spec find_value(store(), cache_key(), non_neg_integer()) :: cache_result()
  defp find_value(store, key, item_ttl_ms) do
    store
    |> Map.get(:items, %{})
    |> Map.get(key, :not_found)
    |> case do
      :not_found ->
        :not_found

      {item, fetched_at} ->
        now = DateTime.utc_now()

        if DateTime.diff(now, fetched_at, :millisecond) >= item_ttl_ms do
          {:expired, item}
        else
          item
        end
    end
  end
end
