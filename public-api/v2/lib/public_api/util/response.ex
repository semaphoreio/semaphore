defmodule PublicAPI.Util.Response do
  @moduledoc false

  import Plug.Conn

  def respond(state, conn, encode? \\ true)

  def respond({:ok, nil}, conn, encode?) do
    respond_(conn, 204, "", encode?)
  end

  def respond({:ok, response}, conn, encode?) do
    respond_(conn, 200, response, encode?)
  end

  def respond({:error, {:user, message}}, conn, encode?) do
    respond_(conn, 400, message, encode?)
  end

  def respond({:error, {:forbidden, message}}, conn, encode?) do
    respond_(conn, 403, message, encode?)
  end

  def respond({:error, {:not_found, message}}, conn, encode?) do
    respond_(
      conn,
      404,
      %{
        message: message,
        documentation_url: Application.get_env(:public_api, :documentation_url)
      },
      encode?
    )
  end

  def respond({:error, {:internal, message}}, conn, encode?) do
    respond_(conn, 500, message, encode?)
  end

  def respond(_error, conn, encode?) do
    respond_(conn, 500, "Internal error", encode?)
  end

  defp respond_(conn, code = 204, _, _) do
    conn
    |> send_resp(code, "")
  end

  # Sobelow is always warning when using send_resp when value is not actual hardcoded string nor encoded,
  #  json encoded content is safe to use send_resp.
  # sobelow_skip ["XSS.SendResp"]
  defp respond_(conn, code, content, _encode? = true),
    do:
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(code, content |> Jason.encode!())

  # The Sobelow.XSS.SendResp is focused on Phoenix apps so it does not recognise Plug.HTML.html_escape/1
  # sobelow_skip ["XSS.SendResp"]
  defp respond_(conn, code, content, _encode? = false),
    do: send_resp(conn, code, Plug.HTML.html_escape(content))

  def respond_paginated({:error, e}, conn), do: respond({:error, e}, conn)

  @doc """
  Respond with a paginated list of entries.
  For offset pagination the total_entries must be set.
  """
  def respond_paginated({:ok, page}, conn) do
    resp_headers = generate_resp_headers(page, conn)

    conn = Map.put(conn, :resp_headers, resp_headers)

    respond({:ok, page.entries}, conn)
  end

  defp generate_resp_headers(page, conn = %{request_path: "/workflows"}) do
    conn
    |> Map.put(:request_path, "/api/#{api_version()}/workflows")
    |> PublicAPI.Util.Headers.paginate(page)
    |> Map.get(:resp_headers)
  end

  defp generate_resp_headers(page, conn) do
    conn
    |> Map.put(:request_path, "/api/#{api_version()}" <> conn.request_path)
    |> PublicAPI.Util.Headers.paginate(page)
    |> Map.get(:resp_headers)
  end

  defp api_version(), do: System.get_env("API_VERSION")
end
