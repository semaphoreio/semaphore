defmodule PipelinesAPI.Members.ListProject do
  @moduledoc false
  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.RBACClient
  alias PipelinesAPI.RBACClient.ResponseFormatter
  alias Plug.Conn

  import PipelinesAPI.Members.Authorize, only: [authorize_view_project_people: 2]

  plug(:authorize_view_project_people)
  plug(:list_project_members)

  def list_project_members(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["members_list_project"], fn ->
      org_id = Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, "")
      project_id = conn.params["project_id"]

      result =
        %{
          org_id: org_id,
          project_id: project_id,
          page_no: parse_page_param(conn.params["page_no"], 0),
          page_size: parse_page_param(conn.params["page_size"], nil)
        }
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

  defp parse_page_param(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {num, _} when num >= 0 -> num
      _ -> default
    end
  end

  defp parse_page_param(_, default), do: default
end
