defmodule Zebra.Apis.InternalJobApi.Lister do
  import Ecto.Query
  alias Zebra.LegacyRepo

  def list_jobs(query_params, pagination_params) do
    # request and spec are huge fields, we don't wan't to load them if not necessary
    fields = Zebra.Models.Job.__schema__(:fields) -- [:request, :spec]

    query =
      from(j in Zebra.Models.Job,
        left_join: t in Zebra.Models.Task,
        on: j.build_id == t.id,
        left_join: d in Zebra.Models.Debug,
        on: j.id == d.job_id
      )
      |> where([j], j.aasm_state in ^query_params.job_states)
      |> filter_by_org_id(query_params.org_id)
      |> filter_by_ppl_ids(query_params.ppl_ids)
      |> filter_only_debugs(query_params.only_debug_jobs)
      |> filter_by_created_at(query_params)
      |> filter_by_machine_types(query_params.machine_types)
      |> select([j], struct(j, ^fields))

    page = page_jobs(query, query_params, pagination_params)
    {:ok, page.entries, serialize_token(page.metadata.after)}
  end

  def list_debugs(query_params, pagination_params) do
    # request and spec are huge fields, we don't wan't to load them if not necessary
    fields = Zebra.Models.Job.__schema__(:fields) -- [:request, :spec]

    query =
      from(j in Zebra.Models.Job, join: d in Zebra.Models.Debug, on: j.id == d.job_id)
      |> where([j], j.aasm_state in ^query_params.job_states)
      |> where([j, d], d.debugged_type in ^query_params.debug_types)
      |> filter_by_org_id(query_params.org_id)
      |> filter_by_project_id(query_params.project_id)
      |> filter_by_debug_user_id(query_params.user_id)
      |> filter_by_debugged_id(query_params.debugged_id)
      |> select([j], struct(j, ^fields))

    page = page_jobs(query, query_params, pagination_params)
    jobs = page.entries |> LegacyRepo.preload([:debug])

    {:ok, jobs, serialize_token(page.metadata.after)}
  end

  defp page_jobs(query, query_params, pagination_params) do
    case pagination_params.order do
      :BY_FINISH_TIME_ASC ->
        query = query |> where([j], j.finished_at >= ^query_params.finished_at_gte)

        list_jobs_by_finish_time_asc(
          query,
          pagination_params.page_token,
          pagination_params.page_size
        )

      :BY_CREATION_TIME_DESC ->
        list_jobs_by_creation_time_desc(
          query,
          pagination_params.page_token,
          pagination_params.page_size
        )
    end
  end

  defp filter_by_machine_types(query, machine_types)
       when is_list(machine_types) and length(machine_types) > 0 do
    query |> where([j], j.machine_type in ^machine_types)
  end

  defp filter_by_machine_types(query, _machine_types), do: query

  defp filter_by_org_id(query, org_id) when is_binary(org_id) and org_id != "" do
    query |> where([j], j.organization_id == ^org_id)
  end

  defp filter_by_org_id(query, _org_id), do: query

  defp filter_by_project_id(query, project_id) when is_binary(project_id) and project_id != "" do
    query |> where([j], j.project_id == ^project_id)
  end

  defp filter_by_project_id(query, _project_id), do: query

  defp filter_by_debug_user_id(query, user_id) when is_binary(user_id) and user_id != "" do
    query |> where([j, d], d.user_id == ^user_id)
  end

  defp filter_by_debug_user_id(query, _user_id), do: query

  defp filter_by_debugged_id(query, id) when is_binary(id) and id != "" do
    query |> where([j, d], d.debugged_id == ^id)
  end

  defp filter_by_debugged_id(query, _id), do: query

  defp filter_by_ppl_ids(query, ppl_ids) when is_list(ppl_ids) and length(ppl_ids) > 0 do
    query |> where([_j, t], t.ppl_id in ^ppl_ids)
  end

  defp filter_by_ppl_ids(query, _ppl_ids), do: query

  defp filter_by_created_at(query, %{
         created_at_gte: %{seconds: gte_seconds},
         created_at_lte: %{seconds: lte_seconds}
       }) do
    gte = DateTime.to_naive(DateTime.from_unix!(gte_seconds))
    lte = DateTime.to_naive(DateTime.from_unix!(lte_seconds))

    query
    |> where([j], j.created_at >= ^gte)
    |> where([j], j.created_at <= ^lte)
  end

  defp filter_by_created_at(query, _), do: query

  defp filter_only_debugs(query, true) do
    query
    |> where([_j, _t, d], fragment("? IS NOT NULL", d.job_id))
  end

  defp filter_only_debugs(query, _only_debugs), do: query

  def list_jobs_by_finish_time_asc(query, page_token, page_size) do
    query
    |> order_by([s], asc: s.finished_at, asc: s.id)
    |> LegacyRepo.paginate(
      cursor_fields: [:finished_at, :id],
      limit: page_size,
      after: deserilize_token(page_token),
      sort_direction: :asc
    )
  end

  def list_jobs_by_creation_time_desc(query, page_token, page_size) do
    query
    |> order_by([s], desc: s.created_at, asc: s.id)
    |> LegacyRepo.paginate(
      cursor_fields: [:created_at, :id],
      limit: page_size,
      after: deserilize_token(page_token),
      sort_direction: :desc
    )
  end

  def deserilize_token(page_token) do
    if page_token == "", do: nil, else: page_token
  end

  def serialize_token(page_token) do
    if is_nil(page_token), do: "", else: page_token
  end
end
