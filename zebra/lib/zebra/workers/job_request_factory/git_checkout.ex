defmodule Zebra.Workers.JobRequestFactory.GitCheckout do
  @moduledoc """
  Handles resilient git checkout configuration for jobs.

  When the :git_clone_slow_retry feature is enabled for an organization,
  this module adds the SEMAPHORE_GIT_CLONE_SLOW_RETRY environment variable,
  which opts the toolbox `checkout` into slow-clone detection and resilient
  retry (speed monitoring, retries, and alternative-endpoint fallback).

  The toolbox keeps sensible defaults for the tuning knobs
  (threshold/timeout/grace/retries), so only the on/off switch is injected
  here; the feature is a no-op in the toolbox when this var is absent.
  """

  alias Zebra.Workers.JobRequestFactory.JobRequest

  @doc """
  Returns environment variables for resilient git checkout.

  If the :git_clone_slow_retry feature is enabled for the organization,
  adds SEMAPHORE_GIT_CLONE_SLOW_RETRY=true to enable it.
  """
  def env_vars(org_id) do
    if FeatureProvider.feature_enabled?(:git_clone_slow_retry, param: org_id) do
      [JobRequest.env_var("SEMAPHORE_GIT_CLONE_SLOW_RETRY", "true")]
    else
      []
    end
  end
end
