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
  require Logger

  using do
    quote do
      use ExUnit.Case, async: true
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

    login_url = "https://id.#{base_domain}/login"

    try do
      # Fill in login form and authenticate
      logged_in_session =
        session
        |> visit(login_url)
        |> (fn s ->
            # Verify login form exists
            has?(s, Wallaby.Query.css("#kc-form-login"))
            s
          end).()
        |> fill_in(Wallaby.Query.text_field("username"), with: root_email)
        |> fill_in(Wallaby.Query.text_field("password"), with: root_password)
        |> click(Wallaby.Query.css("#kc-login"))

      assert current_url(logged_in_session) == "https://#{organization}.#{base_domain}/get_started/"

      {:ok, session: logged_in_session, organization: organization, base_domain: base_domain}
    rescue
      e in Wallaby.ExpectationNotMetError ->
        # Take screenshot of the error state
        take_screenshot(session, name: "login_failure")
        # Log the current URL and HTML source for debugging
        Logger.error("Login failed! Current URL: #{current_url(session)}")        # Attempt to capture some of the page source
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
