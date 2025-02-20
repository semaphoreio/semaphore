defmodule GithubNotifier.Utils.Context do
  @moduledoc """
  Utility module for resolving notification context
  """

  # Default context prefix
  @default_context_prefix "ci/semaphoreci"

  @doc """
  Prepares a context for commit status
  """
  def prepare(name, repo_proxy, org_id) do
    name = name |> GithubNotifier.Utils.Cleaner.clean()
    hook_type = InternalApi.RepoProxy.Hook.Type.key(repo_proxy.git_ref_type)

    prefix = get_prefix()
    suffix = get_suffix(hook_type, repo_proxy.branch_name, org_id)
    "#{prefix}/#{suffix}: #{name}"
  end

  defp get_prefix,
    do:
      Application.get_env(
        :github_notifier,
        :context_prefix,
        @default_context_prefix
      )

  defp get_suffix(:TAG, _, _), do: "tag"
  defp get_suffix(:PR, _, _), do: "pr"

  defp get_suffix(:BRANCH, branch_name, org_id) do
    if gh_merge_queue_branch?(branch_name) && report_gh_merge_queues_as_prs?(org_id) do
      "pr"
    else
      "push"
    end
  end

  defp report_gh_merge_queues_as_prs?(org_id),
    do: FeatureProvider.feature_enabled?(:github_merge_queues, param: org_id)

  defp gh_merge_queue_branch?(name), do: String.starts_with?(name, "gh-readonly-queue/")
end
