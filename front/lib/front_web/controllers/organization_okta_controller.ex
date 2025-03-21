defmodule FrontWeb.OrganizationOktaController do
  @moduledoc false
  use FrontWeb, :controller
  alias Front.{Async, Audit, Models.OktaIntegration}
  require Logger

  plug(FrontWeb.Plugs.FetchPermissions, scope: "org")
  plug(FrontWeb.Plugs.PageAccess, permissions: "organization.view")
  plug(FrontWeb.Plugs.PageAccess, [permissions: "organization.okta.manage"] when action != :show)
  plug(FrontWeb.Plugs.Header)
  plug(:put_layout, :organization_settings)

  @watchman_prefix "organization_okta.endpoint"

  def show(conn, _params) do
    Watchman.benchmark(watchman_name(:show, :duration), fn ->
      organization_id = conn.assigns.organization_id

      with {:ok, params} <- fetch_params(organization_id) do
        case OktaIntegration.find_for_org(organization_id) do
          {:ok, integration} ->
            Watchman.increment(watchman_name(:show, :success))
            render_show(conn, integration, params)

          {:error, :not_found} ->
            Watchman.increment(watchman_name(:show, :success))
            render_show(conn, nil, params)

          e ->
            Watchman.increment(watchman_name(:show, :failure))
            raise e
        end
      else
        {:error, reason} ->
          Watchman.increment(watchman_name(:show, :failure))
          {:error, reason}
      end
    end)
  end

  @doc """
    This endpoint renders a form for creating/modifying okta integration
  """
  def form(conn, _params) do
    Watchman.benchmark(watchman_name(:new, :duration), fn ->
      alias Front.Models.OktaIntegration

      organization_id = conn.assigns.organization_id

      changeset =
        case OktaIntegration.find_for_org(organization_id) do
          {:error, :not_found} ->
            OktaIntegration.new()

          {:ok, integration} ->
            Logger.info("Okta integration found #{inspect(integration)}")
            integration |> OktaIntegration.changeset()
        end

      with {:ok, params} <- fetch_params(organization_id) do
        Watchman.increment(watchman_name(:form, :success))

        render_form(conn, changeset, params)
      else
        {:error, reason} ->
          Watchman.increment(watchman_name(:form, :failure))
          {:error, reason}
      end
    end)
  end

  @doc """
    Destination for "okta_create_form". Used both for creating new and updating
    existing okta integrations.
  """
  def create(conn, %{"okta_integration" => integration}) do
    Watchman.benchmark(watchman_name(:create, :duration), fn ->
      org_id = conn.assigns.organization_id
      user_id = conn.assigns.user_id

      case fetch_params(org_id) do
        {:ok, params} ->
          with {:ok, model} <- create_integration(org_id, user_id, integration),
               {:ok, token} <- gen_token(model) do
            Watchman.increment(watchman_name(:create, :success))
            if Front.on_prem?(), do: log_create(conn, user_id, model)

            conn
            |> put_flash(:notice, "Success: Your organization is connected with Okta")
            |> render_token(token, model.jit_provisioning_enabled, params)
          else
            {:error, :create_integration, changeset, alert} ->
              Watchman.increment(watchman_name(:create, :failure))

              conn
              |> put_flash(:alert, alert)
              |> render_form(changeset, params)

            {:error, :gen_token, err} ->
              Watchman.increment(watchman_name(:create, :failure))
              {:error, err}
          end

        {:error, reason} ->
          Watchman.increment(watchman_name(:create, :failure))
          {:error, reason}
      end
    end)
  end

  @doc """
  Page that renders the group mapping with edit forms.
  This is available only when jit_provisioning_enabled is true.
  """
  def group_mapping(conn, _params) do
    Watchman.benchmark(watchman_name(:group_mapping, :duration), fn ->
      org_id = conn.assigns.organization_id

      with {:ok, params} <- fetch_params(org_id),
           {:okta_integration, {:ok, integration}} <-
             {:okta_integration, OktaIntegration.find_for_org(org_id)},
           {:ok, {groups, _}} <-
             Front.RBAC.Members.list_org_members(org_id, member_type: "group"),
           {:ok, roles} <- Front.RBAC.RoleManagement.list_possible_roles(org_id, "org_scope"),
           {:ok, {default_role_id, group_mapping, role_mapping}} <-
             OktaIntegration.get_mapping(org_id) do
        render_group_mapping(
          conn,
          integration,
          groups,
          roles,
          params,
          default_role_id,
          group_mapping,
          role_mapping
        )
      else
        {:okta_integration, {:error, :not_found}} ->
          conn
          |> put_flash(:alert, "You need to set up Okta integration first")
          |> redirect(to: organization_okta_path(conn, :show))

        error ->
          Logger.error("Group mapping error: #{inspect(error)}")

          conn
          |> put_flash(:alert, "Something went wrong.")
          |> redirect(to: organization_okta_path(conn, :show))
      end
    end)
  end

  @doc """
  Page that updates the group mapping.
  """
  def update_group_mapping(conn, params) do
    Watchman.benchmark(watchman_name(:update_group_mapping, :duration), fn ->
      Logger.info("update_group_mapping, params: #{inspect(params)}")

      org_id = conn.assigns.organization_id

      case OktaIntegration.set_mapping(org_id, params) do
        :ok ->
          conn
          |> put_flash(:notice, "Okta group mappings successfully updated")
          |> redirect(to: organization_okta_path(conn, :show))

        {:error, _error} ->
          conn
          |> put_flash(:alert, "Failed to update Okta group mappings. Please try again.")
          |> redirect(to: organization_okta_path(conn, :group_mapping))
      end
    end)
  end

  @doc """
    Page that lists reprocusions of disconnecting okta organizations and asks users
    to confirm if they want to disconnect Okta
  """
  def disconnect_notice(conn, params) do
    integration_id = params["integration_id"]

    organization_id = conn.assigns.organization_id

    with {:ok, params} <- fetch_params(organization_id) do
      render_discnonnect_notice(conn, integration_id, params)
    else
      {:error, reason} ->
        Watchman.increment(watchman_name(:discnonnect_notice, :failure))
        {:error, reason}
    end
  end

  def disconnect(conn, params) do
    alias Front.Models.OktaIntegration

    integration_id = params["integration_id"]
    user_id = conn.assigns.user_id

    if OktaIntegration.destroy(integration_id, user_id) == :ok do
      conn
      |> put_flash(:notice, "Request sent. Disconnecting Okta might take up to a minute")
      |> redirect(to: settings_path(conn, :show))
    else
      conn
      |> put_flash(
        :alert,
        "Something went wrong while trying to disconnect Okta. Please contact our customer suppor."
      )
      |> redirect(to: organization_okta_path(conn, :show))
    end
  end

  defp create_integration(org_id, user_id, integration) do
    alias Front.Models.OktaIntegration

    case OktaIntegration.create_or_upadte(org_id, user_id, integration) do
      {:ok, model} ->
        {:ok, model}

      {:error, %GRPC.RPCError{} = err} ->
        # This case happens when validation on okta-serrvice side fails
        changeset =
          struct(OktaIntegration, org_id: org_id, creator_id: user_id)
          |> OktaIntegration.changeset(integration)

        {:error, :create_integration, changeset, err.message}

      {:error, changeset} ->
        # This case happens when front validation fails
        {:error, :create_integration, changeset, "Failure: provided invalid data"}
    end
  end

  defp gen_token(integration) do
    alias Front.Models.OktaIntegration

    case OktaIntegration.gen_token(integration.id) do
      {:ok, token} -> {:ok, token}
      {:error, err} -> {:error, :gen_token, err}
    end
  end

  defp fetch_params(organization_id) do
    maybe_organization = Async.run(fetch_organization(organization_id))
    maybe_okta_members = Async.run(fetch_org_okta_members(organization_id))

    with {:ok, organization} <- Async.await(maybe_organization),
         {:ok, okta_members} <- Async.await(maybe_okta_members) do
      {:ok,
       %{
         organization: organization,
         no_of_okta_members: length(okta_members)
       }}
    end
  end

  defp fetch_organization(organization_id),
    do: fn ->
      Front.Models.Organization.find(organization_id)
    end

  defp fetch_org_okta_members(org_id) do
    fn ->
      case OktaIntegration.get_okta_members(org_id) do
        {:ok, user_ids} -> user_ids
        {:error, _} -> []
      end
    end
  end

  defp log_create(conn, user_id, integration) do
    user = Front.Models.User.find(user_id)

    conn
    |> Audit.new(:Okta, :Added)
    |> Audit.add(
      description: "User #{user.name} set up Okta SAML integration #{integration.issuer}"
    )
    |> Audit.add(resource_id: integration.id)
    |> Audit.metadata(saml_issuer: integration.issuer)
    |> Audit.metadata(user_id: user_id)
    |> Audit.log()
  end

  defp render_show(conn, integration, params) do
    render(conn, "show.html",
      permissions: conn.assigns.permissions,
      organization: params.organization,
      org_restricted: params.organization.restricted,
      no_of_okta_members: params.no_of_okta_members,
      integration: integration,
      title: "Okta・#{params.organization.name}",
      notice: get_flash(conn, :notice),
      alert: get_flash(conn, :alert)
    )
  end

  defp render_form(conn, changeset, params) do
    render(conn, "form.html",
      permissions: conn.assigns.permissions,
      organization: params.organization,
      org_restricted: params.organization.restricted,
      title: "Okta・#{params.organization.name}",
      changeset: changeset,
      notice: get_flash(conn, :notice),
      alert: get_flash(conn, :alert)
    )
  end

  defp render_token(conn, token, jit_provisioning_enabled, params) do
    render(conn, "token.html",
      permissions: conn.assigns.permissions,
      organization: params.organization,
      org_restricted: params.organization.restricted,
      jit_provisioning_enabled: jit_provisioning_enabled,
      title: "Okta・#{params.organization.name}",
      token: token,
      notice: get_flash(conn, :notice),
      alert: get_flash(conn, :alert)
    )
  end

  defp render_group_mapping(
         conn,
         integration,
         groups,
         roles,
         params,
         default_role_id,
         group_mapping,
         role_mapping
       ) do
    render(conn, "group_mapping.html",
      js: :organization_okta,
      permissions: conn.assigns.permissions,
      organization: params.organization,
      integration: integration,
      groups: groups,
      roles: roles,
      default_role_id: default_role_id,
      group_mapping: group_mapping,
      role_mapping: role_mapping,
      title: "Okta・#{params.organization.name}",
      notice: get_flash(conn, :notice),
      alert: get_flash(conn, :alert)
    )
  end

  defp render_discnonnect_notice(conn, integration_id, params) do
    render(conn, "disconnect_notice.html",
      permissions: conn.assigns.permissions,
      organization: params.organization,
      integration_id: integration_id,
      org_restricted: params.organization.restricted,
      title: "Okta・#{params.organization.name}",
      notice: get_flash(conn, :notice),
      alert: get_flash(conn, :alert)
    )
  end

  #
  # Watchman callbacks
  #
  defp watchman_name(method, metrics), do: "#{@watchman_prefix}.#{method}.#{metrics}"
end
