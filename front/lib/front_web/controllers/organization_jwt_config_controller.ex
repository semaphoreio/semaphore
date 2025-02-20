defmodule FrontWeb.OrganizationJWTConfigController do
  @moduledoc false
  use FrontWeb, :controller
  alias Front.Async
  alias Front.Audit
  alias Front.Models.JWTConfig
  require Logger

  @read_permission "organization.general_settings.view"
  @read_actions ~w(show)a

  @write_permission "organization.general_settings.manage"
  @write_actions ~w(update)a

  @audit_actions ~w(Modified)a

  plug(FrontWeb.Plugs.FeatureEnabled, [:open_id_connect_filter])
  plug(FrontWeb.Plugs.FetchPermissions, scope: "org")
  plug(FrontWeb.Plugs.PageAccess, [permissions: @read_permission] when action in @read_actions)
  plug(FrontWeb.Plugs.PageAccess, [permissions: @write_permission] when action in @write_actions)
  plug(FrontWeb.Plugs.Header)

  plug(:put_layout, :organization_settings)

  @watchman_prefix "settings.jwt_claims.endpoint"

  def show(conn, _params) do
    Watchman.benchmark(watchman_name(:show, :duration), fn ->
      org_id = conn.assigns.organization_id
      user_id = conn.assigns.user_id

      {:ok, jwt_config} = Async.await(fetch_jwt_config_async(org_id, user_id))

      aws_tags_claim = Enum.find(jwt_config.claims, &(&1.name == "https://aws.amazon.com/tags"))

      render(conn, "index.html",
        jwt_config: jwt_config,
        aws_tags_claim: aws_tags_claim,
        title: "Organization OIDC Token Configuration",
        notice: get_flash(conn, :notice),
        alert: get_flash(conn, :alert)
      )
    end)
  end

  def update(conn, params) do
    Watchman.benchmark(watchman_name(:update, :duration), fn ->
      org_id = conn.assigns.organization_id
      user_id = conn.assigns.user_id

      # Get current config to update only changed values
      {:ok, current_config} = Async.await(fetch_jwt_config_async(org_id, user_id))

      # Update claims based on form data
      updated_claims =
        current_config.claims
        |> Enum.map(fn claim ->
          is_active =
            case params["claims"][claim.name]["is_active"] do
              "true" -> true
              _ -> claim.is_mandatory
            end

          %{claim | is_active: is_active}
        end)

      case JWTConfig.update(org_id, nil, current_config.is_active, updated_claims,
             user_id: user_id
           ) do
        {:ok, _} ->
          Watchman.increment(watchman_name(:update, :success))
          audit_log(conn, :Modified, org_id)

          conn
          |> put_flash(:notice, "OIDC Token configuration updated successfully")
          |> redirect(to: organization_jwt_config_path(conn, :show))

        {:error, reason} ->
          Logger.error("Failed to update OIDC Token config: #{inspect(reason)}")
          Watchman.increment(watchman_name(:update, :failure))

          conn
          |> put_flash(:alert, "Failed to update OIDC Token configuration")
          |> redirect(to: organization_jwt_config_path(conn, :show))
      end
    end)
  end

  defp fetch_jwt_config_async(organization_id, user_id),
    do:
      Async.run(fn ->
        case JWTConfig.get(organization_id, nil, user_id: user_id) do
          {:ok, config} -> config
          {:error, error} -> raise error
        end
      end)

  defp audit_log(conn, action, resource_id) when action in @audit_actions do
    conn
    |> Audit.new(:Organization, action)
    |> Audit.add(description: audit_desc(action))
    |> Audit.add(resource_id: resource_id)
    |> Audit.metadata(requester_id: conn.assigns.user_id)
    |> Audit.log()
  end

  defp audit_log(_conn, _action, _resource_id), do: :ok

  defp audit_desc(:Modified), do: "Modified OIDC Token Configuration"

  defp watchman_name(action, type),
    do: [@watchman_prefix, "#{action}", "#{type}"] |> Enum.join(".")
end
