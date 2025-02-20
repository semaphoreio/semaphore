defmodule PipelinesAPI.Util.Auth do
  @moduledoc """
  Utility module for authorization
  """

  alias PipelinesAPI.ProjectClient
  require Logger

  @project_api_cache

  def project_belongs_to_org(org_id, project_id)
      when is_nil(org_id) or is_nil(project_id),
      do: {:error, {:user, :unauthorized}}

  def project_belongs_to_org(org_id, project_id)
      when org_id == "" or project_id == "",
      do: {:error, {:user, :unauthorized}}

  def project_belongs_to_org(org_id, project_id) do
    case fetch_project(project_id) do
      {:ok, %{metadata: %{org_id: ^org_id}}} ->
        :ok

      output ->
        Logger.error("User not authorized to access project: #{inspect(output)}")
        {:error, {:user, :unauthorized}}
    end
  end

  defp fetch_project(project_id) do
    project_id |> fetch_project_through_cache() |> elem(1)
  end

  defp fetch_project_through_cache(project_id) do
    Cachex.fetch(:project_api_cache, project_id, fn key ->
      case ProjectClient.describe(key) do
        {:ok, project} -> {:commit, {:ok, project}}
        {:error, _} -> {:commit, {:error, :not_found}}
      end
    end)
  end
end
