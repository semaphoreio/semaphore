defmodule Front.Models.Switch do
  require Logger

  alias Front.Clients
  alias Front.Models
  alias InternalApi.Gofer
  alias InternalApi.Gofer.{DescribeRequest, Target, TriggerEvent, TriggerRequest}

  defstruct [
    :id,
    :targets,
    :pipeline_id,
    :pipeline
  ]

  defmodule Target do
    defstruct [:switch_id, :name, :events, :parameters, :deployment]

    def construct(switch_id, raw) do
      %__MODULE__{
        switch_id: switch_id,
        name: raw.name,
        events: Enum.map(raw.trigger_events, &Models.Switch.TriggerEvent.construct/1),
        parameters: raw.parameter_env_vars,
        deployment: Models.Switch.Deployment.construct(raw.dt_description)
      }
    end

    def trigger(target, user_id, parameter_env_vars \\ [], _tracing_headers \\ nil) do
      request =
        TriggerRequest.new(
          switch_id: target.switch_id,
          target_name: target.name,
          triggered_by: user_id,
          request_token: random_string(64),
          override: true,
          env_variables: parameter_env_vars
        )

      if is_nil(target.deployment) || target.deployment.allowed? do
        {:ok, response} = Clients.Gofer.trigger(request)

        case Gofer.ResponseStatus.ResponseCode.key(response.response_status.code) do
          :OK -> {:ok, nil}
          code -> {:error, code, response.response_status.message}
        end
      else
        {:error, :REFUSED, "Triggering promotion blocked by deployment target"}
      end
    end

    def random_string(length) do
      :crypto.strong_rand_bytes(length) |> Base.url_encode64() |> binary_part(0, length)
    end
  end

  defmodule TriggerEvent do
    alias InternalApi.Gofer.TriggerEvent

    defstruct [
      :result,
      :triggered_by,
      :triggered_at,
      :pipeline_id,
      :processed,
      :author,
      :auto_triggered,
      :error_response
    ]

    def construct(raw) do
      %__MODULE__{
        result: TriggerEvent.ProcessingResult.key(raw.processing_result),
        triggered_by: raw.triggered_by,
        pipeline_id: raw.scheduled_pipeline_id,
        processed: raw.processed,
        triggered_at: raw.triggered_at.seconds,
        auto_triggered: raw.auto_triggered,
        error_response: raw.error_response
      }
    end
  end

  def find(id, requester_id) when not is_binary(requester_id), do: find(id, "")

  def find(id, requester_id) do
    # Note: This will only return 10 events per target. We need more.
    request =
      DescribeRequest.new(switch_id: id, events_per_target: 99, requester_id: requester_id)

    with false <- Application.get_env(:front, :hide_promotions, false),
         {:ok, response} <- Clients.Gofer.describe(request),
         :OK <- Gofer.ResponseStatus.ResponseCode.key(response.response_status.code) do
      construct(response)
    else
      _ -> nil
    end
  end

  def construct(raw) do
    %__MODULE__{
      id: raw.switch_id,
      pipeline_id: raw.ppl_id,
      targets:
        Enum.map(raw.targets, fn t ->
          Models.Switch.Target.construct(raw.switch_id, t)
        end)
    }
  end

  def preload_users(switch) when is_nil(switch), do: nil

  def preload_users(switch) do
    users = extract_user_ids(switch) |> Models.User.find_many()

    Map.put(
      switch,
      :targets,
      Enum.map(switch.targets, fn target ->
        Map.put(
          target,
          :events,
          Enum.map(target.events, fn event ->
            Map.put(event, :author, find_trigger_author(event, users))
          end)
        )
      end)
    )
  end

  def extract_user_ids(switch) do
    Enum.map(switch.targets, fn target -> target.events end)
    |> List.flatten()
    |> Enum.map(fn event -> event.triggered_by end)
  end

  def preload_pipelines(switch) when is_nil(switch), do: nil

  def preload_pipelines(switch) do
    pipelines = extract_pipeline_ids(switch) |> Models.Pipeline.find_many()

    Map.put(
      switch,
      :targets,
      Enum.map(switch.targets, fn target ->
        Map.put(
          target,
          :events,
          Enum.map(target.events, fn event ->
            Map.put(event, :pipeline, find_triggered_pipeline(event, pipelines))
          end)
        )
      end)
    )
  end

  def extract_pipeline_ids(switch) do
    Enum.map(switch.targets, fn target -> target.events end)
    |> List.flatten()
    |> Enum.map(fn event -> event.pipeline_id end)
    |> Enum.filter(fn pipeline_id -> pipeline_id != "" end)
  end

  def find_triggered_pipeline(event, pipelines) do
    Enum.find(pipelines, fn pipeline -> event.pipeline_id == pipeline.id end)
  end

  def find_trigger_author(event, users) do
    Enum.find(users, fn user -> event.triggered_by == user.id end)
  end

  def find_target_by_name(switch, name) do
    Enum.find(switch.targets, fn t -> t.name == name end)
  end

  def find_event_by_pipeline_id(switch, pipeline_id) do
    Enum.map(switch.targets, fn target -> target.events end)
    |> List.flatten()
    |> Enum.find(fn event -> event.pipeline_id == pipeline_id end)
  end

  defmodule Deployment do
    defstruct [:id, :name, :allowed?, :reason, :message]

    def construct(nil), do: nil

    def construct(raw) do
      alias InternalApi.Gofer.DeploymentTargetDescription.Access.Reason
      reason = Reason.key(raw.access.reason)
      message = raw.access.message

      %__MODULE__{
        id: raw.target_id,
        name: raw.target_name,
        allowed?: raw.access.allowed,
        reason: reason,
        message: message
      }
    end
  end
end
