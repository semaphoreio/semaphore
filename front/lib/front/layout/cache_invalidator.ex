defmodule Front.Layout.CacheInvalidator do
  require Logger

  alias Front.Layout
  alias Front.RBAC.Members

  @doc """
  Reacts to events in the system and invalidates the UI cache.
  """

  use Tackle.Multiconsumer,
    url: Application.get_env(:front, :amqp_url),
    service: "#{Application.get_env(:front, :cache_reactor_env)}.layout_cache_invalidator",
    service_per_exchange: true,
    routes: [
      {"rbac_exchange", "collaborator_created", :authorization_event},
      {"rbac_exchange", "collaborator_deleted", :authorization_event},
      {"rbac_exchange", "role_created", :authorization_event},
      {"rbac_exchange", "role_deleted", :authorization_event},
      {"rbac_exchange", "role_assigned", :authorization_event},
      {"rbac_exchange", "role_retracted", :authorization_event},
      {"dashboard_exchange", "created", :dashboard_event},
      {"dashboard_exchange", "deleted", :dashboard_event},
      {"dashboard_exchange", "updated", :dashboard_event},
      {"billing_exchange", "plan_changed", :plan_changed},
      {"billing_exchange", "trial_started", :trial_started},
      {"billing_exchange", "trial_status_update", :trial_status_update},
      {"billing_exchange", "trial_expired", :trial_expired},
      {"billing_exchange", "trial_abandoned", :trial_abandoned},
      {"billing_exchange", "credit_card_reconnected", :credit_card_reconnected},
      {"billing_exchange", "credits_changed", :credits_changed},
      {"organization_exchange", "blocked", :blocked_organization},
      {"organization_exchange", "unblocked", :unblocked_organization},
      {"organization_exchange", "updated", :updated_organization},
      {"organization_exchange", "suspension_created", :suspension_created},
      {"organization_exchange", "suspension_removed", :suspension_removed},
      {"project_exchange", "created", :created_project},
      {"project_exchange", "updated", :updated_project},
      {"project_exchange", "soft_deleted", :deleted_project},
      {"project_exchange", "restored", :restored_project},
      {"user_exchange", "favorite_created", :starred},
      {"user_exchange", "favorite_deleted", :unstarred}
    ]

  @metric_name "layout.cache_invalidator.process"
  @log_prefix "[LAYOUT INVALIDATOR]"

  def starred(message) do
    Watchman.benchmark({@metric_name, ["starred"]}, fn ->
      event = InternalApi.User.FavoriteCreated.decode(message)
      user_id = event.favorite.user_id
      organization_id = event.favorite.organization_id
      favorite_id = event.favorite.favorite_id
      invalidate_layout(user_id, organization_id)

      Logger.info(
        "#{@log_prefix} [STARRED] [user_id=#{user_id}] [organization_id=#{organization_id}] [favorite_id=#{favorite_id}] Processing finished"
      )
    end)
  end

  def unstarred(message) do
    Watchman.benchmark({@metric_name, ["unstarred"]}, fn ->
      event = InternalApi.User.FavoriteDeleted.decode(message)
      user_id = event.favorite.user_id
      organization_id = event.favorite.organization_id
      favorite_id = event.favorite.favorite_id
      invalidate_layout(user_id, organization_id)

      Logger.info(
        "#{@log_prefix} [UNSTARRED] [user_id=#{user_id}] [organization_id=#{organization_id}] [favorite_id=#{favorite_id}] Processing finished"
      )
    end)
  end

  def created_project(message) do
    Watchman.benchmark({@metric_name, ["created_project"]}, fn ->
      event = InternalApi.Projecthub.ProjectCreated.decode(message)
      event.project_id |> invalidate_cache_for_project_members(event.org_id)

      Logger.info(
        "#{@log_prefix} [PROJECT_CREATED] [project_id=#{event.project_id}] Processing finished"
      )
    end)
  end

  def restored_project(message) do
    Watchman.benchmark({@metric_name, ["restored_project"]}, fn ->
      event = InternalApi.Projecthub.ProjectRestored.decode(message)
      event.project_id |> invalidate_cache_for_project_members(event.org_id)

      Logger.info(
        "#{@log_prefix} [PROJECT_RESTORED] [project_id=#{event.project_id}] Processing finished"
      )
    end)
  end

  def updated_project(message) do
    Watchman.benchmark({@metric_name, ["updated_project"]}, fn ->
      event = InternalApi.Projecthub.ProjectUpdated.decode(message)
      event.project_id |> invalidate_cache_for_project_members(event.org_id)

      Logger.info(
        "#{@log_prefix} [PROJECT_UPDATED] [project_id=#{event.project_id}] Processing finished"
      )
    end)
  end

  def deleted_project(message) do
    Watchman.benchmark({@metric_name, ["deleted_project"]}, fn ->
      event = InternalApi.Projecthub.ProjectDeleted.decode(message)
      event.org_id |> invalidate_cache_for_organization_members()

      Logger.info(
        "#{@log_prefix} [PROJECT_DELETED] [project_id=#{event.project_id}] Processing finished"
      )
    end)
  end

  def updated_organization(message) do
    Watchman.benchmark({@metric_name, ["updated_organization"]}, fn ->
      event = InternalApi.Organization.OrganizationUpdated.decode(message)
      event.org_id |> invalidate_cache_for_organization_members()

      Logger.info(
        "#{@log_prefix} [UPDATED_ORGANIZATION] [organization_id=#{event.org_id}] Processing finished"
      )
    end)
  end

  def unblocked_organization(message) do
    Watchman.benchmark({@metric_name, ["unblocked_organization"]}, fn ->
      event = InternalApi.Organization.OrganizationUnblocked.decode(message)
      event.org_id |> invalidate_cache_for_organization_members()
      invalidate_billing(event.org_id)

      Logger.info(
        "#{@log_prefix} [UNBLOCKED_ORGANIZATION] [organization_id=#{event.org_id}] Processing finished"
      )
    end)
  end

  def blocked_organization(message) do
    Watchman.benchmark({@metric_name, ["blocked_organization"]}, fn ->
      event = InternalApi.Organization.OrganizationBlocked.decode(message)
      event.org_id |> invalidate_cache_for_organization_members()
      invalidate_billing(event.org_id)

      Logger.info(
        "#{@log_prefix} [BLOCKED_ORGANIZATION] [organization_id=#{event.org_id}] Processing finished"
      )
    end)
  end

  def suspension_created(message) do
    Watchman.benchmark({@metric_name, ["suspension_created"]}, fn ->
      event = InternalApi.Organization.OrganizationSuspensionCreated.decode(message)
      event.org_id |> invalidate_cache_for_organization_members()
      invalidate_billing(event.org_id)

      Logger.info(
        "#{@log_prefix} [SUSPENSION_CREATED] [organization_id=#{event.org_id}] Processing finished"
      )
    end)
  end

  def suspension_removed(message) do
    Watchman.benchmark({@metric_name, ["suspension_removed"]}, fn ->
      event = InternalApi.Organization.OrganizationSuspensionRemoved.decode(message)
      event.org_id |> invalidate_cache_for_organization_members()
      invalidate_billing(event.org_id)

      Logger.info(
        "#{@log_prefix} [SUSPENSION_REMOVED] [organization_id=#{event.org_id}] Processing finished"
      )
    end)
  end

  def trial_abandoned(message) do
    Watchman.benchmark({@metric_name, ["trial_abandoned"]}, fn ->
      event = InternalApi.Billing.TrialAbandoned.decode(message)
      event.org_id |> invalidate_cache_for_organization_members()
      invalidate_billing(event.org_id)

      Logger.info(
        "#{@log_prefix} [TRIAL_ABANDONED] [organization_id=#{event.org_id}] Processing finished"
      )
    end)
  end

  def trial_expired(message) do
    Watchman.benchmark({@metric_name, ["trial_expired"]}, fn ->
      event = InternalApi.Billing.TrialExpired.decode(message)
      event.org_id |> invalidate_cache_for_organization_members()
      invalidate_billing(event.org_id)

      Logger.info(
        "#{@log_prefix} [TRIAL_EXPIRED] [organization_id=#{event.org_id}] Processing finished"
      )
    end)
  end

  def trial_status_update(message) do
    Watchman.benchmark({@metric_name, ["trial_status_update"]}, fn ->
      event = InternalApi.Billing.TrialStatusUpdate.decode(message)
      event.org_id |> invalidate_cache_for_organization_members()
      invalidate_billing(event.org_id)

      Logger.info(
        "#{@log_prefix} [TRIAL_STATUS_UPDATE] [organization_id=#{event.org_id}] Processing finished"
      )
    end)
  end

  def trial_started(message) do
    Watchman.benchmark({@metric_name, ["trial_started"]}, fn ->
      event = InternalApi.Billing.TrialStarted.decode(message)
      event.org_id |> invalidate_cache_for_organization_members()
      invalidate_billing(event.org_id)

      Logger.info(
        "#{@log_prefix} [TRIAL_STARTED] [organization_id=#{event.org_id}] Processing finished"
      )
    end)
  end

  def plan_changed(message) do
    Watchman.benchmark({@metric_name, ["plan_changed"]}, fn ->
      event = InternalApi.Billing.PlanChanged.decode(message)
      event.org_id |> invalidate_cache_for_organization_members()
      invalidate_billing(event.org_id)

      Logger.info(
        "#{@log_prefix} [PLAN_CHANGED] [organization_id=#{event.org_id}] Processing finished"
      )
    end)
  end

  def credit_card_reconnected(message) do
    Watchman.benchmark({@metric_name, ["credit_card_reconnected"]}, fn ->
      event = InternalApi.Billing.CreditCardReconnected.decode(message)
      event.org_id |> invalidate_cache_for_organization_members()
      invalidate_billing(event.org_id)

      Logger.info(
        "#{@log_prefix} [CC_RECONNECTED] [organization_id=#{event.org_id}] Processing finished"
      )
    end)
  end

  def credits_changed(message) do
    Watchman.benchmark({@metric_name, ["credits_changed"]}, fn ->
      event = InternalApi.Billing.CreditsChanged.decode(message)
      event.org_id |> invalidate_cache_for_organization_members()
      invalidate_billing(event.org_id)

      Logger.info(
        "#{@log_prefix} [CREDITS_CHANGED] [organization_id=#{event.org_id}] Processing finished"
      )
    end)
  end

  def dashboard_event(message) do
    Watchman.benchmark({@metric_name, ["dashboard_event"]}, fn ->
      event = InternalApi.Dashboardhub.DashboardEvent.decode(message)
      event.org_id |> invalidate_cache_for_organization_members()

      Logger.info(
        "#{@log_prefix} [DASHBOARD_EVENT] [organization_id=#{event.org_id}] Processing finished"
      )
    end)
  end

  def authorization_event(message) do
    Watchman.benchmark({@metric_name, ["authorization_event"]}, fn ->
      event = InternalApi.Guard.AuthorizationEvent.decode(message)
      invalidate_layout(event.user_id, event.org_id)

      Logger.info(
        "#{@log_prefix} [AUTHORIZATION_EVENT] [user_id=#{event.user_id}] [organization_id=#{event.org_id}] Processing finished"
      )
    end)
  end

  @max_page_size 2000
  def invalidate_cache_for_organization_members(org_id) do
    case Members.list_org_members(org_id, page_size: @max_page_size) do
      {:ok, {members, _total_pages}} ->
        members
        |> Enum.each(fn member -> invalidate_layout(member.id, org_id) end)

      _ ->
        :ok
    end
  end

  def invalidate_cache_for_project_members(project_id, org_id) do
    case Members.list_project_members(org_id, project_id, page_size: @max_page_size) do
      {:ok, {members, _total_pages}} ->
        members
        |> Enum.each(fn member -> invalidate_layout(member.id, org_id) end)

      _ ->
        :ok
    end
  end

  def invalidate_layout(user_id, organization_id) do
    struct!(Layout.Model.LoadParams,
      user_id: user_id,
      organization_id: organization_id
    )
    |> Layout.Model.invalidate()
  end

  def invalidate_billing(org_id) do
    if Front.saas?() do
      Front.Clients.Billing.invalidate_cache(:list_spendings, %{org_id: org_id})
      Front.Clients.Billing.invalidate_cache(:current_spending, %{org_id: org_id})
      Front.Clients.Billing.invalidate_cache(:credits_usage, %{org_id: org_id})
    end

    :ok
  end
end
