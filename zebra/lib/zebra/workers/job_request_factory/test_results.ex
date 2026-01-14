defmodule Zebra.Workers.JobRequestFactory.TestResults do
  @moduledoc """
  Handles test results configuration for jobs.

  When the :test_results_no_trim feature is enabled for an organization,
  this module adds the SEMAPHORE_TEST_RESULTS_NO_TRIM environment variable
  to disable output trimming in the test-results CLI tool.
  """

  alias Zebra.Workers.JobRequestFactory.JobRequest

  @doc """
  Returns environment variables for test results configuration.

  If the :test_results_no_trim feature is enabled for the organization,
  adds SEMAPHORE_TEST_RESULTS_NO_TRIM=true to disable output trimming.
  """
  def env_vars(org_id) do
    if FeatureProvider.feature_enabled?(:test_results_no_trim, param: org_id) do
      [JobRequest.env_var("SEMAPHORE_TEST_RESULTS_NO_TRIM", "true")]
    else
      []
    end
  end
end
