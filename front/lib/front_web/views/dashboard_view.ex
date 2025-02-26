defmodule FrontWeb.DashboardView do
  use FrontWeb, :view

  def poll_state(pagination) do
    case pagination.current do
      "" -> "poll"
      1 -> "poll"
      _ -> "done"
    end
  end

  def get_started_enabled?(conn) do
    organization_id = conn.assigns.organization_id

    FeatureProvider.feature_enabled?(
      :get_started,
      param: organization_id
    )
  end

  def show_get_started_tab?(conn) do
    user_id = conn.assigns.user_id
    organization_id = conn.assigns.organization_id

    enabled? = get_started_enabled?(conn)

    learn = if enabled?, do: Front.Onboarding.Learn.load(organization_id, user_id), else: nil

    cond do
      not enabled? -> false
      learn.progress.is_skipped -> false
      learn.progress.is_finished -> false
      true -> true
    end
  end

  def navigation_element_style(link_name, highlighted_element) do
    link_name_atom =
      link_name
      |> String.downcase()
      |> String.replace(" ", "_")
      |> String.to_atom()

    if link_name_atom == highlighted_element do
      "tab-active"
    end
  end

  def domain do
    Application.get_env(:front, :domain)
  end

  def star_tippy_content(true), do: "Unstar Dashboard"
  def star_tippy_content(false), do: "Star Dashboard"

  def workflow_widget_title(workflow) do
    case workflow.type do
      "tag" -> workflow.tag_name
      "pr" -> workflow.hook_name
      "branch" -> workflow.branch_name
    end
  end

  def json_config(conn) do
    conn
    |> config
    |> Poison.encode!()
  end

  defp config(conn) do
    %{
      baseUrl: dashboard_path(conn, :index, dashboard: "organization-health"),
      organizationHealthUrl: organization_health_index_path(conn, :index, []),
      dateRange: Front.DateRangeGenerator.construct()
    }
  end
end
