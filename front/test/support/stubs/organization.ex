defmodule Support.Stubs.Organization do
  alias InternalApi.Organization.Organization
  alias InternalApi.Organization.Suspension
  alias Support.Stubs.DB

  def default_org_id, do: "92be62c2-9cf4-4dad-b168-d6efa6aa5e21"

  def init do
    DB.add_table(:organizations, [:id, :name, :api_model])
    DB.add_table(:organization_contacts, [:id, :org_id, :type, :name])
    DB.add_table(:suspensions, [:id, :organization_id, :api_model])
    DB.add_table(:organization_repo_integrators, [:id, :types])

    __MODULE__.Grpc.init()
  end

  def create_default(params \\ []) do
    constant = [
      org_id: default_org_id()
    ]

    params |> Keyword.merge(constant) |> create()
  end

  def default do
    DB.find(:organizations, default_org_id())
  end

  def create(params \\ []) do
    name = params[:name] || "RT1"

    name_hash =
      :crypto.hash(:sha256, "#{name}@semaphoreci.com")
      |> Base.encode16(case: :lower)

    default = [
      org_id: Ecto.UUID.generate(),
      name: name,
      org_username: "rt1",
      avatar_url: "https://www.gravatar.com/avatar/#{name_hash}?d=identicon&size=32",
      created_at: Google.Protobuf.Timestamp.new(seconds: 1_522_495_543),
      open_source: false,
      restricted: true,
      ip_allow_list: [],
      deny_member_workflows: false,
      deny_non_member_workflows: false,
      settings: []
    ]

    api_model = default |> Keyword.merge(params) |> Organization.new()

    DB.insert(:organizations, %{
      id: api_model.org_id,
      name: api_model.name,
      api_model: api_model
    })

    # Add default repository integrators (all three types)
    DB.insert(:organization_repo_integrators, %{
      id: api_model.org_id,
      types:
        [:GITHUB_OAUTH_TOKEN, :GITHUB_APP, :BITBUCKET, :GITLAB]
        |> Enum.map(&InternalApi.RepositoryIntegrator.IntegrationType.value/1)
    })

    %{id: api_model.org_id, name: api_model.name, api_model: api_model}
  end

  def suspend(org, params \\ []) do
    default = [
      origin: "Automatic/Billing",
      description: "Trial expired",
      reason: Suspension.Reason.value(:INSUFFICIENT_FUNDS),
      created_at: Google.Protobuf.Timestamp.new(seconds: 1_522_495_543)
    ]

    api_model = default |> Keyword.merge(params) |> Suspension.new()

    DB.insert(:suspensions, %{
      id: Ecto.UUID.generate(),
      organization_id: org.id,
      api_model: api_model
    })
  end

  def put_settings(org, settings) do
    alias InternalApi.Organization.OrganizationSetting, as: Setting
    settings = Enum.into(settings, [], &Setting.new(key: elem(&1, 0), value: elem(&1, 1)))
    new_org = Map.merge(org.api_model, %{settings: settings})

    DB.update(:organizations, %{
      id: org.id,
      name: org.name,
      api_model: new_org
    })
  end

  defmodule Grpc do
    alias InternalApi.Organization.AddMemberResponse
    alias InternalApi.Organization.AddMembersResponse
    alias InternalApi.Organization.CreateResponse
    alias InternalApi.Organization.DeleteMemberResponse
    alias InternalApi.Organization.DescribeResponse
    alias InternalApi.Organization.IsValidResponse
    alias InternalApi.Organization.ListResponse
    alias InternalApi.Organization.ListSuspensionsResponse
    alias InternalApi.Organization.MembersResponse
    alias InternalApi.Organization.RepositoryIntegratorsResponse
    alias InternalApi.Organization.UpdateResponse
    alias Support.Stubs.DB

    def init do
      GrpcMock.stub(OrganizationMock, :describe, &__MODULE__.describe/2)
      GrpcMock.stub(OrganizationMock, :describe_many, &__MODULE__.describe_many/2)
      GrpcMock.stub(OrganizationMock, :update, &__MODULE__.update/2)
      GrpcMock.stub(OrganizationMock, :list, &__MODULE__.list/2)
      GrpcMock.stub(OrganizationMock, :list_suspensions, &__MODULE__.list_suspensions/2)
      GrpcMock.stub(OrganizationMock, :members, &__MODULE__.members/2)
      GrpcMock.stub(OrganizationMock, :add_members, &__MODULE__.add_members/2)
      GrpcMock.stub(OrganizationMock, :add_member, &__MODULE__.add_member/2)
      GrpcMock.stub(OrganizationMock, :delete_member, &__MODULE__.delete_member/2)
      GrpcMock.stub(OrganizationMock, :destroy, &__MODULE__.destroy/2)
      GrpcMock.stub(OrganizationMock, :is_valid, &__MODULE__.is_valid/2)
      GrpcMock.stub(OrganizationMock, :create, &__MODULE__.create/2)

      GrpcMock.stub(
        OrganizationMock,
        :modify_organization_contact,
        &__MODULE__.modify_organization_contact/2
      )

      GrpcMock.stub(
        OrganizationMock,
        :fetch_organization_contacts,
        &__MODULE__.fetch_organization_contacts/2
      )

      GrpcMock.stub(
        OrganizationMock,
        :modify_organization_settings,
        &__MODULE__.modify_organization_settings/2
      )

      GrpcMock.stub(
        OrganizationMock,
        :fetch_organization_settings,
        &__MODULE__.fetch_organization_settings/2
      )

      GrpcMock.stub(
        OrganizationMock,
        :repository_integrators,
        &__MODULE__.repository_integrators/2
      )

      GrpcMock.stub(BillingMock, :organization_status, &__MODULE__.billing_org_status/2)
    end

    def destroy(_, _) do
      Google.Protobuf.Empty.new()
    end

    def describe(req, _) do
      org = DB.find(:organizations, req.org_id)

      if req.include_quotas do
        DescribeResponse.new(
          status: ok(),
          organization:
            InternalApi.Organization.Organization.new(
              org_username: org.api_model.org_username,
              name: org.api_model.name,
              org_id: org.api_model.org_id,
              created_at: Google.Protobuf.Timestamp.new(seconds: 1_522_495_543),
              deny_member_workflows: org.api_model.deny_member_workflows,
              deny_non_member_workflows: org.api_model.deny_non_member_workflows,
              quotas: []
            )
        )
      else
        DescribeResponse.new(status: ok(), organization: org.api_model)
      end
    rescue
      _ ->
        DescribeResponse.new(status: bad_param())
    end

    def describe_many(req, _) do
      orgs = DB.find_many(:organizations, req.org_ids)

      InternalApi.Organization.DescribeManyResponse.new(
        organizations: Enum.map(orgs, & &1.api_model)
      )
    rescue
      _ ->
        reraise GRPC.RPCError, status: GRPC.Status.invalid_argument(), message: "Bad request"
    end

    def update(req, _) do
      org = DB.find(:organizations, req.organization.org_id)

      new_org =
        Map.merge(org.api_model, %{
          name: req.organization.name,
          org_username: req.organization.org_username,
          ip_allow_list: req.organization.ip_allow_list,
          deny_member_workflows: req.organization.deny_member_workflows,
          deny_non_member_workflows: req.organization.deny_non_member_workflows
        })

      updated =
        DB.update(:organizations, %{
          id: req.organization.org_id,
          name: req.organization.name,
          api_model: new_org
        })

      UpdateResponse.new(organization: updated.api_model)
    rescue
      _ ->
        reraise(GRPC.RPCError, message: "Error", status: GRPC.Status.invalid_argument())
    end

    def list(_req, _) do
      orgs =
        DB.all(:organizations)
        |> Enum.map(fn o -> o.api_model end)

      ListResponse.new(status: ok(), organizations: orgs)
    end

    def is_valid(req, _) do
      username = req.org_username

      org_usernames =
        DB.all(:organizations)
        |> Enum.map(fn o -> o.api_model end)
        |> Enum.map(& &1.org_username)

      (username in org_usernames)
      |> case do
        true ->
          IsValidResponse.new(
            is_valid: false,
            errors: "Organization name is already taken"
          )

        _ ->
          IsValidResponse.new(is_valid: true)
      end
    end

    def create(req, _) do
      entry =
        Support.Stubs.Organization.create(
          name: req.organization_name,
          org_username: req.organization_username,
          owner_id: req.creator_id
        )

      Support.Stubs.RBAC.add_member(entry.api_model.org_id, entry.api_model.owner_id, nil)

      CreateResponse.new(
        status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
        organization: entry.api_model
      )
    end

    def list_suspensions(req, _) do
      suspensions = DB.find_all_by(:suspensions, :organization_id, req.org_id)

      ListSuspensionsResponse.new(
        status: Google.Rpc.Status.new(code: Google.Rpc.Code.value(:OK)),
        suspensions: Enum.map(suspensions, fn s -> s.api_model end)
      )
    end

    def members(req, _) do
      users =
        DB.all(:users)
        |> Enum.filter(fn user ->
          if req.name_contains != "" do
            String.starts_with?(
              String.downcase(user.api_model.name),
              String.downcase(req.name_contains)
            )
          else
            true
          end
        end)

      MembersResponse.new(
        status: ok(),
        members:
          Enum.map(users, fn user ->
            InternalApi.Organization.Member.new(
              screen_name: user.api_model.name,
              avatar_url: user.api_model.avatar_url,
              user_id: user.api_model.user_id,
              github_username: user.api_model.github_login,
              membership_id: Ecto.UUID.generate()
            )
          end),
        not_logged_in_members: []
      )
    end

    def delete_member(_req, _) do
      DeleteMemberResponse.new(status: Google.Rpc.Status.new(code: Google.Rpc.Code.value(:OK)))
    end

    def add_members(_req, _) do
      AddMembersResponse.new(
        member: [InternalApi.Organization.Member.new(screen_name: "example_screen_name")]
      )
    end

    def add_member(_req, _) do
      AddMemberResponse.new(
        member: InternalApi.Organization.Member.new(screen_name: "example_screen_name"),
        status: Google.Rpc.Status.new(code: Google.Rpc.Code.value(:OK))
      )
    end

    def fetch_organization_contacts(req, _) do
      alias InternalApi.Organization.FetchOrganizationContactsResponse
      alias InternalApi.Organization.OrganizationContact

      contacts = DB.find_all_by(:organization_contacts, :org_id, req.org_id)

      FetchOrganizationContactsResponse.new(
        org_contacts:
          Enum.map(
            contacts,
            &OrganizationContact.new(
              org_id: &1.org_id,
              type: OrganizationContact.ContactType.value(&1.type |> String.to_atom()),
              name: &1.name
            )
          )
      )
    end

    def modify_organization_contact(req, _) do
      alias InternalApi.Organization.OrganizationContact

      DB.insert(:organization_contacts, %{
        id: Support.Stubs.UUID.gen(),
        org_id: req.org_contact.org_id,
        type: OrganizationContact.ContactType.key(req.org_contact.type) |> Atom.to_string(),
        name: req.org_contact.name
      })

      InternalApi.Organization.ModifyOrganizationContactResponse.new()
    end

    def fetch_organization_settings(req, _) do
      alias InternalApi.Organization.FetchOrganizationSettingsResponse
      org = DB.find(:organizations, req.org_id)
      settings = (org && org.api_model.settings) || []
      FetchOrganizationSettingsResponse.new(settings: settings)
    end

    def modify_organization_settings(req, _) do
      alias InternalApi.Organization.ModifyOrganizationSettingsResponse
      alias InternalApi.Organization.OrganizationSetting, as: Setting

      org = DB.find(:organizations, req.org_id)
      old_settings = Map.new((org && org.api_model.settings) || [], &{&1.key, &1.value})
      new_settings = Map.new(req.settings, &{&1.key, &1.value})

      settings =
        old_settings
        |> Map.merge(new_settings)
        |> Enum.reject(fn {_, v} -> v == "" end)
        |> Enum.into([], &Setting.new(key: elem(&1, 0), value: elem(&1, 1)))

      new_org = Map.merge(org.api_model, %{settings: settings})

      DB.update(:organizations, %{id: org.id, name: org.name, api_model: new_org})
      ModifyOrganizationSettingsResponse.new(settings: new_org.settings)
    end

    def repository_integrators(req, _) do
      case DB.find(:organization_repo_integrators, req.org_id) do
        nil ->
          available = []
          RepositoryIntegratorsResponse.new(primary: nil, enabled: available)

        record ->
          RepositoryIntegratorsResponse.new(
            primary: List.first(record.types),
            enabled: record.types
          )
      end
    end

    def billing_org_status(_req, _) do
      InternalApi.Billing.OrganizationStatusResponse.new(plan_type_slug: "free")
    end

    defp ok do
      InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK))
    end

    defp bad_param do
      InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:BAD_PARAM))
    end
  end
end
