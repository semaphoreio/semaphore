defmodule FrontWeb.LayoutViewTest do
  use FrontWeb.ConnCase
  doctest FrontWeb.LayoutView, import: true

  import Mock
  import Phoenix.View

  @template "_license_banner.html"
  @view FrontWeb.LayoutView

  def render_banner(assigns) do
    render_to_string(@view, @template, assigns)
  end

  test "no banner for valid license" do
    with_mock Front, ee?: fn -> true end do
      html = render_banner(%{license_status: %{valid: true, expires_at: nil}, conn: %Plug.Conn{}})
      refute html =~ "license-expired-banner"
      refute html =~ "license-expiring-banner"
    end
  end

  test "shows expired license banner" do
    with_mock Front, ee?: fn -> true end do
      html =
        render_banner(%{license_status: %{valid: false, expires_at: nil}, conn: %Plug.Conn{}})

      assert html =~ "license-expired-banner"

      assert html =~
               "You are running a Semaphore Enterprise Edition server without a valid license"
    end
  end

  test "shows soon-to-expire license banner" do
    with_mock Front, ee?: fn -> true end do
      # 3 days from now
      expires_at_dt = DateTime.add(DateTime.utc_now(), 3 * 24 * 60 * 60)

      expires_at = %Google.Protobuf.Timestamp{
        seconds: DateTime.to_unix(expires_at_dt),
        nanos: 0
      }

      html =
        render_banner(%{
          license_status: %{valid: true, expires_at: expires_at},
          conn: %Plug.Conn{}
        })

      assert html =~ "license-expiring-banner"
      assert html =~ "Your Semaphore Enterprise Edition license will expire on"
    end
  end
end
