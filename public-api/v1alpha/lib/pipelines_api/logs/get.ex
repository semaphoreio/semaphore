defmodule PipelinesAPI.Logs.Get do
  @moduledoc """
  Plug which serves for gathering logs for a particular job.
  """

  use Plug.Builder

  require Logger
  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.{Metrics}
  alias PipelinesAPI.JobsClient
  alias PipelinesAPI.ProjectClient
  alias PipelinesAPI.ArtifactHubClient
  alias PipelinesAPI.LoghubClient
  alias PipelinesAPI.Loghub2Client
  alias PipelinesAPI.Logs.Params, as: LogsParams
  alias PipelinesAPI.Util.ToTuple
  alias Plug.Conn

  @full_log_paths ["agent/job_logs.txt", "agent/job_logs.txt.gz"]
  @artifacts_api_disabled_message "The artifacts api feature is not enabled for your organization. Please contact support"

  import PipelinesAPI.Logs.Authorize, only: [authorize_job: 2]

  plug(:describe_job)
  plug(:authorize_job)
  plug(:prepare_response)

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

      if LogsParams.full_logs_requested_for_job?(conn.params, job) do
        conn |> get_full_logs(job)
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

  defp get_full_logs(conn, job) do
    with :ok <- ensure_artifacts_api_enabled(conn),
         {:ok, project} <- ProjectClient.describe(job.project_id),
         {:ok, artifact_store_id} <- artifact_store_id_from_project(project),
         {:ok, signed_url} <- fetch_signed_full_log_url(job.id, artifact_store_id) do
      conn
      |> put_resp_header("location", signed_url)
      |> send_resp(302, "")
    else
      {:error, :artifacts_api_disabled} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(403, @artifacts_api_disabled_message)

      {:error, {:not_found, _message}} ->
        Metrics.increment("PipelinesAPI.router", ["full_logs_artifact_lookup_failed"])
        RespCommon.respond(ToTuple.not_found_error("Full log artifact not found"), conn)

      error ->
        Metrics.increment("PipelinesAPI.router", ["full_logs_artifact_lookup_failed"])
        RespCommon.respond(error, conn)
    end
  rescue
    e ->
      Metrics.increment("PipelinesAPI.router", ["full_logs_artifact_lookup_failed"])
      Logger.error("Error getting full logs for #{job.id}: #{inspect(e)}")
      RespCommon.respond(ToTuple.internal_error("Internal error"), conn)
  end

  defp ensure_artifacts_api_enabled(conn) do
    with org_id when is_binary(org_id) and org_id != "" <-
           Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0),
         true <- FeatureProvider.feature_enabled?(:artifacts, param: org_id),
         true <- FeatureProvider.feature_enabled?(:artifacts_api, param: org_id) do
      :ok
    else
      _ -> {:error, :artifacts_api_disabled}
    end
  end

  defp fetch_signed_full_log_url(job_id, artifact_store_id) do
    with {:ok, path} <- resolve_full_log_artifact_path(job_id, artifact_store_id) do
      signed_url_for_artifact_path(artifact_store_id, job_id, path)
    end
  end

  defp resolve_full_log_artifact_path(job_id, artifact_store_id) do
    case ArtifactHubClient.list_path(%{
           artifact_store_id: artifact_store_id,
           scope: "jobs",
           scope_id: job_id,
           path: "agent"
         }) do
      {:ok, items} ->
        pick_preferred_full_log_path(items)

      {:error, {:not_found, _}} ->
        ToTuple.not_found_error("Full log artifact not found")

      error ->
        error
    end
  end

  defp pick_preferred_full_log_path(items) when is_list(items) do
    available_paths =
      items
      |> Enum.flat_map(fn
        %{is_directory: false, path: path} when is_binary(path) -> [path]
        _ -> []
      end)

    @full_log_paths
    |> Enum.find(&(&1 in available_paths))
    |> case do
      nil -> ToTuple.not_found_error("Full log artifact not found")
      path -> {:ok, path}
    end
  end

  defp pick_preferred_full_log_path(_items),
    do: ToTuple.not_found_error("Full log artifact not found")

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
        ToTuple.not_found_error("Full log artifact not found")

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
