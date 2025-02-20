defmodule Ppl.Ppls.Model.Triggerer do
  @moduledoc """
  Parses Triggerer data from the pipeline definition and returns a map with the parsed data.
  """

  alias __MODULE__

  @type wf_triggered_by :: InternalApi.PlumberWF.TriggeredBy.t()
  @type ppl_triggered_by :: InternalApi.Plumber.TriggeredBy.t()
  @type grpc_response :: %{
    wf_triggered_by: wf_triggered_by(),
    wf_triggerer_id: String.t(),
    wf_triggerer_user_id: String.t(),
    wf_triggerer_provider_login: String.t(),
    wf_triggerer_provider_uid: String.t(),
    wf_triggerer_provider_avatar: String.t(),
    ppl_triggered_by: ppl_triggered_by(),
    ppl_triggerer_id: String.t(),
    ppl_triggerer_user_id: String.t(),
    workflow_rerun_of: String.t()
  }

  @type t :: %Triggerer{
    initial_request: boolean(),
    hook_id: String.t(),
    provider_uid: String.t(),
    provider_author: String.t(),
    provider_avatar: String.t(),
    triggered_by: String.t(),
    auto_promoted: boolean(),
    promoter_id: String.t(),
    requester_id: String.t(),
    scheduler_task_id: String.t(),
    partially_rerun_by: String.t(),
    partial_rerun_of: String.t(),
    promotion_of: String.t(),
    wf_rebuild_of: String.t(),
    workflow_id: String.t()
  }

  defstruct [
    :initial_request,
    :hook_id,
    :provider_uid,
    :provider_author,
    :provider_avatar,
    :triggered_by,
    :auto_promoted,
    :promoter_id,
    :requester_id,
    :scheduler_task_id,
    :partially_rerun_by,
    :partial_rerun_of,
    :promotion_of,
    :wf_rebuild_of,
    :workflow_id
  ]

  @spec to_grpc(model :: t()) :: grpc_response()
  def to_grpc(model) do
    with provider <- parse_provider(model),
         wf_triggerer <- parse_workflow_triggerer(model),
         ppl_triggerer <- parse_pipeline_triggerer(model),
         rerun_data <- parse_wf_rerun(model) do
      [
        provider,
        wf_triggerer,
        ppl_triggerer,
        rerun_data
      ]
      |> Enum.reduce(%{}, &Map.merge(&1, &2))
    end
  end

  @spec parse_provider(model :: t()) :: grpc_response()
  defp parse_provider(model) do
    %{
      wf_triggerer_provider_login: model.provider_author,
      wf_triggerer_provider_uid: model.provider_uid,
      wf_triggerer_provider_avatar: model.provider_avatar
    }
  end

  @spec parse_workflow_triggerer(model :: t()) :: grpc_response()
  defp parse_workflow_triggerer(model) do
    model.triggered_by
    |> case do
      "api" ->
        %{
          wf_triggered_by: InternalApi.PlumberWF.TriggeredBy.value(:API),
          wf_triggerer_id: "",
          wf_triggerer_user_id: model.requester_id
        }
      "schedule" ->
        %{
          wf_triggered_by: InternalApi.PlumberWF.TriggeredBy.value(:SCHEDULE),
          wf_triggerer_id: model.scheduler_task_id,
          wf_triggerer_user_id: model.requester_id
        }
      "manual_run" ->
        %{
          wf_triggered_by: InternalApi.PlumberWF.TriggeredBy.value(:MANUAL_RUN),
          wf_triggerer_id: model.scheduler_task_id,
          wf_triggerer_user_id: model.requester_id
        }

      # Hook and fallback
      _ ->
        %{
          wf_triggered_by: InternalApi.PlumberWF.TriggeredBy.value(:HOOK),
          wf_triggerer_id: model.hook_id,
          wf_triggerer_user_id: model.requester_id
        }
    end
  end

  @spec parse_pipeline_triggerer(model :: t()) :: grpc_response()
  defp parse_pipeline_triggerer(model) do
    cond do
      model.initial_request == true ->
        %{
          ppl_triggered_by: InternalApi.Plumber.TriggeredBy.value(:WORKFLOW),
          ppl_triggerer_id: model.workflow_id,
          ppl_triggerer_user_id: model.requester_id
        }

      model.partial_rerun_of != "" ->
        %{
          ppl_triggered_by: InternalApi.Plumber.TriggeredBy.value(:PARTIAL_RE_RUN),
          ppl_triggerer_id: model.partial_rerun_of,
          ppl_triggerer_user_id: model.partially_rerun_by
        }

      model.auto_promoted == true ->
        %{
          ppl_triggered_by: InternalApi.Plumber.TriggeredBy.value(:AUTO_PROMOTION),
          ppl_triggerer_id: model.promotion_of,
          ppl_triggerer_user_id: ""
        }

      model.auto_promoted == false && model.promoter_id != "" ->
        %{
          ppl_triggered_by: InternalApi.Plumber.TriggeredBy.value(:PROMOTION),
          ppl_triggerer_id: model.promotion_of,
          ppl_triggerer_user_id: model.promoter_id
        }


      true ->
        %{
          ppl_triggered_by: InternalApi.Plumber.TriggeredBy.value(:WORKFLOW),
          ppl_triggerer_id: model.workflow_id,
          ppl_triggerer_user_id: model.requester_id
        }
    end
  end

  @spec parse_wf_rerun(model :: t()) :: grpc_response()
  defp parse_wf_rerun(model) do
    %{
      workflow_rerun_of: model.wf_rebuild_of
    }
  end
end
