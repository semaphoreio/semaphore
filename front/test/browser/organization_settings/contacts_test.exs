defmodule Front.Browser.OrganizationSettings.ContactsTest do
  use FrontWeb.WallabyCase
  alias Support.Stubs

  @contacts_tab Query.css("a", text: "Contacts")

  setup %{session: session} do
    user = Stubs.User.create_default()
    org = Stubs.Organization.create_default(restricted: false)
    Support.Stubs.Feature.enable_feature(org.id, :permission_patrol)

    Support.Stubs.PermissionPatrol.add_permissions(org.id, user.id, [
      "organization.view",
      "organization.general_settings.view",
      "organization.general_settings.manage"
    ])

    page = visit(session, "/settings")

    {:ok, %{page: page, org: org}}
  end

  describe "form" do
    browser_test "when org does not have any contacts, it is empty", %{page: page} do
      page
      |> click(@contacts_tab)
      |> assert_contact_forms_are_shown()
    end

    browser_test "when org has only one contact set, display it's information", %{
      page: page,
      org: org
    } do
      insert_contact(org.id, "CONTACT_TYPE_MAIN", "Joe")

      page
      |> click(@contacts_tab)
      |> assert_contact_name_is_present("Joe")
    end

    browser_test "fill out financial contact info", %{page: page} do
      page
      |> click(@contacts_tab)
      |> submit_form()
      |> assert_success_notification()
      |> assert_contact_name_is_present("Charles Mingus")
    end
  end

  ###
  ### Helper functions
  ###

  @name_xpath_selector "//h2[text()=' Main']/..//input[@name='organization_contacts[name]']"
  @save_btn_selector "//h2[text()=' Main']/..//button[@type='submit']"
  defp submit_form(page) do
    page
    |> fill_in(Query.xpath(@name_xpath_selector), with: "Charles Mingus")
    |> click(Query.xpath(@save_btn_selector))
  end

  defp assert_success_notification(page) do
    page
    |> assert_has(Query.css("p", text: "Contact information successfully updated."))
  end

  defp assert_contact_forms_are_shown(page) do
    page
    |> assert_has(Query.css("h2", text: "Contacts"))
    |> assert_has(Query.css("h2", text: "Finances"))
    |> assert_has(Query.css("h2", text: "Main"))
    |> assert_has(Query.css("h2", text: "Security"))

    save_buttons = page |> all(Query.button("Save Changes"))
    assert length(save_buttons) == 3
  end

  defp assert_contact_name_is_present(page, name) do
    page
    |> assert_has(Query.css("input[value='#{name}']"))
  end

  defp insert_contact(org_id, contact_type, name) do
    Support.Stubs.DB.insert(:organization_contacts, %{
      id: Support.Stubs.UUID.gen(),
      org_id: org_id,
      type: contact_type,
      name: name
    })
  end
end
