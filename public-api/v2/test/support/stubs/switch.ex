defmodule Support.Stubs.Switch do
  alias Support.Stubs.DB

  require Logger

  def init do
    DB.add_table(:switches, [:id, :pipeline_id])
    DB.add_table(:targets, [:id, :switch_id, :name, :parameter_env_vars])
    DB.add_table(:trigger_events, [:id, :target_id, :api_model])

    __MODULE__.Grpc.init()
  end

  def create(pipeline_id) do
    DB.insert(:switches, %{id: UUID.uuid4(), pipeline_id: pipeline_id})
  end

  def add_target(switch, params \\ []) do
    defaults = [
      id: UUID.uuid4(),
      switch_id: switch.id,
      name: "production",
      parameter_env_vars: []
    ]

    target = defaults |> Keyword.merge(params) |> Enum.into(%{})

    DB.insert(:targets, target)

    target
  end

  def add_parameter(target_name, params) do
    target = DB.find_by(:targets, :name, target_name)

    target |> Map.merge(%{parameter_env_vars: params})

    DB.update(:targets, target)
  end

  def add_trigger_event(target, params \\ []) do
    alias InternalApi.Gofer.TriggerEvent
    now = DateTime.utc_now() |> DateTime.to_unix()

    params_with_defaults =
      [
        target_name: target.name,
        triggered_at: %Google.Protobuf.Timestamp{seconds: now},
        processed: false
      ]
      |> Keyword.merge(params)

    api_model = struct(TriggerEvent, params_with_defaults)

    trigger_event = %{
      id: UUID.uuid4(),
      target_id: target.id,
      api_model: api_model
    }

    DB.insert(:trigger_events, trigger_event)
  end

  defmodule Grpc do
    def init do
      GrpcMock.stub(GoferMock, :trigger, &__MODULE__.trigger/2)
      GrpcMock.stub(GoferMock, :list_trigger_events, &__MODULE__.list_trigger_events/2)
    end

    def trigger(req, _) do
      case find_target(req.switch_id, req.target_name) do
        nil ->
          %InternalApi.Gofer.TriggerResponse{response_status: status_not_found()}

        target ->
          Support.Stubs.Switch.add_trigger_event(target)
          %InternalApi.Gofer.TriggerResponse{response_status: status_ok()}
      end
    end

    def list_trigger_events(req, _) do
      targets = DB.find_all_by(:targets, :switch_id, req.switch_id)

      trigger_events =
        targets
        |> Enum.map(fn target ->
          DB.find_all_by(:trigger_events, :target_id, target.id) |> DB.extract(:api_model)
        end)
        |> List.flatten()

      Logger.info("Found trigger events: #{inspect(trigger_events)}")

      %InternalApi.Gofer.ListTriggerEventsResponse{
        response_status: status_ok(),
        trigger_events: trigger_events,
        page_number: 1,
        page_size: 10,
        total_entries: Enum.count(trigger_events),
        total_pages: 1
      }
    end

    defp find_target(switch_id, target_name) do
      DB.filter(:targets,
        switch_id: switch_id,
        name: target_name
      )
      |> List.first()
    end

    defp status_not_found do
      %InternalApi.Gofer.ResponseStatus{
        code: InternalApi.Gofer.ResponseStatus.ResponseCode.value(:NOT_FOUND)
      }
    end

    defp status_ok do
      %InternalApi.Gofer.ResponseStatus{
        code: InternalApi.Gofer.ResponseStatus.ResponseCode.value(:OK)
      }
    end
  end
end
