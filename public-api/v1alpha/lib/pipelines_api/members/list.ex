defmodule PipelinesAPI.Members.List do
  @moduledoc false
  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.RBACClient
  alias Plug.Conn

  import PipelinesAPI.Members.Authorize, only: [authorize_view_people: 2]

  plug(:authorize_view_people)
  plug(:list_members)

  def list_members(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["members_list"], fn ->
      org_id = Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, "")

      %{
        org_id: org_id,
        member_type: conn.params["member_type"],
        page_no: parse_page_param(conn.params["page_no"], 0),
        page_size: parse_page_param(conn.params["page_size"], nil)
      }
      |> RBACClient.list_org_members()
      |> RespCommon.respond(conn)
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
