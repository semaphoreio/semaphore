defmodule Scheduler.Actions.ListImpl do
  @moduledoc """
  Module serves to form paginated list of periodics which match the given search params.
  """

  alias Scheduler.Periodics.Model.PeriodicsQueries
  alias Util.ToTuple

  import Scheduler.Actions.Common

  def list(params) do
    with {:ok, org_id} <- non_empty_value_or_default(params, :organization_id, :skip),
         {:ok, project_id} <- non_empty_value_or_default(params, :project_id, :skip),
         true <- either_project_or_org_id_present(project_id, org_id),
         {:ok, requester} <- non_empty_value_or_default(params, :requester_id, :skip),
         {:ok, query} <- non_empty_value_or_default(params, :query, :skip),
         {:ok, page} <- non_empty_value_or_default(params, :page, 1),
         {:ok, page_size} <- non_empty_value_or_default(params, :page_size, 30),
         {:ok, order} <- non_empty_value_or_default(params, :order, :BY_NAME_ASC),
         query_params <- %{
           project_id: project_id,
           organization_id: org_id,
           query: query,
           requester_id: requester,
           page: page,
           page_size: page_size,
           order: order
         },
         {:ok, result} <- PeriodicsQueries.list(query_params) do
      rename_entries(result, :periodics)
    end
  end

  defp rename_entries(result, new_name) do
    result
    |> Map.from_struct()
    |> Map.put(new_name, result.entries)
    |> Map.delete(:entries)
    |> ToTuple.ok()
  end
end
