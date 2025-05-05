defmodule E2E.UI.ProjectCreationFlowTest do
  use E2E.UI.UserTestCase
  require Logger

  describe "Project Creation Flow" do
    @tag timeout: 600_000
    test "complete project creation flow", %{session: session} do
      Logger.info("Starting Project Creation Flow test")

      # Step 1: Navigate to project creation page
      Logger.info("Step 1: Navigating to project creation page")
      session = click(session, Wallaby.Query.link("Create new"))

      # Verify we're on the project creation page
      Logger.info("Verifying project creation page")
      session = assert_has(session, Wallaby.Query.css("h1", text: "Project type"))

      # Step 2: Select GitHub integration using a specific CSS selector
      Logger.info("Step 2: Selecting GitHub integration")
      session = click(session, Wallaby.Query.css(".f3.b", text: "GitHub"))

      # Take screenshot to see what happened
      take_screenshot(session, name: "after_github_click")

      # Verify we're on the repository selection page
      Logger.info("Verifying repository selection page")
      session = assert_has(session, Wallaby.Query.css("h2", text: "Repository"))

      # Step 3: Search for repositories
      Logger.info("Step 3: Searching for repositories")

      session =
        fill_in(session, Wallaby.Query.fillable_field("Search repositories..."), with: "e2e-tests")

      # Give the search some time to complete
      :timer.sleep(1000)

      session = assert_has(session, Wallaby.Query.css(".option"))

      # Try to find and click the "Choose" button if available
      Logger.info("Clicking 'Choose' button")
      session = click(session, Wallaby.Query.css(".green", text: "Choose"))

      # Take screenshot after repository selection
      take_screenshot(session, name: "after_repository_selection")
      # Give some time to check for duplicates
      :timer.sleep(1000)
      take_screenshot(session, name: "after_repository_selection_with_duplicates")

      session = maybe_enable_duplicate(session)

      Logger.info("Clicking create project button")
      assert_has(session, Wallaby.Query.css("button.btn.btn-primary"))
      click(session, Wallaby.Query.button("✓"))

      # Take screenshot after clicking continue
      take_screenshot(session, name: "after_continue")

      :timer.sleep(15_000)
      # Verify we moved to the analysis page and check for the analysis steps checklist
      take_screenshot(session, name: "analysis_page")

      # wait for project creation to complete (until webhook readonly input is visible)
      # This can take up to 15 seconds
      Logger.info("Waiting for project creation to complete (up to 15 seconds)...")

      # click continue button
      session = click(session, Wallaby.Query.link("Continue"))

      # Click on the "I want to configure this project from scratch" link
      Logger.info("Clicking 'I want to configure this project from scratch' link")

      session =
        click(session, Wallaby.Query.link("I want to configure this project from scratch"))

      # Take a screenshot after clicking the link
      take_screenshot(session, name: "configure_from_scratch")

      # Click continue button again after selecting "configure from scratch"
      Logger.info("Clicking Continue button again")
      session = assert_has(session, Wallaby.Query.button("Continue"))
      session = click(session, Wallaby.Query.button("Continue"))

      # Take a screenshot after clicking continue again
      take_screenshot(session, name: "after_second_continue")

      # Click "Looks good, start →" button
      Logger.info("Clicking 'Looks good, start →' button")
      session = assert_has(session, Wallaby.Query.button("Looks good, start →"))
      session = click(session, Wallaby.Query.button("Looks good, start →"))

      # Take a screenshot after clicking the start button
      take_screenshot(session, name: "after_start_button")

      # Wait for 15 seconds to allow page transition
      Logger.info("Waiting 15 seconds for page transition...")
      :timer.sleep(15_000)

      # Verify the URL path starts with "/workflows/"
      Logger.info("Verifying we are on the workflows page")
      current_url = current_url(session)

      assert String.contains?(current_url, "/workflows/"),
             "Expected URL to contain '/workflows/', but got: #{current_url}"

      # Take a final screenshot of the workflows page
      take_screenshot(session, name: "workflows_page")

      Logger.info("Project Creation completed successfully, flow test is complete")
    end
  end

  defp maybe_enable_duplicate(session) do
    if has?(session, Wallaby.Query.button("Make a duplicate project")) do
      click(session, Wallaby.Query.button("Make a duplicate project"))
    end
  end
end
