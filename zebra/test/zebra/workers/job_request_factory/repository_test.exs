defmodule Zebra.Workers.JobRequestFactory.RepositoryTest do
  use Zebra.DataCase

  alias Zebra.Workers.JobRequestFactory.Repository
  alias InternalApi.Projecthub.Project

  @repository %{
    name: "zebra",
    url: "git@github.com:/test-org/test-repo.git",
    provider: "github",
    default_branch: "master"
  }

  @project InternalApi.Projecthub.Project.new(
             metadata: Project.Metadata.new(name: "zebra"),
             spec:
               Project.Spec.new(
                 repository:
                   Project.Spec.Repository.new(url: "git@github.com:/test-org/test-repo.git"),
                 artifact_store_id: Ecto.UUID.generate(),
                 cache_id: Ecto.UUID.generate()
               )
           )

  @private_ssh_key "--BEGIN....lalalala..private_key...END---"

  describe ".find" do
    test "uses repository api" do
      GrpcMock.stub(Support.FakeServers.RepositoryApi, :describe, fn _, _ ->
        InternalApi.Repository.DescribeResponse.new(
          repository:
            InternalApi.Repository.Repository.new(
              name: "zebra2",
              url: "git@bitbucket.org:test-org/test-repo.git",
              provider: "github"
            ),
          private_ssh_key: @private_ssh_key
        )
      end)

      repository =
        {:ok,
         %{
           name: "zebra2",
           url: "git@bitbucket.org:test-org/test-repo.git",
           provider: "github",
           default_branch: "master"
         }, "--BEGIN....lalalala..private_key...END---"}

      assert repository == Repository.find(@project.spec.repository.id)
    end
  end

  describe ".env_vars" do
    test "when there is no repo_proxy for project debug job" do
      {:ok, envs} = Repository.env_vars(@repository, nil, :project_debug_job)

      assert envs == [
               %{
                 "name" => "SEMAPHORE_GIT_PROVIDER",
                 "value" => Base.encode64("github")
               },
               %{
                 "name" => "SEMAPHORE_GIT_URL",
                 "value" => Base.encode64("git@github.com:/test-org/test-repo.git")
               },
               %{
                 "name" => "SEMAPHORE_GIT_REPO_NAME",
                 "value" => Base.encode64("zebra")
               },
               %{
                 "name" => "SEMAPHORE_GIT_DIR",
                 "value" => Base.encode64("zebra")
               },
               %{
                 "name" => "SEMAPHORE_GIT_BRANCH",
                 "value" => Base.encode64("master")
               },
               %{
                 "name" => "SEMAPHORE_GIT_WORKING_BRANCH",
                 "value" => Base.encode64("master")
               },
               %{
                 "name" => "SEMAPHORE_GIT_SHA",
                 "value" => Base.encode64("HEAD")
               }
             ]
    end

    test "when build this is a branch build" do
      hook =
        InternalApi.RepoProxy.Hook.new(
          hook_id: "",
          head_commit_sha: "8d762d04c7c753c2181030a9385b496559e5a885",
          commit_message: "",
          commit_range: "123...456",
          repo_host_url: "",
          repo_host_username: "",
          repo_host_email: "",
          repo_host_avatar_url: "",
          user_id: "",
          semaphore_email: "",
          repo_slug: "test-org/test-repo",
          git_ref: "refs/heads/master",
          git_ref_type: InternalApi.RepoProxy.Hook.Type.value(:BRANCH),
          pr_slug: "",
          pr_name: "",
          pr_number: "",
          pr_sha: "",
          tag_name: "",
          branch_name: "master",
          pr_branch_name: ""
        )

      {:ok, envs} = Repository.env_vars(@repository, hook, :pipeline_job)

      assert envs == [
               %{
                 "name" => "SEMAPHORE_GIT_PROVIDER",
                 "value" => Base.encode64("github")
               },
               %{
                 "name" => "SEMAPHORE_GIT_URL",
                 "value" => Base.encode64("git@github.com:/test-org/test-repo.git")
               },
               %{
                 "name" => "SEMAPHORE_GIT_REPO_NAME",
                 "value" => Base.encode64("zebra")
               },
               %{
                 "name" => "SEMAPHORE_GIT_DIR",
                 "value" => Base.encode64("zebra")
               },
               %{
                 "name" => "SEMAPHORE_GIT_SHA",
                 "value" => Base.encode64("8d762d04c7c753c2181030a9385b496559e5a885")
               },
               %{
                 "name" => "SEMAPHORE_GIT_REPO_SLUG",
                 "value" => Base.encode64("test-org/test-repo")
               },
               %{
                 "name" => "SEMAPHORE_GIT_REF",
                 "value" => Base.encode64("refs/heads/master")
               },
               %{
                 "name" => "SEMAPHORE_GIT_COMMIT_RANGE",
                 "value" => Base.encode64("123...456")
               },
               %{
                 "name" => "SEMAPHORE_GIT_REF_TYPE",
                 "value" => Base.encode64("branch")
               },
               %{
                 "name" => "SEMAPHORE_GIT_BRANCH",
                 "value" => Base.encode64("master")
               },
               %{
                 "name" => "SEMAPHORE_GIT_WORKING_BRANCH",
                 "value" => Base.encode64("master")
               }
             ]
    end

    test "when build this is a pr build" do
      hook =
        InternalApi.RepoProxy.Hook.new(
          hook_id: "",
          head_commit_sha: "8d762d04c7c753c2181030a9385b496559e5a885",
          commit_message: "",
          commit_range: "123...456",
          repo_host_url: "",
          repo_host_username: "",
          repo_host_email: "",
          repo_host_avatar_url: "",
          user_id: "",
          semaphore_email: "",
          repo_slug: "test-org/test-repo",
          git_ref: "refs/pull/1/merge",
          git_ref_type: InternalApi.RepoProxy.Hook.Type.value(:PR),
          pr_slug: "test-org/test-repo",
          pr_name: "First PR",
          pr_number: "1",
          pr_sha: "8d762d04c7c753c2181030a9385b496559e5a883",
          tag_name: "",
          branch_name: "master",
          pr_branch_name: "hotfix"
        )

      {:ok, envs} = Repository.env_vars(@repository, hook, :pipeline_job)

      assert envs == [
               %{
                 "name" => "SEMAPHORE_GIT_PROVIDER",
                 "value" => Base.encode64("github")
               },
               %{
                 "name" => "SEMAPHORE_GIT_URL",
                 "value" => Base.encode64("git@github.com:/test-org/test-repo.git")
               },
               %{
                 "name" => "SEMAPHORE_GIT_REPO_NAME",
                 "value" => Base.encode64("zebra")
               },
               %{
                 "name" => "SEMAPHORE_GIT_DIR",
                 "value" => Base.encode64("zebra")
               },
               %{
                 "name" => "SEMAPHORE_GIT_SHA",
                 "value" => Base.encode64("8d762d04c7c753c2181030a9385b496559e5a885")
               },
               %{
                 "name" => "SEMAPHORE_GIT_REPO_SLUG",
                 "value" => Base.encode64("test-org/test-repo")
               },
               %{
                 "name" => "SEMAPHORE_GIT_REF",
                 "value" => Base.encode64("refs/pull/1/merge")
               },
               %{
                 "name" => "SEMAPHORE_GIT_COMMIT_RANGE",
                 "value" => Base.encode64("123...456")
               },
               %{
                 "name" => "SEMAPHORE_GIT_REF_TYPE",
                 "value" => Base.encode64("pull-request")
               },
               %{
                 "name" => "SEMAPHORE_GIT_BRANCH",
                 "value" => Base.encode64("master")
               },
               %{
                 "name" => "SEMAPHORE_GIT_PR_SLUG",
                 "value" => Base.encode64("test-org/test-repo")
               },
               %{
                 "name" => "SEMAPHORE_GIT_PR_SHA",
                 "value" => Base.encode64("8d762d04c7c753c2181030a9385b496559e5a883")
               },
               %{
                 "name" => "SEMAPHORE_GIT_PR_NUMBER",
                 "value" => Base.encode64("1")
               },
               %{
                 "name" => "SEMAPHORE_GIT_PR_NAME",
                 "value" => Base.encode64("First PR")
               },
               %{
                 "name" => "SEMAPHORE_GIT_PR_BRANCH",
                 "value" => Base.encode64("hotfix")
               },
               %{
                 "name" => "SEMAPHORE_GIT_WORKING_BRANCH",
                 "value" => Base.encode64("hotfix")
               }
             ]
    end

    test "when build this is a tag build" do
      hook = %InternalApi.RepoProxy.Hook{
        hook_id: "",
        head_commit_sha: "8d762d04c7c753c2181030a9385b496559e5a885",
        commit_message: "",
        commit_range: "123...456",
        repo_host_url: "",
        repo_host_username: "",
        repo_host_email: "",
        repo_host_avatar_url: "",
        user_id: "",
        semaphore_email: "",
        repo_slug: "test-org/test-repo",
        git_ref: "refs/tags/v1.0.0",
        git_ref_type: InternalApi.RepoProxy.Hook.Type.value(:TAG),
        pr_slug: "",
        pr_name: "",
        pr_number: "",
        pr_sha: "",
        tag_name: "v1.0.0",
        branch_name: "master"
      }

      {:ok, envs} = Repository.env_vars(@repository, hook, :pipeline_job)

      assert envs == [
               %{
                 "name" => "SEMAPHORE_GIT_PROVIDER",
                 "value" => Base.encode64("github")
               },
               %{
                 "name" => "SEMAPHORE_GIT_URL",
                 "value" => Base.encode64("git@github.com:/test-org/test-repo.git")
               },
               %{
                 "name" => "SEMAPHORE_GIT_REPO_NAME",
                 "value" => Base.encode64("zebra")
               },
               %{
                 "name" => "SEMAPHORE_GIT_DIR",
                 "value" => Base.encode64("zebra")
               },
               %{
                 "name" => "SEMAPHORE_GIT_SHA",
                 "value" => Base.encode64("8d762d04c7c753c2181030a9385b496559e5a885")
               },
               %{
                 "name" => "SEMAPHORE_GIT_REPO_SLUG",
                 "value" => Base.encode64("test-org/test-repo")
               },
               %{
                 "name" => "SEMAPHORE_GIT_REF",
                 "value" => Base.encode64("refs/tags/v1.0.0")
               },
               %{
                 "name" => "SEMAPHORE_GIT_COMMIT_RANGE",
                 "value" => Base.encode64("123...456")
               },
               %{
                 "name" => "SEMAPHORE_GIT_REF_TYPE",
                 "value" => Base.encode64("tag")
               },
               %{
                 "name" => "SEMAPHORE_GIT_BRANCH",
                 "value" => Base.encode64("refs/tags/v1.0.0")
               },
               %{
                 "name" => "SEMAPHORE_GIT_TAG_NAME",
                 "value" => Base.encode64("v1.0.0")
               }
             ]
    end
  end
end
