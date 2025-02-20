defmodule E2E.UI.LoginTest do
  use ExUnit.Case, async: false
  use Wallaby.DSL

  @moduletag :browser

  @moduletag timeout: 300_000

  setup_all do
    Application.put_env(:wallaby, :js_errors, false)
    :ok
  end

  setup do
    {:ok, session} = Wallaby.start_session(js_errors: false)
    {:ok, session: session}
  end

  describe "Login" do
    test "User can log into Semaphore with root credentials", %{session: session} do
      base_domain = Application.get_env(:e2e, :semaphore_base_domain)
      root_email = Application.get_env(:e2e, :semaphore_root_email)
      root_password = Application.get_env(:e2e, :semaphore_root_password)
      organization = Application.get_env(:e2e, :semaphore_organization)

      # Visit login page
      login_url = "https://id.#{base_domain}/login"
      me_url = "https://me.#{base_domain}/"

      Wallaby.Browser.take_screenshot(session)

      # Verify Keycloak login form elements
      me_page =
        session
        |> visit(login_url)
        |> assert_has(Query.css("#kc-form-login"))
        |> assert_has(Query.css("#username"))
        |> assert_has(Query.css("label[for='username']", text: "Email"))
        |> assert_has(Query.css("#password"))
        |> assert_has(Query.css("label[for='password']", text: "Password"))
        |> assert_has(Query.css("#kc-login[type='submit'][value='Sign In']"))
        |> fill_in(Query.text_field("username"), with: root_email)
        |> fill_in(Query.text_field("password"), with: root_password)
        |> click(Query.css("#kc-login"))
        |> assert_has(
          Query.css("p.mb3.pb2",
            text: "Select one of your organizations to continue:",
            timeout: 10_000
          )
        )

      assert Wallaby.Browser.current_url(me_page) == me_url

      # Take screenshot after login
      Wallaby.Browser.take_screenshot(me_page)

      me_page
      |> assert_has(Query.text("#{organization}.#{base_domain}"))
    end
  end
end
