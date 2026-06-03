defmodule PipelinesAPI.Logs.Get do
  @moduledoc """
  Plug which serves for gathering logs for a particular job.
  """

  use Plug.Builder

  require Logger
  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Audit
  alias PipelinesAPI.JobsClient
  alias PipelinesAPI.ProjectClient
  alias PipelinesAPI.ArtifactHubClient
  alias PipelinesAPI.LoghubClient
  alias PipelinesAPI.Loghub2Client
  alias PipelinesAPI.Logs.Params, as: LogsParams
  alias PipelinesAPI.Util.{Metrics, RequestMetrics, ToTuple}
  alias Plug.Conn

  @artifact_job_log_paths ["agent/job_logs.txt", "agent/job_logs.txt.gz"]
  @artifacts_api_disabled_message "The artifacts api feature is not enabled for your organization. Please contact support"

  import PipelinesAPI.Logs.Authorize, only: [authorize_job: 2]

  plug(:track_artifact_job_logs_metrics)
  plug(:describe_job)
  plug(:authorize_job)
  plug(:prepare_response)

  def track_artifact_job_logs_metrics(conn, _opts) do
    conn = Conn.fetch_query_params(conn)

    if LogsParams.artifact_job_logs_requested?(conn.query_params) do
      RequestMetrics.track_request(conn, "full_logs_api_request")
    else
      conn
    end
  end

  def describe_job(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["describe_job"], fn ->
      conn.params
      |> JobsClient.describe()
      |> continue_or_halt(conn)
    end)
  end

  def continue_or_halt({:ok, job}, conn) do
    params = Map.merge(conn.params, %{job: job})
    conn |> Map.put(:params, params)
  end

  def continue_or_halt(error, conn) do
    RespCommon.respond(error, conn) |> halt
  end

  def prepare_response(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["get_logs"], fn ->
      job = conn.params.job

      if LogsParams.artifact_job_logs_requested_for_job?(conn.params, job) do
        conn |> get_artifact_job_logs(job)
      else
        conn |> get_logs(job.id, job.self_hosted)
      end
    end)
  end

  defp get_logs(conn, job_id, true) do
    case Loghub2Client.generate_token(job_id) do
      {:ok, token} ->
        conn
        |> put_resp_header("location", build_loghub2_url(conn, job_id, token))
        |> send_resp(302, "")

      e ->
        RespCommon.respond(e, conn)
    end
  end

  defp get_logs(conn, job_id, false) do
    case LoghubClient.get_log_events(job_id) do
      {:ok, events} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, prepare_response(events))

      e ->
        RespCommon.respond(e, conn)
    end
  rescue
    e ->
      Logger.error("Error getting logs for #{job_id}: #{inspect(e)}")
      RespCommon.respond(e, conn)
  end

  defp get_artifact_job_logs(conn, job) do
    with :ok <- ensure_artifact_job_logs_feature_enabled(conn),
         {:ok, project} <- ProjectClient.describe(job.project_id),
         {:ok, artifact_store_id} <- artifact_store_id_from_project(project),
         {:ok, path} <- resolve_artifact_job_logs_path(job.id, artifact_store_id),
         {:ok, _audit} <- log_artifact_job_logs_download(conn, job, path),
         {:ok, signed_url} <- signed_url_for_artifact_path(artifact_store_id, job.id, path) do
      conn
      |> put_resp_header("location", signed_url)
      |> send_resp(302, "")
    else
      {:error, :artifact_job_logs_feature_disabled} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(403, @artifacts_api_disabled_message)

      {:error, {:not_found, _message}} ->
        Metrics.increment("PipelinesAPI.router", ["full_logs_artifact_lookup_failed"])
        RespCommon.respond(ToTuple.not_found_error("Artifact job logs not found"), conn)

      {:error, {:audit_failed, reason}} ->
        Metrics.increment("PipelinesAPI.router", ["full_logs_artifact_audit_failed"])
        Logger.error("Failed to audit artifact job logs download: #{inspect(reason)}")
        RespCommon.respond(ToTuple.internal_error("Internal error"), conn)

      error ->
        Metrics.increment("PipelinesAPI.router", ["full_logs_artifact_lookup_failed"])
        RespCommon.respond(error, conn)
    end
  rescue
    e ->
      Metrics.increment("PipelinesAPI.router", ["full_logs_artifact_lookup_failed"])
      Logger.error("Error getting artifact job logs for #{job.id}: #{inspect(e)}")
      RespCommon.respond(ToTuple.internal_error("Internal error"), conn)
  end

  defp ensure_artifact_job_logs_feature_enabled(conn) do
    with org_id when is_binary(org_id) and org_id != "" <-
           Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0),
         true <- artifact_job_logs_feature_enabled?(org_id) do
      :ok
    else
      _ -> {:error, :artifact_job_logs_feature_disabled}
    end
  end

  defp artifact_job_logs_feature_enabled?(org_id) do
    FeatureProvider.feature_enabled?(:artifacts_api, param: org_id) ||
      FeatureProvider.feature_enabled?(:artifacts_job_logs, param: org_id)
  end

  defp resolve_artifact_job_logs_path(job_id, artifact_store_id) do
    case ArtifactHubClient.list_path(%{
           artifact_store_id: artifact_store_id,
           scope: "jobs",
           scope_id: job_id,
           path: "agent"
         }) do
      {:ok, items} ->
        pick_preferred_artifact_job_logs_path(items)

      {:error, {:not_found, _}} ->
        ToTuple.not_found_error("Artifact job logs not found")

      error ->
        error
    end
  end

  defp log_artifact_job_logs_download(conn, job, path) do
    case Audit.log_artifact_download(conn, %{
           "scope" => "jobs",
           "scope_id" => job.id,
           "path" => path,
           "project_id" => job.project_id,
           "method" => "GET"
         }) do
      {:ok, _audit} = ok -> ok
      {:error, reason} -> {:error, {:audit_failed, reason}}
    end
  end

  defp pick_preferred_artifact_job_logs_path(items) when is_list(items) do
    available_paths =
      items
      |> Enum.flat_map(fn
        %{is_directory: false, path: path} when is_binary(path) -> [path]
        _ -> []
      end)

    @artifact_job_log_paths
    |> Enum.find(&(&1 in available_paths))
    |> case do
      nil -> ToTuple.not_found_error("Artifact job logs not found")
      path -> {:ok, path}
    end
  end

  defp pick_preferred_artifact_job_logs_path(_items),
    do: ToTuple.not_found_error("Artifact job logs not found")

  defp signed_url_for_artifact_path(artifact_store_id, job_id, path) do
    case ArtifactHubClient.get_signed_url(%{
           artifact_store_id: artifact_store_id,
           scope: "jobs",
           scope_id: job_id,
           path: path,
           method: "GET"
         }) do
      {:ok, %{url: url}} when is_binary(url) and url != "" ->
        {:ok, url}

      {:ok, _response} ->
        ToTuple.not_found_error("Artifact job logs not found")

      error ->
        error
    end
  end

  defp prepare_response(events) do
    Enum.join(['{ "events": [', Enum.join(events, ","), "] }"], "")
  end

  defp build_loghub2_url(conn, job_id, token) do
    "https://#{conn.host}/api/v1/logs/#{job_id}?jwt=#{token}"
  end

  defp artifact_store_id_from_project(%{spec: %{artifact_store_id: artifact_store_id}})
       when is_binary(artifact_store_id) and artifact_store_id != "",
       do: {:ok, artifact_store_id}

  defp artifact_store_id_from_project(_project),
    do: ToTuple.internal_error("Artifact store is not configured")
end
