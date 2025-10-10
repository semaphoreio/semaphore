defmodule E2E.UI.UserManagementTest do
  use E2E.UI.UserTestCase, async: false
  require Logger

  describe "User Management Page" do
    setup %{base_url: base_url} do
      on_exit(fn ->
        {:ok, cleanup_session} = Wallaby.start_session()
        cleanup_session = cleanup_session |> E2E.Support.UserAction.login() |> navigate_to_people_page(base_url)
        remove_all_users(cleanup_session)
      end)
      :ok
    end

    test "accessing and interacting with the People page", %{session: session, base_url: base_url} do
      emails = random_emails(10)

      navigate_to_people_page(session, base_url)
      |> then(fn session ->
        assert_has(session, Wallaby.Query.css("div.b", text: "People"))
        session
      end)
      |> click(Wallaby.Query.button("Add people"))
      |> create_users(emails)
      |> click(Wallaby.Query.button("Create Accounts"))
      |> then(fn session ->
        :timer.sleep(2_000)
        session
      end)
    end

    test "can create a user and log in with it", %{session: session, base_url: base_url, login_url: login_url} do
      emails = random_emails(1)

      session =
        session
        |> navigate_to_people_page(base_url)
        |> assert_has(Wallaby.Query.css("div.b", text: "People"))
        |> click(Wallaby.Query.button("Add people"))
        |> then(fn s -> :timer.sleep(1000); s end)
        |> create_users(emails)
        |> click(Wallaby.Query.button("Create Accounts"))
        |> then(fn s -> :timer.sleep(2000); s end)

      [user_cred] = extract_user_credentials(session)

      {:ok, login_session} = Wallaby.start_session()

      login_session
      |> E2E.Support.UserAction.login(login_url, user_cred.email, user_cred.password)
      |> E2E.Support.UserAction.change_password(hd(random_emails(1)))
    end

    test "can create a user and find them in the people list", %{session: session, base_url: base_url} do
      known_email = "knownuser@example.com"
      session =
        session
        |> navigate_to_people_page(base_url)
        |> assert_has(Wallaby.Query.css("div.b", text: "People"))
        |> click(Wallaby.Query.button("Add people"))
        |> then(fn s -> :timer.sleep(1000); s end)
        |> create_users([known_email])
        |> click(Wallaby.Query.button("Create Accounts"))
        |> then(fn s -> :timer.sleep(2000); s end)

      # Go back to People page if needed
      session = navigate_to_people_page(session, base_url)

      # Find the member div containing the known email
      find_member_scope_by_email(session, known_email)
      |> click(Wallaby.Query.css("button.btn.btn-secondary span", text: "Edit"))

      session
      |> then(fn scope ->
        assert_has(scope, Wallaby.Query.text("Edit user"))
        scope
      end)
      |> click(Wallaby.Query.button("Reset password"))
      |> then(fn scope ->
        assert_has(scope, Wallaby.Query.text("Are you sure you want to reset the password?"))
        scope
      end)
      |> click(Wallaby.Query.button("Reset password"))
      |> then(fn scope ->
        assert_has(scope, Wallaby.Query.text("New temporary password"))
        scope
      end)
      |> then(fn scope ->
        # Find the Admin label and click it
        admin_label = find(scope, Wallaby.Query.css("label.pointer", text: "Admin"))
        Wallaby.Element.click(admin_label)
        scope
      end)
      |> then(fn scope ->
        # Zoom out to make sure the button is in viewport
        _ = execute_script(scope, "document.body.style.zoom = '0.7';")
        scope
      end)
      |> wait_and_click(Wallaby.Query.button("Save changes"), 1_000)
      |> then(fn scope ->
        _ = execute_script(scope, "document.body.style.zoom = '1';")
        scope
      end)
      |> wait_for(Wallaby.Query.text("Role successfully assigned"), 2_000)
      |> then(fn scope ->
        _ = execute_script(scope, "document.body.style.zoom = '0.6';")
        take_screenshot(scope, name: "role_assigned")
        _ = execute_script(scope, "document.body.style.zoom = '1';")
        scope
      end)
      |> then(fn scope ->
        _ = execute_script(scope, "document.body.style.zoom = '0.7';")
        scope
      end)
      |> wait_and_click(Wallaby.Query.button("Cancel"), 1_000)

      # confirm that member is now admin
      session
      |> wait_for(Wallaby.Query.css("div#members"), 3_000)
      |> find_member_scope_by_email(known_email)
      |> wait_for(Wallaby.Query.css("span", text: "Admin"), 3_000)
    end
  end

  @doc """
  Helper function to navigate to the People page
  """
  def navigate_to_people_page(session, base_url) do
    visit(session, "#{base_url}/people")
  end

  defp remove_all_users(session) do
    remove_query = Wallaby.Query.css("button.btn.btn-secondary[name=remove-btn]")
    do_remove_all_users(session, remove_query)
  end

  defp do_remove_all_users(session, query) do
    case all(session, query) do
      [btn | _] ->
        Wallaby.Element.click(btn)
        :timer.sleep(500)
        do_remove_all_users(session, query)
      [] ->
        session
    end
  end

  # Helper: create users by filling in emails and submitting
  defp create_users(session, emails) do
    Enum.reduce(Enum.with_index(emails, 1), session, fn {email, _i}, session_acc ->
      email_fields = all(session_acc, Wallaby.Query.fillable_field("Enter email address"))
      email_field_index = length(email_fields) - 1
      updated_session =
        if email_field_index >= 0 do
          fill_in(
            session_acc,
            Wallaby.Query.fillable_field("Enter email address", count: :any, at: email_field_index),
            with: email
          )
        else
          fill_in(session_acc, Wallaby.Query.fillable_field("Enter email address"), with: email)
        end
      :timer.sleep(300)
      updated_session
    end)
  end

  # Helper: extract credentials from confirmation blocks
  defp extract_user_credentials(session) do
    account_blocks = all(session, Wallaby.Query.css(".email-input-group.mb3"))
    {credentials, failures} =
      Enum.reduce(account_blocks, {[], 0}, fn block, {acc, fails} ->
        try do
          email_element = find(block, Wallaby.Query.css(".f4"))
          email = Wallaby.Element.text(email_element)
          password_element = find(block, Wallaby.Query.css("code.f6"))
          password = Wallaby.Element.text(password_element)
          {[ %{email: email, password: password} | acc ], fails}
        rescue
          Wallaby.QueryError ->
            {acc, fails + 1}
        end
      end)
    if failures > length(account_blocks)/2 do
      flunk("Failed to extract credentials from more than 50% of blocks (#{failures} failures)")
    end
    Enum.reverse(credentials)
  end

  defp find_member_scope_by_email(session, email) do
    username = String.split(email, "@") |> hd()

    all(session, Wallaby.Query.css("div#member"))
    |> Enum.find(fn div ->
      has?(div, Wallaby.Query.link(username))
    end)
    |> case do
      nil ->
        flunk("Could not find member card for #{email}")

      member_div ->
        member_div
    end
  end

  defp random_emails(n) do
    random_str = Enum.map(1..5, fn _ -> Enum.random(~c(abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789)) end) |> to_string()
    Enum.map(1..n, fn i ->
      random_email(random_str, i)
    end)
  end
  # Helper: generate a random email
  defp random_email(random_str, n) do
    "#{random_str}#{n}@example.com"
  end

  defp wait_and_click(scope, query, timeout_ms) do
    wait_for(scope, query, timeout_ms)
    click(scope, query)
  end

  defp wait_for(scope, query, timeout_ms, interval_ms \\ 200)
  defp wait_for(scope, query, timeout_ms, _interval_ms) when timeout_ms <= 0 do
    if has?(scope, query) do
      scope
    else
      flunk("Timed out waiting for #{inspect(query)}")
    end
  end

  defp wait_for(scope, query, timeout_ms, interval_ms) do
    if has?(scope, query) do
      scope
    else
      Process.sleep(interval_ms)
      wait_for(scope, query, timeout_ms - interval_ms, interval_ms)
    end
  end
end
