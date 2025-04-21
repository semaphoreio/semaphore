defmodule CanvasFrontWeb.Plug.AssignOrgInfo do
  import Plug.Conn

  def init(options), do: options

  def call(conn, _opts) do
    org_id =
      conn
      |> get_req_header("x-semaphore-org-id")
      |> List.first()

    org_created_at = fetch_org_created_at(org_id)

    org_name =
      conn
      |> get_req_header("x-semaphore-org-username")
      |> List.first()

    conn
    |> assign(:organization_id, org_id)
    |> assign(:organization_username, org_name)
    |> assign(:organization_created_at, org_created_at)
  end

  defp fetch_org_created_at(nil), do: nil

  defp fetch_org_created_at(org_id) do
    CanvasFront.Models.Organization.find(org_id, [:created_at])
    |> case do
      nil -> nil
      org -> org |> Map.get(:created_at)
    end
  end
end
