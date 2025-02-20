defmodule Block.BlockRequests.Model.BlockRequestsQueries do
  @moduledoc """
  Blocks Queries
  Operations on Blocks type
  """

  require Block.Ctx

  import Ecto.Query

  alias LogTee, as: LT
  alias Block.EctoRepo, as: Repo
  alias Block.BlockRequests.Model.BlockRequests
  alias Block.Ctx

  def insert_request(params, change_set_fn \\ :changeset_request, log? \\ true) do
    ppl_id = Map.get(params, :ppl_id)
    index = Map.get(params, :pple_block_index)

    try do
      BlockRequests |> apply(change_set_fn, [%BlockRequests{}, params]) |> Repo.insert()
      |> process_response(ppl_id, index, log?)
    rescue
      e -> {:error, e}
    catch
      a, b -> {:error, [a, b]}
    end
  end

  defp process_response({:error, %Ecto.Changeset{errors: [ppl_id_and_blk_ind_unique_index: _message]}}, ppl_id, index, log?) do
    if log?, do: LT.info(ppl_id, "There is already block with index #{index} for pipeline with id: ")
    get_by_ppl_data(ppl_id, index)
  end
  defp process_response(block_req, ppl_id, index, true) do
    Ctx.event(block_req, "persisted block run request from ppl #{ppl_id} for block #{index}")
  end
  defp process_response(block_req, _ppl_id, _index, _log?), do: block_req

  def insert_build(block_req, params) do
    block_req |> BlockRequests.changeset_build(params) |> Repo.update()
    |> Ctx.event("persisted build and sub_ppl details for block_request: #{block_req.id}")
  rescue
    e ->
      {:error, e}
  end

  @doc """
  Duplicates passed BlockRequests and changes ppl_id and regenerates block_id.
  Used in partial rebuilding to avoid reruning passed blocks.
  """
  def duplicate(block_id, new_ppl_id) do
    BlockRequests |> Repo.get(block_id) |> change_ids(new_ppl_id) |> duplicate()
  end

  defp change_ids(block_req, new_ppl_id) do
    block_req |> Map.from_struct() |> Map.drop([:id, :ppl_id]) |> Map.put(:ppl_id, new_ppl_id)
  end

  defp duplicate(params) do
    insert_request(params, :changeset_duplicate, false)
  end
  
  @doc """
  Deletes all blocks which belong to given pipeline and all related data structures from DB.
  """
  def delete_blocks_from_ppl(ppl_id) do
    (from br in BlockRequests, 
          where: br.ppl_id == ^ppl_id)
    |> Repo.delete_all()
    |> return_number()
  rescue
    e -> {:error, e}
  end
  
  defp return_number({number, _}) when is_integer(number), do: {:ok, number}
  defp return_number(error), do: {:error, error}
  
  @doc """
  Finds block_request by block_id
  """
  def get_by_id(id) do
    BlockRequests |> Repo.get(id) |> get_id_response(id)
  rescue
    e -> {:error, e}
  end

  defp get_id_response(nil, block_id), do:
    {:error, {:block_request_not_found, block_id}}
  defp get_id_response(value, _), do: {:ok, value}


  @doc """
  Finds block_request by ppl_id and ppl_block_indesx
  """
  def get_by_ppl_data(ppl_id, pple_block_index) do
    BlockRequests |> where(ppl_id: ^ppl_id) |> where(pple_block_index: ^pple_block_index) |> Repo.one()
    |> ppl_data_response(ppl_id, pple_block_index)
  rescue
    e -> {:error, e}
  end

  defp ppl_data_response(nil, ppl_id, pple_block_index), do:
    {:error, {:block_not_found, ppl_id, pple_block_index}}
  defp ppl_data_response(value, _, _), do: {:ok, value}
end
