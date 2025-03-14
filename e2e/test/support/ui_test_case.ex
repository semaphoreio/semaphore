defmodule E2E.UI.UserTestCase do
  @moduledoc """
  A custom ExUnit case for UI tests requiring a logged-in user.

  This module automatically:
  - Tags tests with :user and :browser
  - Sets up Wallaby browser session
  - Performs user login before each test
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      use ExUnit.Case, async: false
      use Wallaby.DSL

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

    logged_in_session =
      session
      |> Wallaby.Browser.visit(login_url)
      |> Wallaby.Browser.fill_in(Wallaby.Query.text_field("username"), with: root_email)
      |> Wallaby.Browser.fill_in(Wallaby.Query.text_field("password"), with: root_password)
      |> Wallaby.Browser.click(Wallaby.Query.css("#kc-login"))
      |> Wallaby.Browser.assert_has(
        Wallaby.Query.css("h1.f2.f1-m.lh-title.mb1",
          text: "Here's what's going on",
          timeout: 10_000
        )
      )

    {:ok, session: logged_in_session, organization: organization, base_domain: base_domain}
  end
end
