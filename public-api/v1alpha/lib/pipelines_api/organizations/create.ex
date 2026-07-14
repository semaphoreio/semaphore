defmodule PipelinesAPI.Organizations.Create do
  @moduledoc """
  Creates an organization for the authenticated user. Reachable only via
  me.<domain>/api/v1alpha/organizations; the user is taken from the
  x-semaphore-user-id header (account-wide token, no org context).
  """

  use Plug.Builder

  alias PipelinesAPI.Organizations.Onboarding
  alias PipelinesAPI.Pipelines.Common
  alias PipelinesAPI.Util.Metrics

  plug(:verify_params)
  plug(:create)

  def create(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["organizations_create"], fn ->
      conn
      |> do_create()
      |> Common.respond(conn)
    end)
  end

  defp do_create(conn) do
    username = conn.params["username"]
    name = conn.params["name"] || username

    with user_id when is_binary(user_id) and user_id != "" <- user_id(conn),
         {:ok, org} <- Onboarding.create_organization(name, username, user_id) do
      {:ok, format_org(org)}
    else
      nil -> {:error, {:user, "missing authenticated user"}}
      "" -> {:error, {:user, "missing authenticated user"}}
      {:error, _} = error -> error
    end
  end

  def verify_params(conn, _opts) do
    if present?(conn.params["username"]) do
      conn
    else
      # Common.respond/2 takes (state, conn) — piping conn in as the first
      # argument crashed with a FunctionClauseError (500) instead of a 400.
      {:error, {:user, "username must be present"}}
      |> Common.respond(conn)
      |> halt()
    end
  end

  defp present?(v), do: is_binary(v) and String.trim(v) != ""

  defp user_id(conn) do
    conn |> get_req_header("x-semaphore-user-id") |> List.first()
  end

  defp format_org(org) do
    %{
      organization_id: Map.get(org, :org_id),
      name: Map.get(org, :name),
      username: Map.get(org, :org_username)
    }
  end
end
