defmodule Zebra.Workers.JobRequestFactory.GitCheckoutTest do
  use Zebra.DataCase

  alias Zebra.Workers.JobRequestFactory.GitCheckout

  describe "env_vars/1" do
    test "returns empty list when feature is disabled" do
      org_id = Ecto.UUID.generate()

      assert GitCheckout.env_vars(org_id) == []
    end

    test "returns SEMAPHORE_GIT_CLONE_SLOW_RETRY env var when feature is enabled" do
      org_id = Support.StubbedProvider.git_clone_slow_retry_org_id()

      env_vars = GitCheckout.env_vars(org_id)

      assert length(env_vars) == 1
      [env_var] = env_vars
      assert env_var["name"] == "SEMAPHORE_GIT_CLONE_SLOW_RETRY"
      assert env_var["value"] == Base.encode64("true")
    end
  end
end
