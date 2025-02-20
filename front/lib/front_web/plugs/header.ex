defmodule FrontWeb.Plugs.Header do
  import Plug.Conn

  def init(default), do: default

  def call(conn, _) do
    Front.Tracing.track(conn.assigns.trace_id, "fetch_layout_model", fn ->
      if conn.assigns[:authorization] == :member do
        conn |> assign_common_app_layout()
      else
        conn
      end
    end)
  end

  defp assign_common_app_layout(conn) do
    params =
      struct!(Front.Layout.Model.LoadParams,
        organization_id: conn.assigns.organization_id,
        user_id: conn.assigns.user_id
      )

    force_cold_boot = conn.params["force_cold_boot"]

    {:ok, layout_model, layout_source} =
      params |> Front.Layout.Model.get(force_cold_boot: force_cold_boot)

    conn
    |> put_layout_source_header(layout_source)
    |> assign(:layout_model, layout_model)
  end

  defp put_layout_source_header(conn, source) do
    case source do
      :from_cache -> conn |> put_resp_header("semaphore_layout_source", "cache")
      :from_api -> conn |> put_resp_header("semaphore_layout_source", "API")
    end
  end
end
