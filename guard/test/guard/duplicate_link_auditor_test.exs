defmodule Guard.DuplicateLinkAuditorTest do
  use Guard.RepoCase, async: true

  alias Guard.DuplicateLinkAuditor

  describe "process/0" do
    test "returns empty counts when no active duplicates exist" do
      # single active link + a revoked pair: neither counts as an active duplicate
      {:ok, _} = Support.Members.insert_repo_host_account(github_uid: "88001")
      {:ok, _} = Support.Members.insert_repo_host_account(github_uid: "88002", revoked: true)
      {:ok, _} = Support.Members.insert_repo_host_account(github_uid: "88002", revoked: true)

      assert {:ok, %{}} = DuplicateLinkAuditor.process()
    end

    test "counts uids actively linked to more than one user, per host" do
      # two active github duplicates for one uid
      {:ok, _} = Support.Members.insert_repo_host_account(github_uid: "88003")
      {:ok, _} = Support.Members.insert_repo_host_account(github_uid: "88003")

      # three active github duplicates for another uid
      {:ok, _} = Support.Members.insert_repo_host_account(github_uid: "88004")
      {:ok, _} = Support.Members.insert_repo_host_account(github_uid: "88004")
      {:ok, _} = Support.Members.insert_repo_host_account(github_uid: "88004")

      # an active bitbucket duplicate pair sharing a github uid value is
      # counted under its own host
      {:ok, _} =
        Support.Members.insert_repo_host_account(github_uid: "88003", repo_host: "bitbucket")

      {:ok, _} =
        Support.Members.insert_repo_host_account(github_uid: "88003", repo_host: "bitbucket")

      # revoked rows never count
      {:ok, _} = Support.Members.insert_repo_host_account(github_uid: "88003", revoked: true)

      assert {:ok, counts} = DuplicateLinkAuditor.process()
      assert counts == %{"github" => 2, "bitbucket" => 1}
    end
  end
end
