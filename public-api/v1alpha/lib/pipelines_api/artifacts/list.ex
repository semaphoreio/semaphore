defmodule PipelinesAPI.Artifacts.List do
  @moduledoc """
  Plug endpoint for listing artifacts through v1alpha API.
  """

  use Plug.Builder

  alias PipelinesAPI.ArtifactHubClient
  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics

  import Plug.Conn, only: [resp: 3, halt: 1]
  import PipelinesAPI.Artifacts.Authorize, only: [authorize_list: 2]

  import PipelinesAPI.Artifacts.Common,
    only: [
      get_artifact_store_id: 2,
      validate_request_params: 3,
      resolve_project_id_from_scope: 2
    ]

  @default_limit 200
  @max_limit 1000
  @enabled_fields ~w(scope scope_id path limit)

  plug(:verify_params)
  plug(:resolve_project_id_from_scope)
  plug(:authorize_list)
  plug(:get_artifact_store_id)
  plug(:list_artifacts)

  def list_artifacts(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["artifacts_list"], fn ->
      result =
        conn.params
        |> ArtifactHubClient.list_path()
        |> format_response(conn.params)

      maybe_track_lookup_failure(result)
      RespCommon.respond(result, conn)
    end)
  end

  def verify_params(conn, _opts) do
    conn
    |> validate_request_params(@enabled_fields, [])
    |> validate_limit()
  end

  defp validate_limit(conn = %{halted: true}), do: conn

  defp validate_limit(conn) do
    case parse_limit(conn.params["limit"]) do
      {:ok, limit} ->
        conn
        |> Map.put(:params, Map.put(conn.params, "limit", limit))

      {:error, message} ->
        conn |> resp(400, message) |> halt()
    end
  end

  defp parse_limit(nil), do: {:ok, @default_limit}
  defp parse_limit(""), do: {:ok, @default_limit}

  defp parse_limit(limit) when is_binary(limit) do
    case Integer.parse(limit) do
      {value, ""} when value >= 1 and value <= @max_limit -> {:ok, value}
      _ -> {:error, "limit must be an integer between 1 and #{@max_limit}"}
    end
  end

  defp parse_limit(_), do: {:error, "limit must be an integer between 1 and #{@max_limit}"}

  defp format_response({:ok, artifacts}, %{"limit" => limit}) when is_integer(limit) do
    sorted_artifacts = sort_artifacts(artifacts)
    limited_artifacts = Enum.take(sorted_artifacts, limit)
    returned = length(limited_artifacts)
    total = length(sorted_artifacts)

    {:ok,
     %{
       artifacts: limited_artifacts,
       page: %{
         limit: limit,
         returned: returned,
         total: total,
         truncated: total > returned
       }
     }}
  end

  defp format_response(error, _params), do: error

  defp sort_artifacts(artifacts) do
    Enum.sort_by(artifacts, fn artifact ->
      artifact
      |> Map.get(:path, "")
      |> to_string()
    end)
  end

  defp maybe_track_lookup_failure({:error, _}) do
    Metrics.increment("PipelinesAPI.router", ["artifacts_list_lookup_failed"])
  end

  defp maybe_track_lookup_failure(_result), do: :ok
end
