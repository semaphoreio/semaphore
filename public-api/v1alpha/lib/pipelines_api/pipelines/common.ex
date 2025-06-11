defmodule PipelinesAPI.Pipelines.Common do
  @moduledoc false

  import Plug.Conn
  import PipelinesAPI.Util.APIResponse

  def respond(state, conn, encode? \\ true)

  def respond({:ok, response}, conn, encode?) do
    respond_(conn, 200, response, encode?)
  end

  def respond({:error, {:user, message}}, conn, encode?) do
    respond_(conn, 400, message, encode?)
  end

  def respond({:error, {:not_found, message}}, conn, encode?) do
    respond_(conn, 404, message, encode?)
  end

  def respond({:error, {:internal, message}}, conn, encode?) do
    respond_(conn, 500, message, encode?)
  end

  def respond(_error, conn, encode?) do
    respond_(conn, 500, "Internal error", encode?)
  end

  # Sobelow is always warning when using send_resp when value is not actual hardcoded string nor encoded,
  #  json encoded content is safe to use send_resp.
  # sobelow_skip ["XSS.SendResp"]
  defp respond_(conn, code, content, _encode? = true) do
    json(conn, content)
  end

  # The Sobelow.XSS.SendResp is focused on Phoenix apps so it does not recognise Plug.HTML.html_escape/1
  # sobelow_skip ["XSS.SendResp"]
  defp respond_(conn, code, content, _encode? = false) do
    conn
    |> put_status(code)
    |> text(Plug.HTML.html_escape(content))
  end

  def respond_paginated({:error, e}, conn), do: respond({:error, e}, conn)

  def respond_paginated({:ok, page}, conn) do
    resp_headers = generate_resp_headers(page, conn)

    conn = Map.put(conn, :resp_headers, resp_headers)

    respond({:ok, page.entries}, conn)
  end

  defp generate_resp_headers(page, conn = %{request_path: "/workflows"}) do
    conn
    |> Map.put(:request_path, "/api/#{api_version()}/plumber-workflows")
    |> Scrivener.Headers.paginate(page)
    |> Map.get(:resp_headers)
  end

  defp generate_resp_headers(page, conn) do
    conn
    |> Map.put(:request_path, "/api/#{api_version()}" <> conn.request_path)
    |> Scrivener.Headers.paginate(page)
    |> Map.get(:resp_headers)
  end

  defp api_version(), do: System.get_env("API_VERSION")
end
