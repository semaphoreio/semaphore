defmodule Front.Browser.SelfHostedAgentsTest do
  use FrontWeb.WallabyCase
  alias Support.{Browser, Stubs}

  setup %{session: session} do
    Stubs.init()
    Stubs.build_shared_factories()

    user = Stubs.User.create_default()
    org = Stubs.Organization.create_default()
    Support.Stubs.Feature.enable_feature(org.id, :permission_patrol)
    Support.Stubs.PermissionPatrol.allow_everything(org.id, user.id)
    Support.Stubs.Feature.enable_feature(org.id, :self_hosted_agents)

    page = visit(session, "/self_hosted_agents")

    {:ok, %{page: page, org: org}}
  end

  browser_test "adding first self-hosted agent type", %{page: page, org: org} do
    page
    |> click_add_agent_type()
    |> set_agent_type_name("test-agent")
    |> click_register_agent_type()
    |> Browser.assert_stable_text(
      "Follow the instructions and you should see the agent running here shortly."
    )

    simulate_booting_an_agent(org.id, "s1-test-agent", "s1-vagrant-23o8127381")
    :timer.sleep(3000)

    page |> Browser.assert_stable_text("s1-vagrant-23o8127381")
  end

  browser_test "listing existing agent types", %{page: page, org: org} do
    create_agent_type(org.id, "s1-test-1")
    create_agent_type(org.id, "s1-test-2")

    simulate_booting_an_agent(org.id, "s1-test-1", "s1-vagrant-23o8127381")
    simulate_booting_an_agent(org.id, "s1-test-1", "s1-vagrant-hlakdjhfal")
    simulate_booting_an_agent(org.id, "s1-test-2", "s1-vagrant-asdufasksj")

    page |> visit("/self_hosted_agents")

    Browser.assert_stable_text(page, "s1-test-1")
    Browser.assert_stable_text(page, "2 running agents")

    Browser.assert_stable_text(page, "s1-test-2")
    Browser.assert_stable_text(page, "1 running agent")
  end

  browser_test "viewing details about a self hosted agent type", %{page: page, org: org} do
    create_agent_type(org.id, "s1-test-1")

    simulate_booting_an_agent(org.id, "s1-test-1", "s1-vagrant-23o8127381")
    simulate_booting_an_agent(org.id, "s1-test-1", "s1-vagrant-hlakdjhfal")

    page
    |> visit("/self_hosted_agents")
    |> click(Query.text("s1-test-1"))

    Browser.assert_stable_text(page, "s1-vagrant-23o8127381")
    Browser.assert_stable_text(page, "s1-vagrant-hlakdjhfal")
  end

  describe "deleting an agent type" do
    browser_test "deleting an agent type with no running agents", %{page: page, org: org} do
      create_agent_type(org.id, "s1-test-1")

      page
      |> visit("/self_hosted_agents")
      |> click(Query.text("s1-test-1"))
      |> click(Query.link("Delete…"))

      Browser.assert_stable_text(page, "Delete s1-test-1")
      Browser.assert_stable_text(page, "This cannot be undone!")

      page
      |> click(Query.button("Delete"))
      |> Browser.assert_flash_notice("Agent type s1-test-1 deleted")
    end

    browser_test "deleting an agent type with running agents", %{page: page, org: org} do
      create_agent_type(org.id, "s1-test-1")

      simulate_booting_an_agent(org.id, "s1-test-1", "s1-vagrant-23o8127381")

      page
      |> visit("/self_hosted_agents")
      |> click(Query.text("s1-test-1"))

      assert_has(page, Query.css(".disabled", text: "Delete…"))
    end
  end

  browser_test "reset token for an agent type", %{page: page, org: org} do
    create_agent_type(org.id, "s1-test-1")

    page
    |> visit("/self_hosted_agents")
    |> click(Query.text("s1-test-1"))
    |> click(Query.link("Reset token…"))

    Browser.assert_stable_text(page, "Reset token for s1-test-1")
    Browser.assert_stable_text(page, "This cannot be undone!")

    page
    |> click(Query.button("Reset token"))
    |> Browser.assert_stable_text("The registration token was successfully reset for s1-test-1")
  end

  browser_test "disable an agent", %{page: page, org: org} do
    create_agent_type(org.id, "s1-test-1")

    simulate_booting_an_agent(org.id, "s1-test-1", "s1-vagrant-23o8127381")

    page
    |> visit("/self_hosted_agents")
    |> click(Query.text("s1-test-1"))
    |> click_disconnect_link()

    Browser.assert_stable_text(page, "Disconnect s1-vagrant-23o8127381")
    Browser.assert_stable_text(page, "This cannot be undone!")

    page
    |> click(Query.button("Disconnect"))
    |> Browser.assert_flash_notice("Agent s1-vagrant-23o8127381 disconnected")
  end

  browser_test "disable all agents", %{page: page, org: org} do
    create_agent_type(org.id, "s1-test-1")

    simulate_booting_an_agent(org.id, "s1-test-1", "s1-vagrant-23o8127381")

    page
    |> visit("/self_hosted_agents")
    |> click(Query.text("s1-test-1"))
    |> click(Query.link("Disable all…"))

    Browser.assert_stable_text(page, "Disable agents for s1-test-1")
    Browser.assert_stable_text(page, "Proceed carefully, this cannot be undone!")

    page
    |> click(Query.radio_button("Disable all (some of them might be running jobs)"))
    |> click(Query.button("Disable agents"))
    |> Browser.assert_flash_notice("All agents for s1-test-1 were disabled")
  end

  browser_test "disable all idle agents", %{page: page, org: org} do
    create_agent_type(org.id, "s1-test-1")

    simulate_booting_an_agent(org.id, "s1-test-1", "s1-vagrant-23o8127381")

    page
    |> visit("/self_hosted_agents")
    |> click(Query.text("s1-test-1"))
    |> click(Query.link("Disable all…"))

    Browser.assert_stable_text(page, "Disable agents for s1-test-1")
    Browser.assert_stable_text(page, "Proceed carefully, this cannot be undone!")

    page
    |> click(Query.radio_button("Disable all idle agents"))
    |> click(Query.button("Disable agents"))
    |> Browser.assert_flash_notice("All idle agents for s1-test-1 were disabled")
  end

  defp click_add_agent_type(page) do
    page |> click(Query.link("Add your first self-hosted agent"))
  end

  defp click_register_agent_type(page) do
    page |> click(Query.button("Looks good. Register"))
  end

  defp click_disconnect_link(page) do
    page |> click(Query.link("Disconnect"))
  end

  defp set_agent_type_name(page, _name) do
    page |> fill_in(Query.text_field("self-hosted-agent-name-suffix"), with: "test-agent")
  end

  defp simulate_booting_an_agent(org_id, type_name, name) do
    Stubs.SelfHostedAgent.add_agent(org_id, type_name, name)
  end

  defp create_agent_type(org_id, name) do
    Stubs.SelfHostedAgent.create(org_id, name)
  end
end
