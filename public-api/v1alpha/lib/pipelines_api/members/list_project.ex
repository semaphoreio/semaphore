defmodule PipelinesAPI.Members.ListProject do
  @moduledoc false
  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.RBACClient
  alias PipelinesAPI.RBACClient.ResponseFormatter
  alias Plug.Conn

  import PipelinesAPI.Members.Authorize, only: [authorize_view_people: 2]

  plug(:authorize_view_people)
  plug(:list_project_members)

  def list_project_members(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["members_list_project"], fn ->
      org_id = Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, "")
      project_id = conn.params["project_id"]

      result =
        %{org_id: org_id, project_id: project_id}
        |> RBACClient.list_project_members()

      case result do
        {:ok, members} ->
          serialized = ResponseFormatter.serialize_members(members)
          RespCommon.respond({:ok, %{members: serialized}}, conn)

        error ->
          RespCommon.respond(error, conn)
      end
    end)
  end
end
