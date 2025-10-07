defmodule E2E.Support.UserAction do
  require Wallaby.Browser
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
    |> wait_for(css("#kc-form-login"), 3_000)
    |> fill_in(text_field("username"), with: email)
    |> fill_in(text_field("password"), with: password)
    |> wait_for(css("#kc-form-buttons"), 3_000)
    |> wait_for(css("#kc-login"), 3_000)
    |> with_retry(fn s -> click(s, css("#kc-login")) end)
  end

  def change_password(session, password) do
    session
    |> wait_for(css("#kc-passwd-update-form"), 3_000)
    |> fill_in(text_field("password-new"), with: password)
    |> fill_in(text_field("password-confirm"), with: password)
    |> wait_for(button("Submit"), 3_000)
    |> click(button("Submit"))
  end

  def wait_for(session, query, timeout_ms, interval_ms \\ 200)
  def wait_for(session, query, timeout_ms, _interval_ms) when timeout_ms <= 0 do
    assert_has(session, query)
  end

  def wait_for(session, query, timeout_ms, interval_ms) do
    if has?(session, query) do
      session
    else
      Process.sleep(interval_ms)
      wait_for(session, query, timeout_ms - interval_ms, interval_ms)
    end
  end

  defp with_retry(session, fun, attempts \\ 3)
  defp with_retry(session, fun, 0), do: fun.(session)

  defp with_retry(session, fun, attempts) do
    fun.(session)
  rescue
    e in Wallaby.StaleReferenceError ->
      Process.sleep(200)

      if attempts > 1 do
        with_retry(session, fun, attempts - 1)
      else
        reraise e, __STACKTRACE__
      end
  end
end
