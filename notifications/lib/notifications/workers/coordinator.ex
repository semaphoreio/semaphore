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
        project = Api.find_project(pipeline.project_id)
        hook = Api.find_hook(pipeline.hook_id)
        workflow = Api.find_workflow(pipeline.wf_id)

        Logger.info("#{request_id} #{event.pipeline_id} #{project.metadata.name}")

        rules =
          Filter.find_rules(
            project.metadata.org_id,
            project.metadata.name,
            pipeline.branch_name,
            hook.pr_branch_name,
            pipeline.yaml_file_name,
            map_result_to_string(pipeline.result)
          )

        Logger.info("#{request_id} #{event.pipeline_id} #{inspect(rules)}")

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

    defp map_result_to_string(enum), do: enum |> Atom.to_string() |> String.downcase()
  end
end
