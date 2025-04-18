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
    {:ok, %{
      next_page_token: nil,
      page_size: 100,
      entries: Enum.map(events, fn event -> stage_event_from_pb(event) end)
    }}
  end

  defp stage_event_from_pb(%API.StageEvent{} = event) do
    %{
      id: event.id,
      source_id: event.source_id,
      source_type: connection_type_from_pb(event.source_type),
      state: event_state_from_pb(event.state),
      created_at: PublicAPI.Util.Timestamps.to_timestamp(event.created_at),
      approved_at: PublicAPI.Util.Timestamps.to_timestamp(event.approved_at),
      approved_by: nil
    }
  end

  defp event_state_from_pb(:PENDING), do: "PENDING"
  defp event_state_from_pb(:WAITING_FOR_APPROVAL), do: "WAITING_FOR_APPROVAL"
  defp event_state_from_pb(:PROCESSED), do: "PROCESSED"
  defp event_state_from_pb(_), do: ""

  def list(stages, ctx) do
    {:ok, %{
      next_page_token: nil,
      page_size: 100,
      entries: Enum.map(stages, fn stage -> stage_from_pb(stage, ctx) end)
    }}
  end

  defp stage_from_pb(%API.Stage{} = stage, ctx) do
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
        approval_required: stage.approval_required,
        connections: Enum.map(stage.connections, fn connection -> connection_from_pb(connection) end),
        run: run_template_from_pb(stage.run_template)
      }
    }
  end

  defp run_template_from_pb(%API.RunTemplate{} = run_template) do
    %{
      type: run_template_type_from_pb(run_template.type),
      semaphore: semaphore_run_template_from_pb(run_template.type, run_template)
    }
  end

  defp run_template_from_pb(_), do: nil

  defp run_template_type_from_pb(:TYPE_SEMAPHORE), do: "SEMAPHORE"
  defp run_template_type_from_pb(_), do: ""

  defp semaphore_run_template_from_pb(:TYPE_SEMAPHORE, %API.RunTemplate{} = run_template) do
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

  defp connection_from_pb(%API.Connection{} = connection) do
    %{
      type: connection_type_from_pb(connection.type),
      name: connection.name,
      filters: Enum.map(connection.filters, fn filter -> filter_from_pb(filter) end),
      filter_operator: filter_operator_from_pb(connection.filter_operator)
    }
  end

  defp filter_from_pb(%API.Connection.Filter{} = filter) do
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

  defp connection_type_from_pb(:TYPE_STAGE), do: "STAGE"
  defp connection_type_from_pb(:TYPE_EVENT_SOURCE), do: "EVENT_SOURCE"
  defp connection_type_from_pb(_), do: ""

  defp filter_operator_from_pb(:FILTER_OPERATOR_AND), do: "AND"
  defp filter_operator_from_pb(:FILTER_OPERATOR_OR), do: "OR"
  defp filter_operator_from_pb(_), do: ""
end
