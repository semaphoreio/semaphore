defmodule Zebra.Workers.Scheduler.OrgTest do
  use Zebra.DataCase
  alias Zebra.Workers.Scheduler.Org

  describe "load with error handling" do
    @org_id Ecto.UUID.generate()

    setup do
      # Reset the cache before each test
      Cachex.clear(:zebra_cache)
      :ok
    end

    test "returns data without caching when error is returned" do
      # First set up a failure
      alias Support.FakeServers.OrganizationApi, as: OrgApi

      GrpcMock.stub(OrgApi, :describe, fn _, _ ->
        {:error, "Connection error"}
      end)

      # Load should return error and not cache it
      assert {:error, _} = Org.load(@org_id)

      # Now set up a success response
      GrpcMock.stub(OrgApi, :describe, fn _, _ ->
        InternalApi.Organization.DescribeResponse.new(
          status:
            InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
          organization: InternalApi.Organization.Organization.new(org_username: "testing-org")
        )
      end)

      # It should now succeed because the error wasn't cached
      assert {:ok, _} = Org.load(@org_id)
    end

    test "properly handles timeouts and doesn't cache them" do
      # First set up a timeout scenario using Wormhole
      alias Support.FakeServers.OrganizationApi, as: OrgApi

      GrpcMock.stub(OrgApi, :describe, fn _, _ ->
        # Sleep to simulate timeout longer than Wormhole's timeout
        Process.sleep(15_000)
        {:ok, "This shouldn't be returned"}
      end)

      # Load should return error due to timeout and not cache it
      assert {:error, _} = Org.load(@org_id)

      # Now set up a success response
      GrpcMock.stub(OrgApi, :describe, fn _, _ ->
        InternalApi.Organization.DescribeResponse.new(
          status:
            InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
          organization: InternalApi.Organization.Organization.new(org_username: "testing-org")
        )
      end)

      # It should now succeed because the timeout wasn't cached
      assert {:ok, _} = Org.load(@org_id)
    end

    test "caches successful responses" do
      # Set up a success response
      alias Support.FakeServers.OrganizationApi, as: OrgApi

      GrpcMock.stub(OrgApi, :describe, fn _, _ ->
        InternalApi.Organization.DescribeResponse.new(
          status:
            InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
          organization: InternalApi.Organization.Organization.new(org_username: "testing-org")
        )
      end)

      # First call should succeed
      assert {:ok, org} = Org.load(@org_id)
      assert org.username == "testing-org"

      # Now set up a failure, which shouldn't be used because we'll use the cached value
      GrpcMock.stub(OrgApi, :describe, fn _, _ ->
        {:error, "Connection error"}
      end)

      # It should still succeed because we're using the cached value
      assert {:ok, org} = Org.load(@org_id)
      assert org.username == "testing-org"
    end
  end
end
