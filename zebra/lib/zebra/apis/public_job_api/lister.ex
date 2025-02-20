defmodule Zebra.Apis.PublicJobApi.Lister do
  require Logger

  alias Semaphore.Jobs.V1alpha.ListJobsRequest, as: Request
  alias Zebra.LegacyRepo

  import Ecto.Query

  @default_page_size 30
  @page_size_limit 30

  def list_jobs(org_id, page_size, project_ids, req) do
    states = map_state_names(req)

    query =
      Zebra.Models.Job
      |> where([j], j.organization_id == ^org_id)
      |> where([j], j.project_id in ^project_ids)
      |> where([j], j.aasm_state in ^states)

    page =
      case Request.Order.key(req.order) do
        :BY_CREATE_TIME_DESC -> list_jobs_by_create_time_desc(req, query, page_size)
      end

    {:ok, page.entries, serialize_token(page.metadata.after)}
  end

  def list_jobs_by_create_time_desc(req, query, page_size) do
    query
    |> order_by([s], desc: s.created_at, desc: s.id)
    |> LegacyRepo.paginate(
      cursor_fields: [:created_at, :id],
      limit: page_size,
      after: deserilize_token(req.page_token),
      sort_direction: :desc
    )
  end

  def extract_page_size(req) do
    cond do
      req.page_size == 0 ->
        {:ok, @default_page_size}

      req.page_size > @page_size_limit ->
        {:error, :precondition_failed, "Page size can't exceed #{@page_size_limit}"}

      true ->
        {:ok, req.page_size}
    end
  end

  def deserilize_token(page_token) do
    if page_token == "", do: nil, else: page_token
  end

  def serialize_token(page_token) do
    if is_nil(page_token), do: "", else: page_token
  end

  def map_state_names(req) do
    req.states
    |> Enum.flat_map(fn s ->
      case Semaphore.Jobs.V1alpha.Job.Status.State.key(s) do
        :PENDING -> ["pending"]
        :QUEUED -> ["enqueued", "scheduled", "waiting-for-agent"]
        :RUNNING -> ["started"]
        :FINISHED -> ["finished"]
      end
    end)
  end
end
