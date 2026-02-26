defmodule FrontWeb.SharedHelpersTest do
  use FrontWeb.ConnCase
  import Mock

  setup do
    Support.FakeServices.stub_responses()
  end

  describe "icon" do
    test "it includes passed options" do
      {:safe, image_string_with_class} = FrontWeb.SharedHelpers.icon("test", class: "db")
      assert image_string_with_class =~ "class='db'"
      assert image_string_with_class =~ "test"
      refute image_string_with_class =~ "width"
      refute image_string_with_class =~ "height"

      {:safe, image_string_with_width} = FrontWeb.SharedHelpers.icon("test", width: "24")
      assert image_string_with_width =~ "width='24'"
      refute image_string_with_width =~ "class"

      {:safe, image_string_without_height} =
        FrontWeb.SharedHelpers.icon("test", width: "24", class: "db")

      assert image_string_without_height =~ "width='24'"
      assert image_string_without_height =~ "class='db'"
      refute image_string_without_height =~ "height"

      {:safe, image_string_with_height} = FrontWeb.SharedHelpers.icon("test", height: "24")
      assert image_string_with_height =~ "height='24'"
    end
  end

  describe "pylon_contact_support_card/2" do
    test "returns nil when pylon feature is disabled", %{conn: conn} do
      layout_model = %Front.Layout.Model{permissions: %{"organization.contact_support" => true}}

      conn =
        conn
        |> assign(:organization_id, "org-1")

      with_mock FeatureProvider, feature_enabled?: fn _, _ -> false end do
        assert FrontWeb.SharedHelpers.pylon_contact_support_card(conn, layout_model) == nil
      end
    end

    test "returns support menu card when pylon feature is enabled", %{conn: conn} do
      layout_model = %Front.Layout.Model{permissions: %{"organization.contact_support" => true}}

      conn =
        conn
        |> assign(:organization_id, "org-1")

      with_mock FeatureProvider,
        feature_enabled?: fn
          :pylon_support, [param: "org-1"] -> true
          :restricted_support, [param: "org-1"] -> false
          _, _ -> false
        end do
        card_html =
          conn
          |> FrontWeb.SharedHelpers.pylon_contact_support_card(layout_model)
          |> Phoenix.HTML.safe_to_string()

        assert card_html =~ "Contact Support (Experimental)"
        assert card_html =~ "href=\"/support/pylon\""
      end
    end
  end
end
