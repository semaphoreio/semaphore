defmodule Rbac.Okta.Saml.Api do
  @moduledoc """
  SAML is used for Single Sign-On. This module provides the main
  entrypoint for all Okta related SAML authentication actions.

  A typical Okta customer will have:

    1. An Okta organization
    2. People from their team are added to Okta
    3. They have set up a "Semaphore 2.0" application on Okta
    4. The audience of the Okta application is set to:
       https://{org-name}.semaphoreci.com
    5. The Single Sign-On URL is set to:
       https://{org-name}.semaphoreci.com/okta/auth

  When a person wants to log into Semaphore with Okta, the flow
  will be:

    1. She logs into Okta
    2. She sees an Application called Semaphore 2.0, she clicks it
    3. This sends an SAML authorization request to the configured
       Single Sign-On URL (ex. rtx.semaphoreci.com/okta/auth)
    4. This module will receive the auth request and handle it

  The data flow is the following:

    +--------+
    | Okta   |
    +--------+
      |
      | POST {org-name}.semaphoreci.com/okta/auth
      | SAMLResponse={base64 encoded SAML payload}
      |
      | Note: It is super weird that the auth request is called response,
      |       but what can you do, SAML is weird af.
      |
    ------ Entering our Kubernetes cluster -----------------------
      |
      V
    +--------+
    | Auth   |
    +--------+
      |
      | The auth service will find the org_id and pass the request
      | to Rbac.
      |
      | x-semaphore-org-id={UUID of the org}
      |
      V
    +-------------------+
    | Rbac.Okta.SAML   |
    +-------------------+
      |
      | 1. Parse the payload of POST /okta/auth
      | 2. Find the user, if he exists
      | 3. Set the session cookie
      | 4. Redirect to the root of the org {org-name}.semaphoreci.com or
      |    to the account page to connect the GitHub account.
      |
      * Done

  Learn more about SAML in the Okta docs:
  https://developer.okta.com/docs/concepts/saml/
  """

  alias Rbac.FrontRepo

  require Logger
  use Plug.Router
  use Sentry.PlugCapture

  plug(Sentry.PlugContext)
  plug(Plug.Logger, log: :info)

  # Okta is sending us UrlEncoded an URL encoded payload, this plug parses it
  plug(Plug.Parsers, parsers: [:urlencoded])

  plug(:dynamic_plug_session)
  plug(:assign_org_id)
  plug(:assign_org_username)
  plug(:match)
  plug(:dispatch)

  #
  # Health checks for the Kubernetes Pod
  # This service is exposed as a single dedicated pod and it needs
  # to have valid health check responses.
  #

  get "/" do
    send_resp(conn, 200, "")
  end

  get "/is_alive" do
    send_resp(conn, 200, "")
  end

  #
  # Okta Authentication
  #

  post "/okta/auth" do
    alias Rbac.Okta.Integration
    alias Rbac.Okta.Saml.PayloadParser

    params = conn.params

    Logger.debug("Auth params: #{inspect(params)}")

    org_id = conn.assigns.org_id
    org_username = conn.assigns.org_username

    Logger.debug("Org ID: #{inspect(org_id)}")
    Logger.debug("Org username: #{inspect(org_username)}")

    consume_uri = "https://#{org_username}.#{domain()}/okta/auth"
    metadata_uri = "https://#{org_username}.#{domain()}"

    with {:ok, integration} <- Integration.find_by_org_id(org_id),
         {:ok, email, att} <- PayloadParser.parse(integration, params, consume_uri, metadata_uri),
         {:ok, okta_user} <- find_okta_user(integration, email),
         {:ok, user} <- find_user(okta_user),
         {:ok, user} <- FrontRepo.User.set_remember_timestamp(user) do
      Watchman.increment("okta_login.success")

      Logger.info(
        "[Okta] User create a session user_id: #{user.id} integration_id: #{integration.id}"
      )

      conn
      |> inject_session_cookie(user)
      |> redirect(user)
    else
      e ->
        Watchman.increment("okta_login.failure")
        Logger.error("Okta auth failed #{inspect(e)}")
        render_not_found(conn)
    end
  end

  defp inject_session_cookie(conn, user) do
    secret_key_base = Application.get_env(:rbac, :session_secret_key_base)
    conn = put_in(conn.secret_key_base, secret_key_base)

    {key, content} = Rbac.Session.serialize_into_session(user)

    conn |> fetch_session() |> put_session(key, content) |> put_session("id_provider", "OKTA")
  end

  defp redirect(conn, user) do
    url =
      if Rbac.FrontRepo.RepoHostAccount.count(user.id) > 0 do
        Rbac.Utils.Http.fetch_redirect_value(conn, "/")
      else
        "https://me.#{domain()}/account/welcome/okta"
      end

    conn
    |> Rbac.Utils.Http.clear_redirect_value()
    |> Rbac.Utils.Http.redirect_to_url(url)
  end

  defp domain, do: Application.get_env(:rbac, :base_domain)

  defp render_not_found(conn) do
    conn |> put_resp_content_type("text/plain") |> send_resp(404, "Not found")
  end

  defp find_okta_user(integration, email) do
    case Rbac.Repo.OktaUser.find_by_email(integration, email) do
      {:ok, user} -> {:ok, user}
      {:error, :not_found} -> {:error, :okta_user, :not_found}
    end
  end

  defp find_user(okta_user) do
    if okta_user.user_id do
      case FrontRepo.User.active_user_by_id(okta_user.user_id) do
        {:ok, user} -> {:ok, user}
        {:error, :not_found} -> {:error, :user, :not_found}
      end
    else
      {:error, :user, :not_found}
    end
  end

  #
  # Handle everything else as Unathorized
  #
  match _ do
    send_resp(conn, 401, "Unauthorized")
  end

  defp assign_org_id(conn, _) do
    id = conn |> get_req_header("x-semaphore-org-id") |> List.first()

    assign(conn, :org_id, id)
  end

  defp assign_org_username(conn, _) do
    id = conn |> get_req_header("x-semaphore-org-username") |> List.first()

    assign(conn, :org_username, id)
  end

  defp dynamic_plug_session(conn, opts), do: Rbac.Session.setup(conn, opts)
end
