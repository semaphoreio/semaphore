defmodule Zebra.Workers.JobRequestFactory.GitCheckout do
  @moduledoc """
  Handles resilient git checkout configuration for jobs.

  When the :git_clone_slow_retry feature is enabled for an organization,
  this module adds the SEMAPHORE_GIT_CLONE_SLOW_RETRY environment variable,
  which opts the toolbox `checkout` into slow-clone detection and resilient
  retry (speed monitoring, retries, and alternative-endpoint fallback).

  Only injected on cloud agents. The resilient behaviour (GeoDNS-based
  alternative-endpoint fallback, DoH lookups) targets GitHub.com reachability
  from Semaphore's cloud egress; on self-hosted agents the network is the
  customer's own, so injecting it there is inappropriate (and the DoH
  endpoint may well be blocked).

  The toolbox keeps sensible defaults for the tuning knobs
  (threshold/timeout/grace/retries), so only the on/off switch is injected
  here; the feature is a no-op in the toolbox when this var is absent.
  """

  alias Zebra.Models.Job
  alias Zebra.Workers.JobRequestFactory.JobRequest

  @doc """
  Returns environment variables for resilient git checkout.

  Adds SEMAPHORE_GIT_CLONE_SLOW_RETRY=true when the job runs on a cloud agent
  and the :git_clone_slow_retry feature is enabled for the organization.
  """
  def env_vars(job, org_id) do
    if inject?(job, org_id) do
      [JobRequest.env_var("SEMAPHORE_GIT_CLONE_SLOW_RETRY", "true")]
    else
      []
    end
  end

  defp inject?(job, org_id) do
    not Job.self_hosted?(job.machine_type) and
      FeatureProvider.feature_enabled?(:git_clone_slow_retry, param: org_id)
  end
end
