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
      :saml_auto_provision,
      :created_at,
      :updated_at
    ])

    DB.add_table(:okta_users, [
      :id,
      :org_id,
      :user_id
    ])

    __MODULE__.Grpc.init()
  end

  defmodule Grpc do
    def init do
      GrpcMock.stub(OktaMock, :set_up, &__MODULE__.set_up/2)
      GrpcMock.stub(OktaMock, :list, &__MODULE__.list/2)
      GrpcMock.stub(OktaMock, :list_users, &__MODULE__.list_users/2)
      GrpcMock.stub(OktaMock, :generate_scim_token, &__MODULE__.generate_scim_token/2)
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
          saml_auto_provision: req.saml_auto_provision,
          created_at: StubTime.now(),
          updated_at: StubTime.now()
        })

      serialized = serialize(integration)

      InternalApi.Okta.SetUpResponse.new(integration: serialized)
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

    defp serialize(integration) do
      InternalApi.Okta.OktaIntegration.new(
        id: integration.id,
        org_id: integration.org_id,
        creator_id: integration.creator_id,
        saml_issuer: integration.saml_issuer,
        sso_url: integration.sso_url,
        saml_auto_provision: integration.saml_auto_provision
      )
    end
  end
end
