defmodule Zebra.Workers.JobRequestFactory.GitCheckoutTest do
  use Zebra.DataCase

  alias Zebra.Models.Job
  alias Zebra.Workers.JobRequestFactory.GitCheckout

  @cloud_job %Job{machine_type: "e1-standard-2"}
  @self_hosted_job %Job{machine_type: "s1-local"}

  describe "env_vars/2" do
    test "returns empty list when feature is disabled" do
      org_id = Ecto.UUID.generate()

      assert GitCheckout.env_vars(@cloud_job, org_id) == []
    end

    test "returns SEMAPHORE_GIT_CLONE_SLOW_RETRY env var on a cloud agent when feature is enabled" do
      org_id = Support.StubbedProvider.git_clone_slow_retry_org_id()

      env_vars = GitCheckout.env_vars(@cloud_job, org_id)

      assert length(env_vars) == 1
      [env_var] = env_vars
      assert env_var["name"] == "SEMAPHORE_GIT_CLONE_SLOW_RETRY"
      assert env_var["value"] == Base.encode64("true")
    end

    test "returns empty list on a self-hosted agent even when feature is enabled" do
      org_id = Support.StubbedProvider.git_clone_slow_retry_org_id()

      assert GitCheckout.env_vars(@self_hosted_job, org_id) == []
    end
  end
end
