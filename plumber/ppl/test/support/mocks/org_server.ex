defmodule Test.Support.Mocks.OrgServer do
  use GRPC.Server, service: InternalApi.Organization.OrganizationService.Service

  def fetch_organization_settings(_request, _stream) do
    Util.Proto.deep_new!(InternalApi.Organization.FetchOrganizationSettingsResponse, %{
      settings: [
        %{key: "custom_machine_type", value: "e1-standard-2"},
        %{key: "custom_os_image", value: "ubuntu2004"}
      ]
    })
  end
end
