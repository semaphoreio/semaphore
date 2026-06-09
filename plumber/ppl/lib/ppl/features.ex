defmodule Ppl.Features do
  @moduledoc """
  Organization feature-flag checks used by plumber.

  Thin wrapper around `FeatureProvider` so feature names live in one place and
  call sites stay readable. All checks fail closed: an empty organization id or
  any error reaching the Feature service results in `false`.
  """

  @sparse_checkout_init_job "sparse_checkout_init_job"

  @doc """
  Whether the initialization (compilation) job may use the optimized blobless +
  sparse checkout for the given organization.
  """
  @spec sparse_checkout_init_job_enabled?(String.t() | nil) :: boolean()
  def sparse_checkout_init_job_enabled?(org_id) when is_binary(org_id) and org_id != "" do
    FeatureProvider.feature_enabled?(@sparse_checkout_init_job, param: org_id)
  end

  def sparse_checkout_init_job_enabled?(_org_id), do: false
end
