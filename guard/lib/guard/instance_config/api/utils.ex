defmodule Guard.InstanceConfig.Api.Utils do
  use Plug.Builder

  def put_notification(conn, level, message) when level in [:notice, :alert] do
    conn |> assign(level, message)
  end

  defp get_notification(conn, level) when level in [:notice, :alert] do
    conn.assigns[level]
  end

  def redirect_to_url(conn, url) do
    url = conn |> add_notifications_to_url(url)

    conn
    |> Guard.Utils.Http.redirect_to_url(url)
  end

  defp add_notifications_to_url(conn, url) do
    (url <> "?")
    |> append_if_present("notice", get_notification(conn, :notice))
    |> append_if_present("alert", get_notification(conn, :alert))
  end

  defp append_if_present(url, key, value) when value != nil do
    "#{url}#{key}=#{value}&"
  end

  defp append_if_present(url, _key, _value), do: url

  def redirect_to_front(conn, path) do
    org_username = conn.assigns[:org_username]
    domain = domain()

    case org_username do
      nil -> conn |> redirect_to_url("https://me.#{domain}")
      org_username -> conn |> redirect_to_url("https://#{org_username}.#{domain}#{path}")
    end
  end

  defp domain, do: Application.get_env(:guard, :base_domain)
end
