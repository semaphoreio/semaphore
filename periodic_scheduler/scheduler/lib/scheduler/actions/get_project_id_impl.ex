defmodule Scheduler.Actions.GetProjectIdImpl do
  @moduledoc """
  Module serves to find project_id based on given search params.
  """

  alias Scheduler.Periodics.Model.PeriodicsQueries
  alias Scheduler.FrontDB.Model.FrontDBQueries
  alias Util.ToTuple

  def get_project_id(params) do
    with {:ok, org_id} <- non_empty_val_or_default(params, :organization_id, :skip),
         {:ok, pr_name} <- non_empty_val_or_default(params, :project_name, :skip),
         {:ok, per_id} <- non_empty_val_or_default(params, :periodic_id, :skip),
         query_params <- %{organization_id: org_id, project_name: pr_name, periodic_id: per_id} do
      get_project_id_(query_params)
    end
  end

  defp non_empty_val_or_default(map, key, default) do
    case Map.get(map, key) do
      val when is_binary(val) and val != "" -> {:ok, val}
      _ -> {:ok, default}
    end
  end

  defp get_project_id_(%{organization_id: org_id, project_name: pr_name})
       when org_id != :skip and pr_name != :skip do
    case FrontDBQueries.get_project_id(org_id, pr_name) do
      {:error, msg} -> msg |> ToTuple.error(:NOT_FOUND)
      response -> response
    end
  end

  defp get_project_id_(%{periodic_id: per_id}) when per_id != :skip do
    case PeriodicsQueries.get_by_id(per_id) do
      {:error, msg} -> msg |> ToTuple.error(:NOT_FOUND)
      {:ok, periodic} -> periodic.project_id |> ToTuple.ok()
    end
  end

  defp get_project_id_(_params) do
    "One of these is required: periodic_id or organization_id + project_name."
    |> ToTuple.error(:INVALID_ARGUMENT)
  end
end
