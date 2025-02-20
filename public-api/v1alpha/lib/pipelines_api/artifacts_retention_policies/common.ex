defmodule PipelinesAPI.ArtifactsRetentionPolicy.Common do
  @moduledoc """
  Utility functions needed to handle deployment targets operations
  """

  use Plug.Builder

  alias PipelinesAPI.ProjectClient
  alias PipelinesAPI.Pipelines.Common

  def get_artifact_store_id(conn, _opts) do
    conn.params
    |> Map.get("project_id")
    |> ProjectClient.describe()
    |> process_response(conn)
  end

  defp process_response({:ok, project}, conn) do
    art_st_id = project.spec.artifact_store_id
    conn |> Map.put(:params, Map.put(conn.params, "artifact_store_id", art_st_id))
  end

  defp process_response(error, conn) do
    error |> Common.respond(conn) |> halt()
  end
end
