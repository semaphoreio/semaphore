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
      render_show(conn, conn.assigns.user_id, params["errors"])
    end)
  end

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
          # Check if feature is enabled
          if FeatureProvider.feature_enabled?(:email_members,
               param: conn.assigns[:organization_id]
             ) or Front.ce?() do
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
          else
            conn
            |> put_flash(:alert, "Email changes are not enabled for your organization.")
            |> redirect(to: account_path(conn, :show))
          end
      end
    end)
  end

  def reset_my_password(conn, _params) do
    Watchman.benchmark("account.reset_my_password.duration", fn ->
      user_id = conn.assigns.user_id

      # Check if feature is enabled
      if FeatureProvider.feature_enabled?(:email_members, param: conn.assigns[:organization_id]) or
           Front.ce?() do
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

  defp render_show(conn, user_id, errors \\ nil)

  defp render_show(conn, user_id, errors) when is_binary(user_id) do
    fetch_user = Async.run(fn -> Models.User.find_user_with_providers(user_id) end)
    {:ok, user} = Async.await(fetch_user)

    render_show(conn, user, errors)
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
end
