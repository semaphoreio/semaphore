defmodule Front.Models.OrganizationSettings do
  alias InternalApi.Organization, as: API

  alias API.OrganizationService.Stub
  alias API.OrganizationSetting, as: Setting

  @type t() :: %{String.t() => String.t()}

  @doc """
  Fetches organization settings from the organization service.
  """
  @spec fetch(String.t()) :: {:ok, t()} | {:error, any()}
  def fetch(organization_id) do
    grpc_call(
      &Stub.fetch_organization_settings/2,
      API.ModifyOrganizationSettingsRequest.new(org_id: organization_id)
    )
  end

  @doc """
  Modifies organization settings in the organization service.
  """
  @spec modify(String.t(), t()) :: {:ok, t()} | {:error, any()}
  def modify(organization_id, settings) do
    grpc_call(
      &Stub.modify_organization_settings/2,
      API.ModifyOrganizationSettingsRequest.new(
        org_id: organization_id,
        settings: to_api(settings)
      )
    )
  end

  defp grpc_call(func, request) do
    endpoint = Application.fetch_env!(:front, :organization_api_grpc_endpoint)

    with {:ok, channel} <- GRPC.Stub.connect(endpoint),
         {:ok, response} <- grpc_send(channel, func, request) do
      {:ok, from_api(response.settings)}
    else
      {:error, _reason} = error -> error
    end
  end

  defp grpc_send(channel, func, request),
    do: func.(channel, request),
    after: GRPC.Stub.disconnect(channel)

  defp from_api(settings) do
    Map.new(settings, &{&1.key, &1.value})
  end

  defp to_api(settings) do
    Enum.into(settings, [], &Setting.new(key: elem(&1, 0), value: elem(&1, 1)))
  end
end
