defmodule Guard.GrpcServers.ServiceAccountServer do
  use GRPC.Server, service: InternalApi.ServiceAccount.ServiceAccountService.Service

  require Logger

  import Guard.Utils, only: [grpc_error!: 2, valid_uuid?: 1, validate_uuid!: 1]
  import Guard.GrpcServers.Utils, only: [observe_and_log: 3]

  alias Guard.Store.ServiceAccount
  alias Guard.Api.Organization
  alias Google.Protobuf.Timestamp
  alias InternalApi.ServiceAccount, as: ServiceAccountPB

  @user_exchange "user_exchange"
  @updated_routing_key "updated"
  @deleted_routing_key "deleted"

  @spec create(ServiceAccountPB.CreateRequest.t(), GRPC.Server.Stream.t()) ::
          ServiceAccountPB.CreateResponse.t()
  def create(
        %ServiceAccountPB.CreateRequest{
          org_id: org_id,
          name: name,
          description: description,
          creator_id: creator_id
        },
        _stream
      ) do
    observe_and_log(
      "grpc.service_account.create",
      %{org_id: org_id, name: name, description: description, creator_id: creator_id},
      fn ->
        # Validate input parameters
        validate_uuid!(org_id)
        validate_uuid!(creator_id)

        if String.trim(name) == "" do
          grpc_error!(:invalid_argument, "Service account name cannot be empty")
        end

        # Verify organization exists
        case Organization.fetch(org_id) do
          nil ->
            grpc_error!(:not_found, "Organization #{org_id} not found")

          _organization ->
            # Create service account
            params = %{
              org_id: org_id,
              name: String.trim(name),
              description: String.trim(description || ""),
              creator_id: creator_id
            }

            case Guard.ServiceAccount.Actions.create(params) do
              {:ok, %{service_account: service_account, api_token: api_token}} ->
                ServiceAccountPB.CreateResponse.new(
                  service_account: map_service_account(service_account),
                  api_token: api_token
                )

              {:error, errors} ->
                Logger.error("Failed to create service account: #{inspect(errors)}")
                grpc_error!(:invalid_argument, "Failed to create service account")
            end
        end
      end
    )
  end

  @spec list(ServiceAccountPB.ListRequest.t(), GRPC.Server.Stream.t()) ::
          ServiceAccountPB.ListResponse.t()
  def list(
        %ServiceAccountPB.ListRequest{
          org_id: org_id,
          page_size: page_size,
          page_token: page_token
        },
        _stream
      ) do
    observe_and_log(
      "grpc.service_account.list",
      %{org_id: org_id, page_size: page_size, page_token: page_token},
      fn ->
        validate_uuid!(org_id)

        # Use default page size if not provided or invalid
        effective_page_size = if page_size > 0 and page_size <= 100, do: page_size, else: 20
        effective_page_token = if page_token == "", do: nil, else: page_token

        case ServiceAccount.find_by_org(org_id, effective_page_size, effective_page_token) do
          {:ok, %{service_accounts: service_accounts, next_page_token: next_page_token}} ->
            ServiceAccountPB.ListResponse.new(
              service_accounts: Enum.map(service_accounts, &map_service_account/1),
              next_page_token: next_page_token || ""
            )

          {:error, :invalid_org_id} ->
            grpc_error!(:invalid_argument, "Invalid organization ID")

          {:error, reason} ->
            Logger.error("Failed to list service accounts for org #{org_id}: #{inspect(reason)}")
            grpc_error!(:internal, "Failed to list service accounts")
        end
      end
    )
  end

  @spec describe(ServiceAccountPB.DescribeRequest.t(), GRPC.Server.Stream.t()) ::
          ServiceAccountPB.DescribeResponse.t()
  def describe(%ServiceAccountPB.DescribeRequest{service_account_id: service_account_id}, _stream) do
    observe_and_log(
      "grpc.service_account.describe",
      %{service_account_id: service_account_id},
      fn ->
        validate_uuid!(service_account_id)

        case ServiceAccount.find(service_account_id) do
          {:ok, service_account} ->
            ServiceAccountPB.DescribeResponse.new(
              service_account: map_service_account(service_account)
            )

          {:error, :not_found} ->
            grpc_error!(:not_found, "Service account #{service_account_id} not found")

          {:error, reason} ->
            Logger.error(
              "Failed to describe service account #{service_account_id}: #{inspect(reason)}"
            )

            grpc_error!(:internal, "Failed to describe service account")
        end
      end
    )
  end

  @spec update(ServiceAccountPB.UpdateRequest.t(), GRPC.Server.Stream.t()) ::
          ServiceAccountPB.UpdateResponse.t()
  def update(
        %ServiceAccountPB.UpdateRequest{
          service_account_id: service_account_id,
          name: name,
          description: description
        },
        _stream
      ) do
    observe_and_log(
      "grpc.service_account.update",
      %{service_account_id: service_account_id, name: name, description: description},
      fn ->
        validate_uuid!(service_account_id)

        if String.trim(name) == "" do
          grpc_error!(:invalid_argument, "Service account name cannot be empty")
        end

        params = %{
          name: String.trim(name),
          description: String.trim(description || "")
        }

        case Guard.ServiceAccount.Actions.update(service_account_id, params) do
          {:ok, service_account} ->
            ServiceAccountPB.UpdateResponse.new(
              service_account: map_service_account(service_account)
            )

          {:error, :not_found} ->
            grpc_error!(:not_found, "Service account #{service_account_id} not found")

          {:error, errors} ->
            Logger.error(
              "Failed to update service account #{service_account_id}: #{inspect(errors)}"
            )

            grpc_error!(:invalid_argument, "Failed to update service account")
        end
      end
    )
  end

  @spec delete(ServiceAccountPB.DeleteRequest.t(), GRPC.Server.Stream.t()) ::
          ServiceAccountPB.DeleteResponse.t()
  def delete(%ServiceAccountPB.DeleteRequest{service_account_id: service_account_id}, _stream) do
    observe_and_log(
      "grpc.service_account.delete",
      %{service_account_id: service_account_id},
      fn ->
        validate_uuid!(service_account_id)

        case Guard.ServiceAccount.Actions.delete(service_account_id) do
          {:ok, :deleted} ->
            ServiceAccountPB.DeleteResponse.new()

          {:error, :not_found} ->
            grpc_error!(:not_found, "Service account #{service_account_id} not found")

          {:error, reason} ->
            Logger.error(
              "Failed to delete service account #{service_account_id}: #{inspect(reason)}"
            )

            grpc_error!(:internal, "Failed to delete service account")
        end
      end
    )
  end

  @spec regenerate_token(ServiceAccountPB.RegenerateTokenRequest.t(), GRPC.Server.Stream.t()) ::
          ServiceAccountPB.RegenerateTokenResponse.t()
  def regenerate_token(
        %ServiceAccountPB.RegenerateTokenRequest{service_account_id: service_account_id},
        _stream
      ) do
    observe_and_log(
      "grpc.service_account.regenerate_token",
      %{service_account_id: service_account_id},
      fn ->
        validate_uuid!(service_account_id)

        case Guard.ServiceAccount.Actions.regenerate_token(service_account_id) do
          {:ok, api_token} ->
            ServiceAccountPB.RegenerateTokenResponse.new(api_token: api_token)

          {:error, :not_found} ->
            grpc_error!(:not_found, "Service account #{service_account_id} not found")

          {:error, reason} ->
            Logger.error(
              "Failed to regenerate token for service account #{service_account_id}: #{inspect(reason)}"
            )

            grpc_error!(:internal, "Failed to regenerate token")
        end
      end
    )
  end

  # Helper functions

  def map_service_account(service_account) do
    ServiceAccountPB.ServiceAccount.new(
      id: service_account.id,
      name: service_account.name,
      description: service_account.description || "",
      org_id: service_account.org_id,
      creator_id: service_account.creator_id || "",
      created_at: grpc_timestamp(service_account.created_at),
      updated_at: grpc_timestamp(service_account.updated_at),
      deactivated: service_account.deactivated || false
    )
  end

  defp grpc_timestamp(nil), do: nil

  defp grpc_timestamp(%DateTime{} = value) do
    unix_timestamp =
      value
      |> DateTime.to_unix(:second)

    Timestamp.new(seconds: unix_timestamp)
  end

  defp grpc_timestamp(value) when is_number(value) do
    Timestamp.new(seconds: value)
  end

  defp grpc_timestamp(_), do: nil
end
