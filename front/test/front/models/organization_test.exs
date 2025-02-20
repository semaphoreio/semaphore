defmodule Front.Models.OrganizationTest do
  require Logger
  use Front.TestCase

  alias Front.Models.Organization
  alias Support.Stubs

  import Mock

  describe ".find" do
    test "when the response is successful => it returns an organization model instance" do
      organization = Support.Factories.organization()

      response =
        InternalApi.Organization.DescribeResponse.new(
          status: Support.Factories.status_ok(),
          organization: organization
        )

      GrpcMock.stub(OrganizationMock, :describe, response)

      assert Organization.find(organization.org_id) == %Organization{
               :name => organization.name,
               :username => organization.org_username,
               :avatar_url => organization.avatar_url,
               :id => organization.org_id,
               :created_at => DateTime.from_unix!(1_522_495_543),
               :open_source => organization.open_source,
               :restricted => organization.restricted,
               :owner_id => organization.owner_id,
               :ip_allow_list => [],
               :deny_member_workflows => false,
               :deny_non_member_workflows => false
             }
    end

    test "when the response is unsuccessful => it returns nil" do
      response =
        InternalApi.Organization.DescribeResponse.new(status: Support.Factories.status_not_ok())

      GrpcMock.stub(OrganizationMock, :describe, response)

      assert Organization.find("231312312312-123-12-312-312") == nil
    end
  end

  describe ".create" do
    test "when the response is successful => it returns an organization model instance" do
      organization = Support.Factories.organization()

      response =
        InternalApi.Organization.CreateResponse.new(
          status: Support.Factories.status_ok(),
          organization: organization
        )

      GrpcMock.stub(OrganizationMock, :create, response)

      {:ok, org} =
        Organization.create(
          [
            name: organization.name,
            username: organization.org_username,
            creator_id: "123323-321231-3213"
          ],
          nil
        )

      assert organization.name == org.name
      assert organization.org_username == org.username
      assert organization.avatar_url == org.avatar_url
      assert organization.org_id == org.id
    end

    test "when we create org with iterator and name of org is uniq => it returns created org" do
      organization = Support.Factories.organization()

      response =
        InternalApi.Organization.CreateResponse.new(
          status: Support.Factories.status_ok(),
          organization: organization
        )

      GrpcMock.stub(OrganizationMock, :create, response)

      {:ok, org} =
        Organization.create(
          [
            name: organization.name,
            username: organization.org_username,
            creator_id: "123323-321231-3213"
          ],
          nil,
          0
        )

      assert org == %Organization{
               :name => organization.name,
               :username => organization.org_username,
               :avatar_url => organization.avatar_url,
               :owner_id => organization.owner_id,
               :id => organization.org_id,
               :created_at => DateTime.from_unix!(organization.created_at.seconds),
               :open_source => organization.open_source,
               :restricted => organization.restricted,
               :ip_allow_list => [],
               :deny_member_workflows => false,
               :deny_non_member_workflows => false
             }
    end

    test "when we create org with iterator and name of org is not uniq => it returns created org with name with sufix" do
      organization = Support.Factories.organization()

      GrpcMock.stub(OrganizationMock, :create, fn req, _stream ->
        if req.organization_username |> String.ends_with?(Front.Sufix.on_position(1)) do
          InternalApi.Organization.CreateResponse.new(
            status: Support.Factories.status_ok(),
            organization: Support.Factories.organization(org_username: req.organization_username)
          )
        else
          InternalApi.Organization.CreateResponse.new(
            status: Support.Factories.status_not_ok("Already taken"),
            organization: Support.Factories.organization(org_username: req.organization_username)
          )
        end
      end)

      {:ok, org} =
        Organization.create(
          [
            name: organization.name,
            username: organization.org_username,
            creator_id: "123323-321231-3213"
          ],
          nil,
          0
        )

      assert org == %Organization{
               :name => organization.name,
               :username => "#{organization.org_username}-#{Front.Sufix.on_position(1)}",
               :avatar_url => organization.avatar_url,
               :id => organization.org_id,
               :created_at => DateTime.from_unix!(organization.created_at.seconds),
               :open_source => organization.open_source,
               :restricted => organization.restricted,
               :owner_id => organization.owner_id,
               :ip_allow_list => [],
               :deny_member_workflows => false,
               :deny_non_member_workflows => false
             }
    end

    test "when we create org with iterator and name of org is not uniq and there is no more sufixes => it returns error tuple" do
      organization = Support.Factories.organization()

      GrpcMock.stub(OrganizationMock, :create, fn req, _stream ->
        InternalApi.Organization.CreateResponse.new(
          status: Support.Factories.status_not_ok("Already taken"),
          organization: Support.Factories.organization(org_username: req.organization_username)
        )
      end)

      assert {:error, "Already taken", _} =
               Organization.create(
                 [
                   name: organization.name,
                   username: organization.org_username,
                   creator_id: "123323-321231-3213"
                 ],
                 nil,
                 0
               )
    end

    test "when the response is unsuccessful => it returns error tuple" do
      response =
        InternalApi.Organization.CreateResponse.new(
          status: Support.Factories.status_not_ok(),
          organization: Support.Factories.organization()
        )

      GrpcMock.stub(OrganizationMock, :create, response)

      {:error, "", org} =
        Organization.create(
          [name: "RT", username: "rt", creator_id: "123323-321231-3213"],
          nil
        )

      assert org == Organization.construct(Support.Factories.organization())
    end
  end

  describe ".update" do
    test "when the response is successful => it returns the ok response" do
      organization = %Organization{id: "123", name: "Rendered Text"}

      response =
        InternalApi.Organization.UpdateResponse.new(
          organization:
            Support.Factories.organization(
              name: "Uber",
              org_username: "uber",
              ip_allow_list: []
            )
        )

      GrpcMock.stub(OrganizationMock, :update, response)

      {:ok, org} =
        Organization.update(
          organization,
          name: "Uber",
          username: "uber",
          ip_allow_list: [],
          deny_member_workflows: false,
          deny_non_member_workflows: false
        )

      assert org.name == "Uber"
      assert org.username == "uber"
      assert org.ip_allow_list == []
    end

    test "when the response is unsuccessful => it returns an error response" do
      organization = %Organization{id: "123", name: "Rendered Text"}

      GrpcMock.stub(OrganizationMock, :update, fn _, _ ->
        raise(GRPC.RPCError, message: "Oops", status: GRPC.Status.invalid_argument())
      end)

      {:error, "Oops"} =
        Organization.update(
          organization,
          name: "Uber",
          username: "uber",
          ip_allow_list: [],
          deny_member_workflows: false,
          deny_non_member_workflows: false
        )
    end
  end

  describe ".destroy" do
    test "sends the correct API request and returns ok, if ok" do
      GrpcMock.stub(OrganizationMock, :destroy, fn req, _ ->
        assert req.org_id == "123"

        Google.Protobuf.Empty.new()
      end)

      org = %Organization{id: "123"}

      {:ok, _} = Organization.destroy(org)
    end

    test "when the response is not ok => returnes an error" do
      GrpcMock.stub(OrganizationMock, :destroy, fn _, _ ->
        raise "Oops!"
      end)

      org = %Organization{id: "123"}

      {:error, _} = Organization.destroy(org)
    end
  end

  describe ".list" do
    test "when the response is successful => it returns the list of organizations" do
      response_org =
        InternalApi.Organization.DescribeManyResponse.new(
          organizations: Support.Factories.organizations()
        )

      response_rbac =
        InternalApi.RBAC.ListAccessibleOrgsResponse.new(
          org_ids: ["1", "2,", "3", "92be62c2-9cf4-4dad-b168-d6efa6aa5e21"]
        )

      GrpcMock.stub(OrganizationMock, :describe_many, response_org)
      GrpcMock.stub(RBACMock, :list_accessible_orgs, response_rbac)

      assert Organization.list("1") == [
               %Organization{
                 id: "1",
                 name: "RT1",
                 username: "rt1",
                 avatar_url: "avatar.com",
                 created_at: DateTime.from_unix!(1_522_495_543),
                 open_source: false,
                 restricted: false,
                 ip_allow_list: [],
                 owner_id: "1",
                 deny_member_workflows: false,
                 deny_non_member_workflows: false
               },
               %Organization{
                 id: "2",
                 name: "RT2",
                 username: "rt2",
                 avatar_url: "avatar.com",
                 created_at: DateTime.from_unix!(1_522_495_543),
                 open_source: false,
                 restricted: false,
                 ip_allow_list: [],
                 owner_id: "2",
                 deny_member_workflows: false,
                 deny_non_member_workflows: false
               },
               %Organization{
                 id: "3",
                 name: "RT3",
                 username: "rt3",
                 avatar_url: "avatar.com",
                 created_at: DateTime.from_unix!(1_522_495_543),
                 open_source: false,
                 restricted: false,
                 ip_allow_list: [],
                 owner_id: "3",
                 deny_member_workflows: false,
                 deny_non_member_workflows: false
               },
               %Organization{
                 id: "92be62c2-9cf4-4dad-b168-d6efa6aa5e21",
                 name: "Semaphore",
                 username: "semaphore",
                 avatar_url: "avatar.com",
                 created_at: DateTime.from_unix!(1_522_495_543),
                 open_source: false,
                 restricted: false,
                 ip_allow_list: [],
                 owner_id: "4",
                 deny_member_workflows: false,
                 deny_non_member_workflows: false
               }
             ]
    end

    test "when the response is unsuccessful => it returns nil" do
      GrpcMock.stub(
        RBACMock,
        :list_accessible_orgs,
        InternalApi.RBAC.ListAccessibleOrgsResponse.new()
      )

      with_mock InternalApi.Organization.OrganizationService.Stub,
        describe_many: fn _, _, _ -> {:error, "Bad Request"} end do
        assert Organization.list("1") == nil
      end
    end
  end

  describe ".list_suspensions" do
    test "when the response is successful => returns the list of suspension reasons" do
      org = Stubs.Organization.create_default()

      Stubs.Organization.suspend(org,
        reason: InternalApi.Organization.Suspension.Reason.value(:INSUFFICIENT_FUNDS)
      )

      Stubs.Organization.suspend(org,
        reason: InternalApi.Organization.Suspension.Reason.value(:VIOLATION_OF_TOS)
      )

      suspensions = Organization.list_suspensions(org.id)

      assert suspensions == [:INSUFFICIENT_FUNDS, :VIOLATION_OF_TOS]
    end

    test "when the request fails => returns nil" do
      response =
        InternalApi.Organization.ListSuspensionsResponse.new(
          status:
            Google.Rpc.Status.new(
              code: Google.Rpc.Code.value(:INTERNAL),
              message: "Something went wrong"
            )
        )

      GrpcMock.stub(OrganizationMock, :list_suspensions, response)

      assert Organization.list_suspensions("1") == nil
    end
  end
end
