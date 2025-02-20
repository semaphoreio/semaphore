defmodule PipelinesAPI.Workflows.Schedule do
  @moduledoc """
  Module is responsible for creating workflows by creating hook on RepoProxy
  service that will trigger a workflow on Plumber
  """

  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.Pipelines.Common
  alias PipelinesAPI.RepoProxyClient
  alias Plug.Conn

  use Plug.Builder

  import PipelinesAPI.Workflows.WfAuthorize, only: [wf_authorize_create: 2]

  plug(:wf_authorize_create)
  plug(:schedule)

  def schedule(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["wf_schedule"], fn ->
      conn
      |> add_requester_id()
      |> RepoProxyClient.create()
      |> Common.respond(conn)
    end)
  end

  defp add_requester_id(conn) do
    requester_id = Conn.get_req_header(conn, "x-semaphore-user-id") |> Enum.at(0, "")
    Map.put(conn.params, "requester_id", requester_id)
  end
end
