defmodule Scheduler.Periodics.Model.PeriodicsQueries do
  @moduledoc """
  Periodics Queries
  Operations on Periodics   type
  """

  import Ecto.Query

  alias Scheduler.PeriodicsRepo, as: Repo
  alias Scheduler.Periodics.Model.Periodics
  alias Scheduler.Utils.GitReference
  alias LogTee, as: LT
  alias Util.ToTuple

  @doc """
  Inserts new Periodic into DB
  """
  def insert(params, api_version \\ "v1.1") do
    processed_params =
      params
      |> Map.put(:id, UUID.uuid4())
      |> preprocess_reference_field(api_version)

    %Periodics{}
    |> Periodics.changeset(api_version, processed_params)
    |> Repo.insert()
    |> process_response(processed_params)
  rescue
    e -> {:error, e}
  catch
    a, b -> {:error, [a, b]}
  end

  defp process_response({:ok, periodic}, _params) do
    periodic |> LT.info("persisted periodic: #{periodic.id}") |> ToTuple.ok()
  end

  defp process_response({:error, %{errors: [unique_project_id_and_name: _msg]}}, params) do
    "Periodic with name '#{params.name}' already exists for project '#{params.project_name}'."
    |> ToTuple.error()
  end

  defp process_response({:error, %{errors: [name: {"can't be blank", _msg}]}}, _p) do
    {:error, "The 'name' parameter can not be empty string."}
  end

  defp process_response({:error, %{errors: [at: {"can't be blank", _msg}]}}, _p) do
    {:error, "The 'at' parameter can not be empty string."}
  end

  defp process_response({:error, %{errors: [reference: {"can't be blank", _msg}]}}, _p) do
    {:error, "The 'reference' parameter can not be empty string."}
  end

  defp process_response({:error, %{errors: [pipeline_file: {"can't be blank", _msg}]}}, _p) do
    {:error, "The 'pipeline_file' parameter can not be empty string."}
  end

  defp process_response(
         {:error, %Ecto.Changeset{valid?: false, errors: [], changes: changes}},
         _p
       ) do
    if Enum.any?(changes.parameters, &(not &1.valid?)),
      do:
        {:error,
         "All parameters need a name. If parameter is required, it also needs a default value."},
      else: {:error, "Unknown error."}
  end

  defp process_response(error_response, _params), do: error_response

  @doc """
  Updates Periodic record with given params
  """
  def update(periodic, params, api_version \\ "v1.1") do
    processed_params = preprocess_reference_field(params, api_version)

    periodic
    |> Periodics.changeset_update(api_version, processed_params)
    |> Repo.update()
    |> process_response(processed_params)
  rescue
    e -> {:error, e}
  catch
    a, b -> {:error, [a, b]}
  end

  @doc """
  Sets paused field of Periodic record to true and records who requested it and when
  """
  def pause(periodic, requester) do
    params = [paused: true, pause_toggled_by: requester, pause_toggled_at: DateTime.utc_now()]

    {1, [response]} =
      Periodics
      |> where([p], p.id == ^periodic.id)
      |> select([p], p)
      |> Repo.update_all(set: params)
      |> LT.info("Paused periodic: #{periodic.id}")

    {:ok, response}
  rescue
    e -> {:error, e}
  catch
    a, b -> {:error, [a, b]}
  end

  @doc """
  Sets paused field of Periodic record to false and records who requested it and when
  """
  def unpause(periodic, requester) do
    params = [paused: false, pause_toggled_by: requester, pause_toggled_at: DateTime.utc_now()]

    {1, [response]} =
      Periodics
      |> where([p], p.id == ^periodic.id)
      |> select([p], p)
      |> Repo.update_all([set: params], returning: true)
      |> LT.info("Unpaused periodic: #{periodic.id}")

    {:ok, response}
  rescue
    e -> {:error, e}
  catch
    a, b -> {:error, [a, b]}
  end

  @doc """
  Sets suspended field of Periodic record to true
  """
  def suspend(periodic) do
    {1, [response]} =
      Periodics
      |> where([p], p.id == ^periodic.id)
      |> select([p], p)
      |> Repo.update_all(set: [suspended: true])
      |> LT.info("Suspended periodic: #{periodic.id}")

    {:ok, response}
  rescue
    e -> {:error, e}
  catch
    a, b -> {:error, [a, b]}
  end

  @doc """
  Sets suspended field of Periodic record to false
  """
  def unsuspend(periodic) do
    {1, [response]} =
      Periodics
      |> where([p], p.id == ^periodic.id)
      |> select([p], p)
      |> Repo.update_all(set: [suspended: false])
      |> LT.info("Unsuspended periodic: #{periodic.id}")

    {:ok, response}
  rescue
    e -> {:error, e}
  catch
    a, b -> {:error, [a, b]}
  end

  @doc """
  Deletes periodic (and all other related data structures via cascade) with given id.
  """
  def delete(id) do
    from(per in Periodics, where: per.id == ^id)
    |> Repo.delete_all()
    |> return_number()
  end

  @doc """
  Finds Periodic by id
  """
  def get_by_id(""), do: {:error, "Periodic with id: '' not found."}

  def get_by_id(id) do
    Periodics
    |> Repo.get(id)
    |> return_tuple("Periodic with id: '#{id}' not found.")
  rescue
    e -> {:error, e}
  end

  @doc """
  Returns batch_no in order batch with periodics that are older than timestamp.
  """
  def get_older_then(timestamp, batch_no) do
    Periodics
    |> where([s], s.inserted_at < ^timestamp)
    |> limit(100)
    |> offset(^calc_offset(batch_no))
    |> Repo.all()
    |> ToTuple.ok()
  rescue
    e -> {:error, e}
  end

  defp calc_offset(batch_no), do: batch_no * 100

  @doc """
  Returns batch_no in order batch with periodics from the given org.
  """
  def get_all_from_org(org_id, batch_no) do
    Periodics
    |> where([p], p.organization_id == ^org_id)
    |> limit(100)
    |> offset(^calc_offset(batch_no))
    |> Repo.all()
    |> ToTuple.ok()
  rescue
    e -> {:error, e}
  end

  @doc """
  Returns list containing a maps with periodics data for each periodic
  which matches given filter params
  """
  def list(params) do
    Periodics
    |> filter_by_organization_id(params.organization_id)
    |> filter_by_project_id(params.project_id)
    |> filter_by_requester_id(params.requester_id)
    |> filter_by_query(params.query)
    |> apply_order(params.order)
    |> select_periodic_details()
    |> Repo.paginate_offset(page: params.page, page_size: params.page_size)
    |> convert_parameters_to_maps()
    |> ToTuple.ok()
  end

  def list_keyset(params) do
    Periodics
    |> filter_by_organization_id(params.organization_id)
    |> filter_by_project_id(params.project_id)
    |> filter_by_query(params.query)
    |> apply_order(params.order)
    |> select_periodic_details()
    |> Repo.paginate_keyset(keyset_params(params))
    |> convert_parameters_to_maps()
    |> ToTuple.ok()
  end

  defp filter_by_organization_id(query, :skip), do: query

  defp filter_by_organization_id(query, org_id),
    do: query |> where([per], per.organization_id == ^org_id)

  defp filter_by_project_id(query, :skip), do: query

  defp filter_by_project_id(query, project_id),
    do: query |> where([per], per.project_id == ^project_id)

  defp filter_by_requester_id(query, :skip), do: query

  defp filter_by_requester_id(query, req_id),
    do: query |> where([per], per.requester_id == ^req_id)

  defp filter_by_query(query, :skip), do: query

  defp filter_by_query(query, query_string),
    do: query |> where([per], ilike(per.name, ^"%#{query_string}%"))

  defp apply_order(query, :BY_NAME_ASC),
    do: query |> order_by([per], asc: per.name, asc: per.id)

  defp apply_order(query, :BY_CREATION_DATE_DESC),
    do: query |> order_by([per], desc: per.inserted_at, desc: per.id)

  defp keyset_params(params),
    do: [cursor(params), {:limit, params.page_size} | keyset_order_fields(params.order)]

  defp cursor(params = %{direction: :NEXT}), do: {:after, params.page_token}
  defp cursor(params = %{direction: :PREV}), do: {:before, params.page_token}

  defp keyset_order_fields(:BY_NAME_ASC),
    do: [cursor_fields: [:name, :id], sort_direction: :asc]

  defp keyset_order_fields(:BY_CREATION_DATE_DESC),
    do: [cursor_fields: [:inserted_at, :id], sort_direction: :desc]

  defp select_periodic_details(query) do
    query
    |> select(
      [per],
      %{
        id: per.id,
        name: per.name,
        recurring: per.recurring,
        project_id: per.project_id,
        reference: per.reference,
        at: per.at,
        pipeline_file: per.pipeline_file,
        requester_id: per.requester_id,
        updated_at: per.updated_at,
        suspended: per.suspended,
        paused: per.paused,
        parameters: per.parameters,
        pause_toggled_by: per.pause_toggled_by,
        pause_toggled_at: per.pause_toggled_at,
        inserted_at: per.inserted_at
      }
    )
  end

  defp convert_parameters_to_maps(page = %{entries: entries}) do
    entries_with_parameters_as_maps =
      Enum.map(entries, fn periodic ->
        parameters_as_maps = Enum.into(periodic.parameters, [], &convert_parameter_to_map/1)
        Map.put(periodic, :parameters, parameters_as_maps)
      end)

    %{page | entries: entries_with_parameters_as_maps}
  end

  defp convert_parameters_to_maps(result), do: result

  defp convert_parameter_to_map(parameter) do
    parameter |> Map.take(~w(name required description default_value options)a)
  end

  defp preprocess_reference_field(params, "v1.0") do
    case Map.get(params, :reference) do
      nil ->
        params

      reference when is_binary(reference) ->
        Map.put(params, :reference, GitReference.normalize(reference))

      _ ->
        params
    end
  end

  defp preprocess_reference_field(params, "v1.1"), do: preprocess_reference_field(params, "v1.0")

  defp preprocess_reference_field(params, _api_version), do: params

  # Utility

  defp return_tuple(nil, nil_msg), do: ToTuple.error(nil_msg)
  defp return_tuple(value, _), do: ToTuple.ok(value)

  defp return_number({number, _}) when is_integer(number),
    do: ToTuple.ok(number)

  defp return_number(error), do: ToTuple.error(error)
end
