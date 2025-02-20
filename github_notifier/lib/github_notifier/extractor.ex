defmodule GithubNotifier.Extractor do
  alias GithubNotifier.Models

  def extract(nil, _block_id), do: nil

  def extract(pipeline, block_id, repo_proxy, project) do
    case GithubNotifier.Utils.Level.level(project, pipeline) do
      [] ->
        nil

      ["block"] ->
        blocks = extract_blocks(pipeline.blocks, block_id)

        project_data(pipeline, repo_proxy, project)
        |> merge_with_blocks(blocks, repo_proxy)

      ["pipeline"] ->
        project_data(pipeline, repo_proxy, project)
        |> merge_with_pipeline(pipeline, repo_proxy)

      ["block", "pipeline"] ->
        blocks = extract_blocks(pipeline.blocks, block_id)
        project_data = project_data(pipeline, repo_proxy, project)

        [
          project_data |> merge_with_blocks(blocks, repo_proxy),
          project_data |> merge_with_pipeline(pipeline, repo_proxy)
        ]
        |> List.flatten()
    end
  end

  def extract_with_summary(pipeline, repo_proxy, project, pipeline_summary) do
    # Don't link to summary tab if the pipeline status and summary status mismatches
    # This situation occurs when the pipeline tests pass(there are no errors in the summary),
    # but at least one of the jobs failed without test results
    link_to_summary_tab? =
      not (pipeline.result == :FAILED and Models.PipelineSummary.is_passed?(pipeline_summary))

    sha = notify_sha(repo_proxy)

    url =
      GithubNotifier.Utils.Url.prepare(
        project,
        pipeline.workflow_id,
        pipeline.id,
        link_to_summary_tab?
      )

    %{
      repository_id: project.repository_id,
      sha: sha,
      url: url,
      ppl_id: pipeline.id,
      org_id: project.org_id
    }
    |> merge_with_pipeline_summary(repo_proxy, pipeline, pipeline_summary)
  end

  defp project_data(pipeline, repo_proxy, project) do
    sha = notify_sha(repo_proxy)
    url = GithubNotifier.Utils.Url.prepare(project, pipeline.workflow_id, pipeline.id)

    %{
      repository_id: project.repository_id,
      sha: sha,
      url: url,
      ppl_id: pipeline.id,
      org_id: project.org_id
    }
  end

  def extract_blocks(blocks, nil), do: blocks

  def extract_blocks(blocks, block_id) do
    Enum.find(blocks, fn block -> block.id == block_id end)
  end

  defp merge_with_blocks(project_data, blocks, repo_proxy) when is_list(blocks) do
    Enum.map(blocks, fn block ->
      merge_with_blocks(project_data, block, repo_proxy)
    end)
  end

  defp merge_with_blocks(project_data, block, repo_proxy) do
    Map.merge(project_data, block_data(block, repo_proxy, project_data.org_id))
  end

  defp merge_with_pipeline(project_data, pipeline, repo_proxy) do
    Map.merge(project_data, pipeline_data(pipeline, repo_proxy, project_data.org_id))
  end

  defp merge_with_pipeline_summary(project_data, repo_proxy, pipeline, pipeline_summary) do
    Map.merge(
      project_data,
      pipeline_summary_data(repo_proxy, pipeline, pipeline_summary, project_data.org_id)
    )
  end

  defp pipeline_summary_data(repo_proxy, pipeline, pipeline_summary, org_id) do
    {state, description} =
      GithubNotifier.Utils.State.extract_with_summary(pipeline, pipeline_summary)

    context = GithubNotifier.Utils.Context.prepare(pipeline.name, repo_proxy, org_id)

    %{state: state, description: description, context: context}
  end

  defp pipeline_data(pipeline, repo_proxy, org_id) do
    {state, description} = GithubNotifier.Utils.State.extract(pipeline)
    context = GithubNotifier.Utils.Context.prepare(pipeline.name, repo_proxy, org_id)

    %{state: state, description: description, context: context}
  end

  defp block_data(block, repo_proxy, org_id) do
    {state, description} = GithubNotifier.Utils.State.extract(block)
    context = GithubNotifier.Utils.Context.prepare(block.name, repo_proxy, org_id)

    %{state: state, description: description, context: context}
  end

  def notify_sha(repo_proxy) do
    case InternalApi.RepoProxy.Hook.Type.key(repo_proxy.git_ref_type) do
      :BRANCH -> repo_proxy.build_sha
      :TAG -> repo_proxy.build_sha
      :PR -> repo_proxy.pr_sha
    end
  end
end
