defmodule E2E.UI.UserTestCase do
  @moduledoc """
  A custom ExUnit case for UI tests requiring a logged-in user.

  This module automatically:
  - Tags tests with :user and :browser
  - Sets up Wallaby browser session
  - Performs user login before each test
  """

  use ExUnit.CaseTemplate
  require Wallaby.Browser
  import Wallaby.Browser
  import E2E.Support.UserAction
  require Logger

  using do
    quote do
      use Wallaby.DSL
      require Wallaby.Browser
      import Wallaby.Browser
      require Logger

      @moduletag :user
      @moduletag :browser
      @moduletag timeout: 300_000
    end
  end

  setup_all do
    Application.put_env(:wallaby, :js_errors, false)
    :ok
  end

  setup do
    {:ok, session} = Wallaby.start_session(js_errors: false)

    base_domain = Application.get_env(:e2e, :semaphore_base_domain)
    root_email = Application.get_env(:e2e, :semaphore_root_email)
    root_password = Application.get_env(:e2e, :semaphore_root_password)
    organization = Application.get_env(:e2e, :semaphore_organization)

    base_url = "https://#{organization}.#{base_domain}"
    login_url = "https://id.#{base_domain}/login"

    try do
      # Fill in login form and authenticate
      logged_in_session = login(session, login_url, root_email, root_password)

      :timer.sleep(1000)
      take_screenshot(logged_in_session, name: "loggedin")

      assert current_url(logged_in_session) ==
               "https://#{organization}.#{base_domain}/get_started/"

      {:ok, session: logged_in_session, organization: organization, base_domain: base_domain, base_url: base_url, login_url: login_url}
    rescue
      e in Wallaby.ExpectationNotMetError ->
        # Take screenshot of the error state
        take_screenshot(session, name: "login_failure")
        # Log the current URL and HTML source for debugging
        # Attempt to capture some of the page source
        Logger.error("Login failed! Current URL: #{current_url(session)}")

        html_source =
          try do
            session
            |> execute_script("return document.documentElement.outerHTML")
            |> String.slice(0, 500)
          rescue
            _ -> "Could not retrieve page source"
          end

        Logger.error("Page source snippet: #{html_source}...")
        reraise e, __STACKTRACE__
    end
  end
end
