defmodule Rbac.GrpcServers.OktaServer do
  use GRPC.Server, service: InternalApi.Okta.Okta.Service

  import Rbac.Utils.Grpc, only: [validate_uuid!: 1, authorize!: 3, grpc_error!: 2]

  require Logger

  alias InternalApi.Okta.{
    SetUpResponse,
    GenerateScimTokenResponse,
    ListResponse,
    ListUsersResponse,
    SetUpMappingResponse,
    DescribeMappingResponse,
    GroupMapping,
    RoleMapping
  }

  @manage_okta_permission "organization.okta.manage"

  @doc """
    set_up endpoint is used both for creating new integrations and modifying the existing one.
  """
  def set_up(req, _stream) do
    observe("set_up", fn ->
      authorize!(@manage_okta_permission, req.creator_id, req.org_id)

      result =
        Rbac.Okta.Integration.create_or_update(
          req.org_id,
          req.creator_id,
          req.sso_url,
          req.saml_issuer,
          req.saml_certificate,
          req.jit_provisioning_enabled,
          req.idempotency_token,
          req.session_expiration_minutes
        )

      case result do
        {:ok, integration} ->
          Logger.info("User #{req.creator_id} is creating Okta integration for org #{req.org_id}")
          Watchman.increment("okta_integration_created")
          %SetUpResponse{integration: serialize(integration)}

        {:error, :cert_decode_error} ->
          Logger.error(
            "Error while decoding the SAML certificate: #{inspect(req.saml_certificate)}"
          )

          grpc_error!(:failed_precondition, "SAML certificate is not valid.")

        e ->
          Logger.error("Error while setting up okta for #{req.org_id}, error: #{inspect(e)}")
          grpc_error!(:unknown, "Unknown error while setting up okta integration")
      end
    end)
  end

  def generate_scim_token(req, _stream) do
    observe("generate_scim_token", fn ->
      validate_uuid!(req.integration_id)

      with {:ok, integration} <- Rbac.Okta.Integration.find(req.integration_id),
           {:ok, token} <- Rbac.Okta.Integration.generate_scim_token(integration) do
        %GenerateScimTokenResponse{token: token}
      else
        {:error, :not_found} ->
          grpc_error!(:not_found, "Okta integration with ID=#{req.integration_id} not found")

        e ->
          Logger.error(
            "Error while setting up okta scim token for #{req.integration_id}, error: #{inspect(e)}"
          )

          grpc_error!(:unknown, "Unknown error while generating okta scim token")
      end
    end)
  end

  def list(req, _stream) do
    observe("list", fn ->
      case Rbac.Okta.Integration.list_for_org(req.org_id) do
        {:ok, integrations} ->
          serialized = Enum.map(integrations, fn i -> serialize(i) end)

          %ListResponse{integrations: serialized}

        e ->
          Logger.error(
            "Error while listing okta integrations for #{req.org_id}, error: #{inspect(e)}"
          )

          grpc_error!(:unknown, "Unknown error while listing okta integrations")
      end
    end)
  end

  def list_users(req, _stream) do
    user_ids = Rbac.Repo.OktaUser.list(req.org_id)
    %ListUsersResponse{user_ids: user_ids}
  rescue
    error ->
      Logger.error(
        "Error while listing okta users for org: #{inspect(req.org_id)}. #{inspect(error)}"
      )

      grpc_error!(:unknown, "Unknown error while listing okta users")
  end

  def destroy(req, _strem) do
    observe("destroy", fn ->
      case Rbac.Okta.Integration.find(req.integration_id) do
        {:ok, integration} ->
          authorize!(@manage_okta_permission, req.user_id, integration.org_id)

          Logger.info(
            "User #{req.user_id} is destroying Okta integration for org #{integration.org_id}"
          )

          Task.Supervisor.async_nolink(:rbac_task_supervisor, fn ->
            Rbac.Okta.Integration.destroy(req.integration_id)
          end)

          %InternalApi.Okta.DestroyResponse{}

        {:error, :not_found} ->
          grpc_error!(:not_found, "Integration does not exist")
      end
    end)
  end

  def set_up_mapping(req, _stream) do
    observe("set_up_mapping", fn ->
      validate_uuid!(req.org_id)

      group_mappings =
        Enum.map(req.group_mapping, fn mapping ->
          %{
            idp_group_id: mapping.okta_group_id,
            semaphore_group_id: mapping.semaphore_group_id
          }
        end)

      role_mappings =
        Enum.map(req.role_mapping, fn mapping ->
          %{
            idp_role_id: mapping.okta_role_id,
            semaphore_role_id: mapping.semaphore_role_id
          }
        end)

      case Rbac.Okta.IdpGroupMapping.create_or_update(
             req.org_id,
             group_mappings,
             role_mappings,
             req.default_role_id
           ) do
        {:ok, _mapping} ->
          Logger.info("Group and role mappings created/updated for org #{req.org_id}")
          %SetUpMappingResponse{}

        {:error, %Ecto.Changeset{} = changeset} ->
          Logger.error(
            "Error while setting up mappings for org #{req.org_id}: #{inspect(changeset)}"
          )

          grpc_error!(
            :failed_precondition,
            "Failed to save mappings: Invalid"
          )

        error ->
          Logger.error("Unknown error while setting up mappings: #{inspect(error)}")
          grpc_error!(:unknown, "Unknown error while setting up mappings")
      end
    end)
  end

  def describe_mapping(req, _stream) do
    observe("describe_mapping", fn ->
      validate_uuid!(req.org_id)

      case Rbac.Okta.IdpGroupMapping.get_for_organization(req.org_id) do
        {:ok, idp_mapping} ->
          # Convert from our internal format to protobuf messages
          group_mapping =
            Enum.map(idp_mapping.group_mapping, fn mapping ->
              %GroupMapping{
                okta_group_id: mapping.idp_group_id,
                semaphore_group_id: mapping.semaphore_group_id
              }
            end)

          role_mapping =
            Enum.map(idp_mapping.role_mapping || [], fn mapping ->
              %RoleMapping{
                okta_role_id: mapping.idp_role_id,
                semaphore_role_id: mapping.semaphore_role_id
              }
            end)

          %DescribeMappingResponse{
            group_mapping: group_mapping,
            role_mapping: role_mapping,
            default_role_id: idp_mapping.default_role_id
          }

        {:error, :not_found} ->
          %DescribeMappingResponse{group_mapping: [], role_mapping: []}

        error ->
          Logger.error("Error while describing mappings for org #{req.org_id}: #{inspect(error)}")

          grpc_error!(:unknown, "Unknown error while describing mappings")
      end
    end)
  end

  #
  # Serialization Utilities
  #

  def serialize(integration) do
    %InternalApi.Okta.OktaIntegration{
      id: integration.id,
      org_id: integration.org_id,
      creator_id: integration.creator_id,
      created_at: serialize_time(integration.inserted_at),
      updated_at: serialize_time(integration.updated_at),
      saml_issuer: integration.saml_issuer,
      idempotency_token: integration.idempotency_token,
      sso_url: integration.sso_url,
      jit_provisioning_enabled: integration.jit_provisioning_enabled,
      session_expiration_minutes: integration.session_expiration_minutes
    }
  end

  def serialize_time(time) do
    %Google.Protobuf.Timestamp{seconds: DateTime.to_unix(time)}
  end

  #
  # Metric utilities
  #
  defp observe(name, f) do
    Watchman.benchmark("okta.internal_api.#{name}.duration", fn ->
      try do
        result = f.()

        Watchman.increment("okta.internal_api.#{name}.response.success")

        result
      rescue
        e ->
          Watchman.increment("okta.internal_api.#{name}.response.error")

          reraise e, __STACKTRACE__
      end
    end)
  end
end
