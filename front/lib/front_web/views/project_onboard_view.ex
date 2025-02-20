defmodule FrontWeb.ProjectOnboardingView do
  use FrontWeb, :view

  def json_config_bootstrap(conn) do
    %{
      "baseUrl" =>
        project_onboarding_path(conn, :onboarding_index, conn.assigns.name_or_id, [""]),
      "stage" => conn.assigns.stage,
      "user" => conn.assigns.user,
      "project" => conn.assigns.project,
      "projectUrl" => project_path(conn, :show, conn.assigns.project.name),
      "updateProjectUrl" =>
        project_onboarding_path(
          conn,
          :update_project_initial_pipeline_file,
          conn.assigns.project.name
        ),
      "skipOnboardingUrl" =>
        project_onboarding_path(conn, :skip_onboarding, conn.assigns.project.name),
      "userProfileUrl" => people_path(conn, :show, conn.assigns.user.id),
      "domain" => Application.get_env(:front, :domain),
      "hasPipeline" => conn.assigns.has_pipeline_file?,
      # "agentStats" => conn.assigns.agent_stats,
      "agentTypes" => %{
        "cloud" => conn.assigns.cloud_agents,
        "selfHosted" =>
          conn.assigns.self_hosted_agents |> Enum.map(fn agent -> %{type: agent.name} end)
      },
      "templates" => Front.Templates.load_all(true),
      "templatesSetup" => Front.Templates.setup(),
      "checkWorkflowUrl" => project_path(conn, :check_workflow, conn.assigns.project.name),
      "commitStarterTemplatesUrl" =>
        project_onboarding_path(conn, :commit_starter_template, conn.assigns.project.name),
      "workflowBuilderUrl" =>
        x_workflow_builder_path(conn, :x_workflow_builder, conn.assigns.project.name),
      "createSelfHostedAgentUrl" => agents_index_path(conn, :index, ["self_hosted", "new"], [])
    }
    |> Poison.encode!()
  end

  def json_config(conn) do
    scope_modification_urls = %{
      github_app: [
        %{
          url: github_app_update_scope_path(conn, :github_app),
          title: "Connect account",
          description: "We need access to your GitHub account to show you repositories"
        }
      ],
      github_oauth_token: [
        %{
          url: github_update_scope_path(conn, :github, access_level: :public),
          title: "Public repositories",
          description: "Import only my public repositories"
        },
        %{
          url: github_update_scope_path(conn, :github, access_level: :private),
          title: "All repositories",
          description: "Import my public &amp; private repositories"
        }
      ],
      bitbucket: [
        %{
          url: bitbucket_update_scope_path(conn, :bitbucket),
          title: "All repositories",
          description: "Import my public &amp; private repositories"
        }
      ],
      gitlab: [
        %{
          url: gitlab_update_scope_path(conn, :gitlab),
          title: "All repositories",
          description: "Import my public &amp; private repositories"
        }
      ]
    }

    %{
      "baseUrl" => project_onboarding_path(conn, :index, []),
      "duplicateCheckUrl" => project_onboarding_path(conn, :check_duplicates, []),
      "createProjectUrl" => project_onboarding_path(conn, :create, []),
      "user" => conn.assigns.user,
      "userProfileUrl" => people_path(conn, :show, conn.assigns.user.id),
      "providers" =>
        conn.assigns.providers
        |> Enum.map(&format_provider(conn).(&1)),
      "primaryProvider" => %{
        "type" => conn.assigns.primary_provider |> Atom.to_string() |> String.downcase()
      },
      "scopeUrls" => scope_modification_urls,
      "githubAppInstallationUrl" =>
        "#{Front.GithubApp.app_url()}/installations/new?state=o_#{conn.assigns.org_id}",
      "setupIntegrationUrl" =>
        git_integration_path(conn, :show, [],
          redirect_to: project_onboarding_path(conn, :index, [])
        ),
      "repositoriesUrl" => project_onboarding_path(conn, :repositories),
      "domain" => Application.get_env(:front, :domain)
    }
    |> Poison.encode!()
  end

  def format_provider(conn) do
    fn provider ->
      %{
        "type" => provider |> Atom.to_string() |> String.downcase(),
        "status" => status(conn.assigns.instance_configs, provider),
        "scopeUpdate" => scope_url(conn, provider)
      }
    end
  end

  defp status([], _provider), do: nil

  defp status(instance_configs, provider) do
    case Map.get(instance_configs, provider) do
      nil -> connection_status(:STATE_EMPTY)
      config -> connection_status(config.state)
    end
  end

  defp scope_url(conn, :GITHUB_APP),
    do: %{url: github_app_update_scope_path(conn, :github_app), method: :post}

  defp scope_url(conn, :GITHUB_OAUTH_TOKEN),
    do: %{url: github_update_scope_path(conn, :github), method: :post}

  defp scope_url(conn, :BITBUCKET),
    do: %{url: bitbucket_update_scope_path(conn, :bitbucket), method: :post}

  defp scope_url(conn, :GITLAB),
    do: %{url: gitlab_update_scope_path(conn, :gitlab), method: :post}

  defp connection_status(:STATE_CONFIGURED), do: "connected"
  defp connection_status(:STATE_EMPTY), do: "not_connected"
  defp connection_status(:STATE_WITH_ERRORS), do: "not_connected"
end
