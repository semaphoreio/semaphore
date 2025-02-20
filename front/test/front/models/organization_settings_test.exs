defmodule Front.Models.OrganizationSettingsTest do
  use ExUnit.Case, async: false
  alias Front.Models.OrganizationSettings

  setup do
    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    org = Support.Stubs.DB.find(:organizations, Support.Stubs.Organization.default_org_id())

    Support.Stubs.Organization.put_settings(org, %{
      "custom_machine_type" => "f1-standard-2",
      "plan_machine_type" => "e2-standard-2",
      "custom_os_image" => "ubuntu2204",
      "plan_os_image" => "ubuntu2004"
    })

    {:ok, org_id: Support.Stubs.Organization.default_org_id()}
  end

  describe "fetch/1" do
    test "returns {:ok, settings} when grpc call is successful", ctx do
      assert {:ok,
              %{
                "custom_machine_type" => "f1-standard-2",
                "plan_machine_type" => "e2-standard-2",
                "custom_os_image" => "ubuntu2204",
                "plan_os_image" => "ubuntu2004"
              }} = OrganizationSettings.fetch(ctx.org_id)
    end

    test "returns {:error, reason} when grpc call is unsuccessful", ctx do
      GrpcMock.stub(OrganizationMock, :fetch_organization_settings, fn _, _ ->
        raise GRPC.RPCError, status: 3, message: "Invalid"
      end)

      on_exit(fn ->
        GrpcMock.stub(
          OrganizationMock,
          :fetch_organization_settings,
          &Support.Stubs.Organization.Grpc.fetch_organization_settings/2
        )
      end)

      assert {:error, %GRPC.RPCError{message: "Invalid"}} = OrganizationSettings.fetch(ctx.org_id)
    end
  end

  describe "modify/2" do
    test "returns {:ok, settings} when grpc call is successful", ctx do
      assert {:ok,
              %{
                "custom_machine_type" => "e2-standard-4",
                "custom_os_image" => "ubuntu2204",
                "plan_machine_type" => "e2-standard-2",
                "plan_os_image" => "ubuntu2004"
              }} =
               OrganizationSettings.modify(ctx.org_id, %{
                 "custom_machine_type" => "e2-standard-4"
               })
    end

    test "returns {:error, reason} when grpc call is unsuccessful", ctx do
      GrpcMock.stub(OrganizationMock, :modify_organization_settings, fn _, _ ->
        raise GRPC.RPCError, status: 3, message: "Invalid"
      end)

      on_exit(fn ->
        GrpcMock.stub(
          OrganizationMock,
          :modify_organization_settings,
          &Support.Stubs.Organization.Grpc.modify_organization_settings/2
        )
      end)

      assert {:error, %GRPC.RPCError{message: "Invalid"}} =
               OrganizationSettings.modify(ctx.org_id, %{"key" => "value"})
    end
  end
end
