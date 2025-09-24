defmodule PipelinesAPI.Schedules.RunNow do
  @moduledoc """
  Plug which serves for running given schedule with schedule definition.
  Supports both new reference format (reference.type/reference.name) and legacy branch parameter.
  """

  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.PeriodicSchedulerClient

  import PipelinesAPI.Schedules.Authorize, only: [authorize_run_now: 2]
  import PipelinesAPI.Schedules.Common, only: [get_project_id: 2]

  plug(:identify_path_param)
  plug(:get_project_id)
  plug(:authorize_run_now)
  plug(:validate_and_normalize_params)
  plug(:run_now)

  def validate_and_normalize_params(conn, _opts) do
    case normalize_and_validate_reference_params(conn.params) do
      {:ok, normalized_params} ->
        %{conn | params: Map.merge(conn.params, normalized_params)}

      {:error, reason} ->
        {:error, {:user, reason}}
        |> RespCommon.respond(conn)
        |> halt()
    end
  end

  def run_now(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["periodic_run_now"], fn ->
      conn.params
      |> PeriodicSchedulerClient.run_now(conn)
      |> handle_run_now_response()
      |> RespCommon.respond(conn)
    end)
  end

  def identify_path_param(conn, _opts) do
    case UUID.info(conn.params["identifier"]) do
      {:ok, _} ->
        put_param_in_conn(conn, "periodic_id", conn.params["identifier"])

      _ ->
        {:error, {:user, "schedule identifier should be a UUID"}}
        |> RespCommon.respond(conn)
        |> halt()
    end
  end

  defp put_param_in_conn(conn, key, value) do
    params = conn.params |> Map.put(key, value)
    Map.put(conn, :params, params)
  end

  # Request validation and normalization

  defp normalize_and_validate_reference_params(params) do
    case normalize_reference_params(params) do
      {:ok, normalized_params} ->
        validate_reference_params(normalized_params)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp normalize_reference_params(params) do
    cond do
      params["reference"] ->
        {:ok, params}

      params["branch"] ->
        reference = %{
          "type" => "BRANCH",
          "name" => params["branch"]
        }

        updated_params =
          params
          |> Map.put("reference", reference)
          |> Map.delete("branch")

        {:ok, updated_params}

      true ->
        {:ok, params}
    end
  end

  defp validate_reference_params(params = %{"reference" => reference}) do
    case reference do
      %{"type" => type, "name" => name} when type in ["BRANCH", "TAG"] and is_binary(name) ->
        if String.trim(name) != "" do
          {:ok, params}
        else
          {:error, "Reference name cannot be empty"}
        end

      %{"type" => type} when type not in ["BRANCH", "TAG"] ->
        {:error, "Reference type must be 'BRANCH' or 'TAG'"}

      _ ->
        {:error, "Reference must contain 'type' and 'name' fields"}
    end
  end

  defp validate_reference_params(params), do: {:ok, params}

  # Enhanced error handling

  defp handle_run_now_response({:error, {:user, message}}) when is_binary(message) do
    cond do
      String.contains?(message, "refs/heads/") ->
        branch_name = extract_reference_name(message, "refs/heads/")
        {:error, {:user, "Branch '#{branch_name}' does not exist in the repository"}}

      String.contains?(message, "refs/tags/") ->
        tag_name = extract_reference_name(message, "refs/tags/")
        {:error, {:user, "Tag '#{tag_name}' does not exist in the repository"}}

      String.contains?(message, "Project assigned to periodic was not found") ->
        {:error, {:user, "Project not found or access denied"}}

      true ->
        {:error, {:user, message}}
    end
  end

  defp handle_run_now_response(response), do: response

  defp extract_reference_name(message, prefix) do
    message
    |> String.split(prefix)
    |> List.last()
    |> String.trim_trailing(".")
  end
end
