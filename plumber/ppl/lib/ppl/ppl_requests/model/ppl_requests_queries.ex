defmodule Ppl.PplRequests.Model.PplRequestsQueries do
  @moduledoc """
  Pipeline Requests Queries
  Operations on Pipeline Requests type
  """

  require Ppl.Ctx

  import Ecto.Query

  alias LogTee, as: LT
  alias Ppl.EctoRepo, as: Repo
  alias Ppl.PplRequests.Model.PplRequests
  alias Ppl.Ppls.Model.PplsQueries
  alias Util.ToTuple
  alias Ppl.Ctx

  @doc """
  Inserts new PplRequest with given params in DB
  """
  def insert_request(ctx, top_level \\ true, initial_request \\ true, start_in_conceived? \\ false) do
    ppl_id = UUID.uuid4()
    wf_id = Map.get(ctx, "wf_id")
    request_token = Map.get(ctx, "request_token")
    prev_ids = Map.get(ctx, "prev_ppl_artefact_ids", [])
    ctx = ctx
          |> Map.delete("wf_id")
          |> Map.delete("request_token")
          |> Map.delete("prev_ppl_artefact_ids")

    params = %{request_args: ctx, request_token: request_token, prev_ppl_artefact_ids: prev_ids,
               top_level: top_level, initial_request: initial_request, id: ppl_id,
               ppl_artefact_id: ppl_id, wf_id:  wf_id}

    insert_request_(params, start_in_conceived?)
  end

  defp insert_request_(params, start_in_conceived? \\ false) do
    %PplRequests{} |> PplRequests.changeset_request(params, start_in_conceived?) |> Repo.insert()
    |> process_response(params[:request_token])
  rescue
    e -> {:error, e}
  catch
    a, b -> {:error, [a, b]}
  end

  defp process_response({:error, %Ecto.Changeset{errors: [unique_request_token_for_ppl_requests: _message]}}, request_token) do
    request_token
    |> LT.info("PplRequestsQueries.insert_request() - There is already pipeline request with request_token: ")
    {:error, {:request_token_exists, request_token}}
  end
  defp process_response(ppl, request_token) do
    Ctx.event(ppl, "persisted schedule request with request_token: #{request_token}")
  end

  @doc """
  Inserts definition into existing PplRequest
  """
  def insert_definition(ppl_req, definition, switch_id \\ "") do
    params = %{definition: definition, switch_id: switch_id}

    ppl_req |> PplRequests.changeset_definition(params) |> Repo.update()
    |> Ctx.event("persisted definition for request with request_token: #{ppl_req.request_token}")
  rescue
    e ->
      {:error, e}
  end

  @doc """
  Inserts source_args into existing PplRequest
  """
  def insert_source(ppl_req, source_args) do
    params = %{source_args: source_args}

    ppl_req |> PplRequests.changeset_source(params) |> Repo.update()
    |> Ctx.event("persisted source_args for pipeline: #{ppl_req.id}")
  rescue
    e ->
      {:error, e}
  end

  @doc """
  Inserts conception response into existing PplRequest
  """
  def insert_conception(ppl_req, conception_args) do
    params = %{"request_args" => ppl_req.request_args
      |> Map.merge(%{
        "hook_id" => conception_args.hook_id,
        "branch_id" => conception_args.branch_id,
        "owner" => conception_args.repo.owner,
        "repo_name" => conception_args.repo.repo_name,
        "branch_name" => conception_args.repo.branch_name,
        "commit_sha" => conception_args.repo.commit_sha,
        "repository_id" => conception_args.repo.repository_id
      })}

    ppl_req |> PplRequests.changeset_conception(params) |> Repo.update()
    |> Ctx.event("persisted hook_id and workflow_id for pipeline: #{ppl_req.id}")
  rescue
    e ->
      {:error, e}
  end

  @doc """
  Creates a duplicate of given ppl_request with new ppl_id and request_token
  """
  def duplicate(orig_ppl_id, request_token, user_id) do
    with {:ok, ppl_req} <- get_by_id(orig_ppl_id),
         {:ok, params}  <- extract_insert_params(ppl_req, request_token, user_id)
    do
      insert_request_(params)
    end
  end

  defp extract_insert_params(ppl_req, request_token, user_id) do
    ppl_req
    |> Map.from_struct()
    |> Map.drop([:block_count, :switch_id])
    |> set_label()
    |> Map.put(:id, UUID.uuid4())
    |> Map.put(:request_token, request_token)
    |> Map.put(:initial_request, false)
    |> store_user_id(user_id)
    |> ToTuple.ok()
  end

  defp set_label(map = %{request_args: %{"label" => _label}}), do: map
  defp set_label(map = %{request_args: request_args, id: id}) do
    with {:ok, ppl}   <- PplsQueries.get_by_id(id),
         request_args <- request_args |> Map.put("label", ppl.label),
    do: map |> Map.put(:request_args, request_args)
  end

  defp store_user_id(map = %{request_args: request_args}, user_id) do
    request_args = Map.put(request_args, "partially_rerun_by", user_id)
    Map.put(map, :request_args, request_args)
  end

  @doc """
  Deletes pipeline_request (and all other related data structure via cascade)
  with given ppl_id
  """
  def delete_pipeline(ppl_id) do
    (from pr in PplRequests, where: pr.id == ^ppl_id)
    |> Repo.delete_all()
    |> return_number()
  end

  @doc """
  Finds PplRequest by ppl_id
  """
  def get_by_id(id) do
    PplRequests
    |> Repo.get(id)
    |> return_tuple("PipelineRequest with id: #{id} not found.")
  rescue
    e -> {:error, e}
  end

  @doc """
  Finds PplRequest by request_token
  """
  def get_by_request_token(request_token) do
    PplRequests |> where(request_token: ^request_token) |> Repo.one()
    |> get_by_request_token_response(request_token)
  rescue
    e -> {:error, e}
  end

  defp get_by_request_token_response(nil, request_token), do:
    {:error, {:request_token_not_found, request_token}}
  defp get_by_request_token_response(value, _request_token), do: {:ok, value}

  @doc """
  Finds PplRequest of initial pipeline in workflow with given id
  """
  def get_initial_wf_ppl(wf_id) do
    PplRequests
    |> where(initial_request: true)
    |> where(top_level: true)
    |> where(wf_id: ^wf_id)
    |> Repo.one()
    |> return_tuple({:not_found, "Workflow with id: #{wf_id} not found."})
  rescue
    e -> {:error, e}
  end

  @doc """
  Finds PplRequest of latest pipeline in workflow with given id
  """
  def latest_ppl_from_workflow(wf_id) do
    PplRequests
    |> where(wf_id: ^wf_id)
    |> order_by([pr], desc: pr.inserted_at)
    |> limit(1)
    |> Repo.one()
    |> return_tuple({:not_found, "Workflow with id: #{wf_id} not found."})
  rescue
    e -> {:error, e}
  end

  @doc """
  Returns number of pipelines from workflow with given wf_id
  """
  def count_pipelines_in_workflow(wf_id) do
    PplRequests
    # From workflow with given wf_id
    |> where([pr], pr.wf_id == ^wf_id)
    |> select([pr], count(pr.id))
    |> Repo.one()
    |> ToTuple.ok()
  rescue
    e -> {:error, e}
  end

  @doc """
  Finds PplRequest of latest pipeline in subtree which originated from
  pipeline with given ppl_id
  """
  def latest_ppl_from_subtree(ppl_id) do
    """
    -- Creates a temporary table which holds ppl_artefact_ids of all extensions of
    -- given ppl

    WITH temoprary(ppl_artefact_id) AS (
      SELECT DISTINCT pr1.ppl_artefact_id
      FROM pipeline_requests AS pr1
        LEFT JOIN pipelines AS p ON pr1.id = p.ppl_id
        LEFT JOIN pipeline_requests AS pr2 ON p.extension_of = pr2.id::varchar
       WHERE pr2.id::varchar = '#{ppl_id}'
    )
    SELECT t.*
    FROM pipeline_requests AS t
    WHERE

      -- First condition: intersection of ids from temoprary table and
      -- prev_ppl_artefact_ids of current pipeline is not empty set
      -- (current pipeline is descendant of pipeline with given ppl_id)

        (ARRAY(SELECT * from temoprary)  && t.prev_ppl_artefact_ids)

      -- Second cond: ppl_artefact_id of current pipeline is in temporary table,
      -- which means it is direct extension of pipeline with given ppl_id

       OR (t.ppl_artefact_id IN (SELECT * from temoprary))

      -- If none of previous is true, given pipeline has no extensions, so return it instead

        OR t.id::varchar = '#{ppl_id}'

    -- Next two: order by creation date and take one latest

    ORDER BY t.inserted_at DESC
    LIMIT 1;
    """
    |> Repo.query([])
    |> to_ppl_req()
  end

  @doc """
  Returns all pipelines from workflow with given wf_id
  """
  def get_all_by_wf_id(wf_id) do
    PplRequests
    |> where(wf_id: ^wf_id)
    |> Repo.all([])
    |> return_tuple("There is not any pipeline from workflow with wf_id '#{wf_id}'.")
  end

  # Utility

  defp return_number({number, _}) when is_integer(number),
    do: ToTuple.ok(number)
  defp return_number(error), do: ToTuple.error(error)

  defp return_tuple(nil, nil_msg), do: ToTuple.error(nil_msg)
  defp return_tuple(value, _),     do: ToTuple.ok(value)

  defp to_ppl_req({:ok, %{columns: columns, rows: [row]}}) do
    columns |> Enum.zip(row) |> Enum.into(%{}) |> to_schema(PplRequests) |> ToTuple.ok()
  end
  defp to_ppl_req(error), do: error

  defp to_schema(map, ecto_type) when is_map(map), do: ecto_type |> Repo.load(map)
end
