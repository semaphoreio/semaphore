defmodule PipelinesAPI.Workflows.WfAuthorize.ValidateRequiredParams do
  @moduledoc """
  For pipelines list request project_id is required, and optional if wf_id is given
  """
  use Plug.Builder
  alias PipelinesAPI.Util.ToTuple

  def validate_params(conn, _opts) do
    with {:error, {:user, "Missing required parameter project_id."}} <- check_project_id(conn),
         {:ok, _wf_id} <- check_wf_id(conn) do
      conn
    else
      {:ok, _project_id} -> conn
      _ -> conn |> resp(404, "Not Found") |> halt
    end
  end

  defp check_project_id(conn) do
    case Map.get(conn.params, "project_id") do
      value when is_binary(value) and value != "" -> value |> ToTuple.ok()
      _ -> "Missing required parameter project_id." |> ToTuple.user_error()
    end
  end

  defp check_wf_id(conn) do
    case Map.get(conn.params, "wf_id") do
      value when is_binary(value) and value != "" -> value |> ToTuple.ok()
      _ -> "Missing required parameter wf_id." |> ToTuple.user_error()
    end
  end
end
