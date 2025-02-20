defmodule Scheduler.Actions.ListKeysetImpl do
  @moduledoc """
  Module serves to form paginated list of periodics which match the given search params.
  """

  alias Scheduler.Periodics.Model.PeriodicsQueries
  import Scheduler.Actions.Common

  def list_keyset(params) do
    with {:ok, org_id} <- non_empty_value_or_default(params, :organization_id, :skip),
         {:ok, project_id} <- non_empty_value_or_default(params, :project_id, :skip),
         {:ok, query} <- non_empty_value_or_default(params, :query, :skip),
         true <- either_project_or_org_id_present(project_id, org_id),
         {:ok, page_token} <- non_empty_value_or_default(params, :page_token, nil),
         {:ok, page_size} <- non_empty_value_or_default(params, :page_size, 30),
         {:ok, order} <- non_empty_value_or_default(params, :order, :BY_NAME_ASC),
         {:ok, direction} <- non_empty_value_or_default(params, :direction, :NEXT),
         query_params <- %{
           project_id: project_id,
           organization_id: org_id,
           query: query,
           page_token: page_token,
           page_size: page_size,
           order: order,
           direction: direction
         },
         {:ok, result} <- PeriodicsQueries.list_keyset(query_params) do
      form_response_params(result, page_size)
    end
  end

  defp form_response_params(result, page_size) do
    {:ok,
     %{
       periodics: result.entries,
       next_page_token: result.metadata.after || "",
       prev_page_token: result.metadata.before || "",
       page_size: page_size
     }}
  end
end
