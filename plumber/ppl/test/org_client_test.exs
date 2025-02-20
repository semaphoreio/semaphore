defmodule Ppl.OrgClientTest do
  use ExUnit.Case, async: false
  alias Ppl.OrgClient

  alias InternalApi.Organization, as: API

  @url_env_var "INTERNAL_API_URL_ORGANIZATION"
  @mock_port 51_521

  setup_all [:setup_grpc_mock, :setup_organization_settings]

  describe "OrgClient.fetch_settings/2" do
    test "when organization has settings configured then returns them",
         %{org_id: org_id, settings: settings} do
      GrpcMock.expect(OrganizationServiceMock, :fetch_organization_settings, fn _request,
                                                                                _stream ->
        Util.Proto.deep_new!(API.FetchOrganizationSettingsResponse, %{
          settings: Enum.into(settings, [], &%{key: elem(&1, 0), value: elem(&1, 1)})
        })
      end)

      assert {:ok, ^settings} = OrgClient.fetch_settings(org_id)
      assert :ok = GrpcMock.verify!(OrganizationServiceMock)
    end

    test "when organization has no settings configured then returns empty map", %{org_id: org_id} do
      GrpcMock.expect(OrganizationServiceMock, :fetch_organization_settings, fn _request,
                                                                                _stream ->
        Util.Proto.deep_new!(API.FetchOrganizationSettingsResponse, %{settings: []})
      end)

      assert {:ok, %{}} = OrgClient.fetch_settings(org_id)
      assert :ok = GrpcMock.verify!(OrganizationServiceMock)
    end

    test "returns {:error, :timeout} when connection times out", %{org_id: org_id} do
      GrpcMock.expect(OrganizationServiceMock, :fetch_organization_settings, fn _request,
                                                                                _stream ->
        Process.sleep(15_000)

        Util.Proto.deep_new!(API.FetchOrganizationSettingsResponse, %{settings: []})
      end)

      assert {:error, :timeout} = OrgClient.fetch_settings(org_id)
      assert :ok = GrpcMock.verify!(OrganizationServiceMock)
    end

    test "returns {:error, reason} when something crashes", %{org_id: org_id} do
      GrpcMock.expect(OrganizationServiceMock, :fetch_organization_settings, fn _request,
                                                                                _stream ->
        raise "Some error"
      end)

      assert {:error, %GRPC.RPCError{}} = OrgClient.fetch_settings(org_id)
      assert :ok = GrpcMock.verify!(OrganizationServiceMock)
    end
  end

  defp setup_grpc_mock(_context) do
    {:ok, %{port: port}} = Test.Support.GrpcServerHelper.start_server_with_cleanup(OrganizationServiceMock)
    Test.Support.GrpcServerHelper.setup_service_url(@url_env_var, port)
  end

  defp setup_organization_settings(_context) do
    {:ok,
     org_id: UUID.uuid4(),
     settings: %{
       "plan_machine_type" => "e2-standard-4",
       "plan_os_image" => "ubuntu2004",
       "custom_machine_type" => "f1-standard-2",
       "custom_os_image" => "ubuntu2204"
     }}
  end
end
