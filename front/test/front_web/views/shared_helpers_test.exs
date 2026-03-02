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

  describe "livechat_enabled?/1" do
    setup do
      original_snippet = Application.get_env(:front, :zendesk_snippet_id)

      on_exit(fn ->
        restore_env(:zendesk_snippet_id, original_snippet)
      end)

      :ok
    end

    test "returns false when both zendesk and pylon chat are enabled", %{conn: conn} do
      Application.put_env(:front, :zendesk_snippet_id, "zendesk-key")

      conn =
        conn
        |> assign(:authorization, :member)
        |> assign(:organization_id, "org-1")

      with_mock FeatureProvider,
        feature_enabled?: fn
          :zendesk_live_chat, [param: "org-1"] -> true
          :pylon_chat, [param: "org-1"] -> true
          _, _ -> false
        end do
        assert FrontWeb.SharedHelpers.livechat_enabled?(conn) == {false, "zendesk-key"}
      end
    end

    test "returns true when zendesk live chat is enabled and pylon chat is disabled", %{
      conn: conn
    } do
      Application.put_env(:front, :zendesk_snippet_id, "zendesk-key")

      conn =
        conn
        |> assign(:authorization, :member)
        |> assign(:organization_id, "org-1")

      with_mock FeatureProvider,
        feature_enabled?: fn
          :zendesk_live_chat, [param: "org-1"] -> true
          :pylon_chat, [param: "org-1"] -> false
          _, _ -> false
        end do
        assert FrontWeb.SharedHelpers.livechat_enabled?(conn) == {true, "zendesk-key"}
      end
    end
  end

  describe "pylon_contact_support_card/2" do
    test "returns nil when support portal features are disabled", %{conn: conn} do
      layout_model = %Front.Layout.Model{permissions: %{"organization.contact_support" => true}}

      conn =
        conn
        |> assign(:organization_id, "org-1")

      with_mock FeatureProvider, feature_enabled?: fn _, _ -> false end do
        assert FrontWeb.SharedHelpers.pylon_contact_support_card(conn, layout_model) == nil
      end
    end

    test "returns nil when unsupported support tier is enabled", %{conn: conn} do
      layout_model = %Front.Layout.Model{permissions: %{"organization.contact_support" => true}}

      conn =
        conn
        |> assign(:organization_id, "org-1")

      with_mock FeatureProvider,
        feature_enabled?: fn
          :"support-tier-2", [param: "org-1"] -> true
          :restricted_support, [param: "org-1"] -> false
          _, _ -> false
        end do
        assert FrontWeb.SharedHelpers.pylon_contact_support_card(conn, layout_model) == nil
      end
    end

    test "returns support portal card when tier 3 is enabled", %{conn: conn} do
      layout_model = %Front.Layout.Model{permissions: %{"organization.contact_support" => true}}

      conn =
        conn
        |> assign(:organization_id, "org-1")

      with_mock FeatureProvider,
        feature_enabled?: fn
          :"support-tier-3", [param: "org-1"] -> true
          :restricted_support, [param: "org-1"] -> false
          _, _ -> false
        end do
        card_html =
          conn
          |> FrontWeb.SharedHelpers.pylon_contact_support_card(layout_model)
          |> Phoenix.HTML.safe_to_string()

        assert card_html =~ "Support Portal"
        assert card_html =~ "href=\"/support/pylon\""
      end
    end
  end

  describe "help menu card interplay with pylon tiers" do
    test "hides zendesk contact support card when support portal mode is active", %{conn: conn} do
      layout_model = %Front.Layout.Model{permissions: %{"organization.contact_support" => true}}

      conn =
        conn
        |> assign(:organization_id, "org-1")

      with_mock FeatureProvider,
        feature_enabled?: fn
          :"support-tier-3", [param: "org-1"] -> true
          :zendesk_support, [param: "org-1"] -> true
          :restricted_support, [param: "org-1"] -> false
          _, _ -> false
        end do
        assert FrontWeb.SharedHelpers.contact_support_card(conn, layout_model) == nil
      end
    end

    test "hides zendesk support requests card when support portal mode is active", %{conn: conn} do
      layout_model = %Front.Layout.Model{permissions: %{"organization.contact_support" => true}}

      conn =
        conn
        |> assign(:organization_id, "org-1")

      with_mock FeatureProvider,
        feature_enabled?: fn
          :premium_support, [param: "org-1"] -> true
          :zendesk_support, [param: "org-1"] -> true
          :restricted_support, [param: "org-1"] -> false
          :advanced_support, [param: "org-1"] -> false
          _, _ -> false
        end do
        assert FrontWeb.SharedHelpers.support_requests_card(conn, layout_model) == nil
      end
    end

    test "keeps old zendesk help menu when pylon tier is missing", %{conn: conn} do
      layout_model = %Front.Layout.Model{permissions: %{"organization.contact_support" => true}}

      conn =
        conn
        |> assign(:organization_id, "org-1")

      with_mock FeatureProvider,
        feature_enabled?: fn
          :pylon_support, [param: "org-1"] -> true
          :zendesk_support, [param: "org-1"] -> true
          :restricted_support, [param: "org-1"] -> false
          :premium_support, [param: "org-1"] -> false
          :advanced_support, [param: "org-1"] -> false
          _, _ -> false
        end do
        card_html =
          conn
          |> FrontWeb.SharedHelpers.contact_support_card(layout_model)
          |> Phoenix.HTML.safe_to_string()

        assert card_html =~ "Contact Support"
      end
    end
  end

  describe "pylon_chat_widget_settings/1" do
    setup do
      original_app_id = Application.get_env(:front, :pylon_chat_app_id)
      original_identity_secret = Application.get_env(:front, :pylon_chat_identity_secret)

      on_exit(fn ->
        restore_env(:pylon_chat_app_id, original_app_id)
        restore_env(:pylon_chat_identity_secret, original_identity_secret)
      end)

      :ok
    end

    test "returns chat settings for logged-in users when pylon feature is enabled", %{conn: conn} do
      Application.put_env(:front, :pylon_chat_app_id, "app-123")

      identity_secret_hex = "00112233445566778899AABBCCDDEEFF"
      Application.put_env(:front, :pylon_chat_identity_secret, identity_secret_hex)

      conn =
        conn
        |> assign(:authorization, :member)
        |> assign(:organization_id, "org-1")
        |> assign(:layout_model, %{
          user: %{
            email: "dev@example.com",
            name: "Dev User",
            avatar_url: "https://avatar.example.com/dev.png"
          }
        })

      with_mock FeatureProvider,
        feature_enabled?: fn
          :pylon_chat, [param: "org-1"] -> true
          _, _ -> false
        end do
        settings = FrontWeb.SharedHelpers.pylon_chat_widget_settings(conn)

        assert settings["app_id"] == "app-123"
        assert settings["email"] == "dev@example.com"
        assert settings["name"] == "Dev User"
        assert settings["account_external_id"] == "org-1"
        assert settings["avatar_url"] == "https://avatar.example.com/dev.png"

        expected_hash =
          :crypto.mac(
            :hmac,
            :sha256,
            Base.decode16!(identity_secret_hex, case: :mixed),
            "dev@example.com"
          )
          |> Base.encode16(case: :lower)

        assert settings["email_hash"] == expected_hash
      end
    end

    test "returns nil when identity secret is invalid", %{conn: conn} do
      Application.put_env(:front, :pylon_chat_app_id, "app-123")
      Application.put_env(:front, :pylon_chat_identity_secret, "not-a-hex-string")

      conn =
        conn
        |> assign(:authorization, :member)
        |> assign(:organization_id, "org-1")
        |> assign(:layout_model, %{user: %{email: "dev@example.com", name: "Dev User"}})

      with_mock FeatureProvider,
        feature_enabled?: fn
          :pylon_chat, [param: "org-1"] -> true
          _, _ -> false
        end do
        assert FrontWeb.SharedHelpers.pylon_chat_widget_settings(conn) == nil
      end
    end

    test "returns nil when pylon feature is disabled", %{conn: conn} do
      Application.put_env(:front, :pylon_chat_app_id, "app-123")
      Application.put_env(:front, :pylon_chat_identity_secret, "00112233445566778899AABBCCDDEEFF")

      conn =
        conn
        |> assign(:authorization, :member)
        |> assign(:organization_id, "org-1")
        |> assign(:layout_model, %{user: %{email: "dev@example.com", name: "Dev User"}})

      with_mock FeatureProvider, feature_enabled?: fn _, _ -> false end do
        assert FrontWeb.SharedHelpers.pylon_chat_widget_settings(conn) == nil
      end
    end
  end

  defp restore_env(key, nil), do: Application.delete_env(:front, key)
  defp restore_env(key, value), do: Application.put_env(:front, key, value)
end
