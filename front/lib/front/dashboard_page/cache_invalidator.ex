defmodule Front.DashboardPage.CacheInvalidator do
  require Logger

  alias Front.DashboardPage
  alias Front.Models

  @doc """
  Reacts to workflow lifecycle events and invalidates homepage cache.
  """

  use Tackle.Multiconsumer,
    url: Application.get_env(:front, :amqp_url),
    service: "#{Application.get_env(:front, :cache_reactor_env)}.dashboard_page_invalidator",
    service_per_exchange: true,
    routes: [
      {"pipeline_state_exchange", "initializing", :pipeline_event},
      {"pipeline_state_exchange", "pending", :pipeline_event},
      {"pipeline_state_exchange", "queuing", :pipeline_event},
      {"pipeline_state_exchange", "running", :pipeline_event},
      {"pipeline_state_exchange", "stopping", :pipeline_event},
      {"pipeline_state_exchange", "done", :pipeline_event},
      {"project_exchange", "updated", :project_updated},
      {"velocity_pipeline_summary_exchange", "done", :pipeline_summary_event}
    ]

  @metric_name "dashboard_page.cache_invalidator.process"
  @log_prefix "[DASHBOARD PAGE INVALIDATOR]"

  def project_updated(message) do
    Watchman.benchmark({@metric_name, ["project_updated"]}, fn ->
      event = InternalApi.Projecthub.ProjectUpdated.decode(message)
      DashboardPage.Model.invalidate_org(event.org_id)

      Logger.info(
        "#{@log_prefix} [PROJECT UPDATED] [project_id=#{event.project_id}] Processing finished"
      )
    end)
  rescue
    e in Protobuf.DecodeError ->
      Logger.error(
        "#{@log_prefix} [PROJECT UPDATED] Processing failed message: #{inspect(message)} error: #{inspect(e)}"
      )
  end

  def pipeline_event(msg) do
    Watchman.benchmark({@metric_name, ["pipeline_event"]}, fn ->
      event = InternalApi.Plumber.PipelineEvent.decode(msg)
      measure_queue_time(event, "pipeline_event")

      invalidate_with_pipeline_id(event.pipeline_id)

      Logger.info(
        "#{@log_prefix} [PIPELINE EVENT] [pipeline_id=#{event.pipeline_id}] Processing finished"
      )
    end)
  rescue
    e in Protobuf.DecodeError ->
      Logger.error(
        "#{@log_prefix} [PIPELINE EVENT] Processing failed message: #{inspect(msg)} error: #{inspect(e)}"
      )
  end

  def pipeline_summary_event(msg) do
    Watchman.benchmark({@metric_name, ["pipeline_summary_event"]}, fn ->
      event = InternalApi.Velocity.PipelineSummaryAvailableEvent.decode(msg)
      measure_queue_time(event, "pipeline_summary_event")

      invalidate_with_pipeline_id(event.pipeline_id)

      Logger.info(
        "#{@log_prefix} [PIPELINE SUMMARY EVENT] [pipeline_id=#{event.pipeline_id}] Processing finished"
      )
    end)
  rescue
    e in Protobuf.DecodeError ->
      Logger.error(
        "#{@log_prefix} [PIPELINE SUMMARY EVENT] Processing failed message: #{inspect(msg)} error: #{inspect(e)}"
      )
  end

  # Private

  defp measure_queue_time(event, tag) do
    fetched_for_processing_at = :os.system_time(:millisecond)
    emitted_at = event.timestamp.seconds * 1000 + div(event.timestamp.nanos, 1_000_000)
    queue_duration = fetched_for_processing_at - emitted_at

    Watchman.submit(
      {"dashboard_page.cache_invalidator.message_queue", [tag]},
      queue_duration,
      :timing
    )
  end

  defp invalidate_with_pipeline_id(pipeline_id) do
    pipeline = Models.Pipeline.find_metadata(pipeline_id)
    project = Models.Project.find_by_id(pipeline.project_id)
    DashboardPage.Model.invalidate_org(project.organization_id)
  end
end
