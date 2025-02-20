defmodule Dashboardhub.PublicGrpcApi.ListDashboards do
  import Ecto.Query
  require Logger

  alias Dashboardhub.Repo

  @default_page_size 100
  @page_size_limit 100

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

  def query(org_id, page_size, page_token) do
    Watchman.benchmark("dashboardhub.query_dashboard_list.duration", fn ->
      page_token = if page_token == "", do: nil, else: page_token

      page =
        Repo.Dashboard
        |> where([d], d.org_id == ^org_id)
        |> order_by([d], asc: d.inserted_at, asc: d.id)
        |> Repo.paginate(cursor_fields: [:inserted_at, :id], limit: page_size, after: page_token)

      next_page_token = if is_nil(page.metadata.after), do: "", else: page.metadata.after

      {:ok, page.entries, next_page_token}
    end)
  end
end
