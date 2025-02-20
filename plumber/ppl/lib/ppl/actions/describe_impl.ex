defmodule Ppl.Actions.DescribeImpl do
  @moduledoc """
  Module which implements Describe pipeline action
  """

  alias Ppl.Ppls.Model.PplsQueries
  alias Ppl.PplBlocks.Model.PplBlocksQueries
  alias LogTee, as: LT
  alias Util.ToTuple

  def describe(params) do
    with ppl_id when is_binary(ppl_id) <- Map.get(params, :ppl_id, missing_ppl_id_error()),
         true                <- valid_uuid(ppl_id, "Pipeline with id: '#{ppl_id}' not found."),
         detailed?           <- Map.get(params, :detailed, false),
         {:ok, ppl_details}  <- PplsQueries.get_details(ppl_id),
         {:ok, blks_details} <- get_block_details?(ppl_id, detailed?)
    do
      {:ok, ppl_details, blks_details}
    else
      e ->
        LT.error(e, "Describe request failure")
    end
  end

  defp missing_ppl_id_error(), do: {:error, "Invalid request - missing field ppl_id."}

  defp valid_uuid(uuid, error_message) do
    case UUID.info(uuid) do
      {:ok, _} -> true
      _ -> {:error, error_message}
    end
  end

  defp get_block_details?(_ppl_id, false), do: {:ok, []}
  defp get_block_details?(ppl_id, true) do
    case  PplBlocksQueries.get_all_by_id(ppl_id) do
      {:ok, ppl_blocks}
        -> get_blocks_details(ppl_id, ppl_blocks)
      {:error, "no ppl blocks for ppl with id:" <> _rest}
        -> {:ok, []}
      error -> error
    end
  end

  defp get_blocks_details(ppl_id, ppl_blocks) do
    case Block.list(ppl_id) do
      {:ok, executed_blk_details} ->

        ppl_blocks
        |> Enum.map(fn ppl_block -> form_block_description(ppl_block, executed_blk_details) end)
        |> ToTuple.ok()

      error -> error
    end
  end

  # block_id=nil covers all cases when block was not running (waiting, done-canceled, done-stuck)
  defp form_block_description(ppl_block = %{block_id: nil}, _) do
    %{block_id: "", name: ppl_block.name, build_req_id: "", jobs: []}
    |> Map.merge(extract_status(ppl_block))
    |> Map.put(:error_description, ppl_block.error_description || "")
  end

  defp form_block_description(ppl_block, blocks_details) do
    blocks_details
    |> Enum.find(fn details -> details.block_id == ppl_block.block_id end)
    |> Map.merge(%{name: ppl_block.name})
    |> Map.merge(extract_status(ppl_block))
  end

  defp extract_status(block),
    do: block |> Map.take([:state, :result, :result_reason])
end
