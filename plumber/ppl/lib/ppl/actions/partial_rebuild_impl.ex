defmodule Ppl.Actions.PartialRebuildImpl do
  @moduledoc """
  Module which implements partial_rebuild action with given original pipeline id.
  """

  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.PplSubInits.Model.PplSubInitsQueries
  alias Ppl.PplOrigins.Model.PplOriginsQueries
  alias Ppl.PplTraces.Model.PplTracesQueries
  alias Ppl.Ppls.Model.PplsQueries
  alias LogTee, as: LT
  alias Ppl.PplSubInits.STMHandler.CreatedState
  alias Ppl.EctoRepo, as: Repo
  alias Ecto.Multi
  alias Looper.STM.Publisher
  alias Ppl.Ppls.STMHandler.Common
  alias Ppl.Actions.ScheduleImpl
  alias Util.ToTuple

  defp publish_retry_count(), do: Application.get_env(:ppl, :publish_retry_count)
  defp publish_timeout(), do: Application.get_env(:ppl, :publish_timeout)

  def partial_rebuild(params) do
    params
    |> LT.info("Request: 'partial_rebuild', request")
    |> partial_rebuild_transaction()
    |> case do
        {:ok, %{ppl_req: ppl_req}} ->
          with {:ok, args} <- prepare_publisher_args(ppl_req.id),
               _result     <-  Wormhole.capture(Publisher, :publish, args, stacktrace: true,
                                 retry_count: publish_retry_count(), timeout_ms: publish_timeout()),
               :ok         <- CreatedState.execute_now(),
          do: {:ok, ppl_req.id}

        # Idempotency -> return {:ok, ...}
        {:error, :ppl_req, {:request_token_exists, request_token}, _} ->
          with {:ok, ppl_req}  <- PplRequestsQueries.get_by_request_token(request_token),
          do: {:ok, ppl_req.id}

        error ->
          LT.error(error, "Partial rebuild request failure")
    end
  end

  defp partial_rebuild_transaction(request) do
    Multi.new()
    # duplicate original ppl request with new ppl_id and without definition
    |> Multi.run(:ppl_req, fn _, _ ->
      PplRequestsQueries.duplicate(request.ppl_id, request.request_token, request.user_id) end)
    # insert pipeline based on that request and set partial_rebuild_of field
    |> Multi.run(:ppl, fn _, %{ppl_req: ppl_req} ->
      PplsQueries.insert(ppl_req, request.ppl_id) end)
    # update pipeline to include wf_number
    |> Multi.run(:wf_num, fn _, %{ppl_req: ppl_req, ppl: ppl} ->
      ScheduleImpl.set_workflow_number(ppl, ppl_req, false) end)
    # insert pipeline sub init of 'rebuild' type for this pipeline
    |> Multi.run(:ppl_sub_init, fn _, %{ppl_req: ppl_req} ->
      PplSubInitsQueries.insert(ppl_req, "rebuild") end)
    # save inital_request separately for easier debug
    |> Multi.run(:ppl_origins_request, fn _, %{ppl_req: ppl_req} ->
      PplOriginsQueries.insert(ppl_req.id, request |> Map.put(:type, "partial_rebuild_request")) end)
    # create ppl trace for this pipeline
    |> Multi.run(:ppl_trace, fn _, %{ppl: ppl} ->
      PplTracesQueries.insert(ppl) end)
    |> Repo.transaction()
  end

  defp prepare_publisher_args(ppl_id) do
    [
      _ids       = %{ppl_id: ppl_id},
      _state     = "initializing",
      _encode_cb = fn params -> Common.publisher_callback(params) end
    ] |> ToTuple.ok()
  end
end
