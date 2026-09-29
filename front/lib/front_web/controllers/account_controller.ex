defmodule FrontWeb.AccountController do
  use FrontWeb, :controller

  require Logger

  alias Front.{Async, Models}

  plug(:put_layout, "account.html")
  plug(FrontWeb.Plugs.CacheControl, :no_cache)

  def welcome_okta(conn, _params) do
    Watchman.benchmark("account.welcome.duration", fn ->
      user_id = conn.assigns.user_id

      fetch_user = Async.run(fn -> Models.User.find(user_id) end)
      {:ok, user} = Async.await(fetch_user)

      render(
        conn,
        "welcome/okta.html",
        user: user,
        title: "Welcome to Semaphore"
      )
    end)
  end

  def show(conn, params) do
    Watchman.benchmark("account.show.duration", fn ->
      conn
      |> maybe_put_oauth_flash(params)
      |> render_show(conn.assigns.user_id, params["errors"])
    end)
  end

  defp maybe_put_oauth_flash(conn, %{"status" => "error", "code" => code}) do
    put_flash(conn, :alert, oauth_error_text(code))
  end

  defp maybe_put_oauth_flash(conn, %{"status" => "error"}) do
    put_flash(conn, :alert, generic_oauth_error())
  end

  defp maybe_put_oauth_flash(conn, %{"status" => "success"}) do
    put_flash(conn, :notice, "Repository account connected.")
  end

  defp maybe_put_oauth_flash(conn, _params), do: conn

  defp oauth_error_text("invalid_uid"),
    do:
      "Your account did not return the required profile data (username or user ID). " <>
        "Please verify your account is fully set up and try again."

  defp oauth_error_text("missing_name"),
    do:
      "Your profile is missing a display name. " <>
        "Please set a name in your account settings and try connecting again."

  defp oauth_error_text("missing_login"), do: "Your profile is missing a username."

  defp oauth_error_text("login_not_allowed"),
    do:
      "Login is not allowed when using SAML as the default authentication method. " <>
        "Please contact your administrator."

  defp oauth_error_text("auth_failed"),
    do:
      "We couldn't authenticate. Please try again. " <>
        "If the problem persists, contact our support team."

  defp oauth_error_text(_code), do: generic_oauth_error()

  defp generic_oauth_error,
    do:
      "We're sorry, but your connection attempt was unsuccessful. Please try again. " <>
        "If you continue to experience issues, please contact our support team for assistance."

  def update(conn, params) do
    Watchman.benchmark("account.update.duration", fn ->
      user_id = conn.assigns.user_id

      fetch_user = Async.run(fn -> Models.User.find_user_with_providers(user_id) end)

      {:ok, user} = Async.await(fetch_user)

      case Models.User.update(user, %{name: params["name"]}) do
        {:ok, _updated_user} ->
          conn
          |> put_flash(:notice, "Changes saved.")
          |> redirect(to: account_path(conn, :show))

        {:error, error_messages} ->
          user = Map.put(user, :name, params["name"])

          conn
          |> put_flash(:alert, compose_alert_message(error_messages.errors))
          |> put_status(422)
          |> render_show(user, error_messages)
      end
    end)
  end

  defp compose_alert_message(%{other: m}), do: "Failed: #{m}"
  defp compose_alert_message(_), do: "Failed to update the account..."

  def reset_token(conn, _params) do
    Watchman.benchmark("account.regenerate_token.duration", fn ->
      user_id = conn.assigns.user_id

      case Models.User.regenerate_token(user_id) do
        {:ok, new_token} ->
          conn
          |> put_flash(:notice, "Token reset.")
          |> assign(:token, new_token)
          |> render_show(user_id)

        {:error, error} ->
          Logger.error("Error during token reset #{user_id}: #{inspect(error)}")

          conn
          |> put_flash(
            :alert,
            "An error occurred while regenerating the API token. Please contact our support team."
          )
          |> render_show(user_id)
      end
    end)
  end

  def reset_password(conn, %{"user_id" => user_id}) do
    Watchman.benchmark("account.reset_password", fn ->
      if FeatureProvider.feature_enabled?(:email_members, param: conn.assigns.organization_id) do
        case Models.Member.reset_password(conn.assigns.user_id, user_id) do
          {:ok, res} ->
            conn
            |> put_flash(:notice, res.msg)
            |> assign(:password, res.password)
            |> render_show(user_id)

          {:error, error} ->
            Logger.error("Error during password reset #{user_id}: #{inspect(error)}")

            conn
            |> put_flash(
              :alert,
              "An error occurred while rotating the password. Please contact our support team."
            )
            |> redirect(to: account_path(conn, :show))
        end
      else
        conn
        |> FrontWeb.PageController.status404(%{})
        |> Plug.Conn.halt()
      end
    end)
  end

  def update_repo_scope(conn, params = %{"provider" => provider}) do
    Watchman.benchmark("account.update_repo_scope.duration", fn ->
      domain = Application.get_env(:front, :domain)
      path = "https://me.#{domain}#{account_path(conn, :show)}"

      scope =
        case params["access_level"] do
          "public" -> "public_repo,user:email"
          "private" -> "repo,user:email"
          "email" -> "user:email"
          _ -> "repo,user:email"
        end

      url =
        case provider do
          "github" ->
            "https://id.#{domain}/oauth/github?scope=#{scope}&redirect_path=#{path}"

          p ->
            "https://id.#{domain}/oauth/#{p}?redirect_path=#{path}"
        end

      redirect(conn, external: url)
    end)
  end

  def change_my_email(conn, %{"email" => email}) do
    Watchman.benchmark("account.change_my_email.duration", fn ->
      if FeatureProvider.feature_enabled?(:email_members,
           param: conn.assigns.organization_id
         ) do
        user_id = conn.assigns.user_id
        email = String.trim(email)

        # Basic validation
        cond do
          email == "" ->
            conn
            |> put_flash(:alert, "Email address cannot be empty.")
            |> redirect(to: account_path(conn, :show))

          not valid_email_format?(email) ->
            conn
            |> put_flash(:alert, "Please enter a valid email address.")
            |> redirect(to: account_path(conn, :show))

          true ->
            case Models.Member.change_email(user_id, user_id, email) do
              {:ok, %{msg: msg}} ->
                conn
                |> put_flash(:notice, msg)
                |> redirect(to: account_path(conn, :show))

              {:error, error_msg} ->
                conn
                |> put_flash(:alert, "Failed to update email: #{error_msg}")
                |> redirect(to: account_path(conn, :show))
            end
        end
      else
        conn
        |> FrontWeb.PageController.status404(%{})
        |> Plug.Conn.halt()
      end
    end)
  end

  def reset_my_password(conn, _params) do
    Watchman.benchmark("account.reset_my_password.duration", fn ->
      user_id = conn.assigns.user_id

      # Check if feature is enabled
      if FeatureProvider.feature_enabled?(:email_members) or Front.ce?() do
        case Models.Member.reset_password(user_id, user_id) do
          {:ok, %{msg: msg, password: new_password}} ->
            conn
            |> put_flash(:notice, msg)
            |> assign(:new_password, new_password)
            |> render_show(user_id)

          {:error, error_msg} ->
            conn
            |> put_flash(:alert, "Failed to reset password: #{error_msg}")
            |> render_show(user_id)
        end
      else
        conn
        |> put_flash(:alert, "Password changes are not enabled for your organization.")
        |> render_show(user_id)
      end
    end)
  end

  def delete_user(conn, _params) do
    Watchman.benchmark("account.delete_with_owned_orgs.duration", fn ->
      user_id = conn.assigns.user_id
      tracing_headers = conn.assigns.tracing_headers

      case Models.User.delete_user(user_id, tracing_headers) do
        {:ok, _user} ->
          conn
          |> redirect(external: destroyed_account_redirect_url(conn))

        {:error, error_message} ->
          conn
          |> put_flash(:alert, error_message)
          |> redirect(to: account_path(conn, :show))
      end
    end)
  end

  defp render_show(conn, user_id, errors \\ nil)

  defp render_show(conn, user_id, errors) when is_binary(user_id) do
    fetch_user = Async.run(fn -> Models.User.find_user_with_providers(user_id) end)

    case Async.await(fetch_user) do
      {:ok, user} ->
        render_show(conn, user, errors)

      _ ->
        conn
        |> put_flash(:alert, "User not found.")
        |> redirect(to: "/")
    end
  end

  defp render_show(conn, user, errors) do
    render(
      conn,
      "show.html",
      user: user,
      owned: true,
      errors: errors,
      title: "Semaphore - Account"
    )
  end

  defp valid_email_format?(email) do
    email_regex = ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/
    Regex.match?(email_regex, email)
  end

  defp destroyed_account_redirect_url(_conn) do
    domain = Application.get_env(:front, :domain)
    "https://id.#{domain}/destroyed_account"
  end
end
