defmodule Projecthub.Models.OrganizationTest do
  use Projecthub.DataCase
  alias Projecthub.Models.Organization

  describe ".find" do
    test "it fetches the organization with correct params" do
      org_response =
        InternalApi.Organization.DescribeResponse.new(
          status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
          organization:
            InternalApi.Organization.Organization.new(
              org_username: "semaphore",
              org_id: "12345678-1234-5678-1234-567812345678"
            )
        )

      FunRegistry.set!(Support.FakeServices.OrganizationService, :describe, fn req, _stream ->
        assert req.org_id == "12345678-1234-5678-1234-567812345678"

        org_response
      end)

      assert Organization.find("12345678-1234-5678-1234-567812345678")
    end
  end
end
