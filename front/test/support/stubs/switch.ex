defmodule Support.Stubs.Switch do
  alias Support.Stubs.{DB, UUID}

  def init do
    DB.add_table(:switches, [:id, :pipeline_id])
    DB.add_table(:targets, [:id, :switch_id, :name, :parameter_env_vars, :dt_description])
    DB.add_table(:trigger_events, [:id, :target_id, :api_model])

    __MODULE__.Grpc.init()
  end

  def create(pipeline_id) do
    DB.insert(:switches, %{id: UUID.gen(), pipeline_id: pipeline_id})
  end

  def add_target(switch, params \\ []) do
    defaults = [
      id: UUID.gen(),
      switch_id: switch.id,
      name: "production",
      parameter_env_vars: [],
      dt_description: nil
    ]

    target = defaults |> Keyword.merge(params) |> Enum.into(%{})

    DB.insert(:targets, target)

    target
  end

  def remove_all_targets(switch) do
    DB.delete(:targets, &(&1.switch_id == switch.id))
  end

  def remove_target(target) do
    DB.delete(:targets, target.id)
  end

  def add_parameter(target_name, params) do
    target = DB.find_by(:targets, :name, target_name)

    target |> Map.merge(%{parameter_env_vars: params})

    DB.update(:targets, target)
  end

  def add_trigger_event(target, params \\ []) do
    alias InternalApi.Gofer.TriggerEvent
    now = DateTime.utc_now() |> DateTime.to_unix()

    defaults = [
      target_name: target.name,
      triggered_at: Google.Protobuf.Timestamp.new(seconds: now),
      processed: false
    ]

    api_model = defaults |> Keyword.merge(params) |> TriggerEvent.new()

    trigger_event = %{
      id: UUID.gen(),
      target_id: target.id,
      api_model: api_model
    }

    DB.insert(:trigger_events, trigger_event)
  end

  defmodule Grpc do
    alias InternalApi.Gofer.{
      DescribeResponse,
      TargetDescription
    }

    def init do
      GrpcMock.stub(GoferMock, :describe, &__MODULE__.describe_switch/2)
      GrpcMock.stub(GoferMock, :trigger, &__MODULE__.trigger/2)
    end

    def trigger(_, _) do
      Support.Factories.Gofer.succeeded_trigger_response()
    end

    def describe_switch(req, _) do
      DB.find(:switches, req.switch_id)
      |> case do
        nil ->
          # some pipelines don't have switches
          DescribeResponse.new(response_status: status_not_found())

        switch ->
          targets = DB.find_all_by(:targets, :switch_id, req.switch_id)
          pipeline = DB.find(:pipelines, switch.pipeline_id)

          if Support.Stubs.Pipeline.initializing?(pipeline) do
            # pipeline in the initialization phase don't have promotions
            DescribeResponse.new(response_status: status_not_found())
          else
            DescribeResponse.new(
              response_status: status_ok(),
              ppl_id: switch.pipeline_id,
              switch_id: switch.id,
              targets: map_targets_to_response(targets)
            )
          end
      end
    end

    defp status_ok do
      ok = InternalApi.Gofer.ResponseStatus.ResponseCode.value(:OK)

      InternalApi.Gofer.ResponseStatus.new(code: ok)
    end

    defp status_not_found do
      ok = InternalApi.Gofer.ResponseStatus.ResponseCode.value(:NOT_FOUND)

      InternalApi.Gofer.ResponseStatus.new(code: ok)
    end

    defp map_targets_to_response(targets) do
      targets |> Enum.map(fn target -> construct_target_response(target) end)
    end

    defp construct_target_response(target) do
      trigger_events =
        DB.find_all_by(:trigger_events, :target_id, target.id) |> DB.extract(:api_model)

      TargetDescription.new(
        name: target.name,
        trigger_events: trigger_events,
        parameter_env_vars:
          Enum.map(target.parameter_env_vars, fn p ->
            InternalApi.Gofer.ParamEnvVar.new(p)
          end),
        dt_description: construct_dt_description(target.dt_description)
      )
    end

    defp construct_dt_description(dt_description) when is_map(dt_description),
      do: Util.Proto.deep_new!(InternalApi.Gofer.DeploymentTargetDescription, dt_description)

    defp construct_dt_description(nil), do: nil
  end
end
