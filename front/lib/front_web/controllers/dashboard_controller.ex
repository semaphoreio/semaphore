defmodule FrontWeb.DashboardController do
  use FrontWeb, :controller
  require Logger

  alias Front.{
    Async,
    Models,
    Widgets
  }

  plug(FrontWeb.Plugs.OrganizationAuthorization)
  plug(FrontWeb.Plugs.Header when action in [:index, :show])

  def index(conn, params) do
    Watchman.benchmark("dashboard_controller.index", fn ->
      dashboard = conn |> extract_preferred_dashboard

      dashboard = if should_force_get_started?(conn), do: "get-started", else: dashboard

      case dashboard do
        "get-started" ->
          conn
          |> redirect(to: get_started_index_path(conn, :index, []))

        "starred" ->
          conn
          |> render_starred_page(params)

        "organization-health" ->
          enabled? =
            FeatureProvider.feature_enabled?(:organization_health,
              param: conn.assigns.organization_id
            )

          if enabled? do
            conn
            |> render_org_health_page(params)
          else
            conn
            |> render_404()
          end

        _ ->
          conn
          |> render_other_pages(params)
      end
    end)
  end

  defp extract_preferred_dashboard(conn) do
    dashboards = ["everyones-activity", "my-work", "starred", "organization-health"]
    default_value = "my-work"

    if Enum.member?(dashboards, conn.params["dashboard"]) do
      conn.params["dashboard"]
    else
      conn.req_cookies["home-page-dashboard"] || default_value
    end
  end

  defp should_force_get_started?(conn) do
    dashboard_selected? = String.length(conn.params["dashboard"] || "") > 0

    get_started_enabled? =
      FeatureProvider.feature_enabled?(:get_started, param: conn.assigns.organization_id)

    if get_started_enabled? and not dashboard_selected? do
      learn = Front.Onboarding.Learn.load(conn.assigns.organization_id, conn.assigns.user_id)

      cond do
        learn.progress.is_skipped -> false
        learn.progress.is_finished -> false
        true -> true
      end
    else
      false
    end
  end

  defp params(conn, page_token, direction, filters, project_ids, org_id) do
    user_id = conn.assigns.user_id
    direction = map_workflow_direction(direction)

    # TMP solution
    seconds = Timex.now() |> Timex.shift(days: -7) |> Timex.to_unix()
    time = Google.Protobuf.Timestamp.new(seconds: seconds)

    [
      page_size: 10,
      page_token: page_token,
      direction: direction,
      created_after: time,
      project_ids: project_ids,
      organization_id: org_id
    ]
    |> inject_requester(filters.requester, user_id)
  end

  defp inject_requester(keywords, false, _), do: keywords

  defp inject_requester(keywords, true, requester_id),
    do: Keyword.merge(keywords, requester_id: requester_id)

  defp map_workflow_direction("next"),
    do: InternalApi.PlumberWF.ListKeysetRequest.Direction.value(:NEXT)

  defp map_workflow_direction("previous"),
    do: InternalApi.PlumberWF.ListKeysetRequest.Direction.value(:PREVIOUS)

  defp map_workflow_direction(_), do: map_workflow_direction("next")

  def workflows(conn, params) do
    user_id = conn.assigns.user_id
    org_id = conn.assigns.organization_id
    page_token = params["page_token"] || ""
    direction = params["direction"] || ""
    requester = params["requester"] == "true"

    {:ok, project_ids} = Front.RBAC.Members.list_accessible_projects(org_id, user_id)

    filters = %{requester: requester}
    params = params(conn, page_token, direction, filters, project_ids, org_id)

    {workflows, next_page_token, previous_page_token} = list_workflows(params)

    previous = if previous_page_token != "", do: previous_page_token, else: nil
    next = if next_page_token != "", do: next_page_token, else: nil
    newest = if page_token == "", do: false, else: true
    visible = if previous != nil or next != nil, do: true, else: false

    pagination = %{
      visible: visible,
      newest: newest,
      previous: previous,
      next: next
    }

    pollman = %{
      state: "poll",
      href: "/workflows",
      params: [
        page_token: page_token,
        direction: direction,
        requester: requester,
        organization_id: org_id
      ]
    }

    conn
    |> put_layout(false)
    |> render(
      "partials/_workflows.html",
      workflows: workflows,
      pagination: pagination,
      pollman: pollman,
      page: :dashboard
    )
  end

  defp find_dashboard(name, org_id, user_id) do
    Models.Dashboard.find(name, org_id, user_id)
  end

  def show(conn, params) do
    Watchman.benchmark("dashboard.show.duration", fn ->
      user_id = conn.assigns.user_id
      org_id = conn.assigns.organization_id
      trace_id = conn.assigns.trace_id
      name = params["name"]

      from = params["from"] || ""
      to = params["to"] || ""

      Logger.info("Header info ---")
      Logger.info("User ID: #{user_id}")
      Logger.info("Org id: #{org_id}")
      Logger.info("---")

      fetch_dashboard = Async.run(fn -> find_dashboard(name, org_id, user_id) end)
      fetch_user = Async.run(fn -> find_user(user_id, trace_id) end)
      fetch_organization = Async.run(fn -> find_organization(org_id, trace_id) end)

      {:ok, dashboard} = Async.await(fetch_dashboard)
      {:ok, organization} = Async.await(fetch_organization)
      {:ok, user} = Async.await(fetch_user)

      case dashboard do
        nil ->
          conn |> render_404

        dashboard ->
          date_picker = Front.DatePicker.construct(from, to)

          widgets = fetch_widgets_data(dashboard, conn, date_picker)

          conn
          |> render(
            "show.html",
            js: :dashboard,
            organization: organization,
            user: user,
            title: "#{dashboard.name}・#{organization.name}",
            dashboard: dashboard,
            widgets: widgets,
            starred?: Models.User.has_favorite(user_id, org_id, dashboard.id),
            date_picker: date_picker,
            from: from,
            to: to
          )
      end
    end)
  end

  def poll(conn, params) do
    Watchman.benchmark("dashboard.poll.duration", fn ->
      user_id = conn.assigns.user_id
      org_id = conn.assigns.organization_id
      id = params["id"]
      index = extract_index(params)
      page_token = params["page_token"] || ""
      direction = params["direction"] || ""
      from = params["from"] || ""
      to = params["to"] || ""

      Logger.info("Header info ---")
      Logger.info("User ID: #{user_id}")
      Logger.info("Org id: #{org_id}")
      Logger.info("---")

      case Models.Dashboard.find(id, org_id, user_id) do
        nil ->
          conn |> render_404

        dashboard ->
          date_picker = Front.DatePicker.construct(from, to)

          widget =
            fetch_widget_data(
              dashboard,
              Enum.at(dashboard.widgets, index),
              index,
              conn,
              date_picker,
              page_token,
              direction
            )

          conn
          |> put_layout(false)
          |> render(
            "_widget.html",
            widget: widget,
            dashboard_id: id,
            from: from,
            to: to
          )
      end
    end)
  end

  defp fetch_widgets_data(dashboard, conn, date_picker) do
    alias Front.Utils

    Utils.parallel_map_with_index(dashboard.widgets, fn {w, idx} ->
      fetch_widget_data(dashboard, w, idx, conn, date_picker)
    end)
  end

  defp fetch_widget_data(
         dashboard,
         widget,
         idx,
         conn,
         date_picker,
         page_token \\ "",
         direction \\ ""
       ) do
    alias Front.Widgets

    ctx = %{
      org_id: conn.assigns.organization_id,
      user_id: conn.assigns.user_id,
      page_token: page_token,
      direction: direction,
      dashboard_id: dashboard.id,
      widget_idx: idx,
      from: date_picker.range.first,
      to: date_picker.range.last
    }

    type = widget |> Map.fetch!("type") |> map_widget_type()
    filters = widget |> Map.fetch!("filters")
    name = widget |> Map.fetch!("name")

    data = Widgets.Fetcher.fetch(type, filters, ctx)

    %{
      type: type,
      name: name,
      data: data
    }
  end

  defp map_widget_type("list"), do: "list_workflows"
  defp map_widget_type(type), do: type

  defp render_404(conn) do
    conn
    |> put_status(:not_found)
    |> put_layout(false)
    |> put_view(FrontWeb.ErrorView)
    |> render("404.html")
  end

  def chart(conn, params) do
    Watchman.benchmark("dashboard.chart.duration", fn ->
      user_id = conn.assigns.user_id
      org_id = conn.assigns.organization_id
      id = params["id"]
      index = params["index"] |> Integer.parse() |> elem(0)

      from = params["from"] || ""
      to = params["to"] || ""

      Logger.info("Header info ---")
      Logger.info("User ID: #{user_id}")
      Logger.info("Org id: #{org_id}")
      Logger.info("---")

      case Models.Dashboard.find(id, org_id, user_id) do
        nil ->
          conn
          |> put_status(404)
          |> json(%{error: "Widget can not be found!"})

        dashboard ->
          date_picker = Front.DatePicker.construct(from, to)

          widget =
            dashboard.widgets
            |> decorate_widgets(
              user_id,
              org_id,
              dashboard,
              index,
              nil,
              nil,
              date_picker.range.first,
              date_picker.range.last
            )

          conn
          |> json(widget)
      end
    end)
  end

  defp extract_index(params) do
    if Map.has_key?(params, "index") do
      params["index"] |> Integer.parse() |> elem(0)
    else
      nil
    end
  end

  # credo:disable-for-next-line
  defp decorate_widgets(
         widgets,
         user_id,
         org_id,
         dashboard,
         nil,
         _page,
         _page_size,
         from,
         to
       ) do
    Watchman.benchmark("construct_widgets.duration", fn ->
      widgets
      |> Enum.map(fn widget -> Widgets.Factory.create(widget) end)
      |> Enum.map(fn widget ->
        Widgets.Fetcher.fetch(
          widget,
          dashboard,
          nil,
          user_id,
          org_id,
          nil,
          nil,
          from,
          to
        )
      end)
    end)
  end

  # credo:disable-for-next-line
  defp decorate_widgets(
         widgets,
         user_id,
         org_id,
         dashboard,
         index,
         page,
         page_size,
         from,
         to
       ) do
    Watchman.benchmark("construct_widget.duration", fn ->
      widgets
      |> Enum.at(index)
      |> Widgets.Factory.create()
      |> Widgets.Fetcher.fetch(
        dashboard,
        index,
        user_id,
        org_id,
        page,
        page_size,
        from,
        to
      )
    end)
  end

  defp find_user(user_id, trace_id) do
    Front.Tracing.track(trace_id, :fetch_user, fn ->
      Models.User.find(user_id)
    end)
  end

  defp find_organization(org_id, trace_id) do
    Front.Tracing.track(trace_id, :fetch_org, fn ->
      Models.Organization.find(org_id)
    end)
  end

  defp list_workflows(params) do
    if params[:project_ids] == [] do
      {[], "", ""}
    else
      {wfs, next_page_token, previous_page_token} =
        Watchman.benchmark("home_page.list_keyset", fn ->
          Models.Workflow.list_keyset(params)
        end)

      workflows =
        Watchman.benchmark("home_page.decorate_workflows", fn ->
          Front.Decorators.Workflow.decorate_many(wfs)
        end)

      {workflows, next_page_token, previous_page_token}
    end
  end

  defp render_org_health_page(conn, params) do
    Watchman.increment("velocity.organization_health_page.hit")
    user = conn.assigns.layout_model.user
    organization = conn.assigns.layout_model.current_organization

    dashboard = conn |> extract_preferred_dashboard
    starred_items = conn.assigns.layout_model.starred_items

    signup = params["signup"]
    notice = conn |> get_flash(:notice)

    conn
    |> put_resp_cookie("home-page-dashboard", dashboard, secure: true)
    |> render("index.html",
      organization: organization,
      user: user,
      title: "Semaphore・#{organization.name}",
      social_metatags: true,
      starred_items: starred_items,
      signup: signup,
      notice: notice,
      dashboard: dashboard,
      js: :organization_health_tab,
      layout: {FrontWeb.LayoutView, "dashboard.html"}
    )
  end

  defp render_starred_page(conn, params) do
    user = conn.assigns.layout_model.user
    organization = conn.assigns.layout_model.current_organization

    dashboard = conn |> extract_preferred_dashboard
    starred_items = conn.assigns.layout_model.starred_items

    signup = params["signup"]
    notice = conn |> get_flash(:notice)

    conn
    |> put_resp_cookie("home-page-dashboard", dashboard, secure: true)
    |> render(
      "index.html",
      organization: organization,
      user: user,
      title: "Semaphore・#{organization.name}",
      social_metatags: true,
      starred_items: starred_items,
      signup: signup,
      notice: notice,
      dashboard: dashboard,
      layout: {FrontWeb.LayoutView, "dashboard.html"}
    )
  end

  defp render_other_pages(conn, params) do
    user = conn.assigns.layout_model.user
    organization = conn.assigns.layout_model.current_organization

    dashboard = conn |> extract_preferred_dashboard
    page_token = params["page_token"] || ""
    direction = params["direction"] || ""
    starred_items = conn.assigns.layout_model.starred_items

    signup = params["signup"]
    notice = conn |> get_flash(:notice)

    filters = %{requester: dashboard == "my-work"}
    user_id = conn.assigns.user_id
    org_id = conn.assigns.organization_id

    {:ok, project_ids} =
      Watchman.benchmark("home_page.list_project_ids", fn ->
        Front.RBAC.Members.list_accessible_projects(org_id, user_id)
      end)

    params = params(conn, page_token, direction, filters, project_ids, org_id)

    {workflows, next_page_token, previous_page_token} =
      Watchman.benchmark("home_page.list_workflows", fn ->
        list_workflows(params)
      end)

    previous = if previous_page_token != "", do: previous_page_token, else: nil
    next = if next_page_token != "", do: next_page_token, else: nil
    newest = if page_token == "", do: false, else: true
    visible = if previous != nil or next != nil, do: true, else: false

    pagination = %{
      visible: visible,
      newest: newest,
      previous: previous,
      next: next
    }

    pollman = %{
      state: "poll",
      href: "/workflows",
      params: [
        page_token: page_token,
        direction: direction,
        requester: filters.requester,
        organization_id: org_id
      ]
    }

    conn
    |> put_resp_cookie("home-page-dashboard", dashboard, secure: true)
    |> render(
      "index.html",
      js: :me_page,
      organization: organization,
      user: user,
      starred_items: starred_items,
      title: "Semaphore・#{organization.name}",
      social_metatags: true,
      workflows: workflows,
      pagination: pagination,
      pollman: pollman,
      signup: signup,
      notice: notice,
      dashboard: dashboard,
      layout: {FrontWeb.LayoutView, "dashboard.html"}
    )
  end
end
