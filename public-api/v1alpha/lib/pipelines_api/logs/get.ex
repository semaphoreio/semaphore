defmodule PipelinesAPI.Logs.Get do
  @moduledoc """
  Plug which serves for gathering logs for a particular job.
  """

  use Plug.Builder

  import PipelinesAPI.Util.APIResponse

  require Logger
  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.{Metrics}
  alias PipelinesAPI.JobsClient
  alias PipelinesAPI.LoghubClient
  alias PipelinesAPI.Loghub2Client

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

      conn
      |> get_logs(job.id, job.self_hosted)
    end)
  end

  defp get_logs(conn, job_id, true) do
    case Loghub2Client.generate_token(job_id) do
      {:ok, token} ->
        conn
        |> put_resp_header("location", build_loghub2_url(conn, job_id, token))
        |> put_status(conn.status || 302)
        |> text("")

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

  defp prepare_response(events) do
    Enum.join([~c'{ "events": [', Enum.join(events, ","), "] }"], "")
  end

  defp build_loghub2_url(conn, job_id, token) do
    "https://#{conn.host}/api/v1/logs/#{job_id}?jwt=#{token}"
  end
end
