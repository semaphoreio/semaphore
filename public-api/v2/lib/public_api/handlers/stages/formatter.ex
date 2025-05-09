defmodule PublicAPI.Handlers.Stages.Formatter do
  @moduledoc false
  alias InternalApi.Delivery, as: API

  def describe(stage = %API.Stage{}, ctx) do
    {:ok, stage_from_pb(stage, ctx)}
  end

  def event(event = %API.StageEvent{}) do
    {:ok, stage_event_from_pb(event)}
  end

  def list_events(events) do
    {:ok,
     %{
       next_page_token: nil,
       page_size: 100,
       entries: Enum.map(events, fn event -> stage_event_from_pb(event) end)
     }}
  end

  defp stage_event_from_pb(event = %API.StageEvent{}) do
    %{
      id: event.id,
      source_id: event.source_id,
      source_type: connection_type_from_pb(event.source_type),
      state: event_state_from_pb(event.state),
      state_reason: event_state_reason_from_pb(event.state_reason),
      created_at: PublicAPI.Util.Timestamps.to_timestamp(event.created_at),
      tags: Enum.map(event.tags, fn tag ->
        %{name: tag.name, value: tag.value, state: tag_state_from_pb(tag.state)}
      end),
      approvals:
        Enum.map(event.approvals, fn approval ->
          %{
            approved_by: approval.approved_by,
            approved_at: PublicAPI.Util.Timestamps.to_timestamp(approval.approved_at)
          }
        end)
    }
  end

  defp event_state_from_pb(:STATE_PENDING), do: "PENDING"
  defp event_state_from_pb(:STATE_WAITING), do: "WAITING"
  defp event_state_from_pb(:STATE_PROCESSED), do: "PROCESSED"
  defp event_state_from_pb(_), do: nil

  defp event_state_reason_from_pb(:STATE_REASON_APPROVAL), do: "APPROVAL"
  defp event_state_reason_from_pb(:STATE_REASON_TIME_WINDOW), do: "TIME_WINDOW"
  defp event_state_reason_from_pb(:STATE_REASON_EXECUTION), do: "EXECUTION"
  defp event_state_reason_from_pb(:STATE_REASON_CONNECTION), do: "CONNECTION"
  defp event_state_reason_from_pb(:STATE_REASON_CANCELLED), do: "CANCELLED"
  defp event_state_reason_from_pb(:STATE_REASON_UNHEALTHY), do: "UNHEALTHY"
  defp event_state_reason_from_pb(_), do: nil

  defp tag_state_from_pb(:TAG_STATE_UNKNOWN), do: "UNKNOWN"
  defp tag_state_from_pb(:TAG_STATE_HEALTHY), do: "HEALTHY"
  defp tag_state_from_pb(:TAG_STATE_UNHEALTHY), do: "UNHEALTHY"
  defp tag_state_from_pb(_), do: nil

  def list(stages, ctx) do
    {:ok,
     %{
       next_page_token: nil,
       page_size: 100,
       entries: Enum.map(stages, fn stage -> stage_from_pb(stage, ctx) end)
     }}
  end

  defp stage_from_pb(stage = %API.Stage{}, ctx) do
    organization = %{id: stage.organization_id, name: ctx.organization.name}
    canvas = %{id: stage.canvas_id}

    %{
      apiVersion: "v2",
      kind: "Stage",
      metadata: %{
        id: stage.id,
        name: stage.name,
        organization: organization,
        canvas: canvas,
        timeline: %{
          created_at: PublicAPI.Util.Timestamps.to_timestamp(stage.created_at),
          created_by: nil
        }
      },
      spec: %{
        conditions: Enum.map(stage.conditions, fn condition -> condition_from_pb(condition) end),
        connections:
          Enum.map(stage.connections, fn connection -> connection_from_pb(connection) end),
        run: run_template_from_pb(stage.run_template),
        use: tag_usage_def_from_pb(stage.use)
      }
    }
  end

  defp tag_usage_def_from_pb(def = %API.TagUsageDefinition{}) do
    %{
      from: def.from,
      tags: Enum.map(def.tags, fn t ->
        %{name: t.name, valueFrom: t.valueFrom}
      end)
    }
  end

  defp run_template_from_pb(run_template = %API.RunTemplate{}) do
    %{
      type: run_template_type_from_pb(run_template.type),
      semaphore: semaphore_run_template_from_pb(run_template.type, run_template)
    }
  end

  defp run_template_from_pb(_), do: nil

  defp run_template_type_from_pb(:TYPE_SEMAPHORE), do: "SEMAPHORE"
  defp run_template_type_from_pb(_), do: ""

  defp semaphore_run_template_from_pb(:TYPE_SEMAPHORE, run_template = %API.RunTemplate{}) do
    task_id =
      if run_template.semaphore.task_id != "",
        do: run_template.semaphore.task_id,
        else: nil

    %{
      project_id: run_template.semaphore.project_id,
      branch: run_template.semaphore.branch,
      pipeline_file: run_template.semaphore.pipeline_file,
      task_id: task_id,
      parameters:
        Enum.map(run_template.semaphore.parameters, fn {key, value} ->
          %{name: key, value: value}
        end)
    }
  end

  defp semaphore_run_template_from_pb(_, _), do: nil

  defp condition_from_pb(condition = %API.Condition{}) do
    %{
      type: condition_type_from_pb(condition.type),
      approval: approval_condition_from_pb(condition.type, condition.approval),
      time_window: time_window_condition_from_pb(condition.type, condition.time_window)
    }
  end

  defp connection_from_pb(connection = %API.Connection{}) do
    %{
      type: connection_type_from_pb(connection.type),
      name: connection.name,
      filters: Enum.map(connection.filters, fn filter -> filter_from_pb(filter) end),
      filter_operator: filter_operator_from_pb(connection.filter_operator)
    }
  end

  defp filter_from_pb(filter = %API.Connection.Filter{}) do
    %{
      type: filter_type_from_pb(filter.type),
      data: data_filter_from_pb(filter.type, filter.data)
    }
  end

  defp filter_type_from_pb(:FILTER_TYPE_DATA), do: "DATA"
  defp filter_type_from_pb(_), do: ""

  defp data_filter_from_pb(:FILTER_TYPE_DATA, data) do
    %{expression: data.expression}
  end

  defp data_filter_from_pb(_, _), do: nil

  defp approval_condition_from_pb(:CONDITION_TYPE_APPROVAL, condition) do
    %{count: condition.count}
  end

  defp approval_condition_from_pb(_, _), do: nil

  defp time_window_condition_from_pb(:CONDITION_TYPE_TIME_WINDOW, condition) do
    %{start: condition.start, end: condition.end, week_days: condition.week_days}
  end

  defp time_window_condition_from_pb(_, _), do: nil

  defp connection_type_from_pb(:TYPE_STAGE), do: "STAGE"
  defp connection_type_from_pb(:TYPE_EVENT_SOURCE), do: "EVENT_SOURCE"
  defp connection_type_from_pb(_), do: ""

  defp condition_type_from_pb(:CONDITION_TYPE_APPROVAL), do: "APPROVAL"
  defp condition_type_from_pb(:CONDITION_TYPE_TIME_WINDOW), do: "TIME_WINDOW"
  defp condition_type_from_pb(_), do: ""

  defp filter_operator_from_pb(:FILTER_OPERATOR_AND), do: "AND"
  defp filter_operator_from_pb(:FILTER_OPERATOR_OR), do: "OR"
  defp filter_operator_from_pb(_), do: ""
end
