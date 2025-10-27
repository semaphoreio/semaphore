defmodule Guard.InstanceConfig.Api do
  @moduledoc """
  The flow is the following:

    on the page served by front
      |
      | On the client side the user clicks on the "Connect GitHub" button.
      | The button redirects the user to the `id.{domain}/github_app_manifest?org_id={org_id}`
      | The org_id is used to redirect the user back to the organization page, and generate a state token.
      |
      V
    +--------------------------+
    | Guard.InstanceConfig.Api |
    +--------------------------+
      |
      | This API generates a manifest for the GitHub App,
      | render a super simple HTML page with the manifest form, submit button
      | and piece of JavaScript that will automatically submit the form.
      | 1. generates a state used to prevent CSRF attacks.
      |    token is base64 encoded string of a JSON object containing
      |    - organization_id
      |    - some random 16 character string.
      | 2. The state token is saved in the session cookie.
      |
      | GET id.{domain}/github_app_manifest?state={state}
      | state = base64({org_id: UUID, token: String})
      |
      | POST https://github.com/settings/apps/new?state={state}
      |
      V
    +--------+
    | Github |
    +--------+
      |
      | Github will prompt the user to authenticate and create the app.
      |
      | GET id.{domain}/github_app_callback?code={code}state={state}
      |
      V
    +--------------------------+
    | Guard.InstanceConfig.Api |
    +--------------------------+
      |
      | 1. This API receives the callback from GitHub, parse the state token
      |    and compare it with the one saved in the session cookie.
      | 2. If the state token matches, it will fetch the GitHub App data
      |    from GitHub `https://github.com//app-manifests/{code}/conversions` and save it.
      | 3. Generate a new state token and save it in the session cookie,
      |    this state token is again base64 encoded JSON object containing
      |    the organization_id and some random 16 character string.
      | 4. Redirect the user back to GitHub to install the app.
      |
      | GET  {github_app.html_url}/installations/new
      |
      V
    +--------+
    | Github |
    +--------+
      |
      | Github prompts the user to install the app.
      | User is redirected back to Semaphore.
      |
      | GET {org-name}.{domain}/github_app_installation?state={state}
      |
      V
    +--------+
    | front  |
    +--------+
      |
      | Parse state token and redirect the user to the
      | organization page.
      |
      * Done
  """

  require Logger
  use Plug.Router
  use Sentry.PlugCapture
  import Guard.InstanceConfig.Api.Utils

  @state_cookie_key "github_app_state"
  @front_redirect_path Application.compile_env(:guard, :front_git_integration_path)

  if Application.compile_env!(:guard, :environment) == :dev do
    use Plug.Debugger, otp_app: :guard
  end

  plug(Sentry.PlugContext)
  plug(Guard.Utils.Http.RequestLogger)
  plug(:plug_fetch_query_params)

  plug(Unplug,
    if: {Unplug.Predicates.RequestPathEquals, "/github_app_manifest_callback"},
    do: {Guard.InstanceConfig.Api.CookieOrgUsername, [state_cookie_key: @state_cookie_key]}
  )

  plug(Unplug,
    if: {Unplug.Predicates.RequestPathEquals, "/github_app_manifest"},
    do: {Guard.InstanceConfig.Api.OrgIdAssign, []}
  )

  plug(:dynamic_plug_session)

  plug(:match)
  plug(:dispatch)

  get "/is_alive" do
    send_resp(conn, 200, "")
  end

  get "/github_app_manifest" do
    org_id = conn.assigns[:org_id]

    manifest = Guard.InstanceConfig.GithubApp.manifest(conn.assigns[:org_username])

    with integration <- Guard.InstanceConfig.Store.get(:CONFIG_TYPE_GITHUB_APP),
         {:does_not_exist, true} <- {:does_not_exist, is_nil(integration)},
         token <- Guard.InstanceConfig.Token.encode(org_id),
         {:ok, manifest_json} <- Jason.encode(manifest) do
      conn
      |> put_resp_cookie(@state_cookie_key, token)
      |> render_manifest_page(
        manifest: manifest_json |> html_escape(),
        url: github_app_install_url() <> "?state=#{token}"
      )
    else
      {:does_not_exist, false} ->
        conn
        |> put_notification(:notice, "Integration already exists")
        |> redirect_to_front(@front_redirect_path)

      err ->
        Logger.error("Error rendering the manifest page: #{inspect(err)}")

        conn
        |> put_notification(:notice, "Internal error")
        |> redirect_to_front(@front_redirect_path)
    end
  end

  get "/github_app_manifest_callback" do
    state = conn.query_params["state"] |> URI.decode()
    code = conn.query_params["code"]
    org_id = conn.assigns[:org_id]

    with {:code, true} <- {:code, is_binary(code)},
         conn <- Plug.Conn.fetch_cookies(conn),
         {:ok, state_token} <- Map.fetch(conn.cookies, @state_cookie_key),
         {:matching_csrf, true} <- {:matching_csrf, state == state_token},
         {:ok, github_app_data} <- Guard.InstanceConfig.GithubApp.fetch(code),
         changeset <-
           Guard.InstanceConfig.Models.Config.changeset(%Guard.InstanceConfig.Models.Config{}, %{
             name: :CONFIG_TYPE_GITHUB_APP |> Atom.to_string(),
             config: github_app_data
           }),
         {:ok, _} <- Guard.InstanceConfig.Store.set(changeset) do
      new_state = Guard.InstanceConfig.Token.encode(org_id)

      conn
      |> put_resp_cookie(@state_cookie_key, new_state)
      |> redirect_to_url(github_app_data.html_url <> "/installations/new?state=#{new_state}")
    else
      {:code, false} ->
        conn
        |> put_notification(:alert, "Code is missing")
        |> redirect_to_front(@front_redirect_path)

      {:matching_csrf, false} ->
        conn
        |> put_notification(:alert, "CSRF token mismatch")
        |> redirect_to_front(@front_redirect_path)

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_notification(
          :alert,
          "Error saving the GitHub App data: #{inspect(changeset.errors)}"
        )
        |> redirect_to_front(@front_redirect_path)

      {:error, error_message} ->
        conn
        |> put_notification(:alert, "Error fetching the GitHub App data: #{error_message}")
        |> redirect_to_front(@front_redirect_path)
    end
  end

  # sobelow_skip ["XSS.SendResp"]
  defp render_manifest_page(conn, assigns) do
    html_content =
      Guard.TemplateRenderer.render_template([assigns: assigns], "submit_manifest.html")

    conn
    |> put_resp_header("content-type", "text/html; charset=utf-8")
    |> send_resp(200, html_content)
  end

  #
  # Handle everything else as Unathorized
  #
  match _ do
    send_resp(conn, 401, "Unauthorized")
  end

  def html_escape(string) do
    string
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end

  defp dynamic_plug_session(conn, opts), do: Guard.Session.setup(conn, opts)

  defp github_app_install_url, do: Application.get_env(:guard, :github_app_install_url)

  defp plug_fetch_query_params(conn, _opts) do
    conn |> fetch_query_params()
  end
end
