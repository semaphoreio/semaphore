defmodule PipelinesAPI.Artifacts.Common do
  @moduledoc """
  Shared helpers for artifacts API endpoints.
  """

  use Plug.Builder

  alias Google.Rpc.Code
  alias PipelinesAPI.JobsClient
  alias PipelinesAPI.Pipelines.Common
  alias PipelinesAPI.ProjectClient
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.Util.ToTuple
  alias PipelinesAPI.Util.VerifyData, as: VD
  alias PipelinesAPI.WorkflowClient.{WFGrpcClient, WFRequestFormatter}

  import Plug.Conn, only: [resp: 3, halt: 1]

  @valid_scopes ~w(projects workflows jobs)
  @valid_methods ~w(GET HEAD)

  def get_artifact_store_id(conn, _opts) do
    conn.params
    |> Map.get("project_id")
    |> ProjectClient.describe()
    |> process_response(conn)
  end

  def verify_scope_ownership(conn, _opts) do
    conn.params
    |> scope_belongs_to_project()
    |> continue_or_halt(conn)
  end

  def scope_valid?(scope), do: scope in @valid_scopes
  def method_valid?(method), do: method in @valid_methods

  def validate_request_params(conn, enabled_fields, opts \\ []) do
    require_path? = Keyword.get(opts, :require_path, false)
    validate_method? = Keyword.get(opts, :validate_method, false)
    method_error_message = "method must be one of: GET, HEAD"

    with {:ok, method} <- normalize_method(conn.params["method"], validate_method?),
         {:ok, normalized_path} <- sanitize_relative_path(conn.params["path"], require_path?) do
      result =
        VD.verify(:ok, true, "")
        |> maybe_verify_project_id(conn.params["project_id"])
        |> VD.verify(
          VD.is_present_string?(conn.params["scope"]),
          "scope must be present"
        )
        |> VD.verify(
          scope_valid?(conn.params["scope"]),
          "scope must be one of: projects, workflows, jobs"
        )
        |> VD.verify(
          VD.is_present_string?(conn.params["scope_id"]),
          "scope_id must be present"
        )
        |> VD.verify(
          VD.is_valid_uuid?(conn.params["scope_id"]),
          "scope_id must be a valid UUID"
        )
        |> maybe_verify_method(validate_method?, method)

      result
      |> VD.finalize_verification(conn, enabled_fields)
      |> set_normalized_params(normalized_path, method, validate_method?)
    else
      {:error, ^method_error_message} ->
        conn |> resp(400, method_error_message) |> halt()

      {:error, message} ->
        conn |> resp(400, message) |> halt()
    end
  end

  def project_id_from_scope(%{"scope" => "projects", "scope_id" => scope_id}), do: {:ok, scope_id}

  def project_id_from_scope(%{"scope" => "jobs", "scope_id" => scope_id}) do
    with {:ok, job} <- JobsClient.describe(%{"job_id" => scope_id}),
         true <- is_binary(job.project_id) and job.project_id != "" do
      {:ok, job.project_id}
    else
      false ->
        ToTuple.internal_error("Internal error")

      {:error, {:internal, _}} = error ->
        error

      {:error, _} ->
        ToTuple.not_found_error("Not found")

      _ ->
        ToTuple.internal_error("Internal error")
    end
  end

  def project_id_from_scope(%{"scope" => "workflows", "scope_id" => scope_id}) do
    with {:ok, response} <-
           scope_id |> WFRequestFormatter.form_describe_request() |> WFGrpcClient.describe(),
         {:ok, workflow} <- workflow_from_response(response),
         true <- is_binary(workflow.project_id) and workflow.project_id != "" do
      {:ok, workflow.project_id}
    else
      false ->
        ToTuple.internal_error("Internal error")

      {:error, {:internal, _}} = error ->
        error

      {:error, _} ->
        ToTuple.not_found_error("Not found")

      _ ->
        ToTuple.internal_error("Internal error")
    end
  end

  def project_id_from_scope(_params), do: ToTuple.not_found_error("Not found")

  def sanitize_relative_path(path, required? \\ false)

  def sanitize_relative_path(path, false) when path in [nil, ""], do: {:ok, ""}

  def sanitize_relative_path(path, true) when path in [nil, ""],
    do: {:error, "path must be present"}

  def sanitize_relative_path(path, required?) when is_binary(path) do
    trimmed_path = String.trim(path)

    cond do
      trimmed_path == "" and required? ->
        {:error, "path must be present"}

      trimmed_path == "" ->
        {:ok, ""}

      String.starts_with?(trimmed_path, "/") ->
        {:error, "absolute paths are not allowed"}

      String.contains?(trimmed_path, "\\") ->
        {:error, "invalid path"}

      true ->
        segments = String.split(trimmed_path, "/", trim: true)

        if Enum.any?(segments, &(&1 in [".", ".."])) do
          {:error, "path traversal is not allowed"}
        else
          {:ok, Enum.join(segments, "/")}
        end
    end
  end

  def sanitize_relative_path(_, _), do: {:error, "invalid path"}

  defp normalize_method(_method, false), do: {:ok, "GET"}
  defp normalize_method(nil, true), do: {:ok, "GET"}
  defp normalize_method(method, true) when is_binary(method), do: {:ok, String.upcase(method)}
  defp normalize_method(_method, true), do: {:error, "method must be one of: GET, HEAD"}

  defp maybe_verify_method(result, false, _method), do: result

  defp maybe_verify_project_id(result, nil), do: result
  defp maybe_verify_project_id(result, ""), do: result

  defp maybe_verify_project_id(result, project_id) do
    VD.verify(result, VD.is_valid_uuid?(project_id), "project id must be a valid UUID")
  end

  defp maybe_verify_method(result, true, method) do
    VD.verify(
      result,
      method_valid?(method),
      "method must be one of: GET, HEAD"
    )
  end

  defp set_normalized_params(conn = %{halted: true}, _path, _method, _validate_method?), do: conn

  defp set_normalized_params(conn, path, method, true) do
    updated_params =
      conn.params
      |> Map.put("path", path)
      |> Map.put("method", method)

    conn
    |> Map.put(:params, updated_params)
  end

  defp set_normalized_params(conn, path, _method, false) do
    conn
    |> Map.put(:params, Map.put(conn.params, "path", path))
  end

  defp process_response({:ok, project}, conn) do
    art_store_id = project.spec.artifact_store_id
    conn |> Map.put(:params, Map.put(conn.params, "artifact_store_id", art_store_id))
  end

  defp process_response(error, conn) do
    error |> Common.respond(conn) |> halt()
  end

  defp continue_or_halt(:ok, conn), do: conn

  defp continue_or_halt({:error, {:internal, _}}, conn) do
    increment_scope_ownership_metric(conn, "internal_error")
    conn |> resp(500, "Internal error") |> halt()
  end

  defp continue_or_halt({:error, _}, conn) do
    increment_scope_ownership_metric(conn, "failed")
    conn |> resp(404, "Not found") |> halt()
  end

  defp continue_or_halt(_error, conn) do
    increment_scope_ownership_metric(conn, "internal_error")
    conn |> resp(500, "Internal error") |> halt()
  end

  defp increment_scope_ownership_metric(conn, outcome) do
    metric_tag =
      conn
      |> scope_ownership_endpoint()
      |> Kernel.<>("_scope_ownership_#{outcome}")

    Metrics.increment("PipelinesAPI.router", [metric_tag])
  end

  defp scope_ownership_endpoint(%{request_path: request_path}) when is_binary(request_path) do
    cond do
      String.ends_with?(request_path, "/artifacts/signed_url") -> "artifacts_signed_url"
      String.ends_with?(request_path, "/artifacts") -> "artifacts_list"
      true -> "artifacts"
    end
  end

  defp scope_ownership_endpoint(_conn), do: "artifacts"

  defp scope_belongs_to_project(params = %{"project_id" => project_id}) do
    with {:ok, resolved_project_id} <- project_id_from_scope(params),
         true <- resolved_project_id == project_id do
      :ok
    else
      false ->
        ToTuple.not_found_error("Not found")

      {:error, {:internal, _}} = error ->
        error

      {:error, _} ->
        ToTuple.not_found_error("Not found")

      _ ->
        ToTuple.internal_error("Internal error")
    end
  end

  defp scope_belongs_to_project(_params), do: ToTuple.not_found_error("Not found")

  defp workflow_from_response(%{status: %{code: code}, workflow: workflow})
       when not is_nil(workflow) do
    case workflow_status(code) do
      :OK -> {:ok, workflow}
      :FAILED_PRECONDITION -> ToTuple.not_found_error("Not found")
      :NOT_FOUND -> ToTuple.not_found_error("Not found")
      _ -> ToTuple.internal_error("Internal error")
    end
  end

  defp workflow_from_response(%{status: %{code: code}}) do
    case workflow_status(code) do
      :FAILED_PRECONDITION -> ToTuple.not_found_error("Not found")
      :NOT_FOUND -> ToTuple.not_found_error("Not found")
      _ -> ToTuple.internal_error("Internal error")
    end
  end

  defp workflow_from_response(_response), do: ToTuple.internal_error("Internal error")

  defp workflow_status(code) when is_integer(code) do
    code
    |> Code.key()
    |> case do
      nil -> :UNKNOWN
      status -> status
    end
  rescue
    _ -> :UNKNOWN
  end
end
