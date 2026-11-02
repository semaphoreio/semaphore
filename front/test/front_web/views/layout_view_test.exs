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

  describe "turbo_full_reload_page?/1" do
    defp conn_with_js(js), do: %Plug.Conn{assigns: %{js: js}}

    test "opts pages owning long lived client state out of Turbo rendering" do
      assert FrontWeb.LayoutView.turbo_full_reload_page?(conn_with_js(:workflow_editor))
      assert FrontWeb.LayoutView.turbo_full_reload_page?(conn_with_js(:logs))
    end

    test "matches the assign whether it is an atom or a string" do
      assert FrontWeb.LayoutView.turbo_full_reload_page?(conn_with_js("workflow_editor"))
    end

    test "lets every other page render through Turbo" do
      refute FrontWeb.LayoutView.turbo_full_reload_page?(conn_with_js(:workflow_view))
      refute FrontWeb.LayoutView.turbo_full_reload_page?(conn_with_js(:people_page))
    end

    test "is false when the page sets no js assign" do
      refute FrontWeb.LayoutView.turbo_full_reload_page?(%Plug.Conn{assigns: %{}})
    end
  end

  describe "turbo_enabled?/1 with the feature provisioned" do
    @org_id "78114608-be8a-465a-b9cd-81970fb802c6"

    defp conn_with_org(org_id), do: %Plug.Conn{assigns: %{organization_id: org_id}}

    setup do
      # The org level override can only be set for a feature that exists, and
      # ui_turbo_navigation is not part of the default seed.
      Support.Stubs.Feature.setup_feature("ui_turbo_navigation", state: :HIDDEN, quantity: 0)

      :ok
    end

    test "is true for an organization the feature is enabled for" do
      Support.Stubs.Feature.enable_feature(@org_id, :ui_turbo_navigation)

      assert FrontWeb.LayoutView.turbo_enabled?(conn_with_org(@org_id))
    end

    test "is false for an organization the feature is hidden for" do
      Support.Stubs.Feature.disable_feature(@org_id, :ui_turbo_navigation)

      refute FrontWeb.LayoutView.turbo_enabled?(conn_with_org(@org_id))
    end
  end

  #
  # No setup here on purpose. ui_turbo_navigation has no feature record yet, so
  # this is what every organization gets today, and it is the case that keeps
  # the flag off until someone provisions it.
  #
  describe "turbo_enabled?/1 without the feature provisioned" do
    test "is false for an organization" do
      refute FrontWeb.LayoutView.turbo_enabled?(conn_with_org(@org_id))
    end

    test "is false when there is no organization on the conn" do
      refute FrontWeb.LayoutView.turbo_enabled?(%Plug.Conn{assigns: %{}})
    end
  end
end
