defmodule Test.Support.RequestFactory do
  @test_commit_sha_1 "#{:crypto.strong_rand_bytes(20) |> Base.encode16(case: :lower)}"
  @test_commit_sha_2 "#{:crypto.strong_rand_bytes(20) |> Base.encode16(case: :lower)}"
  @moduledoc false

  def schedule_args(args, :local) do
    %{
      "service" => "local",
      "repo_name" => "2_basic",
      "branch_name" => "master",
      "request_token" => UUID.uuid1(),
      "hook_id" => UUID.uuid1(),
      "branch_id" => UUID.uuid4(),
      "file_name" => "semaphore.yml",
      "working_dir" => ".semaphore",
      "owner" => "rt",
      "project_id" => UUID.uuid4(),
      "requester_id" => UUID.uuid4(),
      "wf_id" => UUID.uuid4(),
      "organization_id" => UUID.uuid4(),
      "label" => "master",
      "commit_sha" => String.slice(@test_commit_sha_1, 0, 10)
    }
    |> Map.merge(args)
  end

  def schedule_args(args, :github) do
    %{
      "request_token" => UUID.uuid1(),
      "service" => "git_hub",
      "owner" => "renderedtext",
      "repo_name" => "pipelines-test-repo-auto-call",
      "branch_name" => "master",
      "commit_sha" => @test_commit_sha_1,
      "project_id" => UUID.uuid4(),
      "hook_id" => UUID.uuid4(),
      "branch_id" => UUID.uuid4(),
      "wf_id" => UUID.uuid4(),
      "file_name" => "semaphore.yml",
      "working_dir" => ".semaphore",
      "label" => "master",
      "requester_id" => UUID.uuid4(),
      "organization_id" => UUID.uuid4()
    }
    |> Map.merge(args)
  end

  def schedule_args(args, :bitbucket) do
    %{
      "request_token" => UUID.uuid1(),
      "service" => "bitbucket",
      "owner" => "renderedtext",
      "repo_name" => "test_repo",
      "branch_name" => "master",
      "repository_id" => "repo_id_1",
      "commit_sha" => @test_commit_sha_1,
      "project_id" => UUID.uuid4(),
      "hook_id" => UUID.uuid4(),
      "branch_id" => UUID.uuid4(),
      "wf_id" => UUID.uuid4(),
      "file_name" => "semaphore.yml",
      "working_dir" => ".semaphore",
      "label" => "master",
      "requester_id" => UUID.uuid4(),
      "organization_id" => UUID.uuid4()
    }
    |> Map.merge(args)
  end

  def schedule_args(args, :git) do
    %{
      "request_token" => UUID.uuid1(),
      "service" => "git",
      "owner" => "renderedtext",
      "repo_name" => "test_repo",
      "branch_name" => "master",
      "repository_id" => "repo_id_1",
      "commit_sha" => @test_commit_sha_1,
      "project_id" => UUID.uuid4(),
      "hook_id" => UUID.uuid4(),
      "branch_id" => UUID.uuid4(),
      "wf_id" => UUID.uuid4(),
      "file_name" => "semaphore.yml",
      "working_dir" => ".semaphore",
      "label" => "master",
      "requester_id" => UUID.uuid4(),
      "organization_id" => UUID.uuid4()
    }
    |> Map.merge(args)
  end

  def schedule_args(args, :gitlab) do
    %{
      "request_token" => UUID.uuid1(),
      "service" => "gitlab",
      "owner" => "renderedtext",
      "repo_name" => "test_repo",
      "branch_name" => "master",
      "repository_id" => "repo_id_1",
      "commit_sha" => @test_commit_sha_1,
      "project_id" => UUID.uuid4(),
      "hook_id" => UUID.uuid4(),
      "branch_id" => UUID.uuid4(),
      "wf_id" => UUID.uuid4(),
      "file_name" => "semaphore.yml",
      "working_dir" => ".semaphore",
      "label" => "master",
      "requester_id" => UUID.uuid4(),
      "organization_id" => UUID.uuid4()
    }
    |> Map.merge(args)
  end

  def source_args(args) do
    %{
      hook_id: "24681012141618",
      head_commit_sha: String.slice(@test_commit_sha_1, 0, 7),
      notify_commit_sha: String.slice(@test_commit_sha_2, 0, 7),
      commit_message: "Commit message from repo-proxy-ref",
      repo_host_url: "git@github.com/owner/repo",
      repo_host_username: "user_1",
      repo_host_email: "user_1@mailcom",
      repo_host_avatar_url: "pictures.com/user_1",
      user_id: "user_1_uuid",
      semaphore_email: "user_1@mailcom",
      repo_slug: "git@github.com/owner/repo",
      git_ref: "master",
      git_ref_type: "branch",
      pr_slug: "",
      pr_name: "",
      pr_number: "",
      pr_sha: "asdfghjkl",
      pr_branch_name: "",
      tag_name: "",
      branch_name: "master",
      commit_range: "1234...4567"
    }
    |> Map.merge(args)
  end
end
