defmodule Support.Stubs.Organization do
  #
  # TODO: This stub is not complete. Some values are still hardcoded. DO NOT COPY.
  #
  # Hardcoding id values and API responses does not scale well. The more tests
  # we add that really on hardcoding, the harder it will become to untangle
  # the tests in the future.
  #

  alias Support.Stubs.DB
  alias InternalApi.Organization.Organization
  alias InternalApi.Organization.Suspension

  def default_org_id, do: "92be62c2-9cf4-4dad-b168-d6efa6aa5e21"

  def init do
    DB.add_table(:organizations, [:id, :name, :api_model])
    DB.add_table(:suspensions, [:id, :organization_id, :api_model])

    __MODULE__.Grpc.init()
  end

  def create_default(params \\ []) do
    constant = [
      org_id: default_org_id()
    ]

    params |> Keyword.merge(constant) |> create()
  end

  def create(params \\ []) do
    default = [
      org_id: Ecto.UUID.generate(),
      name: "RT1",
      org_username: "rt1",
      avatar_url: "https://www.gravatar.com/avatar/3b3be63a4c2a439b013787725dfce802?d=identicon",
      created_at: Google.Protobuf.Timestamp.new(seconds: 1_522_495_543),
      open_source: false,
      restricted: true,
      ip_allow_list: []
    ]

    api_model = default |> Keyword.merge(params) |> Organization.new()

    DB.insert(:organizations, %{
      id: api_model.org_id,
      name: api_model.name,
      api_model: api_model
    })
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

  defmodule Grpc do
    alias Support.Stubs.DB
    alias InternalApi.Organization.DescribeResponse
    alias InternalApi.Organization.UpdateResponse
    alias InternalApi.Organization.ListResponse
    alias InternalApi.Organization.ListSuspensionsResponse
    alias InternalApi.Organization.MembersResponse
    alias InternalApi.Organization.RepositoryIntegratorsResponse
    alias InternalApi.Organization.DeleteMemberResponse
    alias InternalApi.Organization.AddMemberResponse
    alias InternalApi.Organization.AddMembersResponse

    def init do
      GrpcMock.stub(OrganizationMock, :describe, &__MODULE__.describe/2)
      GrpcMock.stub(OrganizationMock, :update, &__MODULE__.update/2)
      GrpcMock.stub(OrganizationMock, :list, &__MODULE__.list/2)
      GrpcMock.stub(OrganizationMock, :list_suspensions, &__MODULE__.list_suspensions/2)
      GrpcMock.stub(OrganizationMock, :members, &__MODULE__.members/2)
      GrpcMock.stub(OrganizationMock, :add_members, &__MODULE__.add_members/2)
      GrpcMock.stub(OrganizationMock, :add_member, &__MODULE__.add_member/2)
      GrpcMock.stub(OrganizationMock, :delete_member, &__MODULE__.delete_member/2)
      GrpcMock.stub(OrganizationMock, :destroy, &__MODULE__.destroy/2)

      GrpcMock.stub(
        OrganizationMock,
        :repository_integrators,
        &__MODULE__.repository_integrators/2
      )
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

    def update(req, _) do
      org = DB.find(:organizations, req.organization.org_id)

      new_org =
        Map.merge(org.api_model, %{
          name: req.organization.name,
          org_username: req.organization.org_username,
          ip_allow_list: req.organization.ip_allow_list
        })

      updated =
        DB.update(:organizations, %{
          id: req.organization.org_id,
          name: req.organization.name,
          api_model: new_org
        })

      UpdateResponse.new(
        status: %Google.Rpc.Status{code: 0, message: "Success"},
        organization: updated.api_model
      )
    rescue
      _ ->
        UpdateResponse.new(status: %Google.Rpc.Status{code: 123, message: "Error"})
    end

    def list(_req, _) do
      orgs =
        DB.all(:organizations)
        |> Enum.map(fn o -> o.api_model end)

      ListResponse.new(status: ok(), organizations: orgs)
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

    def repository_integrators(_req, _) do
      available = [2, 1, 0]

      RepositoryIntegratorsResponse.new(
        primary: available |> List.first(),
        enabled: available,
        available: available
      )
    end

    defp ok do
      InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK))
    end

    defp bad_param do
      InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:BAD_PARAM))
    end
  end
end
