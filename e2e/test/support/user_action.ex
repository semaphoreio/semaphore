defmodule E2E.Support.UserAction do
  import Wallaby.Browser
  import Wallaby.Query

  def login(session) do
    base_domain = Application.get_env(:e2e, :semaphore_base_domain)
    root_email = Application.get_env(:e2e, :semaphore_root_email)
    root_password = Application.get_env(:e2e, :semaphore_root_password)

    login_url = "https://id.#{base_domain}/login"

    login(session, login_url, root_email, root_password)
  end

  def login(session, login_url, email, password) do
    session
    |> visit(login_url)
    |> then(fn s ->
      # Verify login form exists
      has?(s, css("#kc-form-login"))
      s
    end)
    |> fill_in(text_field("username"), with: email)
    |> fill_in(text_field("password"), with: password)
    |> click(css("#kc-login"))

  end

  def change_password(session, password) do
    session
    |> fill_in(text_field("password-new"), with: password)
    |> fill_in(text_field("password-confirm"), with: password)
    |> click(button("Submit"))
  end
end
