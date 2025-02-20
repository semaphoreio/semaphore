defmodule Rbac.Okta.Scim.AuthPlug do
  @moduledoc """
  This module is the main security verification for all SCIM actions.
  It is protecting all endpoints in the SCIM.API.

  When it is finished, it injects:
  - conn.assigns.org_id
  - conn.assigns.integration

  If the auth is succesful, it goes allows the action to happen.
  Otherwise, it returns HTTP 401.
  """
  import Plug.Conn

  alias Rbac.Okta.Integration

  def init(options), do: options

  def call(conn, _opts) do
    if health_check?(conn) do
      conn
    else
      authorize(conn)
    end
  end

  def authorize(conn) do
    with conn <- assign_org_id(conn),
         {:ok, integration} <- Integration.find_by_org_id(conn.assigns.org_id),
         {:ok, provided_token} <- extract_bearer_token(conn),
         true <- valid_token?(provided_token, integration.scim_token_hash),
         conn <- assign(conn, :integration, integration) do
      conn
    else
      _ -> conn |> render_unauthorized() |> halt()
    end
  end

  defp render_unauthorized(conn) do
    conn |> put_resp_content_type("text/plain") |> send_resp(401, "Unathorized")
  end

  defp assign_org_id(conn) do
    id = conn |> get_req_header("x-semaphore-org-id") |> List.first()

    assign(conn, :org_id, id)
  end

  defp health_check?(conn) do
    conn.request_path == "/" || conn.request_path == "/is_alive"
  end

  def extract_bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, token}
      _ -> {:error, :not_found}
    end
  end

  @min_token_size 30

  def valid_token?(provided_token, saved_token_hash) do
    cond do
      saved_token_hash == nil ->
        false

      saved_token_hash == "" ->
        false

      String.length(provided_token) < @min_token_size ->
        false

      true ->
        case Base.decode64(saved_token_hash) do
          {:ok, saved_token_hash} ->
            provided_hash = Rbac.Okta.Scim.Token.hash(provided_token)

            provided_hash == saved_token_hash

          _ ->
            false
        end
    end
  end
end
