defmodule Support.Stubs.Okta do
  alias Support.Stubs.{DB, UUID}
  alias Support.Stubs.Time, as: StubTime

  require Logger

  def init do
    DB.add_table(:okta_integrations, [
      :id,
      :org_id,
      :creator_id,
      :saml_issuer,
      :sso_url,
      :saml_certificate,
      :jit_provisioning_enabled,
      :created_at,
      :updated_at
    ])

    DB.add_table(:okta_users, [
      :id,
      :org_id,
      :user_id
    ])

    DB.add_table(:okta_group_mappings, [
      :org_id,
      :default_role_id,
      :mappings
    ])

    __MODULE__.Grpc.init()
  end

  defmodule Grpc do
    def init do
      GrpcMock.stub(OktaMock, :set_up, &__MODULE__.set_up/2)
      GrpcMock.stub(OktaMock, :list, &__MODULE__.list/2)
      GrpcMock.stub(OktaMock, :list_users, &__MODULE__.list_users/2)
      GrpcMock.stub(OktaMock, :generate_scim_token, &__MODULE__.generate_scim_token/2)
      GrpcMock.stub(OktaMock, :describe_group_mapping, &__MODULE__.describe_group_mapping/2)
      GrpcMock.stub(OktaMock, :set_up_group_mapping, &__MODULE__.set_up_group_mapping/2)
    end

    def set_up(req, _) do
      integration =
        DB.insert(:okta_integrations, %{
          id: UUID.gen(),
          org_id: req.org_id,
          creator_id: req.creator_id,
          sso_url: req.sso_url,
          saml_issuer: req.saml_issuer,
          saml_certificate: req.saml_certificate,
          jit_provisioning_enabled: req.jit_provisioning_enabled,
          created_at: StubTime.now(),
          updated_at: StubTime.now()
        })

      serialized = serialize(integration)

      resp = InternalApi.Okta.SetUpResponse.new(integration: serialized)

      Logger.info("[stub] Created Okta integration: #{inspect(resp)}")

      resp
    end

    def list(req, _) do
      integrations = DB.find_all_by(:okta_integrations, :org_id, req.org_id)
      serialized = Enum.map(integrations, &serialize/1)

      InternalApi.Okta.ListResponse.new(integrations: serialized)
    end

    def list_users(req, _) do
      okta_users =
        DB.find_all_by(:okta_users, :org_id, req.org_id)
        |> Enum.map(& &1.user_id)
        |> Enum.filter(&(!is_nil(&1)))

      InternalApi.Okta.ListUsersResponse.new(user_ids: okta_users)
    end

    def generate_scim_token(_req, _) do
      token = :crypto.strong_rand_bytes(64) |> Base.url_encode64() |> binary_part(0, 64)

      InternalApi.Okta.GenerateScimTokenResponse.new(token: token)
    end

    def describe_group_mapping(req, _) do
      org_id = req.org_id

      group_mapping = DB.find_by(:okta_group_mappings, :org_id, org_id)

      if group_mapping do
        # Return the existing mapping
        mappings =
          Enum.map(group_mapping.mappings, fn mapping ->
            InternalApi.Okta.GroupMapping.new(
              semaphore_group_id: mapping.semaphore_group_id,
              okta_group_id: mapping.okta_group_id
            )
          end)

        InternalApi.Okta.DescribeGroupMappingResponse.new(
          default_role_id: group_mapping.default_role_id,
          mappings: mappings
        )
      else
        # Return empty mapping
        InternalApi.Okta.DescribeGroupMappingResponse.new(
          default_role_id: "",
          mappings: []
        )
      end
    end

    def set_up_group_mapping(req, _) do
      org_id = req.org_id
      default_role_id = req.default_role_id

      # Convert the protobuf mappings to a simpler map structure for storage
      mappings =
        Enum.map(req.mappings, fn mapping ->
          %{
            semaphore_group_id: mapping.semaphore_group_id,
            okta_group_id: mapping.okta_group_id
          }
        end)

      # Delete any existing mapping for this org
      DB.delete(:okta_group_mappings, fn mapping -> mapping.org_id == org_id end)

      # Insert the new mapping
      DB.insert(:okta_group_mappings, %{
        org_id: org_id,
        default_role_id: default_role_id,
        mappings: mappings
      })

      Logger.info("[stub] Set up Okta group mapping for org: #{org_id}")

      # Return empty response
      InternalApi.Okta.SetUpGroupMappingResponse.new()
    end

    defp serialize(integration) do
      InternalApi.Okta.OktaIntegration.new(
        id: integration.id,
        org_id: integration.org_id,
        creator_id: integration.creator_id,
        saml_issuer: integration.saml_issuer,
        sso_url: integration.sso_url,
        jit_provisioning_enabled: integration.jit_provisioning_enabled
      )
    end
  end
end
