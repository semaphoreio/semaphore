defmodule Ppl.Actions.TerminateImpl do
  @moduledoc """
  Module which implements Terminate pipeline action
  """

  alias Ppl.Ppls.Model.{PplsQueries, Ppls}
  alias LogTee, as: LT
  alias Ppl.EctoRepo, as: Repo
  alias Ppl.Ppls.STMHandler.RunningState, as: PplRunningState
  alias Ppl.Ppls.STMHandler.QueuingState, as: PplQueuingState
  import Ecto.Query

  def terminate(params) do
    params |> LT.info("Request: 'terminate', request")

    with ppl_id when is_binary(ppl_id) <- Map.get(params, "ppl_id", missing_ppl_id_error()),
         terminated_by when is_binary(terminated_by) <- Map.get(params, "requester_id", missing_terminated_by()),
         true       <- valid_uuid(ppl_id, "Pipeline with id: '#{ppl_id}' not found."),
         {:ok, ppl} <- PplsQueries.get_by_id(ppl_id),
         response = {:ok, _message} <- terminate_ppl(ppl, terminated_by, ppl.state)
    do
      response
    else
      error ->
        LT.error(error, "Terminate request failure")
    end
  end

  defp missing_ppl_id_error(), do: {:error, "Invalid request - missing field ppl_id."}
  defp missing_terminated_by(), do: {:error, "Invalid request - missing field requester_id."}

  defp terminate_ppl(_ppl, _terminated_by, "stopping"),  do: {:ok, "Pipeline termination started."}
  defp terminate_ppl(_ppl, _terminated_by, "done"),      do: {:ok, "Pipeline termination started."}
  defp terminate_ppl(ppl, terminated_by, _state) do
    ppl
    |> Ppls.changeset(termination_params(terminated_by))
    |> Repo.update()
    |> trigger_state_handlers(ppl.ppl_id)
    |> respond_terminated()
  end

  defp termination_params(terminated_by) do
    %{terminate_request: "stop",
      terminate_request_desc: "API call",
      terminated_by: terminated_by
    }
  end

  defp trigger_state_handlers(resp = {:ok, _}, ppl_id) do
    query_fun = fn query -> query |> where(ppl_id: ^ppl_id) end

    query_fun |> PplQueuingState.execute_now_with_predicate()
    query_fun |> PplRunningState.execute_now_with_predicate()

    resp
  end
  defp trigger_state_handlers(error, _ppl_id), do: error

  defp respond_terminated({:ok, _}), do: {:ok, "Pipeline termination started."}
  defp respond_terminated(error), do: error

  defp valid_uuid(uuid, error_message) do
    case UUID.info(uuid) do
      {:ok, _} -> true
      _ -> {:error, error_message}
    end
  end
end
