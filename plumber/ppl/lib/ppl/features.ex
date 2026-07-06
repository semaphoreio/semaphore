defmodule Ppl.Features do
  @moduledoc """
  Organization feature-flag checks used by plumber.

  Thin wrapper around `FeatureProvider` so feature names live in one place and
  call sites stay readable. All checks fail closed: an empty organization id or
  any error reaching the Feature service results in `false`.

  The boolean result is memoized for a short time in the `:feature_cache` Cachex
  instance. `FeatureProvider` only caches successful provider responses, so
  without this a `feature-hub` outage would make every pipeline initialization
  pay the gRPC timeout. Caching the (fail-closed) result briefly keeps a blip
  from repeatedly stalling the init path.
  """

  require Logger

  @sparse_checkout_init_job "sparse_checkout_init_job"

  @cache :feature_cache
  @result_ttl_ms :timer.seconds(30)

  @doc """
  Whether the initialization (compilation) job may use the optimized blobless +
  sparse checkout for the given organization.
  """
  @spec sparse_checkout_init_job_enabled?(String.t() | nil) :: boolean()
  def sparse_checkout_init_job_enabled?(org_id) when is_binary(org_id) and org_id != "" do
    cached_result(@sparse_checkout_init_job, org_id, fn ->
      FeatureProvider.feature_enabled?(@sparse_checkout_init_job, param: org_id)
    end)
  end

  def sparse_checkout_init_job_enabled?(_org_id), do: false

  # Memoize the boolean result (including the fail-closed false) for a short TTL.
  # On any cache error we fall back to evaluating directly, so caching can never
  # make the check less available than the bare provider call.
  defp cached_result(feature, org_id, fun) do
    key = {:ppl_features, feature, org_id}

    case Cachex.get(@cache, key) do
      {:ok, nil} ->
        result = fun.()
        Cachex.put(@cache, key, result, ttl: @result_ttl_ms)
        result

      {:ok, cached} ->
        cached

      other ->
        Logger.warning("Ppl.Features cache read failed for #{inspect(key)}: #{inspect(other)}")
        fun.()
    end
  end
end
