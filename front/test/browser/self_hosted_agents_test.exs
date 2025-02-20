defmodule Front.Browser.SelfHostedAgentsTest do
  use FrontWeb.WallabyCase
  alias Support.Stubs

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

  test "adding first self-hosted agent type", %{page: page, org: org} do
    page
    |> click_add_agent_type()
    |> set_agent_type_name("test-agent")
    |> click_register_agent_type()
    |> assert_text("Follow the instructions and you should see the agent running here shortly.")

    simulate_booting_an_agent(org.id, "s1-test-agent", "s1-vagrant-23o8127381")
    :timer.sleep(3000)

    page |> assert_text("s1-vagrant-23o8127381")
  end

  test "listing existing agent types", %{page: page, org: org} do
    create_agent_type(org.id, "s1-test-1")
    create_agent_type(org.id, "s1-test-2")

    simulate_booting_an_agent(org.id, "s1-test-1", "s1-vagrant-23o8127381")
    simulate_booting_an_agent(org.id, "s1-test-1", "s1-vagrant-hlakdjhfal")
    simulate_booting_an_agent(org.id, "s1-test-2", "s1-vagrant-asdufasksj")

    page |> visit("/self_hosted_agents")

    assert_text(page, "s1-test-1")
    assert_text(page, "2 running agents")

    assert_text(page, "s1-test-2")
    assert_text(page, "1 running agent")
  end

  test "viewing details about a self hosted agent type", %{page: page, org: org} do
    create_agent_type(org.id, "s1-test-1")

    simulate_booting_an_agent(org.id, "s1-test-1", "s1-vagrant-23o8127381")
    simulate_booting_an_agent(org.id, "s1-test-1", "s1-vagrant-hlakdjhfal")

    page
    |> visit("/self_hosted_agents")
    |> click(Query.text("s1-test-1"))

    assert_text(page, "s1-vagrant-23o8127381")
    assert_text(page, "s1-vagrant-hlakdjhfal")
  end

  describe "deleting an agent type" do
    test "deleting an agent type with no running agents", %{page: page, org: org} do
      create_agent_type(org.id, "s1-test-1")

      page
      |> visit("/self_hosted_agents")
      |> click(Query.text("s1-test-1"))
      |> click(Query.link("Delete…"))

      assert_text(page, "Delete s1-test-1")
      assert_text(page, "This cannot be undone!")

      page |> click(Query.button("Delete"))

      assert_text(page, "Agent type s1-test-1 deleted")
    end

    test "deleting an agent type with running agents", %{page: page, org: org} do
      create_agent_type(org.id, "s1-test-1")

      simulate_booting_an_agent(org.id, "s1-test-1", "s1-vagrant-23o8127381")

      page
      |> visit("/self_hosted_agents")
      |> click(Query.text("s1-test-1"))

      assert_has(page, Query.css(".disabled", text: "Delete…"))
    end
  end

  test "reset token for an agent type", %{page: page, org: org} do
    create_agent_type(org.id, "s1-test-1")

    page
    |> visit("/self_hosted_agents")
    |> click(Query.text("s1-test-1"))
    |> click(Query.link("Reset token…"))

    assert_text(page, "Reset token for s1-test-1")
    assert_text(page, "This cannot be undone!")

    page |> click(Query.button("Reset token"))

    assert_text(
      page,
      "The registration token was successfully reset for s1-test-1"
    )
  end

  test "disable an agent", %{page: page, org: org} do
    create_agent_type(org.id, "s1-test-1")

    simulate_booting_an_agent(org.id, "s1-test-1", "s1-vagrant-23o8127381")

    page
    |> visit("/self_hosted_agents")
    |> click(Query.text("s1-test-1"))
    |> click_disconnect_link()

    assert_text(page, "Disconnect s1-vagrant-23o8127381")
    assert_text(page, "This cannot be undone!")

    page |> click(Query.button("Disconnect"))

    assert_text(page, "Agent s1-vagrant-23o8127381 disconnected")
  end

  test "disable all agents", %{page: page, org: org} do
    create_agent_type(org.id, "s1-test-1")

    simulate_booting_an_agent(org.id, "s1-test-1", "s1-vagrant-23o8127381")

    page
    |> visit("/self_hosted_agents")
    |> click(Query.text("s1-test-1"))
    |> click(Query.link("Disable all…"))

    assert_text(page, "Disable agents for s1-test-1")
    assert_text(page, "Proceed carefully, this cannot be undone!")

    page
    |> click(Query.radio_button("Disable all (some of them might be running jobs)"))
    |> click(Query.button("Disable agents"))

    assert_text(page, "All agents for s1-test-1 were disabled")
  end

  test "disable all idle agents", %{page: page, org: org} do
    create_agent_type(org.id, "s1-test-1")

    simulate_booting_an_agent(org.id, "s1-test-1", "s1-vagrant-23o8127381")

    page
    |> visit("/self_hosted_agents")
    |> click(Query.text("s1-test-1"))
    |> click(Query.link("Disable all…"))

    assert_text(page, "Disable agents for s1-test-1")
    assert_text(page, "Proceed carefully, this cannot be undone!")

    page
    |> click(Query.radio_button("Disable all idle agents"))
    |> click(Query.button("Disable agents"))

    assert_text(page, "All idle agents for s1-test-1 were disabled")
  end

  defp click_add_agent_type(page) do
    page |> click(Query.link("Add your first self-hosted agent"))
  end

  defp click_register_agent_type(page) do
    script = "document.querySelector('#register-self-hosted-agent').scrollIntoView()"

    page |> execute_script(script)
    page |> click(Query.button("Looks good. Register"))
  end

  defp click_disconnect_link(page) do
    script = "document.querySelector('.disable-self-hosted-agent').scrollIntoView()"

    page |> execute_script(script)
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
