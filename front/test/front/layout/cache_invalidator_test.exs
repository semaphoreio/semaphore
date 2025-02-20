defmodule Front.Layout.CacheInvalidatorTest do
  use ExUnit.Case
  import Mock

  alias Support.Stubs.DB

  alias Front.Layout.CacheInvalidator
  alias Front.Layout.Model
  alias Front.RBAC.Members

  setup do
    Cacheman.clear(:front)

    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    user = DB.first(:users)
    project = DB.first(:projects)
    organization = DB.first(:organizations)

    [
      user: user,
      project: project,
      organization: organization
    ]
  end

  describe "authorization_event" do
    test "invalidates organization layout for user", %{
      user: user,
      organization: organization,
      project: project
    } do
      params =
        struct!(Model.LoadParams,
          user_id: user.id,
          organization_id: organization.id
        )

      {:ok, _model, :from_api} = params |> Model.get()

      assert Cacheman.exists?(:front, params |> Model.cache_key())

      InternalApi.Guard.AuthorizationEvent.new(
        user_id: params.user_id,
        org_id: params.organization_id,
        project_id: project.id,
        timestamp: %Google.Protobuf.Timestamp{seconds: 1, nanos: 1}
      )
      |> InternalApi.Guard.AuthorizationEvent.encode()
      |> CacheInvalidator.authorization_event()

      refute Cacheman.exists?(:front, params |> Model.cache_key())
    end
  end

  describe "starred" do
    test "invalidates organization layout for user who starred", %{
      user: user,
      organization: organization
    } do
      params =
        struct!(Model.LoadParams,
          user_id: user.id,
          organization_id: organization.id
        )

      {:ok, _model, :from_api} = params |> Model.get()

      assert Cacheman.exists?(:front, params |> Model.cache_key())

      InternalApi.User.FavoriteCreated.new(
        favorite: %InternalApi.User.Favorite{
          user_id: params.user_id,
          organization_id: params.organization_id,
          kind: InternalApi.User.Favorite.Kind.value(:PROJECT),
          favorite_id: Support.Stubs.UUID.gen()
        },
        timestamp: %Google.Protobuf.Timestamp{seconds: 1, nanos: 1}
      )
      |> InternalApi.User.FavoriteCreated.encode()
      |> CacheInvalidator.starred()

      refute Cacheman.exists?(:front, params |> Model.cache_key())
    end
  end

  describe "unstarred" do
    test "invalidates organization layout for user who unstarred", %{
      user: user,
      organization: organization
    } do
      params =
        struct!(Model.LoadParams,
          user_id: user.id,
          organization_id: organization.id
        )

      {:ok, _model, :from_api} = params |> Model.get()

      assert Cacheman.exists?(:front, params |> Model.cache_key())

      InternalApi.User.FavoriteDeleted.new(
        favorite: %InternalApi.User.Favorite{
          user_id: params.user_id,
          organization_id: params.organization_id,
          kind: InternalApi.User.Favorite.Kind.value(:PROJECT),
          favorite_id: Support.Stubs.UUID.gen()
        },
        timestamp: %Google.Protobuf.Timestamp{seconds: 1, nanos: 1}
      )
      |> InternalApi.User.FavoriteDeleted.encode()
      |> CacheInvalidator.starred()

      refute Cacheman.exists?(:front, params |> Model.cache_key())
    end
  end

  describe "updated_organization" do
    test "invalidates organization layout for all members", %{organization: organization} do
      organization.id |> cache_layouts_for_organization_members()

      assert organization_members_have_cached_layout(organization.id)

      InternalApi.Organization.OrganizationUpdated.new(
        org_id: organization.id,
        timestamp: %Google.Protobuf.Timestamp{seconds: 1, nanos: 1}
      )
      |> InternalApi.Organization.OrganizationUpdated.encode()
      |> CacheInvalidator.updated_organization()

      refute organization_members_have_cached_layout(organization.id)
    end
  end

  describe "unblocked_organization" do
    test "invalidates organization layout for all members", %{organization: organization} do
      organization.id |> cache_layouts_for_organization_members()

      assert organization_members_have_cached_layout(organization.id)

      InternalApi.Organization.OrganizationUnblocked.new(
        org_id: organization.id,
        timestamp: %Google.Protobuf.Timestamp{seconds: 1, nanos: 1}
      )
      |> InternalApi.Organization.OrganizationUnblocked.encode()
      |> CacheInvalidator.unblocked_organization()

      refute organization_members_have_cached_layout(organization.id)
    end
  end

  describe "blocked_organization" do
    test "invalidates organization layout for all members", %{organization: organization} do
      organization.id |> cache_layouts_for_organization_members()

      assert organization_members_have_cached_layout(organization.id)

      InternalApi.Organization.OrganizationBlocked.new(
        org_id: organization.id,
        timestamp: %Google.Protobuf.Timestamp{seconds: 1, nanos: 1}
      )
      |> InternalApi.Organization.OrganizationBlocked.encode()
      |> CacheInvalidator.blocked_organization()

      refute organization_members_have_cached_layout(organization.id)
    end
  end

  describe "suspension_created" do
    test "invalidates organization layout for all members", %{organization: organization} do
      organization.id |> cache_layouts_for_organization_members()

      assert organization_members_have_cached_layout(organization.id)

      InternalApi.Organization.OrganizationSuspensionCreated.new(
        org_id: organization.id,
        reason: InternalApi.Organization.Suspension.Reason.value(:VIOLATION_OF_TOS),
        timestamp: %Google.Protobuf.Timestamp{seconds: 1, nanos: 1}
      )
      |> InternalApi.Organization.OrganizationSuspensionCreated.encode()
      |> CacheInvalidator.suspension_created()

      refute organization_members_have_cached_layout(organization.id)
    end
  end

  describe "suspension_removed" do
    test "invalidates organization layout for all members", %{organization: organization} do
      organization.id |> cache_layouts_for_organization_members()

      assert organization_members_have_cached_layout(organization.id)

      InternalApi.Organization.OrganizationSuspensionRemoved.new(
        org_id: organization.id,
        reason: InternalApi.Organization.Suspension.Reason.value(:VIOLATION_OF_TOS),
        timestamp: %Google.Protobuf.Timestamp{seconds: 1, nanos: 1}
      )
      |> InternalApi.Organization.OrganizationSuspensionRemoved.encode()
      |> CacheInvalidator.suspension_removed()

      refute organization_members_have_cached_layout(organization.id)
    end
  end

  describe "trial_abandoned" do
    test "invalidates organization layout for all members", %{organization: organization} do
      organization.id |> cache_layouts_for_organization_members()

      assert organization_members_have_cached_layout(organization.id)

      InternalApi.Billing.TrialAbandoned.new(
        org_id: organization.id,
        timestamp: %Google.Protobuf.Timestamp{seconds: 1, nanos: 1}
      )
      |> InternalApi.Billing.TrialAbandoned.encode()
      |> CacheInvalidator.trial_abandoned()

      refute organization_members_have_cached_layout(organization.id)
    end
  end

  describe "trial_expired" do
    test "invalidates organization layout for all members", %{organization: organization} do
      organization.id |> cache_layouts_for_organization_members()

      assert organization_members_have_cached_layout(organization.id)

      InternalApi.Billing.TrialExpired.new(
        org_id: organization.id,
        timestamp: %Google.Protobuf.Timestamp{seconds: 1, nanos: 1}
      )
      |> InternalApi.Billing.TrialExpired.encode()
      |> CacheInvalidator.trial_expired()

      refute organization_members_have_cached_layout(organization.id)
    end
  end

  describe "trial_status_update" do
    test "invalidates organization layout for all members", %{organization: organization} do
      organization.id |> cache_layouts_for_organization_members()

      assert organization_members_have_cached_layout(organization.id)

      InternalApi.Billing.TrialStatusUpdate.new(
        org_id: organization.id,
        timestamp: %Google.Protobuf.Timestamp{seconds: 1, nanos: 1}
      )
      |> InternalApi.Billing.TrialStatusUpdate.encode()
      |> CacheInvalidator.trial_status_update()

      refute organization_members_have_cached_layout(organization.id)
    end
  end

  describe "trial_started" do
    test "invalidates organization layout for all members", %{organization: organization} do
      organization.id |> cache_layouts_for_organization_members()

      assert organization_members_have_cached_layout(organization.id)

      InternalApi.Billing.TrialStarted.new(
        org_id: organization.id,
        timestamp: %Google.Protobuf.Timestamp{seconds: 1, nanos: 1}
      )
      |> InternalApi.Billing.TrialStarted.encode()
      |> CacheInvalidator.trial_started()

      refute organization_members_have_cached_layout(organization.id)
    end
  end

  describe "credit_card_reconnected" do
    test "invalidates organization layout for all members", %{organization: organization} do
      organization.id |> cache_layouts_for_organization_members()

      assert organization_members_have_cached_layout(organization.id)

      InternalApi.Billing.CreditCardReconnected.new(
        org_id: organization.id,
        timestamp: %Google.Protobuf.Timestamp{seconds: 1, nanos: 1}
      )
      |> InternalApi.Billing.CreditCardReconnected.encode()
      |> CacheInvalidator.credit_card_reconnected()

      refute organization_members_have_cached_layout(organization.id)
    end
  end

  describe "plan_changed" do
    test "invalidates organization layout for all members", %{organization: organization} do
      organization.id |> cache_layouts_for_organization_members()

      assert organization_members_have_cached_layout(organization.id)

      InternalApi.Billing.PlanChanged.new(
        org_id: organization.id,
        timestamp: %Google.Protobuf.Timestamp{seconds: 1, nanos: 1}
      )
      |> InternalApi.Billing.PlanChanged.encode()
      |> CacheInvalidator.plan_changed()

      refute organization_members_have_cached_layout(organization.id)
    end
  end

  describe "dashboard_event" do
    test "invalidates organization layout for all members", %{organization: organization} do
      organization.id |> cache_layouts_for_organization_members()

      assert organization_members_have_cached_layout(organization.id)

      InternalApi.Dashboardhub.DashboardEvent.new(
        org_id: organization.id,
        dashboard_id: "b17c3583-0948-4fe8-9e76-d15ac8df1482",
        timestamp: %Google.Protobuf.Timestamp{seconds: 1, nanos: 1}
      )
      |> InternalApi.Dashboardhub.DashboardEvent.encode()
      |> CacheInvalidator.dashboard_event()

      refute organization_members_have_cached_layout(organization.id)
    end
  end

  describe "updated_project" do
    test "invalidates organization layout for all project members", %{
      organization: organization,
      project: project
    } do
      members = [%{id: Ecto.UUID.generate()}, %{id: Ecto.UUID.generate()}]

      with_mocks [
        {Members, [],
         [
           list_project_members: fn _, _ -> {:ok, {members, nil}} end,
           list_project_members: fn _, _, _ -> {:ok, {members, nil}} end,
           filter_projects: fn _, _, _ -> [] end,
           list_accessible_orgs: fn _ -> {:ok, [organization.id]} end
         ]}
      ] do
        cache_layouts_for_project_members(project.id, organization.id)

        assert project_members_have_cached_layout(project.id, organization.id)

        InternalApi.Projecthub.ProjectUpdated.new(
          org_id: organization.id,
          project_id: project.id,
          timestamp: %Google.Protobuf.Timestamp{seconds: 1, nanos: 1}
        )
        |> InternalApi.Projecthub.ProjectUpdated.encode()
        |> CacheInvalidator.updated_project()

        refute project_members_have_cached_layout(project.id, organization.id)
      end
    end
  end

  describe "deleted_project" do
    test "invalidates organization layout for all members", %{organization: organization} do
      organization.id |> cache_layouts_for_organization_members()

      assert organization_members_have_cached_layout(organization.id)

      InternalApi.Projecthub.ProjectDeleted.new(
        org_id: organization.id,
        project_id: "b17c3583-0948-4fe8-9e76-d15ac8df1482",
        timestamp: %Google.Protobuf.Timestamp{seconds: 1, nanos: 1}
      )
      |> InternalApi.Projecthub.ProjectDeleted.encode()
      |> CacheInvalidator.deleted_project()

      refute organization_members_have_cached_layout(organization.id)
    end
  end

  # Private

  defp cache_layouts_for_organization_members(organization_id) do
    {:ok, {members, _total_pages}} = Members.list_org_members(organization_id)

    members
    |> Enum.map(fn member ->
      params =
        struct!(Model.LoadParams,
          user_id: member.id,
          organization_id: organization_id
        )

      {:ok, _model, :from_api} = params |> Model.get()
    end)
  end

  defp organization_members_have_cached_layout(organization_id) do
    {:ok, {members, _total_pages}} = Members.list_org_members(organization_id)

    members
    |> Enum.any?(fn member ->
      params =
        struct!(Model.LoadParams,
          user_id: member.id,
          organization_id: organization_id
        )

      Cacheman.exists?(:front, params |> Model.cache_key())
    end)
  end

  defp cache_layouts_for_project_members(project_id, organization_id) do
    {:ok, {members, _total_pages}} = Members.list_project_members(organization_id, project_id)

    members
    |> Enum.map(fn member ->
      params =
        struct!(Model.LoadParams,
          user_id: member.id,
          organization_id: organization_id
        )

      {:ok, _model, :from_api} = params |> Model.get()
    end)
  end

  defp project_members_have_cached_layout(project_id, organization_id) do
    {:ok, {members, _total_pages}} = Members.list_project_members(organization_id, project_id)

    members
    |> Enum.any?(fn member ->
      params =
        struct!(Model.LoadParams,
          user_id: member.id,
          organization_id: organization_id
        )

      cache_key = Model.cache_key(params)

      Cacheman.exists?(:front, cache_key)
    end)
  end
end
