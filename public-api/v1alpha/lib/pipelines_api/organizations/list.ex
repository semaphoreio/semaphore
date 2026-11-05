defmodule PipelinesAPI.Organizations.List do
  @moduledoc """
  Lists the organizations the authenticated user belongs to. Reachable only via
  GET me.<domain>/api/v1alpha/organizations; the user is taken from the
  x-semaphore-user-id header (account-wide token, no org context).

  Returns ONLY the caller's own organizations - the user_id is read exclusively
  from the header the auth edge injects, never from a query param or request
  body, so a caller cannot enumerate another user's organizations.
  """

  use Plug.Builder

  alias PipelinesAPI.OrganizationsClient
  alias PipelinesAPI.Pipelines.Common
  alias PipelinesAPI.Util.Metrics

  plug(:list)

  def list(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["organizations_list"], fn ->
      conn
      |> do_list()
      |> Common.respond(conn)
    end)
  end

  defp do_list(conn) do
    with user_id when is_binary(user_id) and user_id != "" <- user_id(conn),
         {:ok, orgs} <- OrganizationsClient.list_for_user(user_id) do
      {:ok, Enum.map(orgs, &format_org/1)}
    else
      nil -> {:error, {:user, "missing authenticated user"}}
      "" -> {:error, {:user, "missing authenticated user"}}
      {:error, _} = error -> error
    end
  end

  # user_id comes ONLY from the header the auth edge injects. It is never taken
  # from conn.params/body, so the listing is always scoped to the caller.
  defp user_id(conn) do
    conn |> get_req_header("x-semaphore-user-id") |> List.first()
  end

  defp format_org(org) do
    %{
      organization_id: Map.get(org, :org_id),
      name: Map.get(org, :name),
      username: Map.get(org, :org_username),
      created_at: format_timestamp(Map.get(org, :created_at))
    }
  end

  # Protobuf Timestamp -> ISO8601 string; nil for the proto3 zero value / absent.
  defp format_timestamp(%{seconds: seconds}) when is_integer(seconds) and seconds > 0 do
    case DateTime.from_unix(seconds) do
      {:ok, dt} -> DateTime.to_iso8601(dt)
      _ -> nil
    end
  end

  defp format_timestamp(_), do: nil
end
