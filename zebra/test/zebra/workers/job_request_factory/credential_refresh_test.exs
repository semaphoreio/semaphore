defmodule Zebra.Workers.JobRequestFactory.CredentialRefreshTest do
  use ExUnit.Case, async: false

  alias Zebra.Workers.JobRequestFactory.CredentialRefresh

  describe "validity/1" do
    test "outlasts the job's time limit by an hour" do
      assert CredentialRefresh.validity(%{execution_time_limit: 3600}) == 7200
    end

    test "is at most 25 hours" do
      assert CredentialRefresh.validity(%{execution_time_limit: 24 * 3600}) == 25 * 3600
      assert CredentialRefresh.validity(%{execution_time_limit: 72 * 3600}) == 25 * 3600
    end

    test "is 25 hours without a time limit" do
      assert CredentialRefresh.validity(%{execution_time_limit: nil}) == 25 * 3600
      assert CredentialRefresh.validity(%{execution_time_limit: 0}) == 25 * 3600
      assert CredentialRefresh.validity(%{}) == 25 * 3600
    end
  end
end
