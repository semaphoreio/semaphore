defmodule FrontWeb.OrganizationPFCController do
  @moduledoc false
  use FrontWeb, :controller
  alias Front.{Async, Audit}
  require Logger

  alias Front.Models.OrganizationSettings
  alias Front.Models.PreFlightChecks.AgentConfig
  alias Front.Models.PreFlightChecks.OrganizationPFC

  @actions ~w(put_pre_flight_checks put_init_job_defaults show delete)a

  plug(FrontWeb.Plugs.FetchPermissions, scope: "org")
  plug(FrontWeb.Plugs.PageAccess, permissions: "organization.view")
  plug(FrontWeb.Plugs.Header when action in @actions)
  plug(:put_layout, :organization_settings)

  @watchman_prefix "organization_pfcs.endpoint"

  def show(conn, _params) do
    Watchman.benchmark(watchman_name(:show, :duration), fn ->
      organization_id = conn.assigns.organization_id
      user_id = conn.assigns.user_id
      log_data = log_data_closure(organization_id, user_id, :show)

      maybe_model = Async.run(fetch_model(organization_id))

      with {:ok, params} <- fetch_params(organization_id, user_id),
           {:ok, model} <- Async.await(maybe_model) do
        changeset = OrganizationPFC.changeset(model)
        Watchman.increment(watchman_name(:show, :success))

        render_page(conn, changeset, params)
      else
        {:error, reason} ->
          Logger.error(log_data.(reason))
          Watchman.increment(watchman_name(:show, :failure))
          {:error, reason}
      end
    end)
  end

  def put_pre_flight_checks(conn, %{"organization_pfc" => pfc_params}) do
    Watchman.benchmark(watchman_name(:put, :duration), fn ->
      organization_id = conn.assigns.organization_id
      user_id = conn.assigns.user_id

      log_data = log_data_closure(organization_id, user_id, :put)
      audit_log(conn)

      changeset = OrganizationPFC.empty() |> OrganizationPFC.changeset(pfc_params)

      with {:ok, params} <- fetch_params(organization_id, user_id),
           {:ok, :authorized} <- action_allowed?(conn, :put_pre_flight_checks),
           {:ok, conn} <- validate_and_apply_pfcs(conn, changeset, params) do
        Watchman.increment(watchman_name(:put, :success))
        conn
      else
        {:error, :unauthorized} ->
          conn
          |> put_flash(:alert, "Insufficient permissions.")
          |> redirect(to: organization_pfc_path(conn, :show))

        {:error, reason} ->
          Watchman.increment(watchman_name(:put, :failure))
          Logger.error(log_data.(reason))

          conn
          |> put_flash(:alert, "Failure: Unable to configure pre-flight checks")
          |> redirect(to: organization_pfc_path(conn, :show))
      end
    end)
  end

  defp validate_and_apply_pfcs(conn, changeset, params) do
    organization_id = conn.assigns.organization_id
    user_id = conn.assigns.user_id

    with {:ok, model} <- Ecto.Changeset.apply_action(changeset, :insert),
         {:ok, _model} <- OrganizationPFC.apply(organization_id, user_id, model) do
      {:ok,
       conn
       |> put_flash(:notice, "Success: pre-flight checks configured")
       |> redirect(to: organization_pfc_path(conn, :show))}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {:ok,
         conn
         |> put_flash(:alert, "Failure: provided invalid data")
         |> render_page(changeset, params)}
    end
  end

  def put_init_job_defaults(conn, %{"agent_config" => params}) do
    Watchman.benchmark(watchman_name(:put_init_job_defaults, :duration), fn ->
      organization_id = conn.assigns.organization_id
      user_id = conn.assigns.user_id

      log_data = log_data_closure(organization_id, user_id, :put_init_job_defaults)
      audit_log(conn)

      changeset = AgentConfig.new() |> AgentConfig.changeset(params)

      with {:ok, params} <- fetch_params(organization_id, user_id),
           {:ok, :authorized} <- action_allowed?(conn, :put_init_job_defaults),
           {:ok, conn} <- validate_and_apply_init_job_defaults(conn, changeset, params) do
        Watchman.increment(watchman_name(:put_init_job_defaults, :success))
        conn
      else
        {:error, :unauthorized} ->
          conn
          |> put_flash(:alert, "Insufficient permissions.")
          |> redirect(to: organization_pfc_path(conn, :show))

        {:error, reason} ->
          Watchman.increment(watchman_name(:put_init_job_defaults, :failure))
          Logger.error(log_data.(reason))

          conn
          |> put_flash(:alert, "Failure: Unable to configure initialization job settings")
          |> redirect(to: organization_pfc_path(conn, :show))
      end
    end)
  end

  defp validate_and_apply_init_job_defaults(conn, changeset, _params) do
    organization_id = conn.assigns.organization_id

    with {:ok, model} <- Ecto.Changeset.apply_action(changeset, :insert),
         {:ok, _model} <-
           OrganizationSettings.modify(organization_id, %{
             "custom_machine_type" => model.machine_type,
             "custom_os_image" => model.os_image
           }) do
      {:ok,
       conn
       |> put_flash(:notice, "Success: initialization job settings configured")
       |> redirect(to: organization_pfc_path(conn, :show))}
    else
      {:error, %Ecto.Changeset{} = _changeset} ->
        {:ok,
         conn
         |> put_flash(:alert, "Failure: provided invalid data")
         |> redirect(to: organization_pfc_path(conn, :show))}
    end
  end

  def delete(conn, _params) do
    Watchman.benchmark(watchman_name(:delete, :duration), fn ->
      organization_id = conn.assigns.organization_id
      user_id = conn.assigns.user_id

      log_data = log_data_closure(organization_id, user_id, :delete)
      audit_log(conn)

      with {:ok, :authorized} <- action_allowed?(conn, :delete),
           :ok <- OrganizationPFC.destroy(organization_id, user_id) do
        Watchman.increment(watchman_name(:delete, :success))

        conn
        |> put_flash(:notice, "Success: pre-flight checks deleted")
        |> redirect(to: organization_pfc_path(conn, :show))
      else
        {:error, :unauthorized} ->
          conn
          |> put_flash(:alert, "Insufficient permissions.")
          |> redirect(to: organization_pfc_path(conn, :show))

        {:error, reason} ->
          Watchman.increment(watchman_name(:delete, :failure))
          Logger.error(log_data.(reason))

          conn
          |> put_flash(:alert, "Failure: cannot delete pre-flight checks")
          |> redirect(to: organization_pfc_path(conn, :show))
      end
    end)
  end

  defp fetch_params(organization_id, user_id) do
    maybe_organization = Async.run(fetch_organization(organization_id))
    maybe_secrets = Async.run(fetch_secrets(organization_id, user_id))
    maybe_init_job_defaults = Async.run(fetch_init_job_defaults(organization_id))
    maybe_cloud_agents = Async.run(fetch_cloud_agents(organization_id))
    maybe_self_hosted_agents = Async.run(fetch_self_hosted_agents(organization_id))

    with {:ok, organization} <- Async.await(maybe_organization),
         {:ok, secrets} <- Async.await(maybe_secrets),
         {:ok, init_job_defaults} <- Async.await(maybe_init_job_defaults),
         {:ok, {:ok, cloud_agents}} <- Async.await(maybe_cloud_agents),
         {:ok, {:ok, self_hosted_agents}} <- Async.await(maybe_self_hosted_agents) do
      {:ok,
       %{
         organization: organization,
         secrets: secrets,
         init_job_defaults: init_job_defaults,
         cloud_agents: cloud_agents,
         self_hosted_agents: self_hosted_agents
       }}
    end
  end

  defp fetch_organization(organization_id),
    do: fn ->
      Front.Models.Organization.find(organization_id)
    end

  defp fetch_model(organization_id),
    do: fn ->
      if FeatureProvider.feature_enabled?(:pre_flight_checks, param: organization_id) do
        case OrganizationPFC.describe(organization_id) do
          {:ok, model} -> model
          {:error, %{code: :NOT_FOUND}} -> OrganizationPFC.new()
          {:error, error} -> raise error
        end
      else
        OrganizationPFC.new()
      end
    end

  defp fetch_init_job_defaults(organization_id),
    do: fn ->
      case Front.Models.OrganizationSettings.fetch(organization_id) do
        {:ok, settings} ->
          machine_type = settings["custom_machine_type"] || settings["plan_machine_type"] || ""
          os_image = settings["custom_os_image"] || settings["plan_os_image"] || ""

          AgentConfig.new(machine_type: machine_type, os_image: os_image)
          |> AgentConfig.changeset(%{})

        {:error, error} ->
          raise error
      end
    end

  defp fetch_secrets(organization_id, user_id),
    do: fn -> Front.Models.Secret.list(user_id, organization_id, "", :ORGANIZATION, true) end

  defp fetch_cloud_agents(organization_id),
    do: fn -> Front.Models.AgentType.list(organization_id) end

  defp fetch_self_hosted_agents(organization_id),
    do: fn -> Front.SelfHostedAgents.AgentType.list(organization_id) end

  defp action_allowed?(conn, :put_pre_flight_checks) do
    if conn.assigns.permissions["organization.pre_flight_checks.manage"],
      do: {:ok, :authorized},
      else: {:error, :unauthorized}
  end

  defp action_allowed?(conn, :put_init_job_defaults) do
    if conn.assigns.permissions["organization.pre_flight_checks.manage"],
      do: {:ok, :authorized},
      else: {:error, :unauthorized}
  end

  defp action_allowed?(conn, :delete) do
    if conn.assigns.permissions["organization.pre_flight_checks.manage"],
      do: {:ok, :authorized},
      else: {:error, :unauthorized}
  end

  defp render_page(conn, changeset, params) do
    render(conn, "show.html",
      js: :organization_pfcs,
      permissions: conn.assigns.permissions,
      changeset: changeset,
      init_job_defaults: params.init_job_defaults,
      cloud_agents: params.cloud_agents,
      self_hosted_agents: params.self_hosted_agents,
      organization: params.organization,
      org_restricted: params.organization.restricted,
      title: "Pre-flight checks・#{params.organization.name}",
      notice: get_flash(conn, :notice),
      alert: get_flash(conn, :alert),
      secrets: params.secrets
    )
  end

  defp log_data_closure(organization_id, user_id, action) do
    fn reason ->
      formatter = &"#{elem(&1, 0)}=\"#{inspect(elem(&1, 1))}\""

      %{
        organization_id: organization_id,
        requester_id: user_id,
        action: action,
        reason: reason
      }
      |> Enum.map_join(" ", formatter)
    end
  end

  defp audit_log(conn = %Plug.Conn{method: "PUT", path_info: ["init_job_defaults"]}) do
    conn
    |> Audit.new(:Organization, :Modified)
    |> Audit.add(description: "Modified initialization job agent configuration")
    |> Audit.add(resource_id: conn.assigns.organization_id)
    |> Audit.metadata(requester_id: conn.assigns.user_id)
    |> Audit.log()
  end

  defp audit_log(conn = %Plug.Conn{method: "PUT", path_info: ["pre_flight_checks"]}) do
    conn
    |> Audit.new(:Organization, :Modified)
    |> Audit.add(description: "Applied organization pre-flight checks")
    |> Audit.add(resource_id: conn.assigns.organization_id)
    |> Audit.metadata(requester_id: conn.assigns.user_id)
    |> Audit.log()
  end

  defp audit_log(conn = %Plug.Conn{method: "DELETE"}) do
    conn
    |> Audit.new(:Organization, :Modified)
    |> Audit.add(description: "Deleted organization pre-flight checks")
    |> Audit.add(resource_id: conn.assigns.organization_id)
    |> Audit.metadata(requester_id: conn.assigns.user_id)
    |> Audit.log()
  end

  #
  # Watchman callbacks
  #
  defp watchman_name(method, metrics), do: "#{@watchman_prefix}.#{method}.#{metrics}"
end
