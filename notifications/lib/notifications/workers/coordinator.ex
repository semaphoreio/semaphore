defmodule Notifications.Workers.Coordinator do
  defmodule PipelineFinished do
    alias Notifications.Workers.Coordinator.Filter
    alias Notifications.Workers.Coordinator.Api

    require Logger

    use Tackle.Consumer,
      url: Application.get_env(:notifications, :amqp_url),
      exchange: "pipeline_state_exchange",
      routing_key: "done",
      service: "notifications.pipeline_finished"

    def handle_message(message) do
      Watchman.benchmark("pipeline_finished_notifier.duration", fn ->
        request_id = Ecto.UUID.generate()

        event = InternalApi.Plumber.PipelineEvent.decode(message)

        Logger.info("#{request_id} #{event.pipeline_id}")

        {pipeline, blocks} = Api.find_pipeline(event.pipeline_id)

        case Api.find_project(pipeline.project_id) do
          nil -> skip_without_project(request_id, pipeline)
          project -> notify(request_id, pipeline, blocks, project)
        end

        Logger.info("#{request_id} #{event.pipeline_id}")
      end)
    catch
      kind, reason ->
        stacktrace = __STACKTRACE__
        exception = Exception.normalize(kind, reason, stacktrace)

        _ =
          Sentry.capture_exception(
            exception,
            stacktrace: stacktrace,
            error_type: kind
          )

        :erlang.raise(kind, reason, stacktrace)
    end

    # A pipeline can finish after its project is deleted. With no project there
    # are no rules to match, so the event is acknowledged without notifying.
    defp skip_without_project(request_id, pipeline) do
      Watchman.increment("pipeline_finished_notifier.project_not_found")

      Logger.info(
        "#{request_id} #{pipeline.ppl_id} project #{pipeline.project_id} not found, skipping"
      )
    end

    defp notify(request_id, pipeline, blocks, project) do
      hook = find_hook(request_id, pipeline)
      workflow = Api.find_workflow(pipeline.wf_id)

      Logger.info("#{request_id} #{pipeline.ppl_id} #{project.metadata.name}")

      {tag_name, branch_name, pr_branch_name} = extract_references(pipeline, hook)

      rules =
        Filter.find_rules(
          project.metadata.org_id,
          project.metadata.name,
          branch_name,
          pr_branch_name,
          pipeline.yaml_file_name,
          map_result_to_string(pipeline.result),
          tag_name
        )

      Logger.info("#{request_id} #{pipeline.ppl_id} #{inspect(rules)}")

      # Used to construct the message
      organization = Api.find_organization(project.metadata.org_id)

      data = %{
        workflow: workflow,
        pipeline: pipeline,
        blocks: blocks,
        project: project,
        hook: hook,
        organization: organization
      }

      rules
      |> Enum.filter(&authorized?(&1.notification.creator_id, &1.org_id, project.metadata.id))
      |> Enum.each(fn rule -> process(request_id, rule, data) end)
    end

    # Messages for a pipeline without a hook are built from the pipeline itself.
    defp find_hook(request_id, pipeline) do
      case Api.find_hook(pipeline.hook_id) do
        nil ->
          Watchman.increment("pipeline_finished_notifier.hook_not_found")
          Logger.info("#{request_id} #{pipeline.ppl_id} hook #{pipeline.hook_id} not found")
          nil

        hook ->
          hook
      end
    end

    def process(request_id, rule, data) do
      Logger.info("#{request_id} [processing] #{inspect(rule)}")

      if rule.slack do
        s = Notifications.Models.Rule.decode_slack(rule.slack)

        Notifications.Workers.Slack.publish(request_id, s.endpoint, s.channels, data)
      end

      if rule.webhook do
        s = Notifications.Models.Rule.decode_webhook(rule.webhook)

        Notifications.Workers.Webhook.publish(request_id, s, data)
      end

      Logger.info("#{request_id} [done]")
    end

    defp authorized?(_creator_id = nil, _org_id, _project_id), do: true

    defp authorized?(creator_id, org_id, project_id) do
      case Notifications.Auth.can_view_project?(creator_id, org_id, project_id) do
        {:ok, :authorized} -> true
        _ -> false
      end
    end

    defp extract_references(pipeline, nil), do: extract_references_from_pipeline(pipeline)
    defp extract_references(_pipeline, hook = %{git_ref_type: :TAG}), do: {hook.tag_name, nil, ""}
    defp extract_references(pipeline, hook), do: {nil, pipeline.branch_name, hook.pr_branch_name}

    defp extract_references_from_pipeline(%{branch_name: "refs/tags/" <> tag_name}),
      do: {tag_name, nil, ""}

    defp extract_references_from_pipeline(%{branch_name: branch_name}), do: {nil, branch_name, ""}

    defp map_result_to_string(enum), do: enum |> Atom.to_string() |> String.downcase()
  end
end
