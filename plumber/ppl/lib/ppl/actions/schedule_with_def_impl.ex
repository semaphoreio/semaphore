defmodule Ppl.Actions.ScheduleWithDefImpl do
  @moduledoc """
  Module which implements Schedule pipeline action with given pipeline definition.
  """

  import Ecto.Query

  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.PplOrigins.Model.PplOriginsQueries
  alias Ppl.PplSubInits.STMHandler.CreatedState
  alias LogTee, as: LT
  alias Ecto.Multi
  alias Ppl.Actions.ScheduleImpl

  def schedule(ctx, definition, initial_definition, top_level?, initial_request?) do
    log_run_request(ctx)

    ctx
    |> ScheduleImpl.prepare_request_multi(top_level?, initial_request?, false)
    |> add_defintion_to_request(definition)
    |> save_initial_definition(initial_definition)
    |> ScheduleImpl.persist_request
    |> case do
      {:ok, %{ppl_req: ppl_req}} ->
          predicate = fn query -> query |> where(ppl_id: ^ppl_req.id) end
          CreatedState.execute_now_with_predicate(predicate)
          {:ok, ppl_req.id}
      error ->
          LT.error(error, "Schedule request with definition failure")
    end
  end

  @suppressed_attributes ~w(access_token client_secret)
  defp log_run_request(ctx) do
    ctx
    |> suppress_attributes(@suppressed_attributes)
    |> LT.info("Request: 'schedule with definition")
  end

  defp suppress_attributes(ctx, attribute_list) do
    attribute_list
    |> Enum.reduce(ctx, fn key, map -> Map.delete(map, key) end)
    |> Map.put("suppressed_attributes", attribute_list)
  end

  defp add_defintion_to_request(multi, definition) do
    multi
    |> Multi.run(:ppl_req_definition, fn _, %{ppl_req: ppl_req} ->
      PplRequestsQueries.insert_definition(ppl_req, definition) end)
  end

  defp save_initial_definition(multi, initial_definition) do
    multi
    # save inital_definition separately for easier debug
    |> Multi.run(:ppl_origins_definition, fn _, %{ppl_origins_request: ppl_or} ->
      PplOriginsQueries.save_definition(ppl_or, initial_definition) end)
  end
end
