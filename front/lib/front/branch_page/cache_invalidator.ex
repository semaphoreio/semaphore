defmodule Front.BranchPage.CacheInvalidator do
  require Logger

  alias Front.BranchPage
  alias Front.Models

  @doc """
  Reacts to events in the system and invalidates the UI cache.
  """

  use Tackle.Multiconsumer,
    url: Application.get_env(:front, :amqp_url),
    service: "#{Application.get_env(:front, :cache_reactor_env)}.branch_page_invalidator",
    service_per_exchange: true,
    routes: [
      {"pipeline_state_exchange", "initializing", :pipeline_event},
      {"pipeline_state_exchange", "pending", :pipeline_event},
      {"pipeline_state_exchange", "queuing", :pipeline_event},
      {"pipeline_state_exchange", "running", :pipeline_event},
      {"pipeline_state_exchange", "stopping", :pipeline_event},
      {"pipeline_state_exchange", "done", :pipeline_event},
      {"velocity_pipeline_summary_exchange", "done", :pipeline_summary_event},
      {"hook_exchange", "pr_unmergeable", :pr_unmergeable_event}
    ]

  @metric_name "branch_page.cache_invalidator.process"
  @log_prefix "[BRANCH PAGE INVALIDATOR]"

  def pipeline_event(message) do
    Watchman.benchmark({@metric_name, ["pipeline_event"]}, fn ->
      event = InternalApi.Plumber.PipelineEvent.decode(message)

      measure_queue_time(event, "pipeline_event")
      invalidate_with_pipeline_id(event.pipeline_id)

      Logger.info(
        "#{@log_prefix} [PIPELINE EVENT] [pipeline_id=#{event.pipeline_id}] Processing finished"
      )
    end)
  rescue
    e in Protobuf.DecodeError ->
      Logger.error(
        "#{@log_prefix} [PIPELINE EVENT] Processing failed message: #{inspect(message)} error: #{inspect(e)}"
      )
  end

  def pipeline_summary_event(message) do
    Watchman.benchmark({@metric_name, ["pipeline_summary_event"]}, fn ->
      event = InternalApi.Velocity.PipelineSummaryAvailableEvent.decode(message)

      measure_queue_time(event, "pipeline_summary_event")
      invalidate_with_pipeline_id(event.pipeline_id)

      Logger.info(
        "#{@log_prefix} [PIPELINE SUMMARY EVENT] [pipeline_id=#{event.pipeline_id}] Processing finished"
      )
    end)
  rescue
    e in Protobuf.DecodeError ->
      Logger.error(
        "#{@log_prefix} [PIPELINE SUMMARY EVENT] Processing failed message: #{inspect(message)} error: #{inspect(e)}"
      )
  end

  def pr_unmergeable_event(message) do
    Watchman.benchmark({@metric_name, ["pr_unmergeable_event"]}, fn ->
      event = InternalApi.RepoProxy.PullRequestUnmergeable.decode(message)

      measure_queue_time(event, "pr_unmergeable_event")
      invalidate_with_pr_branch(event.project_id, event.branch_name)

      Logger.info(
        "#{@log_prefix} [PR UNMERGEABLE EVENT] [project_id=#{event.project_id} branch=#{event.branch_name}] Processing finished"
      )
    end)
  rescue
    e in Protobuf.DecodeError ->
      Logger.error(
        "#{@log_prefix} [PR UNMERGEABLE EVENT] Processing failed message: #{inspect(message)} error: #{inspect(e)}"
      )
  end

  def measure_queue_time(event, tag) do
    fetched_for_processing_at = :os.system_time(:millisecond)
    emitted_at = event.timestamp.seconds * 1000 + div(event.timestamp.nanos, 1_000_000)
    queue_duration = fetched_for_processing_at - emitted_at

    Watchman.submit(
      {"branch_page.cache_invalidator.message_queue", [tag]},
      queue_duration,
      :timing
    )
  end

  defp invalidate_with_pipeline_id(pipeline_id) do
    Models.Pipeline.invalidate(pipeline_id)

    pipeline = Models.Pipeline.find_metadata(pipeline_id)

    Models.Workflow.invalidate(pipeline.workflow_id)

    {:ok, _} =
      struct!(BranchPage.Model.LoadParams, branch_id: pipeline.branch_id)
      |> BranchPage.Model.invalidate()
  end

  defp invalidate_with_pr_branch(project_id, branch_name) do
    #
    # Find the latest workflow for the branch,
    # and invalidate the cache for it, since it's from that workflow
    # that we determine the conflict status of the branch.
    #
    workflow =
      Models.Workflow.find_latest(
        project_id: project_id,
        branch_name: branch_name
      )

    Models.RepoProxy.invalidate(workflow.hook_id)
    Models.Workflow.invalidate(workflow.id)

    {:ok, _} =
      struct!(BranchPage.Model.LoadParams, branch_id: workflow.branch_id)
      |> BranchPage.Model.invalidate()
  end
end
