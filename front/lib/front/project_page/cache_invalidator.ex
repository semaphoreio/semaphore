defmodule Front.ProjectPage.CacheInvalidator do
  require Logger

  alias Front.Async
  alias Front.Models
  alias Front.ProjectPage

  @doc """
  Reacts to events in the system and invalidates the UI cache.
  """

  use Tackle.Multiconsumer,
    url: Application.get_env(:front, :amqp_url),
    service: "#{Application.get_env(:front, :cache_reactor_env)}.project_page_invalidator",
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

  @metric_name "project_page.cache_invalidator.process"
  @log_prefix "[PROJECT PAGE INVALIDATOR]"

  def project_updated(message) do
    Watchman.benchmark({@metric_name, ["project_updated"]}, fn ->
      event = InternalApi.Projecthub.ProjectUpdated.decode(message)

      invalidate_branch_list =
        Async.run(fn ->
          {:ok, _} =
            struct!(ProjectPage.Model.LoadParams,
              project_id: event.project_id,
              organization_id: event.org_id,
              user_page?: false,
              ref_types: ["branch"]
            )
            |> ProjectPage.Model.invalidate()
        end)

      invalidate_pr_list =
        Async.run(fn ->
          {:ok, _} =
            struct!(ProjectPage.Model.LoadParams,
              project_id: event.project_id,
              organization_id: event.org_id,
              user_page?: false,
              ref_types: ["pr"]
            )
            |> ProjectPage.Model.invalidate()
        end)

      invalidate_tag_list =
        Async.run(fn ->
          {:ok, _} =
            struct!(ProjectPage.Model.LoadParams,
              project_id: event.project_id,
              organization_id: event.org_id,
              user_page?: false,
              ref_types: ["tag"]
            )
            |> ProjectPage.Model.invalidate()
        end)

      invalidate_all_list =
        Async.run(fn ->
          {:ok, _} =
            struct!(ProjectPage.Model.LoadParams,
              project_id: event.project_id,
              organization_id: event.org_id,
              user_page?: false,
              ref_types: [""]
            )
            |> ProjectPage.Model.invalidate()
        end)

      {:ok, _data} = Async.await(invalidate_branch_list)
      {:ok, _data} = Async.await(invalidate_pr_list)
      {:ok, _data} = Async.await(invalidate_tag_list)
      {:ok, _data} = Async.await(invalidate_all_list)

      Logger.info(
        "#{@log_prefix} [PROJECT UPDATED] [project_id=#{event.project_id}] Processing finished"
      )
    end)
  end

  def pipeline_event(msg) do
    Watchman.benchmark({@metric_name, ["pipeline_event"]}, fn ->
      event = InternalApi.Plumber.PipelineEvent.decode(msg)

      event |> measure_queue_time("pipeline_event")

      invalidate_with_pipeline_id(event.pipeline_id)

      Logger.info(
        "#{@log_prefix} [PIPELINE EVENT] [pipeline_id=#{event.pipeline_id}] Processing finished"
      )
    end)
  rescue
    e in Protobuf.DecodeError ->
      Logger.error(
        "#{@log_prefix} [PIPELINE SUMMARY EVENT] Processing failed message: #{inspect(msg)} error: #{inspect(e)}"
      )
  end

  def pipeline_summary_event(msg) do
    Watchman.benchmark({@metric_name, ["pipeline_summary_event"]}, fn ->
      event = InternalApi.Velocity.PipelineSummaryAvailableEvent.decode(msg)

      event |> measure_queue_time("pipeline_summary_event")

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

  def measure_queue_time(event, tag) do
    fetched_for_processing_at = :os.system_time(:millisecond)
    emitted_at = event.timestamp.seconds * 1000 + div(event.timestamp.nanos, 1_000_000)
    queue_duration = fetched_for_processing_at - emitted_at

    Watchman.submit(
      {"project_page.cache_invalidator.message_queue", [tag]},
      queue_duration,
      :timing
    )
  end

  defp invalidate_with_pipeline_id(pipeline_id) do
    Models.Pipeline.invalidate(pipeline_id)

    pipeline = Models.Pipeline.find_metadata(pipeline_id)

    Models.Workflow.invalidate(pipeline.workflow_id)

    project = Models.Project.find_by_id(pipeline.project_id)
    hook = Models.RepoProxy.find(pipeline.hook_id)

    ref_type = hook.type

    git_ref_type_params =
      struct!(ProjectPage.Model.LoadParams,
        project_id: project.id,
        organization_id: project.organization_id,
        user_page?: false,
        ref_types: [ref_type]
      )

    all_git_ref_types_params =
      struct!(ProjectPage.Model.LoadParams,
        project_id: project.id,
        organization_id: project.organization_id,
        user_page?: false,
        ref_types: [""]
      )

    if Application.get_env(:front, :preheat_project_page) == "true" do
      refresh_git_ref_type =
        Async.run(fn ->
          {:ok, _data, :from_api} = git_ref_type_params |> ProjectPage.Model.refresh()
        end)

      refresh_all_git_ref_types =
        Async.run(fn ->
          {:ok, _data, :from_api} = all_git_ref_types_params |> ProjectPage.Model.refresh()
        end)

      {:ok, _} = Async.await(refresh_git_ref_type)
      {:ok, _} = Async.await(refresh_all_git_ref_types)
    else
      invalidate_git_ref_type =
        Async.run(fn ->
          git_ref_type_params |> ProjectPage.Model.invalidate()
        end)

      invalidate_all_git_ref_types =
        Async.run(fn ->
          all_git_ref_types_params |> ProjectPage.Model.invalidate()
        end)

      {:ok, _} = Async.await(invalidate_git_ref_type)
      {:ok, _} = Async.await(invalidate_all_git_ref_types)
    end
  end
end
