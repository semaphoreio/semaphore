defmodule FrontWeb.GitIntegrationController do
  use FrontWeb, :controller

  require Logger

  plug(FrontWeb.Plugs.FetchPermissions, scope: "org")
  plug(FrontWeb.Plugs.PageAccess, permissions: "organization.instance_git_integration.manage")
  plug(FrontWeb.Plugs.Header when action in [:show, :new, :create])
  plug(:put_layout, :organization_settings)
  plug(FrontWeb.Plugs.CacheControl, :no_cache)
  plug(:authorize_feature)

  @available_integrations [
    :CONFIG_TYPE_GITHUB_APP,
    :CONFIG_TYPE_BITBUCKET_APP,
    :CONFIG_TYPE_GITLAB_APP
  ]
  @csrf_token_cookie_key "github_app_state"

  def show(conn, _params) do
    Watchman.benchmark("git_integration.show.duration", fn ->
      notice = extract_notice(conn.params)
      org_id = conn.assigns.organization_id
      bitbucket_enabled? = FeatureProvider.feature_enabled?(:bitbucket, param: org_id)
      gitlab_enabled? = FeatureProvider.feature_enabled?(:gitlab, param: org_id)

      integrations =
        @available_integrations
        |> Enum.filter(fn
          :CONFIG_TYPE_BITBUCKET_APP -> bitbucket_enabled?
          :CONFIG_TYPE_GITLAB_APP -> gitlab_enabled?
          :CONFIG_TYPE_GITHUB_APP -> true
        end)

      Front.Models.InstanceConfig.list_integrations(integrations, secrets: true)
      |> case do
        {:ok, integrations} ->
          integration_configs =
            integrations
            |> flatten_and_format_integrations()

          render_show_page(conn, integration_configs, notice)

        {:error, error} ->
          Logger.error("Failed to fetch integration configurations: #{inspect(error)}")

          conn
          |> put_flash(:error, "Failed to fetch integration configurations.")
          |> render_show_page(empty_integrations(), notice)
      end
    end)
  end

  def delete(conn, params) do
    Watchman.benchmark("git_integration.delete.duration", fn ->
      Logger.info("Deleting integration: #{inspect(params)}")

      Front.Models.InstanceConfig.modify_integration(
        type_to_config_type(params["type"]),
        :STATE_EMPTY,
        []
      )
      |> case do
        :ok ->
          Logger.info("Integration deleted successfully.")

          conn
          |> put_flash(:notice, "Integration deleted successfully.")
          |> redirect(to: git_integration_path(conn, :show, []))

        {:error, error} ->
          Logger.error("Failed to delete integration: #{inspect(error)}")

          conn
          |> put_flash(:error, "Failed to delete integration.")
          |> redirect(to: git_integration_path(conn, :show, []))
      end
    end)
  end

  def update(conn, params) do
    Watchman.benchmark("git_integration.update.duration", fn ->
      Logger.debug("Updating integration: #{inspect(params)}")
      type = params["path"] |> List.first()

      redirect_to = params["redirect_to"]

      # filter known params only
      params =
        Map.take(params, [
          "app_id",
          "slug",
          "name",
          "html_url",
          "pem",
          "webhook_secret",
          "client_id",
          "client_secret"
        ])

      Front.Models.InstanceConfig.modify_integration(
        type_to_config_type(type),
        :STATE_CONFIGURED,
        params
      )
      |> case do
        :ok ->
          Logger.info("Integration updated successfully.")

          redirect_to = redirect_to || git_integration_path(conn, :show, [type])

          conn
          |> put_flash(:notice, "Integration updated successfully.")
          |> redirect(to: redirect_to)

        {:error, error} ->
          Logger.error("Failed to update integration: #{inspect(error)}")

          conn
          |> put_flash(:error, "Failed to update integration.")
          |> redirect(to: git_integration_path(conn, :show, [type]))
      end
    end)
  end

  defp extract_notice(params) do
    case params["notice"] do
      nil -> nil
      notice -> notice
    end
  end

  defp empty_integrations do
    %{integrations: [], new_integrations: []}
  end

  defp flatten_and_format_integrations(integrations) do
    integrations
    |> Enum.reduce(%{integrations: [], new_integrations: []}, &integration_reducer/2)
  end

  defp integration_reducer(integration = %{state: state}, acc)
       when state in [:STATE_CONFIGURED, :STATE_WITH_ERRORS] do
    %{acc | integrations: [integration | acc.integrations]}
  end

  defp integration_reducer(integration = %{state: state}, acc)
       when state in [:STATE_UNSPECIFIED, :STATE_EMPTY] do
    %{acc | new_integrations: [integration | acc.new_integrations]}
  end

  defp type_to_config_type("github_app"), do: :CONFIG_TYPE_GITHUB_APP
  defp type_to_config_type("gitlab"), do: :CONFIG_TYPE_GITLAB_APP
  defp type_to_config_type("bitbucket"), do: :CONFIG_TYPE_BITBUCKET_APP

  defp authorize_feature(conn, _opts) do
    case feature_state(conn) do
      :enabled -> conn
      :zero_state -> render_zero_page(conn)
      :hidden -> render_404(conn)
    end
  end

  defp feature_state(conn) do
    feature_type = :instance_git_integration
    org_id = conn.assigns[:organization_id]

    cond do
      FeatureProvider.feature_enabled?(feature_type, param: org_id) -> :enabled
      FeatureProvider.feature_zero_state?(feature_type, param: org_id) -> :zero_state
      true -> :hidden
    end
  end

  defp render_show_page(conn, integrations_config, notice) do
    render(
      conn,
      "show.html",
      notice: notice,
      integrations_config: integrations_config,
      org_id: conn.assigns.organization_id,
      csrf_token_cookie_key: @csrf_token_cookie_key,
      js: :gitIntegration
    )
  end

  defp render_zero_page(conn) do
    render(
      conn,
      "show.html",
      notice: nil,
      integrations_config: empty_integrations(),
      org_id: conn.assigns.organization_id,
      csrf_token_cookie_key: @csrf_token_cookie_key,
      js: :gitIntegration
    )
  end

  defp render_404(conn) do
    conn
    |> FrontWeb.PageController.status404(%{})
    |> Plug.Conn.halt()
  end
end
