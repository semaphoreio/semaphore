defmodule Front.Browser.OrganizationSettings.OktaIntegrationTest do
  use FrontWeb.WallabyCase
  alias Support.{Browser, Stubs}

  @page_header Query.css("h1", text: "Okta Integration")
  @setup_btn Query.css("a", text: "Set Up")
  @okta_tab Query.css("a", text: "Okta Integration")
  @okta_tab_active Query.css("a.bg-green", text: "Okta Integration")
  @save_btn Query.button("Save")
  @edit_link Query.link("Edit")

  @saml_cert "---- BEGIN CERTIFICATE ---- \n .... \n ---- END CERTIFICATE ----"

  setup %{session: session} do
    user = Stubs.User.create_default()
    org = Stubs.Organization.create_default(restricted: false)
    Support.Stubs.Feature.enable_feature(org.id, :rbac__saml)
    Support.Stubs.Feature.enable_feature(org.id, :permission_patrol)

    Support.Stubs.PermissionPatrol.allow_everything(org.id, user.id)

    page = visit(session, "/settings")

    {:ok, %{page: page}}
  end

  describe "visiting empty state" do
    browser_test "it describes what is okta and shows a button for setting it up", %{page: page} do
      page
      |> click(@okta_tab)
      |> assert_okta_tab_is_active()
      |> assert_we_are_on_zero_state()
    end
  end

  describe "setting up a new okta integration" do
    browser_test "it asks for saml issues and certificate", %{page: page} do
      page
      |> navigate_to_setup_form()
      |> assert_we_are_on_setup_form()
    end

    browser_test "it displays errors if issuer or certificate are not filled in", %{page: page} do
      page
      |> navigate_to_setup_form()
      |> submit_form()
      |> assert_has(Query.text("SAML issuer can't be blank"))
      |> assert_has(Query.text("Certificate can't be blank"))
    end

    browser_test "it redirects back to empty state if you hit cancel", %{page: page} do
      page
      |> navigate_to_setup_form()
      |> cancel_form()
      |> assert_we_are_on_zero_state()
    end

    browser_test "if the form is valid it completes the setup and shows the SCIM token", %{
      page: page
    } do
      page
      |> set_up()
      |> assert_has(Query.text("SCIM Authorization token"))
      |> click_view_integration()
      |> Browser.assert_stable(Query.css("div.bg-green", text: "Connected"))
    end
  end

  describe "visiting an already set up integration" do
    browser_test "the page shows that okta is connected", %{page: page} do
      page
      |> set_up()
      |> visit("/settings/okta")
      |> Browser.assert_stable(Query.css("div.bg-green", text: "Connected"))
    end
  end

  defp submit_form(page) do
    page
    |> assert_has(@save_btn)
    |> click(@save_btn)
  end

  defp click_view_integration(page) do
    page
    |> assert_has(Query.link("View Integration"))
    |> click(Query.link("View Integration"))
  end

  defp cancel_form(page) do
    page
    |> assert_has(Query.link("Cancel"))
    |> click(Query.link("Cancel"))
  end

  defp assert_we_are_on_zero_state(page) do
    page
    |> assert_has(@page_header)
    |> assert_has(@setup_btn)
  end

  defp assert_we_are_on_setup_form(page) do
    page
    |> assert_has(Query.css("h1", text: "Okta Integration Setup"))
    |> assert_has(Query.css("label", text: "SAML Issuer"))
    |> assert_has(Query.css("label", text: "SAML Certificate"))
    |> assert_has(@save_btn)
  end

  defp navigate_to_setup_form(page) do
    page = page |> click(@okta_tab)

    cond do
      has_element?(page, @setup_btn) ->
        page |> click(@setup_btn)

      has_element?(page, @edit_link) ->
        page |> click(@edit_link)

      true ->
        # force the helpful assertion error
        assert_we_are_on_zero_state(page)
    end
  end

  defp assert_okta_tab_is_active(page) do
    page |> assert_has(@okta_tab_active)
  end

  defp set_up(page) do
    page
    |> navigate_to_setup_form()
    |> fill_in(Query.text_field("Single Sign-On URL"), with: "https://example.okta.com")
    |> fill_in(Query.text_field("SAML Issuer"), with: "https://example.okta.com")
    |> fill_in(Query.text_field("SAML Certificate"), with: @saml_cert)
    |> submit_form()
  end

  defp has_element?(page, query) do
    Browser.retry_on_stale(fn -> has?(page, query) end)
  end
end
