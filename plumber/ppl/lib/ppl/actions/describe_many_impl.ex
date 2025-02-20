defmodule Ppl.Actions.DescribeManyImpl do
  @moduledoc """
  Module which implements DescribeMany pipelines action
  """

  alias Ppl.Ppls.Model.PplsQueries
  alias LogTee, as: LT
  alias Util.ToTuple

  def describe_many(request) do
    request
    |> Map.get(:ppl_ids)
    |> Enum.find(:all_ids_uuid, fn x -> not_uuid(x) end)
    |> describe_many_(request.ppl_ids)
    |> ToTuple.ok()
  rescue
    error in [RuntimeError] ->
      error.message |> LT.error("Describe_many request failure") |> ToTuple.error()
  end

  defp not_uuid(id) do
    case UUID.info(id) do
      {:ok, _} -> false
      _ -> true
    end
  end

  defp describe_many_(:all_ids_uuid, ppl_ids) do
    Enum.map(ppl_ids, fn ppl_id ->
      case PplsQueries.get_details(ppl_id) do
        {:ok, ppl_details} -> ppl_details
        {:error, message} -> raise(message)
      end
    end)
  end
  defp describe_many_(invalid_id, _ppl_ids),
    do: raise("Pipeline with id: '#{invalid_id}' not found.")
end
