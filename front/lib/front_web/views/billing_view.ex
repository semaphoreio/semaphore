defmodule FrontWeb.BillingView do
  require Logger

  use FrontWeb, :view

  alias Front.Models.Billing

  @type badge_colors :: :green | :red | :purple
  @type badge :: {badge_colors, badge_content :: String.t()} | nil

  def initial_plan_config(conn) do
    %{
      acknowledgePlanChangeUrl:
        billing_acknowledge_plan_change_path(conn, :acknowledge_plan_change, []),
      billingUrl: billing_index_path(conn, :index, [])
    }
    |> Poison.encode!()
  end

  def json_config(conn) do
    url_opts = []

    url_opts =
      if conn.assigns.spending.id do
        [{:spending_id, conn.assigns.spending.id} | url_opts]
      else
        []
      end

    url_opts =
      if conn.params["force_cold_boot"] do
        [{:force_cold_boot, true} | url_opts]
      else
        url_opts
      end

    available_plans = Billing.PlanSwitch.list_plans(conn.assigns.organization_id)

    %{
      baseUrl: billing_index_path(conn, :index, []),
      seatsUrl: billing_seats_path(conn, :seats, url_opts),
      costsUrl: billing_costs_path(conn, :costs, url_opts),
      invoicesUrl: billing_invoices_path(conn, :invoices, url_opts),
      spendingCsvUrl: billing_spending_csv_path(conn, :spending_csv, url_opts),
      projectsCsvUrl: billing_projects_csv_path(conn, :projects_csv, url_opts),
      budgetUrl: billing_budget_path(conn, :set_budget, url_opts),
      creditsUrl: billing_credits_path(conn, :credits, url_opts),
      upgradeUrl: billing_upgrade_path(conn, :upgrade, []),
      newOrganizationUrl: "https://billing.#{Application.fetch_env!(:front, :domain)}/new?reset",
      spendings: conn.assigns.spendings,
      currentSpending: conn.assigns.current_spending,
      budget: conn.assigns.budget,
      selectedSpendingId: conn.assigns.spending.id,
      isBillingManager: Front.Auth.can?(conn, :ManageBilling),
      availablePlans: available_plans,
      currentPlanType: Billing.PlanSwitch.current_plan_type(conn.assigns.current_spending.plan),
      canUpgradeUrl: billing_can_upgrade_path(conn, :can_upgrade, []),
      peoplePageUrl: people_path(conn, :organization, []),
      agentsPageUrl: self_hosted_agent_path(conn, :index),
      contactSupportUrl: Front.Zendesk.new_ticket_location(),
      acknowledgePlanChangeUrl:
        billing_acknowledge_plan_change_path(conn, :acknowledge_plan_change, [])
    }
    |> then(fn params ->
      if FeatureProvider.feature_enabled?(:project_spendings, param: conn.assigns.organization_id) or
           Front.Auth.is_billing_admin?(conn.assigns.organization_id, conn.assigns.user_id) do
        project_spendings = %{
          topProjectsUrl: billing_top_projects_path(conn, :top_projects, url_opts),
          projectsUrl: billing_projects_path(conn, :projects, url_opts),
          projectUrl: billing_project_path(conn, :project, url_opts)
        }

        Map.put(params, :projectSpendings, project_spendings)
      else
        params
      end
    end)
    |> Poison.encode!()
  end

  def can_create_organization?(conn) do
    alias Front.Clients.Billing, as: BillingClient

    BillingClient.can_setup_organization(%{
      owner_id: conn.assigns.user_id
    })
    |> case do
      {:ok, %{allowed: true}} ->
        true

      _ ->
        false
    end
  rescue
    _ ->
      true
  end

  def with_plan_overlay?(conn) do
    conn.assigns.current_spending
    |> case do
      %{plan: plan} ->
        plan

      :none ->
        Billing.Plan.zero()
    end
    |> case do
      %{flags: flags} ->
        :trial_end_nack in flags

      _ ->
        false
    end
  end

  @spec badge(Plug.Conn.t()) :: String.t()
  def badge(conn) do
    plan =
      conn.assigns.current_spending
      |> case do
        %{plan: plan} ->
          plan

        :none ->
          Billing.Plan.zero()
      end

    is_billing_manager? = Front.Auth.can?(conn, :ManageBilling)

    get_badge(plan, is_billing_manager?)
    |> case do
      {_badge_color, badge_content} = badge ->
        %{
          text: badge_content,
          class: badge_class(badge, is_billing_manager?)
        }

      _ ->
        nil
    end
    |> case do
      nil ->
        ""

      content when is_billing_manager? ->
        render("badges/manager.html", conn: conn, content: content)

      content when not is_billing_manager? ->
        render("badges/member.html", conn: conn, content: content)

      _ ->
        ""
    end
  rescue
    e ->
      Logger.error("Failed to render billing badge: #{inspect(e)}")

      ""
  end

  @spec badge_class(badge, boolean()) :: String.t()
  def badge_class(badge, is_billing_manager?) do
    classes = "db white f6 lh-title ph2 ph3-ns pv1"

    {badge_color, _badge_content} = badge

    {badge_color, is_billing_manager?}
    |> case do
      {:red, true} ->
        classes <> " link bg-red hover-bg-dark-red"

      {:red, false} ->
        classes <> " bg-red"

      {:green, true} ->
        classes <> " link bg-green hover-bg-dark-green"

      {:green, false} ->
        classes <> " bg-green"

      {:purple, true} ->
        classes <> " link bg-purple hover-bg-dark-purple"

      {:purple, false} ->
        classes <> " bg-purple"
    end
  end

  @spec get_badge(Billing.Plan.t(), boolean()) :: badge
  defp get_badge(plan, is_billing_manager?) do
    [
      trial_badge(plan, is_billing_manager?),
      prepaid_badge(plan, is_billing_manager?),
      postpaid_badge(plan, is_billing_manager?),
      grandfathered_badge(plan, is_billing_manager?),
      flat_badge(plan, is_billing_manager?),
      opensource_badge(plan, is_billing_manager?),
      free_badge(plan, is_billing_manager?)
    ]
    |> Enum.filter(& &1)
    |> case do
      [{badge_color, nil} | _] ->
        plan_name = "#{plan.display_name} Plan"
        {badge_color, plan_name}

      [{badge_color, badge_content} | _] ->
        plan_name = "#{plan.display_name} Plan"
        content = Enum.join([plan_name, badge_content], " - ")
        {badge_color, content}

      [] ->
        nil
    end
  end

  @spec trial_badge(Billing.Plan.t(), boolean()) :: badge()
  defp trial_badge(plan, is_billing_manager?) do
    on_trial? = Billing.Plan.trial?(plan) == true
    trial_expired? = Billing.Plan.trial_expired?(plan)

    cond do
      on_trial? and trial_expired? and is_billing_manager? ->
        {:red, "Trial expired → Select a plan"}

      on_trial? and trial_expired? and not is_billing_manager? ->
        {:red, "Trial expired"}

      on_trial? ->
        days_left = Billing.Plan.subscription_days(plan)
        {:green, "Trial #{FrontWeb.SharedHelpers.pluralize("day", days_left)} left"}

      true ->
        nil
    end
  end

  @spec prepaid_badge(Billing.Plan.t(), boolean()) :: badge()
  defp prepaid_badge(plan, is_billing_manager?) do
    on_prepaid? = plan.charging_type == :prepaid
    pipelines_blocked? = Billing.Plan.pipelines_blocked?(plan)

    cond do
      pipelines_blocked? and on_prepaid? and is_billing_manager? ->
        {:red, "credits used up, pipelines disabled → Manage billing"}

      pipelines_blocked? and on_prepaid? and not is_billing_manager? ->
        {:red, "credits used up, pipelines disabled"}

      true ->
        nil
    end
  end

  @spec postpaid_badge(Billing.Plan.t(), boolean()) :: badge()
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp postpaid_badge(plan, is_billing_manager?) do
    no_payment_method? = :no_payment_method in plan.suspensions
    pipelines_blocked? = Billing.Plan.pipelines_blocked?(plan)
    on_postpaid? = plan.charging_type == :postpaid

    cond do
      on_postpaid? and no_payment_method? and is_billing_manager? ->
        {:red, "Your pipelines will stop running soon → Please update your billing info"}

      on_postpaid? and no_payment_method? and not is_billing_manager? ->
        {:red,
         "Your pipelines will stop running soon, please tell your organization owner to update the billing info"}

      on_postpaid? and pipelines_blocked? and is_billing_manager? ->
        {:red, "Pipelines disabled → Please update your billing info"}

      on_postpaid? and pipelines_blocked? and not is_billing_manager? ->
        {:red,
         "Pipelines disabled, please tell your organization owner to update the billing info"}

      true ->
        nil
    end
  end

  @spec grandfathered_badge(Billing.Plan.t(), boolean()) :: badge()
  defp grandfathered_badge(_plan, _is_billing_manager?) do
    nil
  end

  @spec flat_badge(Billing.Plan.t(), boolean()) :: badge()
  defp flat_badge(plan, is_billing_manager?) do
    days_left = Billing.Plan.subscription_days(plan)
    pipelines_blocked? = Billing.Plan.pipelines_blocked?(plan)
    on_flat? = plan.charging_type == :flat

    cond do
      on_flat? and pipelines_blocked? and days_left == 0 and is_billing_manager? ->
        {:red, "Annual plan expired, pipelines disabled → Manage billing"}

      pipelines_blocked? and days_left == 0 and not is_billing_manager? ->
        {:red, "Annual plan expired, pipelines disabled"}

      true ->
        nil
    end
  end

  @spec free_badge(Billing.Plan.t(), boolean()) :: badge()
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp free_badge(plan, is_billing_manager?) do
    is_trial_eligible? = Billing.Plan.eligible_for_trial?(plan)
    pipelines_blocked? = Billing.Plan.pipelines_blocked?(plan)
    on_free_plan? = Billing.Plan.on_free_plan?(plan)

    cond do
      on_free_plan? and pipelines_blocked? and is_billing_manager? and is_trial_eligible? ->
        {:red,
         "Pipelines disabled, you spent your free monthly credit → Start a 14-day free trial to unblock"}

      on_free_plan? and pipelines_blocked? and is_billing_manager? and not is_trial_eligible? ->
        {:red, "Pipelines disabled, you spent your free monthly credit → Upgrade to unblock"}

      on_free_plan? and pipelines_blocked? and not is_billing_manager? ->
        {:red, "Pipelines disabled, you spent your free monthly credit"}

      on_free_plan? and is_billing_manager? and is_trial_eligible? ->
        {:purple, "limited concurrency → Upgrade, Start a 14-day free trial"}

      on_free_plan? and is_billing_manager? and not is_trial_eligible? ->
        {:purple, "limited concurrency → Upgrade to remove the limit"}

      on_free_plan? and not is_billing_manager? ->
        {:purple, "limited concurrency"}

      true ->
        nil
    end
  end

  @spec opensource_badge(Billing.Plan.t(), boolean()) :: badge()
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp opensource_badge(plan, _is_billing_manager?) do
    on_opensource_plan? = Billing.Plan.on_opensource_plan?(plan)

    if on_opensource_plan? do
      {:purple, nil}
    else
      nil
    end
  end
end
