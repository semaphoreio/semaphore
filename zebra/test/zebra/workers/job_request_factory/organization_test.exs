defmodule Zebra.Workers.JobRequestFactory.OrganizationTest do
  use Zebra.DataCase

  alias Zebra.Workers.JobRequestFactory.Organization

  @org_id "22222222-oooo-4b67-a417-f31f2fa0f105"

  describe ".find" do
    test "when describe org request succeeds => it constructs the org url variable" do
      GrpcMock.stub(Support.FakeServers.OrganizationApi, :describe, fn _, _ ->
        status = InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK))

        organization =
          InternalApi.Organization.Organization.new(
            org_username: "zebraz-org",
            org_id: @org_id
          )

        InternalApi.Organization.DescribeResponse.new(
          status: status,
          organization: organization
        )
      end)

      {:ok, organization} = Organization.find(@org_id)
      assert organization.org_id == @org_id
      assert organization.org_username == "zebraz-org"
    end

    test "when grpc communication fails => it returns an error tuple" do
      GrpcMock.stub(Support.FakeServers.OrganizationApi, :describe, fn _, _ ->
        raise "oops grpc did it again"
      end)

      assert Organization.find(@org_id) ==
               {:error, :communication_error}
    end

    test "when describe org is not found => it returns an error tuple" do
      GrpcMock.stub(Support.FakeServers.OrganizationApi, :describe, fn _, _ ->
        InternalApi.Organization.DescribeResponse.new(
          status:
            InternalApi.ResponseStatus.new(
              code: InternalApi.ResponseStatus.Code.value(:BAD_PARAM),
              message: "Org not found"
            )
        )
      end)

      assert Organization.find(@org_id) ==
               {:stop_job_processing,
                "Organization 22222222-oooo-4b67-a417-f31f2fa0f105 not found"}
    end
  end
end
