defmodule Block.BlockSubppls.Model.BlockSubpplsQueries do
  @moduledoc """
  Block Subppl Queries
  Operations on Block Subppl type

  'pending' - initial block subppl state.
  Ready to send run request to ppl service
  From 'pending' block subppl transitions to 'running' or 'done'.

  'running'
  Block subppl execution is still in progress.
  The request will be fetched by some looper later and checked again.
  From 'running' block subppl transitions to 'stopping' or 'done'.

  'stopping'
  Subppl's termination is started, waiting for it to be finished in ppl service.
  From 'stopping' block subppl transitions to 'done'.

  'done' - terminal state
  Subppl's execution is done and execution result is saved in 'result' field.
  """
  import Ecto.Query

  alias Ecto.Multi
  alias Block.EctoRepo, as: Repo
  alias Block.BlockSubppls.Model.BlockSubppls


  def multi_insert(multi, blk_req, {subppl_file_path, block_subppl_index}) do
    params = %{block_id: blk_req.id}
      |> Map.put(:state, "pending")
      |> Map.put(:in_scheduling, "false")
      |> Map.put(:subppl_file_path, subppl_file_path)
      |> Map.put(:block_subppl_index, block_subppl_index)

    changeset = BlockSubppls.changeset(%BlockSubppls{}, params)
    name = "block_subppl_#{block_subppl_index}"
    Multi.insert(multi, String.to_atom(name), changeset)
  end

  def terminate(subppl, t_request, t_request_desc) do
    params = %{terminate_request: t_request, terminate_request_desc: t_request_desc}
    subppl
    |> BlockSubppls.changeset(params)
    |> Repo.update()
  end

  def get_by_block_data(block_id, block_index) do
      BlockSubppls
      |> where(block_id: ^block_id)
      |> where(block_subppl_index: ^block_index)
      |> Repo.one()
      |> return_tuple("no subppl for block: #{block_id} with index: #{block_index} found")
    rescue
      e -> {:error, e}
  end

  def get_all_by_id(id) do
      BlockSubppls
      |> where(block_id: ^id)
      |> order_by([p], [asc: p.block_subppl_index])
      |> Repo.all()
      |> return_tuple("no subppl's for block with id: #{id} found")
    rescue
      e -> {:error, e}
  end

  defp return_tuple(nil, nil_msg), do: return_error_tuple(nil_msg)
  defp return_tuple([], empty_msg), do: return_error_tuple(empty_msg)
  defp return_tuple(value, _),     do: return_ok_tuple(value)

  defp return_ok_tuple(value), do: {:ok, value}

  defp return_error_tuple(value), do: {:error, value}
end
