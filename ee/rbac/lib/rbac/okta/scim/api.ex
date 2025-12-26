defmodule Rbac.Okta.Scim.Api do
  @moduledoc """
  What is this and how it works?

  Okta is able to automatically add and update users in Semaphore by using the SCIM
  protocol. The SCIM protocl is quite simple and it requires Semaphore to implement
  only a couple of endpoints.

  These endpoints are:
    - GET /Users     — Get a list of Okta users in a Semaphore org
    - GET /Users/:id — Describe a user in a Semaphore org
    - POST /Users    — Provision a new user with the provided info
    - PUT /Users     — Activate user details, or de-activate the user

  All the requests are JSON, and all the responses are JSON as well.

  This module is an implementation of this communication protocol. It is
  an HTTP service that exposes these actions.

  The data flow is the following:

    +--------+
    | Okta   |
    +--------+
      |
      | POST {org-name}.semaphoreci.com/okta/scim/Users
      |
      | payload = %{
      |   "active" => true,
      |   "displayName" => "Igor Sarcevic",
      |   "emails" => [
      |     %{
      |       "primary" => true,
      |       "type" => "work",
      |       "value" => "igor@renderedtext.com"
      |     }
      |   ],
      |   "externalId" => "00u207apm0oRvgHEE697",
      |   "groups" => [],
      |   "locale" => "en-US",
      |   "name" => %{"familyName" => "Sarcevic", "givenName" => "Igor"},
      |   "password" => "HaMfe17v",
      |   "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
      |   "userName" => "igor@renderedtext.com"
      | }
      |
      | Authorization Header is a bearer key provided by Semaphore.
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
    | Rbac.Okta.SCIM   |
    +-------------------+
      |
      | 1. Find the integration record for the referenced org
      | 2. Validate the key presented in the Auth header
      | 3. Create a new user in the org.
      |
      * Done
  """

  require Logger
  use Plug.Router
  use Sentry.PlugCapture

  plug(Sentry.PlugContext)

  plug(Plug.Parsers,
    parsers: [:json],
    pass: ["application/json", "text/json"],
    json_decoder: Jason
  )

  # authorizes and injects assigns.org_id and assigns.integration
  plug(Rbac.Okta.Scim.AuthPlug)

  plug(:match)
  plug(:dispatch)

  alias Rbac.Okta.Integration
  alias Rbac.Okta.Scim.Filter

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
  # Okta SCIM Actions
  #
  # GitHub documentation about the SCIM endpoints is best one out there
  # https://docs.github.com/en/rest/scim#about-the-scim-api. The SCIM
  # protocol offers more than what they provided, but it is a great
  # start for the implemenation.
  #
  # The other good documentation source is provided by Okta.
  # https://developer.okta.com/docs/reference/scim/scim-20/#create-users
  # hint: in the up-right corner you can disable dark mode. The page
  # is unredable without this.
  #

  get "/okta/scim/Users" do
    org_id = conn.assigns.org_id
    integration = conn.assigns.integration

    location = "org_id: #{org_id} integration_id: #{integration.id}"
    Logger.info("OKTA SCIM: Listing users in #{location} with params: #{inspect(conn.params)}")

    start_index = parse_number(conn.params["startIndex"]) || 1
    filters = Filter.compute(conn.params["filter"])
    count = parse_number(conn.params["count"]) || 0

    {users, total_count} = Rbac.Repo.OktaUser.list(integration, start_index - 1, count, filters)
    serialized = users |> Enum.map(&serialize_user/1)

    json(conn, 200, %{
      "schemas" => ["urn:ietf:params:scim:api:messages:2.0:ListResponse"],
      "totalResults" => total_count,
      "startIndex" => start_index,
      "itemsPerPage" => length(serialized),
      "Resources" => serialized
    })
  end

  get "/okta/scim/Users/:id" do
    org_id = conn.assigns.org_id
    user_id = conn.path_params["id"]
    integration = conn.assigns.integration

    location = "org_id: #{org_id} integration_id: #{integration.id}"
    Logger.info("OKTA SCIM: Describing user #{user_id} in #{location}")

    case Integration.find_user(integration, user_id) do
      {:ok, user} ->
        json(conn, 200, serialize_user(user))

      {:error, :not_found} ->
        render_user_not_found(conn)

      e ->
        Logger.error("OKTA SCIM: Failed to get user in #{location} err: #{e}")
        json(conn, 500, "Internal server error")
    end
  end

  put "/okta/scim/Users/:id" do
    create_audit_log(conn, :Modified, "Okta sent a request for updating user.")

    org_id = conn.assigns.org_id
    user_id = conn.path_params["id"]
    integration = conn.assigns.integration

    location = "org_id: #{org_id} integration_id: #{integration.id}"
    Logger.info("OKTA SCIM: Updating user #{user_id} in #{location}")

    case Integration.update_user(integration, user_id, conn.body_params) do
      {:ok, user} ->
        create_audit_log(conn, :Modified, "Okta user successfully modified")
        json(conn, 200, serialize_user(user))

      {:error, :not_found} ->
        create_audit_log(conn, :Modified, "Okta user doesn't exist")
        render_user_not_found(conn)

      {:error, err} ->
        create_audit_log(conn, :Modified, "Error while updating okta user")
        Logger.error("OKTA SCIM: Failed to update user #{user_id} in #{location}, err: #{err}")
        json(conn, 500, "Internal server error")
    end
  end

  post "/okta/scim/Users" do
    create_audit_log(conn, :Added, "Okta sent a request for adding new user.")

    org_id = conn.assigns.org_id
    integration = conn.assigns.integration
    location = "org_id: #{org_id} integration_id: #{integration.id}"

    case Integration.add_user(integration, conn.body_params) do
      {:ok, user} ->
        create_audit_log(conn, :Added, "User #{user.id} successfully created.")
        Logger.info("OKTA SCIM: Added user #{user.id} in #{location}")

        json(conn, 201, serialize_user(user))

      {:error, err} ->
        create_audit_log(conn, :Added, "Failed to add new user")
        Logger.error("OKTA SCIM: Failed to add user in #{location} err: #{err}")
        json(conn, 500, "Internal server error")
    end
  end

  def render_user_not_found(conn) do
    json(conn, 404, %{
      "schemas" => ["urn:ietf:params:scim:api:messages:2.0:Error"],
      "detail" => "User not found",
      "status" => 404
    })
  end

  #
  # Helper for creating Audit logs
  #

  defp create_audit_log(conn, operation, description) do
    alias Rbac.Events.Audit

    {:ok, metadata} = Jason.encode(conn.body_params)

    %{
      user_id: Rbac.Utils.Common.nil_uuid(),
      org_id: conn.assigns.org_id,
      resource: :User,
      operation: operation,
      username: "Okta",
      operation_id: header(conn, "x-request-id") || Ecto.UUID.generate(),
      metadata: metadata,
      description: description,
      medium: :API
    }
    |> Audit.create_event()
    |> Audit.publish()
  end

  defp header(conn, name) do
    conn |> Plug.Conn.get_req_header(name) |> List.first()
  end

  #
  # Handle everything else as Unathorized
  #

  match _ do
    Logger.error("Unknown SCIM path")
    Logger.error(inspect(conn))

    send_resp(conn, 401, "Unauthorized")
  end

  defp json(conn, status, payload) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(payload))
  end

  defp serialize_user(okta_user) do
    Map.merge(okta_user.payload, %{
      id: okta_user.id,
      meta: %{resourceType: "User"}
    })
  end

  defp parse_number(nil), do: nil
  defp parse_number(str), do: Integer.parse(str) |> elem(0)
end
