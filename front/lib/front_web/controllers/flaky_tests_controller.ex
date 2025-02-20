# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule FrontWeb.FlakyTestsController do
  use FrontWeb, :controller
  import Plug.Conn
  require Logger

  alias FrontWeb.Plugs

  alias Front.{
    Audit,
    Breadcrumbs,
    Models,
    ProjectPage
  }

  plug(Plugs.ProjectAuthorization)

  plug(
    Plugs.Header
    when action in [:index]
  )

  plug(FrontWeb.Plugs.FeatureEnabled, [:superjerry_tests])

  def index(conn, params) do
    model = fetch_project_page_model(conn, params)

    # Increment the hit count for the test explorer index page if the user is not a super admin
    unless is_insider?(conn) do
      Watchman.increment(
        {"test_explorer.index.hit",
         [
           model.organization.name,
           model.project.name
         ]}
      )
    end

    assigns =
      %{
        js: :flaky_tests_tab,
        project: model.project,
        organization: model.organization,
        title: "#{model.project.name}・#{model.organization.name}",
        notice: get_flash(conn, :notice),
        layout: {FrontWeb.LayoutView, "project.html"},
        starred?: is_starred?(conn, params)
      }
      |> Breadcrumbs.Project.construct(conn, :flaky_tests)

    conn
    |> render("index.html", assigns)
  end

  def flaky_tests(conn, params) do
    org_id = conn.assigns.organization_id
    project_id = conn.assigns.project.id

    page = params["page"] || "1"
    page_size = params["page_size"] || "20"
    sort_field = params["sort_field"] || "total_disruptions_count"
    sort_dir = params["sort_dir"] || "desc"
    query = params["query"] || ""

    filters = URI.decode(query)

    case Front.Superjerry.list_flaky_tests(
           org_id,
           project_id,
           page,
           page_size,
           sort_field,
           sort_dir,
           filters
         ) do
      {:ok, {flaky_tests, pagination}} ->
        conn
        |> put_resp_header("X-TOTAL-PAGES", pagination.total_pages)
        |> put_resp_header("X-TOTAL-RESULTS", pagination.total_results)
        |> render("flaky_tests.json", flaky_tests: flaky_tests)

      {:error, message} ->
        json(conn, %{message: message})
    end
  end

  def flaky_test_details(conn, params) do
    org_id = conn.assigns.organization_id
    project_id = conn.assigns.project.id
    test_id = params["test_id"] || ""
    query = params["query"] || ""

    filters = URI.decode(query)

    case Front.Superjerry.flaky_test_details(
           org_id,
           project_id,
           test_id,
           filters
         ) do
      {:ok, flaky_test_details} ->
        json(conn, flaky_test_details)

      {:error, message} ->
        json(conn, %{message: message})
    end
  end

  def flaky_test_disruptions(conn, params = %{"test_id" => test_id}) do
    org_id = conn.assigns.organization_id
    project_id = conn.assigns.project.id
    page = params["page"] || "1"
    page_size = params["page_size"] || "10"
    query = params["query"] || ""

    filters = URI.decode(query)

    case Front.Superjerry.flaky_test_disruptions(
           org_id,
           project_id,
           test_id,
           page,
           page_size,
           filters
         ) do
      {:ok, {flaky_test_disruptions, pagination}} ->
        conn
        |> put_resp_header("X-TOTAL-PAGES", pagination.total_pages)
        |> put_resp_header("X-TOTAL-RESULTS", pagination.total_results)
        |> json(flaky_test_disruptions)

      {:error, message} ->
        json(conn, %{message: message})
    end
  end

  def disruption_history(conn, params) do
    org_id = conn.assigns.organization_id
    project_id = conn.assigns.project.id
    query = params["query"] || ""

    filters = URI.decode(query)

    case Front.Superjerry.list_disruption_history(org_id, project_id, filters) do
      {:ok, disruption_history} ->
        render(conn, "disruptions_history.json", historical: disruption_history)

      {:error, message} ->
        json(conn, %{message: message})
    end
  end

  def flaky_history(conn, params) do
    org_id = conn.assigns.organization_id
    project_id = conn.assigns.project.id
    query = params["query"] || ""

    filters = URI.decode(query)

    case Front.Superjerry.list_flaky_history(org_id, project_id, filters) do
      {:ok, flaky_history} ->
        render(conn, "flaky_history.json", historical: flaky_history)

      {:error, message} ->
        json(conn, %{message: message})
    end
  end

  def filters(conn, _params) do
    project_id = conn.assigns.project.id
    org_id = conn.assigns.organization_id

    case Models.TestExplorer.FlakyTestsFilter.filters(org_id, project_id) do
      {:ok, response} ->
        render(conn, "filters.json", filters: response.filters)

      {:error, message} ->
        json(conn, %{message: message})
    end
  end

  def create_filter(conn, params) do
    project_id = conn.assigns.project.id
    org_id = conn.assigns.organization_id
    user_id = conn.assigns.user_id
    filter = Map.get(params, "filter", "")

    resource_name = Map.get(filter, "name", "missing name")

    case Models.TestExplorer.FlakyTestsFilter.create_filter(org_id, project_id, filter) do
      {:ok, response} ->
        conn
        |> Audit.new(:FlakyTests, :Added)
        |> Audit.add(resource_name: resource_name)
        |> Audit.add(description: "Filter created")
        |> Audit.metadata(project_id: project_id)
        |> Audit.metadata(user_id: user_id)
        |> Audit.log()

        render(conn, "filter.json", filter: response.filter)

      {:error, message} ->
        conn
        |> put_status(:bad_request)
        |> json(%{message: message})
    end
  end

  def remove_filter(conn, params) do
    filter_id = params["filter_id"]
    project_id = conn.assigns.project.id
    user_id = conn.assigns.user_id

    case Models.TestExplorer.FlakyTestsFilter.remove_filter(filter_id) do
      {:ok, _} ->
        conn
        |> Audit.new(:FlakyTests, :Removed)
        |> Audit.add(resource_id: filter_id)
        |> Audit.add(description: "Filter removed")
        |> Audit.metadata(project_id: project_id)
        |> Audit.metadata(user_id: user_id)
        |> Audit.log()

        send_resp(conn, :no_content, "")

      {:error, message} ->
        conn
        |> put_status(:bad_request)
        |> json(%{message: message})
    end
  end

  def update_filter(conn, params) do
    filter = Map.get(params, "filter", "")
    id = Map.get(params, "filter_id", "missing filter")
    project_id = conn.assigns.project.id
    user_id = conn.assigns.user_id

    resource_name = Map.get(filter, "name", "")

    case Models.TestExplorer.FlakyTestsFilter.update_filter(id, filter) do
      {:ok, response} ->
        conn
        |> Audit.new(:FlakyTests, :Modified)
        |> Audit.add(resource_name: resource_name)
        |> Audit.add(resource_id: id)
        |> Audit.add(description: "Filter modified")
        |> Audit.metadata(project_id: project_id)
        |> Audit.metadata(user_id: user_id)
        |> Audit.log()

        json(conn, %{filter: response.filter})

      err ->
        conn
        |> put_status(:bad_request)
        |> json(%{message: err.message})
    end
  end

  def add_label(conn, _params = %{"test_id" => test_id, "label" => label}) do
    org_id = conn.assigns.organization_id
    project_id = conn.assigns.project.id
    user_id = conn.assigns.user_id

    case Front.Superjerry.add_label(org_id, project_id, test_id, label) do
      {:ok, response} ->
        conn
        |> Audit.new(:FlakyTests, :Added)
        |> Audit.add(resource_name: label)
        |> Audit.add(description: "Label added")
        |> Audit.metadata(project_id: project_id)
        |> Audit.metadata(user_id: user_id)
        |> Audit.log()

        json(conn, %{label: response})

      {:error, message} ->
        conn
        |> put_status(:bad_request)
        |> json(%{message: message})
    end
  end

  def remove_label(conn, _params = %{"test_id" => test_id, "label" => label}) do
    org_id = conn.assigns.organization_id
    project_id = conn.assigns.project.id
    user_id = conn.assigns.user_id

    case Front.Superjerry.remove_label(org_id, project_id, test_id, label) do
      {:ok, _} ->
        conn
        |> Audit.new(:FlakyTests, :Removed)
        |> Audit.add(resource_name: label)
        |> Audit.add(description: "Label removed")
        |> Audit.metadata(project_id: project_id)
        |> Audit.metadata(user_id: user_id)
        |> Audit.log()

        send_resp(conn, :no_content, "")

      {:error, message} ->
        conn
        |> put_status(:bad_request)
        |> json(%{message: message})
    end
  end

  def resolve(conn, _params = %{"test_id" => test_id}) do
    call_action(conn, "resolved", test_id, &Front.Superjerry.resolve/4)
  end

  def undo_resolve(conn, _params = %{"test_id" => test_id}) do
    call_action(conn, "unresolved", test_id, &Front.Superjerry.undo_resolve/4)
  end

  defp call_action(conn, type, test_id, action_fun) do
    project_id = conn.assigns.project.id
    user_id = conn.assigns.user_id
    org_id = conn.assigns.organization_id

    case action_fun.(org_id, project_id, test_id, user_id) do
      {:ok, response} ->
        conn
        |> Audit.new(:FlakyTests, :Modified)
        |> Audit.add(resource_id: test_id)
        |> Audit.add(description: "test marked as #{type}")
        |> Audit.metadata(project_id: project_id)
        |> Audit.metadata(user_id: user_id)
        |> Audit.metadata(action: type)
        |> Audit.log()

        json(conn, %{action: response})

      {:error, message} ->
        conn
        |> put_status(:bad_request)
        |> json(%{message: message})
    end
  end

  def save_ticket_url(conn, params = %{"test_id" => test_id}) do
    project_id = conn.assigns.project.id
    ticket_url = params["ticket_url"] || ""
    user_id = conn.assigns.user_id
    org_id = conn.assigns.organization_id

    case Front.Superjerry.save_ticket_url(org_id, project_id, test_id, ticket_url, user_id) do
      {:ok, response} ->
        conn
        |> Audit.new(:FlakyTests, :Modified)
        |> Audit.add(resource_id: test_id)
        |> Audit.add(description: "test ticket url modified")
        |> Audit.metadata(ticket_url: ticket_url)
        |> Audit.metadata(project_id: project_id)
        |> Audit.metadata(user_id: user_id)
        |> Audit.log()

        json(conn, %{ticket_url: response})

      {:error, message} ->
        conn
        |> put_status(:bad_request)
        |> json(%{message: message})
    end
  end

  def initialize_filters(conn, _params) do
    project_id = conn.assigns.project.id
    org_id = conn.assigns.organization_id
    user_id = conn.assigns.user_id

    case Models.TestExplorer.FlakyTestsFilter.initialize_filters(org_id, project_id) do
      {:ok, response} ->
        conn
        |> Audit.new(:FlakyTests, :Added)
        |> Audit.add(resource_name: "Filters")
        |> Audit.add(description: "Default Filters initialized")
        |> Audit.metadata(user_id: user_id)
        |> Audit.metadata(project_id: project_id)
        |> Audit.log()

        render(conn, "filters.json", filters: response.filters)

      {:error, message} ->
        json(conn, %{message: message})
    end
  end

  def webhook_settings(conn, _params) do
    project_id = conn.assigns.project.id
    org_id = conn.assigns.organization_id

    case Front.Superjerry.webhook_settings(org_id, project_id) do
      {:ok, response} ->
        conn
        |> json(%{webhook_settings: response})

      {:error, message} ->
        conn
        |> put_status(:bad_request)
        |> json(%{message: message})
    end
  end

  def create_webhook_settings(conn, _params) do
    project_id = conn.assigns.project.id
    org_id = conn.assigns.organization_id
    webhook_url = conn.body_params["webhook_url"] || ""
    branches = conn.body_params["branches"] || []
    enabled = Map.get(conn.body_params, "enabled", true)
    greedy = Map.get(conn.body_params, "greedy", true)
    user_id = conn.assigns.user_id

    if webhook_url == "" or !String.starts_with?(webhook_url, "https://") do
      conn
      |> put_status(:bad_request)
      |> json(%{message: "Webhook url must start with https://"})
      |> halt()
    else
      case Front.Superjerry.create_webhook_settings(
             org_id,
             project_id,
             webhook_url,
             branches,
             enabled,
             greedy
           ) do
        {:ok, response} ->
          conn
          |> Audit.new(:FlakyTests, :Added)
          |> Audit.add(resource_name: "Webhook Settings")
          |> Audit.add(description: "Webhook Settings Added")
          |> Audit.metadata(user_id: user_id)
          |> Audit.metadata(project_id: project_id)
          |> Audit.metadata(organization_id: org_id)
          |> Audit.metadata(webhook_url: webhook_url)
          |> Audit.metadata(enabled: enabled)
          |> Audit.metadata(branches: branches)
          |> Audit.log()

          json(conn, %{webhook_settings: response})

        {:error, message} ->
          conn
          |> put_status(:bad_request)
          |> json(%{message: message})
      end
    end
  end

  def update_webhook_settings(conn, _params) do
    project_id = conn.assigns.project.id
    org_id = conn.assigns.organization_id
    webhook_url = conn.body_params["webhook_url"] || ""
    branches = conn.body_params["branches"] || []
    enabled = Map.get(conn.body_params, "enabled", false)
    greedy = Map.get(conn.body_params, "greedy", false)
    user_id = conn.assigns.user_id

    if webhook_url == "" or !String.starts_with?(webhook_url, "https://") do
      conn
      |> put_status(:bad_request)
      |> json(%{message: "Webhook url must start with https://"})
      |> halt()
    else
      case Front.Superjerry.update_webhook_settings(
             org_id,
             project_id,
             webhook_url,
             branches,
             enabled,
             greedy
           ) do
        :ok ->
          conn
          |> Audit.new(:FlakyTests, :Modified)
          |> Audit.add(resource_name: "Webhook Settings")
          |> Audit.add(description: "Webhook settings modified")
          |> Audit.metadata(user_id: user_id)
          |> Audit.metadata(project_id: project_id)
          |> Audit.metadata(organization_id: org_id)
          |> Audit.metadata(webhook_url: webhook_url)
          |> Audit.metadata(enabled: enabled)
          |> Audit.log()

          send_resp(conn, :no_content, "")

        {:error, message} ->
          conn
          |> put_status(:bad_request)
          |> json(%{message: message})
      end
    end
  end

  def delete_webhook_settings(conn, _params) do
    project_id = conn.assigns.project.id
    org_id = conn.assigns.organization_id
    user_id = conn.assigns.user_id

    case Front.Superjerry.delete_webhook_settings(
           org_id,
           project_id
         ) do
      :ok ->
        conn
        |> Audit.new(:FlakyTests, :Removed)
        |> Audit.add(resource_name: "Webhook Settings")
        |> Audit.add(description: "Webhook settings removed")
        |> Audit.metadata(user_id: user_id)
        |> Audit.metadata(project_id: project_id)
        |> Audit.metadata(organization_id: org_id)
        |> Audit.log()

        send_resp(conn, :no_content, "")

      {:error, message} ->
        conn
        |> put_status(:bad_request)
        |> json(%{message: message})
    end
  end

  defp fetch_project_page_model(conn, params) do
    org_id = conn.assigns.organization_id
    user_id = conn.assigns.user_id
    project = conn.assigns.project

    params =
      struct!(
        ProjectPage.Model.LoadParams,
        project_id: project.id,
        organization_id: org_id,
        user_id: user_id,
        page_token: params["page_token"] || "",
        direction: params["direction"] || "",
        user_page?: false,
        ref_types: []
      )

    {:ok, model, _page_source} =
      params
      |> ProjectPage.Model.get(force_cold_boot: conn.params["force_cold_boot"])

    model
  end

  defp is_starred?(conn, _params) do
    org_id = conn.assigns.organization_id
    user_id = conn.assigns.user_id
    project = conn.assigns.project

    Front.Tracing.track(
      conn.assigns.trace_id,
      "check_if_project_is_starred",
      fn ->
        Watchman.benchmark(
          "project_page_check_star",
          fn ->
            Models.User.has_favorite(user_id, org_id, project.id)
          end
        )
      end
    )
  end

  @nil_uuid "00000000-0000-0000-0000-000000000000"
  defp is_insider?(conn),
    do: Front.RBAC.Permissions.has?(conn.assigns.user_id, @nil_uuid, "insider.view")
end
