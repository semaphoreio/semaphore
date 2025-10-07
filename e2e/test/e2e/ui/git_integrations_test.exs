defmodule E2E.UI.GitIntegrationsTest do
  use E2E.UI.UserTestCase

  def navigate_to_git_integrations(session, organization, base_domain) do
    git_integrations_url = "https://#{organization}.#{base_domain}/settings/git_integrations/"
    Logger.info("Navigating to Git Integrations page: #{git_integrations_url}")

    session
    |> visit(git_integrations_url)
  end

  describe "Git Integrations page" do
    setup %{session: session, organization: organization, base_domain: base_domain} do
      session = navigate_to_git_integrations(session, organization, base_domain)
      {:ok, %{session: session}}
    end

    test "has correct title and description", %{session: session} do
      session
      |> assert_has(Wallaby.Query.text("Git Integrations", count: 1))
    end

    test "has two main sections: Integrations and Connect new", %{session: session} do
      session
      |> assert_has(
        Wallaby.Query.css("[data-testid='integration-box']", count: 2)
      )
      |> assert_has(
        Wallaby.Query.css("[data-testid='integration-box'] .b",
          text: "Integrations"
        )
      )
      |> assert_has(
        Wallaby.Query.css("[data-testid='integration-box'] .b",
          text: "Connect new"
        )
      )
    end

    test "has at least one connected integration", %{session: session} do
      session
      |> assert_has(
        Wallaby.Query.css("[data-testid='integration-card']", minimum: 1)
      )

      has_github_or_gitlab =
        has?(session, Wallaby.Query.css("img[src*='icn-github.svg']")) ||
          has?(session, Wallaby.Query.css("img[src*='icn-gitlab.svg']"))

      assert has_github_or_gitlab, "Expected to find either GitHub or GitLab integration card"

      session
      |> assert_has(Wallaby.Query.text("connected", minimum: 1))
    end

    test "has available integrations to connect", %{session: session} do
      session
      |> assert_has(
        Wallaby.Query.css("[data-testid='integration-card']", minimum: 1,
          timeout: 10_000
        )
      )

      available_for_connect =
        has?(session, Wallaby.Query.css("img[src*='icn-github.svg']:not(.f6.gray ~ *)")) ||
          has?(session, Wallaby.Query.css("img[src*='icn-gitlab.svg']:not(.f6.gray ~ *)")) ||
          has?(session, Wallaby.Query.css("img[src*='icn-bitbucket.svg']"))

      assert available_for_connect,
             "Expected to find at least one available integration to connect"

      session
      |> assert_has(Wallaby.Query.link("Connect", minimum: 1))
    end
  end

  describe "Integration details page" do
    setup %{session: session, organization: organization, base_domain: base_domain} do
      session = navigate_to_git_integrations(session, organization, base_domain)

      # Find the edit button and click it - we use a simpler direct approach
      session
      |> click(
        Wallaby.Query.link("edit", count: 2, at: 0)
      )
      |> assert_has(Wallaby.Query.text("Configuration parameters"))

      {:ok, %{session: session}}
    end

    test "has correct page structure and navigation", %{session: session} do
      session
      |> assert_has(Wallaby.Query.link("← Back to Integration"))
      |> assert_has(Wallaby.Query.css("[data-testid='integration-title']"))
    end

    test "shows connection status", %{session: session} do
      session
      |> assert_has(Wallaby.Query.text("GitHub App Connection"))
      # Green circle indicator
      |> assert_has(Wallaby.Query.css("[data-testid='connection-status']", minimum: 1))
    end

    test "has required permissions section", %{session: session} do
      session
      |> assert_has(Wallaby.Query.text("Required Permissions"))
      |> assert_has(Wallaby.Query.css("li", minimum: 5))
    end

    test "has remove connection section", %{session: session} do
      session
      |> assert_has(Wallaby.Query.text("Remove connection"))
      |> assert_has(Wallaby.Query.text("Warning: Removing this integration"))
      |> assert_has(Wallaby.Query.button("Delete"))
    end
  end

  describe "New integration setup page" do
    setup %{session: session, organization: organization, base_domain: base_domain} do
      session = navigate_to_git_integrations(session, organization, base_domain)

      # #git-integration-app > div > div:nth-child(4) > div.ph3.pv2.mv2 > div:nth-child(3) > div.flex.items-center.justify-end > a

      session
      |> find(Wallaby.Query.css("[data-testid='integration-box']", count: 2, at: 1))
      |> click(Wallaby.Query.link("Connect"))

      session
      |> assert_has(Wallaby.Query.text("Integration Setup"))

      {:ok, %{session: session}}
    end

    test "has correct page structure and navigation", %{session: session} do
      session
      |> assert_has(Wallaby.Query.link("← Back to Integration"))
      |> assert_has(Wallaby.Query.text("Integration Setup"))
    end

    test "has configuration parameters section", %{session: session} do
      session
      |> assert_has(Wallaby.Query.text("Configuration parameters"))
      |> assert_has(Wallaby.Query.text("Callback URL"))
    end

    test "has required permissions list", %{session: session} do
      session
      |> assert_has(Wallaby.Query.text("Required Permissions"))
      |> assert_has(Wallaby.Query.css("li", minimum: 5))
    end

    test "has connect integration form", %{session: session} do
      session
      |> assert_has(Wallaby.Query.text_field("client_id"))
      |> assert_has(Wallaby.Query.css("input[type='password'][name='client_secret']"))
      |> assert_has(Wallaby.Query.button("Connect Integration"))
    end
  end
end
