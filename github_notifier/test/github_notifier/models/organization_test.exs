defmodule GithubNotifier.Models.OrganizationTest do
  use ExUnit.Case

  alias GithubNotifier.Models.Organization

  describe ".find" do
    test "when the response is succesfull => it returns an organization model instance" do
      organization =
        struct(InternalApi.Organization.Organization,
          id: "123",
          name: "fooo"
        )

      response =
        struct(InternalApi.Organization.DescribeResponse,
          status: Support.Factories.status_ok(),
          organization: organization
        )

      GrpcMock.stub(OrganizationMock, :describe, response)

      assert Organization.find(organization.org_id) == %Organization{
               :name => organization.org_username,
               :id => organization.org_id
             }
    end

    test "when the response is unsuccesfull => it returns nil" do
      response =
        struct(InternalApi.Organization.DescribeResponse,
          status: Support.Factories.status_not_ok()
        )

      GrpcMock.stub(OrganizationMock, :describe, response)

      assert Organization.find("231312312312-123-12-312-312") == nil
    end
  end
end
