defmodule FrontWeb.GitIntegrationView do
  require Logger
  use FrontWeb, :view

  def json_config(conn) do
    config = conn.assigns.integrations_config

    %{
      "baseUrl" => git_integration_path(conn, :show, []),
      "orgId" => conn.assigns.org_id,
      "orgUsername" => conn.assigns.organization_username,
      "integrations" => config.integrations |> Enum.map(&format_integration(conn, &1)),
      "newIntegrations" => config.new_integrations |> Enum.map(&format_new_integration(conn, &1)),
      "csrfTokenCookieKey" => conn.assigns.csrf_token_cookie_key,
      "domain" => Application.get_env(:front, :domain)
    }
    |> Poison.encode!()
  end

  defp format_integration(conn, %{
         type: :CONFIG_TYPE_GITHUB_APP,
         fields: github_app,
         instruction_fields: manifest,
         state: state
       }),
       do: %{
         "appName" => github_app["slug"],
         "appId" => github_app["app_id"],
         "name" => github_app["name"],
         "deleteUrl" =>
           git_integration_path(conn, :delete, [config_type_to_type(:CONFIG_TYPE_GITHUB_APP)]),
         "updateUrl" =>
           git_integration_path(conn, :update, [config_type_to_type(:CONFIG_TYPE_GITHUB_APP)]),
         "connectionStatus" => connection_status(state),
         "description" => "GitHub Cloud integration through installed GitHub App.",
         "htmlUrl" => github_app["html_url"],
         "privateKeySignature" => key_signature(github_app["pem"]),
         "type" => "github_app",
         "manifest" => manifest(manifest)
       }

  defp format_integration(conn, %{
         type: :CONFIG_TYPE_GITLAB_APP,
         fields: _gitlab_app,
         instruction_fields: manifest,
         state: state
       }),
       do: %{
         "type" => "gitlab",
         "appName" => "Gitlab app",
         "description" => "Gitlab OAuth integration",
         "manifest" => manifest(manifest),
         "connectionStatus" => connection_status(state),
         "deleteUrl" =>
           git_integration_path(conn, :delete, [config_type_to_type(:CONFIG_TYPE_GITLAB_APP)]),
         "updateUrl" =>
           git_integration_path(conn, :update, [config_type_to_type(:CONFIG_TYPE_GITLAB_APP)])
       }

  defp format_integration(conn, %{
         type: :CONFIG_TYPE_BITBUCKET_APP,
         fields: _bitbucket_app,
         instruction_fields: manifest,
         state: state
       }),
       do: %{
         "type" => "bitbucket",
         "appName" => "Bitbucket app",
         "description" => "Bitbucket OAuth integration",
         "manifest" => manifest(manifest),
         "connectionStatus" => connection_status(state),
         "deleteUrl" =>
           git_integration_path(conn, :delete, [config_type_to_type(:CONFIG_TYPE_GITLAB_APP)]),
         "updateUrl" =>
           git_integration_path(conn, :update, [config_type_to_type(:CONFIG_TYPE_GITLAB_APP)])
       }

  defp format_new_integration(_conn, %{type: :CONFIG_TYPE_GITHUB_APP}) do
    %{
      "name" => "GitHub Cloud - GitHub App",
      "description" =>
        "Create and install a GitHub App on your cloud GitHub account. This is a fastest method with granular permission controlls.",
      "setupTime" => "1",
      "connectUrl" => connect_github_app_url(),
      "type" => "github_app"
    }
  end

  defp format_new_integration(conn, integration = %{type: :CONFIG_TYPE_GITLAB_APP}) do
    Logger.debug("Formatting new integration: #{inspect(integration)}")

    %{
      "name" => "Gitlab app",
      "description" => "Gitlab OAuth integration",
      "setupTime" => "3",
      "type" => "gitlab",
      "internalSetup" => true,
      "connectUrl" =>
        git_integration_path(conn, :update, [config_type_to_type(:CONFIG_TYPE_GITLAB_APP)]),
      "manifest" => manifest(integration.instruction_fields)
    }
  end

  defp format_new_integration(conn, integration = %{type: :CONFIG_TYPE_BITBUCKET_APP}) do
    Logger.debug("Formatting new integration: #{inspect(integration)}")

    %{
      "name" => "Bitbucket app",
      "description" => "Bitbucket OAuth integration",
      "setupTime" => "3",
      "type" => "bitbucket",
      "internalSetup" => true,
      "connectUrl" =>
        git_integration_path(conn, :update, [config_type_to_type(:CONFIG_TYPE_BITBUCKET_APP)]),
      "manifest" => manifest(integration.instruction_fields)
    }
  end

  defp config_type_to_type(:CONFIG_TYPE_GITHUB_APP), do: "github_app"
  defp config_type_to_type(:CONFIG_TYPE_GITLAB_APP), do: "gitlab"
  defp config_type_to_type(:CONFIG_TYPE_BITBUCKET_APP), do: "bitbucket"

  defp connection_status(:STATE_CONFIGURED), do: "connected"
  defp connection_status(:STATE_WITH_ERRORS), do: "error"

  defp connect_github_app_url do
    Application.get_env(:front, :connect_github_app_url)
  end

  defp key_signature(key) do
    ExPublicKey.loads(key)
    |> case do
      {:ok, key} ->
        "SHA256:" <>
          (key
           |> ExPublicKey.RSAPrivateKey.get_fingerprint()
           |> Base.decode16!(case: :lower)
           |> Base.encode64())

      {:error, _} ->
        "Invalid key"
    end
  end

  defp manifest(fields), do: fields
end
