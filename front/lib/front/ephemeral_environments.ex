defmodule Front.EphemeralEnvironments do
  defmodule Behaviour do
    alias InternalApi.EphemeralEnvironments.EphemeralEnvironmentType

    @callback list(
                org_id :: String.t(),
                project_id :: String.t()
              ) :: {:ok, [EphemeralEnvironmentType.t()]} | {:error, any}

    @callback create(environment_type :: EphemeralEnvironmentType.t()) ::
                {:ok, EphemeralEnvironmentType.t()} | {:error, any}

    @callback update(environment_type :: EphemeralEnvironmentType.t()) ::
                {:ok, EphemeralEnvironmentType.t()} | {:error, any}

    @callback delete(
                id :: String.t(),
                org_id :: String.t()
              ) :: :ok | {:error, any}

    @callback cordon(
                id :: String.t(),
                org_id :: String.t()
              ) :: {:ok, EphemeralEnvironmentType.t()} | {:error, any}
  end

  def list(org_id, project_id),
    do: ephemeral_environments_impl().list(org_id, project_id)

  def create(environment_type),
    do: ephemeral_environments_impl().create(environment_type)

  def update(environment_type),
    do: ephemeral_environments_impl().update(environment_type)

  def delete(id, org_id),
    do: ephemeral_environments_impl().delete(id, org_id)

  def cordon(id, org_id),
    do: ephemeral_environments_impl().cordon(id, org_id)

  defp ephemeral_environments_impl do
    {client, _client_opts} = Application.fetch_env!(:front, :ephemeral_environments_client)

    client
  end
end
