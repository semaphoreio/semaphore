defmodule FrontWeb.BillingController do
  use FrontWeb, :controller
  require Logger
  alias Front.Models.Billing, as: BillingModel
  alias FrontWeb.Plugs.{FetchPermissions, PageAccess}

  plug(FrontWeb.Plugs.OnPremBlocker)

  plug(FetchPermissions, scope: "org")
  plug(PageAccess, permissions: "organization.view")

  plug(
    PageAccess,
    [permissions: "organization.plans_and_billing.manage"] when action == :set_budget
  )

  plug(
    PageAccess,
    [permissions: "organization.plans_and_billing.view"]
    when action in [:spending_csv, :projects_csv]
  )

  plug(:return_empty_json_if_unauthorized when action not in [:index])
  plug(:put_layout, :organization)
  plug(FrontWeb.Plugs.CacheControl, :no_cache)
  plug(FrontWeb.Plugs.Header)
  plug(:load_spendings, except: [:credits])
  plug(:load_budget, only: [:index])
  plug(:load_current_spending, only: [:index])
  plug(FrontWeb.Plugs.FeatureEnabled, [:new_billing])

  plug(
    FrontWeb.Plugs.FeatureEnabled,
    [:project_spendings] when action in [:project, :projects, :top_projects]
  )

  @top_projects_count 5

  def index(conn, _params) do
    conn
    |> assign(:js, :billingDashboard)
    |> assign(:title, "Plans & Billing・Semaphore")
    |> render("index.html", permissions: conn.assigns.permissions)
  end

  def seats(conn, _params) do
    seats = BillingModel.list_seats(conn.assigns.spending.id, get_opts(conn))

    conn
    |> json(%{
      seats: seats
    })
  end

  def costs(conn, _params) do
    costs = BillingModel.spending_report(conn.assigns.spending.id, get_opts(conn))

    conn
    |> json(%{
      costs: costs
    })
  end

  def invoices(conn, _params) do
    invoices = BillingModel.list_invoices(conn.assigns.organization_id, get_opts(conn))

    conn
    |> json(%{
      invoices: invoices
    })
  end

  def get_budget(conn, _params) do
    budget = BillingModel.get_budget(conn.assigns.organization_id, get_opts(conn))

    conn
    |> json(%{
      budget: budget
    })
  end

  def top_projects(conn, _params) do
    from_date = conn.assigns.spending.from
    to_date = conn.assigns.spending.to

    top_projects =
      BillingModel.list_projects(conn.assigns.organization_id, from_date, to_date, get_opts(conn))
      |> Enum.sort_by(
        fn project ->
          Money.parse!(project.cost.total_price)
        end,
        Money
      )
      |> Enum.take(@top_projects_count)
      |> Enum.map(fn project ->
        BillingModel.describe_project(project.id, from_date, to_date, get_opts(conn))
      end)

    conn
    |> json(top_projects)
  end

  def projects(conn, _params) do
    from_date = conn.assigns.spending.from
    to_date = conn.assigns.spending.to

    projects =
      BillingModel.list_projects(conn.assigns.organization_id, from_date, to_date, get_opts(conn))

    conn
    |> json(projects)
  end

  def project(conn, params) do
    from_date = conn.assigns.spending.from
    to_date = conn.assigns.spending.to

    selected_project =
      BillingModel.list_projects(conn.assigns.organization_id, from_date, to_date, get_opts(conn))
      |> Enum.find(&(&1.name == params["project_name"]))

    %{project: project, costs: costs} =
      BillingModel.describe_project(
        selected_project.id,
        from_date,
        to_date,
        get_opts(conn)
      )

    conn
    |> json(%{
      project: project,
      costs: costs
    })
  end

  def set_budget(conn, params) do
    defaults = %{
      "limit" => "0",
      "email" => ""
    }

    params =
      defaults
      |> Map.merge(params)
      |> Map.take(["limit", "email"])

    budget =
      BillingModel.update_budget(conn.assigns.organization_id, params["limit"], params["email"])

    conn
    |> json(%{
      budget: budget
    })
  end

  def spending_csv(conn, _params) do
    spending = conn.assigns.spending
    spending_csv = BillingModel.Spending.to_csv(spending)

    filename =
      spending.display_name
      |> String.downcase()
      |> String.replace(",", "")
      |> String.replace(" ", "")
      |> String.replace("-", "_")

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}.csv\"")
    |> put_root_layout(false)
    |> send_resp(200, spending_csv)
  end

  def projects_csv(conn, _params) do
    from_date = conn.assigns.spending.from
    to_date = conn.assigns.spending.to
    spending = conn.assigns.spending

    projects =
      BillingModel.list_projects(conn.assigns.organization_id, from_date, to_date, get_opts(conn))

    projects_csv = BillingModel.ProjectSpending.to_csv(projects)

    filename =
      spending.display_name
      |> String.downcase()
      |> String.replace(",", "")
      |> String.replace(" ", "")
      |> String.replace("-", "_")

    filename = "projects_#{filename}"

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}.csv\"")
    |> put_root_layout(false)
    |> send_resp(200, projects_csv)
  end

  def credits(conn, _params) do
    credits = BillingModel.get_credits(conn.assigns.organization_id, get_opts(conn))

    conn
    |> json(%{
      available: credits.available,
      balance: credits.balance
    })
  end

  def upgrade(conn, params) do
    org_id = conn.assigns.organization_id
    plan_slug = BillingModel.PlanSwitch.plan_type_to_slug(params["plan_type"])

    plan_upgrade = BillingModel.upgrade_plan(org_id, plan_slug)

    spending_id =
      plan_upgrade.spending_id
      |> case do
        spending_id when spending_id in [nil, ""] ->
          spending = BillingModel.current_spending(org_id, reload_cache?: true)
          spending.id

        spending_id ->
          BillingModel.current_spending(org_id, reload_cache?: true)
          BillingModel.list_spendings(org_id, reload_cache?: true)

          spending_id
      end

    status_code = if plan_upgrade.errors == [], do: 200, else: 422

    conn
    |> put_status(status_code)
    |> json(%{
      spending_id: spending_id,
      payment_method_url: plan_upgrade.payment_method_url,
      message: plan_upgrade.errors |> Enum.join(", ")
    })
  end

  def can_upgrade(conn, %{"plan_type" => plan_type}) do
    plan_type = String.to_existing_atom(plan_type)

    BillingModel.PlanSwitch.validate_plan_change(conn.assigns.organization_id, plan_type)
    |> case do
      :ok ->
        conn
        |> json(%{
          allowed: true
        })

      {:error, errors} ->
        formatted_errors =
          errors
          |> Enum.group_by(fn {key, _message} -> key end, fn {_, message} -> message end)

        conn
        |> put_status(422)
        |> json(%{
          allowed: false,
          errors: formatted_errors
        })
    end
  end

  def acknowledge_plan_change(conn, _params) do
    org_id = conn.assigns.organization_id

    {:ok, _} = Front.Clients.Billing.acknowledge_trial_end(%{org_id: org_id})

    conn
    |> json(%{})
  end

  defp get_opts(conn) do
    if conn.params["force_cold_boot"] do
      [reload_cache?: true]
    else
      []
    end
  end

  defp load_spendings(conn, _opts) do
    spendings = BillingModel.list_spendings(conn.assigns.organization_id, get_opts(conn))

    conn.params["spending_id"]
    |> case do
      spending_id when spending_id in [nil, ""] ->
        spendings
        |> case do
          [] -> :not_found
          [first_spending | _] -> first_spending
        end

      spending_id ->
        Enum.find(spendings, :not_found, &(&1.id == spending_id))
    end
    |> case do
      :not_found ->
        conn
        |> Front.Auth.render404()

      spending ->
        conn
        |> assign(:spending, spending)
        |> assign(:spendings, spendings)
    end
  end

  defp load_budget(conn, _opts) do
    organization_id = conn.assigns.organization_id
    organization = Front.Models.Organization.find(organization_id)

    owner_email =
      organization.owner_id
      |> Front.Models.User.find(nil, [:email])
      |> case do
        nil -> ""
        user -> user.email
      end

    budget = BillingModel.get_budget(organization_id, get_opts(conn))

    conn
    |> assign(:budget, %{budget | default_email: owner_email})
  end

  defp load_current_spending(conn, _opts) do
    organization_id = conn.assigns.organization_id

    cache_opts =
      if conn.params["force_cold_boot"] do
        [reload_cache?: true]
      else
        []
      end

    try do
      current_spending = BillingModel.current_spending(organization_id, cache_opts)
      assign(conn, :current_spending, current_spending)
    rescue
      e ->
        Logger.error("Error loading current spending for #{organization_id}: #{inspect(e)}")
        assign(conn, :current_spending, :none)
    end
  end

  defp return_empty_json_if_unauthorized(conn, _opts) do
    if conn.assigns.permissions["organization.plans_and_billing.view"] do
      conn
    else
      conn
      |> json(%{})
      |> halt()
    end
  end
end
