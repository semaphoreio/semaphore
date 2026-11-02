defmodule Zebra.Workers.JobRequestFactory.Settings do
  @moduledoc """
  Concurrency settings for the job request factory, read once at boot.

  Each setting comes from an environment variable. A missing or empty value
  falls back to the default, and anything that isn't a positive integer
  stops the boot with an error naming the variable.

  Every in-flight job holds a DB connection for its whole transaction, and
  the pool is shared with the other workers in the pod. Parallelism is
  lowered to leave at least two connections for them.
  """

  require Logger

  @defaults %{parallelism: 10, records_per_tick: 100, process_timeout: 15_000}

  @env_vars %{
    parallelism: "JOB_REQUEST_FACTORY_PARALLELISM",
    records_per_tick: "JOB_REQUEST_FACTORY_RECORDS_PER_TICK",
    process_timeout: "JOB_REQUEST_FACTORY_PROCESS_TIMEOUT_MS"
  }

  @reserved_connections 2

  def load! do
    config = Application.get_env(:zebra, Zebra.Workers.JobRequestFactory, [])
    pool_size = Application.fetch_env!(:zebra, Zebra.LegacyRepo)[:pool_size]

    settings =
      Map.new(@defaults, fn {key, default} ->
        {key, parse!(@env_vars[key], Keyword.get(config, key), default)}
      end)

    configured = settings.parallelism
    parallelism = fit_to_pool(configured, pool_size)

    if parallelism != configured do
      Logger.warning(
        "job_request_factory: parallelism #{configured} lowered to #{parallelism} " <>
          "for a DB pool of #{pool_size}"
      )
    end

    %{settings | parallelism: parallelism}
  end

  @doc """
  Parses a raw environment value. nil and blank values return the default.
  """
  def parse!(_name, nil, default), do: default
  def parse!(_name, value, _default) when is_integer(value) and value > 0, do: value

  def parse!(name, value, default) when is_binary(value) do
    case String.trim(value) do
      "" ->
        default

      trimmed ->
        case Integer.parse(trimmed) do
          {n, ""} when n > 0 -> n
          _ -> invalid!(name, value)
        end
    end
  end

  def parse!(name, value, _default), do: invalid!(name, value)

  @doc """
  Lowers parallelism so the factory leaves connections for the other workers
  in the pod, without going below 1.
  """
  def fit_to_pool(parallelism, pool_size) do
    parallelism |> min(pool_size - @reserved_connections) |> max(1)
  end

  defp invalid!(name, value) do
    raise ArgumentError, "#{name} must be a positive integer, got: #{inspect(value)}"
  end
end
