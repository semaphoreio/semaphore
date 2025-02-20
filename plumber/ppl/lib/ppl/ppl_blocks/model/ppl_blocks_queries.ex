defmodule Ppl.PplBlocks.Model.PplBlocksQueries do
  @moduledoc """
  Pipeline Blocks Queries
  Operations on Pipeline Blocks type

  'initializing' - initial pipeline block state.
  - regular blocks go straight through into waiting state
  - blocks with duplicate flag are duplicated in block app via API call and then go to 'done'

  'waiting'
  Waiting for pipeline to enters 'running' state if block has no dependencies,
  or for all dependant blocks to finish their execution.
  From 'waiting' pipeline block transitions to 'running' or 'done'(failed or canceld).

  'running'
  This pipeline's block execution is in progress.
  When checked:
  - If termination_request is 'stop', block transitions to 'stopping'
  - If it is not done, it will be fetched by looper later and checked again.
  - If it is done, it goes to 'done' state.
  From 'running' pipeline block transitions to 'done' or 'stopping'

  'stopping'
  Pipeline block's termination is started, waiting for it's termination in block app.
  From 'stopping' pipeline block transitions to 'done'(stopped).

  'done' - terminal state
  Block's execution is finished and result is set.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias Ppl.EctoRepo, as: Repo
  alias Ppl.PplBlocks.Model.PplBlocks
  alias Ppl.Ppls.Model.Ppls

  @const_params %{state: "initializing", in_scheduling: "false"}

  @doc """
      iex> multi = Ecto.Multi.new()
      ...>   |> multi_insert(%{id: UUID.uuid1(),
      ...>   definition: %{"blocks" => [%{"name" => "b1"}, %{"name" => "b2"}]}})
      iex> Map.get(multi, :operations) |> Enum.count()
      2
  """
  def multi_insert(multi, ppl_req, duplicate \\ false) do
    ppl_req.definition["blocks"]
    # Block name is required in definition so `block["name"]` is safe
    |> Enum.map(fn block -> {block["name"], block["execution_time_limit"]} end)
    |> Enum.with_index()
    |> Enum.reduce(multi, fn({{name, time_limit}, index}, multi) ->
      params =
        %{ppl_id: ppl_req.id, block_index: index, name: name, duplicate: duplicate}
        |> add_if_not_nil(:exec_time_limit_min, time_limit |> to_minutes())

      multi_insert_block(multi, params)
    end)
  end

  defp add_if_not_nil(map, _key, nil), do: map
  defp add_if_not_nil(map, key, value), do: Map.put(map, key, value)

  defp to_minutes(nil), do: nil
  defp to_minutes(limit_map) do
    Map.get(limit_map, "minutes", 0) + Map.get(limit_map, "hours", 0) * 60
  end

  defp multi_insert_block(multi, params) do
    changeset = PplBlocks.changeset(%PplBlocks{}, Map.merge(@const_params, params))
    name = String.to_atom("ppl_block_#{params.block_index}")
    Multi.insert(multi, name, changeset)
  end

  @doc """
  Returnes true if number of PplBlocks in done state for pipeline with given
  ppl_id is equal to parameter block_count, otherwise it returnes false.
  If `result` parameter is given, it will count only  PplBlocks in done state
  with given result
  """
  def all_blocks_done?(ppl_id, block_count, result \\ nil) do
    ppl_id
    |> done_blocks_count(result)
    |> equal?(block_count)
  end

  defp done_blocks_count(ppl_id, nil) do
    PplBlocks
    |> where(ppl_id: ^ppl_id, state: "done")
    |> select([b], count(b.id))
    |> Repo.one()
  end

  defp done_blocks_count(ppl_id, result) do
    PplBlocks
    |> where(ppl_id: ^ppl_id, state: "done", result: ^result)
    |> select([b], count(b.id))
    |> Repo.one()
  end

  defp equal?(done_count, block_count) when done_count == block_count, do: true
  defp equal?(_done_count, _block_count), do: false

  @doc """
  Returns result and result reason of chronologically first block
  which is not in done - passed state for pipeline with given ppl_id.
  """
  def get_first_not_passed_block_result_and_reason(ppl_id) do
    ppl_id
    |> get_first_not_passed_block_result_and_reason_query()
    |> Repo.one
  end

  defp get_first_not_passed_block_result_and_reason_query(ppl_id) do
    from (a in PplBlocks),
      where: a.state == "done" and a.result != "passed" and a.ppl_id == ^ppl_id,
       order_by: [asc: a.updated_at],
       limit: 1,
       select: {a.result, a.result_reason}
  end

  @doc """
  Sets termination flags for all non-done PplBlocks of Pipeline with given ppl_id
  """
  def terminate_all(ppl_id, t_request, t_request_desc) do
    PplBlocks
    |> where([p], p.ppl_id == ^ppl_id)
    |> where([p], p.state != "done")
    |> update_set([terminate_request: t_request])
    |> update_set([terminate_request_desc: t_request_desc])
    |> Repo.update_all([])
    |> return_number()
  rescue
    e -> {:error, e}
  end

  defp update_set(q, fields), do: q |> update(set: ^fields)

  @doc """
  It will return configured fast_failing strategy if any other block from same pipeline
  has finished with result different than "passed", or false if fast_failing strategy
  is not configured or no blocks form same pipeline fulfills condition above.
  """
  def should_do_fast_failing?(ppl_blk) do
    from(pb in PplBlocks,
         join: p in Ppls, on: pb.ppl_id == p.ppl_id,
         where: pb.ppl_id == ^ppl_blk.ppl_id,
         where: pb.state == "done" and pb.result != "passed",
         where: p.fast_failing != "none",
         select: p.fast_failing,
         limit: 1)
    |> Repo.one()
    |> fast_failing_response()
  end

  defp fast_failing_response(nil), do: {:ok, false}
  defp fast_failing_response(""), do: {:ok, false}
  defp fast_failing_response(ff_strategy) when is_binary(ff_strategy),
   do: {:ok, ff_strategy}

  @doc """
  Sets terminate request fields for given PplBlocks
  """
  def terminate(ppl_blk, t_request, t_request_desc) do
    params = %{terminate_request: t_request, terminate_request_desc: t_request_desc}
    ppl_blk
    |> PplBlocks.changeset(params)
    |> Repo.update()
  end

  def get_by_id_and_index(id, index) do
      PplBlocks |> where(ppl_id: ^id, block_index: ^index) |> Repo.one()
      |> return_tuple({:not_found, "block with index #{index} for ppl: #{id} not found"})
    rescue
      e -> {:error, e}
  end

  @doc """
  Get all blocks for a given pipeline
  """
  def get_all_by_id(id) do
      PplBlocks
      |> where(ppl_id: ^id)
      |> order_by([p], [asc: p.block_index])
      |> Repo.all()
      |> return_tuple("no ppl blocks for ppl with id: #{id} found")
    rescue
      e -> {:error, e}
  end

  @doc """
  Returns all blocks for every pipeline with ID in provided IDs list
  """
  def all_blocks_from_pipelines(ppl_ids) do
    PplBlocks
    |> where([pb], pb.ppl_id in ^ppl_ids)
    |> select_active_block()
    |> order_by([pb], [asc: pb.ppl_id, asc: pb.block_index])
    |> Repo.all()
    |> return_tuple("There are no blocks for any of given pipleines.")
  rescue
    e -> {:error, e}
  end

  defp select_active_block(query) do
    query
    |> select([pb],
      %{
        ppl_id: pb.ppl_id,
        block_index: pb.block_index,
        block_id: fragment("coalesce(nullif(?::text, ''), '')", pb.block_id),
        name: pb.name,
        priority: fragment("coalesce(?, 0)", pb.priority),
        state: pb.state,
        result: fragment("coalesce(nullif(?, ''), '')", pb.result),
        result_reason: fragment("coalesce(nullif(?, ''), '')", pb.result_reason),
        error_description: fragment("coalesce(nullif(?, ''), '')", pb.error_description),
      }
    )
  end

  @doc """
  Preload list of :connections (depenedencies) for each PplBlock and
  :dependency_pipeline_block (PplBlock) for each connection dependency.
  """
  def preload_dependencies(ppl_block) do
    ppl_block |> Repo.preload([connections: :dependency_pipeline_block])
  end

  defp return_number({number, _}) when is_integer(number),
    do: return_ok_tuple(number)
  defp return_number(error), do: return_error_tuple(error)

  defp return_tuple(nil, nil_msg), do: return_error_tuple(nil_msg)
  defp return_tuple([], message),  do: return_error_tuple(message)
  defp return_tuple(value, _),     do: return_ok_tuple(value)

  defp return_ok_tuple(value), do: {:ok, value}

  defp return_error_tuple(value), do: {:error, value}
end
