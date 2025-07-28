defmodule FrontWeb.ReportView do
  use FrontWeb, :view

  def json_config(conn) do
    conn
    |> config
    |> Poison.encode!()
  end

  defp config(conn) do
    %{
      baseUrl: conn.assigns.base_url,
      reportUrl: conn.assigns.report_url,
      reportContext: conn.assigns.report_context
    }
  end
end
