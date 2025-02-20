defmodule Ppl.PplBlocks.Model.PplBlockConectionsQueries do
  @moduledoc false

  import Ecto.Query

  alias Ppl.PplBlocks.Model.{PplBlocksQueries, PplBlockConnections}
  alias Ecto.Multi
  alias Ppl.EctoRepo, as: Repo
  alias Util.ToTuple

  @doc """
  The requirement is that PplBlocks for the ppl_id are already created.

  This operation is called on Ppl transition from pendin/queuing to running.
  """
  def multi_insert(multi, ppl_req) do
    multi
    |> compute_connections(ppl_req)
    |> persist_connections
  end

  defp compute_connections(multi, ppl_req) do
    Multi.run(multi, :compute_connections, fn _, _ ->
      {:ok, ppl_blocks} = PplBlocksQueries.get_all_by_id(ppl_req.id)

      block_deps(ppl_req)
      # replace PplBlock names with PplBlock id for all PplBlocks
      |> Enum.map(fn {target, deps} ->
        {name2ppl_block_id(target, ppl_blocks), Enum.map(deps, &name2ppl_block_id(&1, ppl_blocks))}
      end)
      # {target, [dep1, dep2, ...]} ==> [{target, dep1}, {target, dep2}, ...]
      |> Enum.map(fn {target, deps} ->
        [List.duplicate(target, length(deps)), deps]
        |> Enum.zip
      end)
      |> List.flatten
      |> ToTuple.ok
    end)
  end

  defp persist_connections(multi) do
    Multi.run(multi, :persist_connections, fn _, executed ->
      executed
      |> Map.get(:compute_connections)
      |> Enum.reduce(Multi.new, fn connection = {t, d}, multi ->
        name = String.to_atom("ppl_block_connection#{inspect connection}")
        changeset = PplBlockConnections.changeset(
          %PplBlockConnections{}, %{target: t, dependency: d})
        Multi.insert(multi, name, changeset)
      end)
      |> Repo.transaction
    end)
  end

  defp block_deps(ppl_req) do
    block_deps_with_index = block_deps_with_index(ppl_req)

    block_deps_with_index
    |> Enum.map(fn
      {{name, deps}, _} -> {name, deps}
    end)
  end

  defp block_deps_with_index(ppl_req) do
    ppl_req.definition
    |> Map.get("blocks")
    |> Enum.map(fn block -> {block["name"], block["dependencies"]} end)
    |> Enum.with_index()
  end


  defp name2ppl_block_id(name, ppl_blocks) do
    ppl_blocks
    |> Enum.find(fn ppl_block -> name == ppl_block.name end)
    |> Map.get(:id)
  end

  @doc """
  Find all connections for given PplBlock entity
  """
  def get_all_by_id(id) do
      PplBlockConnections
      |> where(dependency: ^id)
      |> order_by([p], [asc: p.inserted_at])
      |> Repo.all()
      |> return_tuple("no ppl block connections for ppl block with id: #{id} found")
    rescue
      e -> {:error, e}
  end

  defp return_tuple(nil, nil_msg), do: return_error_tuple(nil_msg)
  defp return_tuple([], message),  do: return_error_tuple(message)
  defp return_tuple(value, _),     do: return_ok_tuple(value)

  defp return_ok_tuple(value), do: {:ok, value}

  defp return_error_tuple(value), do: {:error, value}
end
