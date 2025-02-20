defmodule RepoProxyRef.Grpc.Server do
  @test_commit_sha_1 "#{:crypto.strong_rand_bytes(20) |> Base.encode16(case: :lower)}"
  @test_commit_sha_2 "#{:crypto.strong_rand_bytes(20) |> Base.encode16(case: :lower)}"
  @test_commit_sha_3 "#{:crypto.strong_rand_bytes(20) |> Base.encode16(case: :lower)}"
  use GRPC.Server, service: InternalApi.RepoProxy.RepoProxyService.Service

  alias InternalApi.RepoProxy.DescribeResponse
  alias InternalApi.RepoProxy.CreateBlankResponse
  alias Util.Proto

  def describe(%{hook_id: "timeout"}, _stream) do
    :timer.sleep(5_000)
    Proto.deep_new!(DescribeResponse, %{})
  end

  def describe(%{hook_id: "bad_param"}, _stream) do
    %{status: %{code: :BAD_PARAM, message: "Error"}}
    |> Proto.deep_new!(DescribeResponse)
  end

  def describe(%{hook_id: hook_id}, _stream) do
    %{status: %{code: :OK, message: ""}}
    |> Map.merge(mock_hook(hook_id))
    |> Proto.deep_new!(DescribeResponse)
  end

  def create_blank(%{request_token: "timeout"}, _stream) do
    :timer.sleep(7_000)
    Proto.deep_new!(CreateBlankResponse, %{})
  end

  def create_blank(%{request_token: "bad_param"}, _stream) do
    raise GRPC.RPCError,
      status: GRPC.Status.invalid_argument(),
      message: "Bad parameter"
  end

  def create_blank(%{request_token: "invalid"}, _stream) do
    raise GRPC.RPCError,
      status: GRPC.Status.invalid_argument(),
      message: "Invalid request token"
  end

  def create_blank(request = %{requester_id: "10_schedule_extension" = requester_id}, _stream) do
    create_blank_response(request.wf_id, request.pipeline_id, requester_id)
  end

  def create_blank(
        request = %{requester_id: "14_free_topology_failing_block" = requester_id},
        _stream
      ) do
    create_blank_response(request.wf_id, request.pipeline_id, requester_id)
  end

  def create_blank(%{requester_id: requester_id, wf_id: wf_id, pipeline_id: ppl_id}, _stream) do
    create_blank_response(wf_id, ppl_id, requester_id)
  end

  defp create_blank_response(wf_id, ppl_id, requester_id) do
    Proto.deep_new!(CreateBlankResponse, %{
      hook_id: "hook_id",
      branch_id: "branch_id",
      wf_id: wf_id,
      pipeline_id: ppl_id,
      repo: mock_repo(requester_id)
    })
  end

  defp mock_repo("10_schedule_extension") do
    %{
      owner: "rt",
      repo_name: "10_schedule_extension",
      branch_name: "master",
      commit_sha: String.slice(@test_commit_sha_1, 0, 10),
      repository_id: ""
    }
  end

  defp mock_repo("14_free_topology_failing_block") do
    %{
      owner: "rt",
      repo_name: "14_free_topology_failing_block",
      branch_name: "master",
      commit_sha: String.slice(@test_commit_sha_2, 0, 7),
      repository_id: ""
    }
  end

  defp mock_repo(_repo_name) do
    %{
      owner: "renderedtext",
      repo_name: "zebra",
      branch_name: "master",
      commit_sha: "0000000000000000000000000000000000000001",
      repository_id: "00000000-0000-4000-a000-000000000001"
    }
  end

  defp mock_hook(hook_id) do
    %{
      hook: %{
        hook_id: hook_id,
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
        git_ref_type: ref_type(hook_id),
        pr_slug: "",
        pr_name: "",
        pr_number: "",
        pr_sha: pr_sha(hook_id),
        pr_branch_name: pr_branch_name(hook_id),
        tag_name: "",
        branch_name: branch_name(hook_id),
        commit_range: commit_range(hook_id)
      }
    }
  end

  defp ref_type("tag"), do: :TAG
  defp ref_type("pr"), do: :PR
  defp ref_type(_), do: :BRANCH

  defp branch_name("pr"), do: "pr_base"
  defp branch_name(_), do: "master"

  defp pr_branch_name("pr"), do: "pr_head"
  defp pr_branch_name(_), do: ""

  defp commit_range("tag"), do: ""
  defp commit_range(_), do: "1234...4567"

  defp pr_sha("pr"), do: "asdf12345"
  defp pr_sha(_), do: ""
end
