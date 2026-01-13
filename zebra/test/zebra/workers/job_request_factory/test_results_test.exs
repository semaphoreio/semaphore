defmodule Zebra.Workers.JobRequestFactory.TestResultsTest do
  use Zebra.DataCase

  alias Zebra.Workers.JobRequestFactory.TestResults

  describe "env_vars/1" do
    test "returns empty list when feature is disabled" do
      org_id = Ecto.UUID.generate()

      assert TestResults.env_vars(org_id) == []
    end

    test "returns SEMAPHORE_TEST_RESULTS_NO_TRIM env var when feature is enabled" do
      org_id = Support.StubbedProvider.test_results_no_trim_org_id()

      env_vars = TestResults.env_vars(org_id)

      assert length(env_vars) == 1
      [env_var] = env_vars
      assert env_var["name"] == "SEMAPHORE_TEST_RESULTS_NO_TRIM"
      assert env_var["value"] == Base.encode64("true")
    end
  end
end
