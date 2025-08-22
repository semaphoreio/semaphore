defmodule Front.ServiceAccount do
  defmodule Behaviour do
    alias InternalApi.ServiceAccount.ServiceAccount

    @callback create(
                org_id :: String.t(),
                name :: String.t(),
                description :: String.t(),
                creator_id :: String.t()
              ) :: {:ok, {ServiceAccount.t(), String.t()}} | {:error, any}

    @callback list(
                org_id :: String.t(),
                page_size :: integer(),
                page_token :: String.t() | nil
              ) :: {:ok, {[ServiceAccount.t()], String.t() | nil}} | {:error, any}

    @callback describe(service_account_id :: String.t()) ::
                {:ok, ServiceAccount.t()} | {:error, any}

    @callback describe_many(service_account_ids :: [String.t()]) ::
                {:ok, [ServiceAccount.t()]} | {:error, any}

    @callback update(
                service_account_id :: String.t(),
                name :: String.t(),
                description :: String.t()
              ) :: {:ok, ServiceAccount.t()} | {:error, any}

    @callback delete(service_account_id :: String.t()) :: :ok | {:error, any}

    @callback regenerate_token(service_account_id :: String.t()) ::
                {:ok, String.t()} | {:error, any}
  end

  def create(org_id, name, description, creator_id),
    do: service_account_impl().create(org_id, name, description, creator_id)

  def list(org_id, page_size, page_token \\ nil),
    do: service_account_impl().list(org_id, page_size, page_token)

  def describe(service_account_id),
    do: service_account_impl().describe(service_account_id)

  def describe_many(service_account_ids),
    do: service_account_impl().describe_many(service_account_ids)

  def update(service_account_id, name, description),
    do: service_account_impl().update(service_account_id, name, description)

  def delete(service_account_id),
    do: service_account_impl().delete(service_account_id)

  def regenerate_token(service_account_id),
    do: service_account_impl().regenerate_token(service_account_id)

  defp service_account_impl do
    {client, _client_opts} = Application.fetch_env!(:front, :service_account_client)

    client
  end
end
