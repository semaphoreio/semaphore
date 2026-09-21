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
      :session_expiration_minutes,
      :created_at,
      :updated_at
    ])

    DB.add_table(:okta_users, [
      :id,
      :org_id,
      :user_id
    ])

    DB.add_table(:okta_mappings, [
      :org_id,
      :default_role_id,
      :group_mappings,
      :role_mappings
    ])

    __MODULE__.Grpc.init()
  end

  defmodule Grpc do
    def init do
      GrpcMock.stub(OktaMock, :set_up, &__MODULE__.set_up/2)
      GrpcMock.stub(OktaMock, :list, &__MODULE__.list/2)
      GrpcMock.stub(OktaMock, :list_users, &__MODULE__.list_users/2)
      GrpcMock.stub(OktaMock, :generate_scim_token, &__MODULE__.generate_scim_token/2)
      GrpcMock.stub(OktaMock, :describe_mapping, &__MODULE__.describe_mapping/2)
      GrpcMock.stub(OktaMock, :set_up_mapping, &__MODULE__.set_up_mapping/2)
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
          session_expiration_minutes: req.session_expiration_minutes,
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

    def describe_mapping(req, _) do
      org_id = req.org_id

      mapping = DB.find_by(:okta_mappings, :org_id, org_id)

      if mapping do
        group_mappings =
          Enum.map(mapping.group_mappings || [], fn mapping ->
            InternalApi.Okta.GroupMapping.new(
              semaphore_group_id: mapping.semaphore_group_id,
              okta_group_id: mapping.okta_group_id
            )
          end)

        role_mappings =
          Enum.map(mapping.role_mappings || [], fn mapping ->
            InternalApi.Okta.RoleMapping.new(
              semaphore_role_id: mapping.semaphore_role_id,
              okta_role_id: mapping.okta_role_id
            )
          end)

        InternalApi.Okta.DescribeMappingResponse.new(
          default_role_id: mapping.default_role_id,
          group_mapping: group_mappings,
          role_mapping: role_mappings
        )
      else
        InternalApi.Okta.DescribeMappingResponse.new(
          default_role_id: "",
          group_mapping: [],
          role_mapping: []
        )
      end
    end

    def set_up_mapping(req, _) do
      org_id = req.org_id
      default_role_id = req.default_role_id

      group_mappings =
        Enum.map(req.group_mapping || [], fn mapping ->
          %{
            semaphore_group_id: mapping.semaphore_group_id,
            okta_group_id: mapping.okta_group_id
          }
        end)

      role_mappings =
        Enum.map(req.role_mapping || [], fn mapping ->
          %{
            semaphore_role_id: mapping.semaphore_role_id,
            okta_role_id: mapping.okta_role_id
          }
        end)

      DB.delete(:okta_mappings, fn mapping -> mapping.org_id == org_id end)

      DB.insert(:okta_mappings, %{
        org_id: org_id,
        default_role_id: default_role_id,
        group_mappings: group_mappings,
        role_mappings: role_mappings
      })

      Logger.info("[stub] Set up Okta mappings for org: #{org_id}")

      InternalApi.Okta.SetUpMappingResponse.new()
    end

    defp serialize(integration) do
      InternalApi.Okta.OktaIntegration.new(
        id: integration.id,
        org_id: integration.org_id,
        creator_id: integration.creator_id,
        saml_issuer: integration.saml_issuer,
        sso_url: integration.sso_url,
        jit_provisioning_enabled: integration.jit_provisioning_enabled,
        session_expiration_minutes: integration.session_expiration_minutes
      )
    end
  end
end
