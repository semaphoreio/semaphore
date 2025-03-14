defmodule Rbac.Okta.Saml.Provisioner.AddUser.Test do
  use Rbac.RepoCase, async: true
  @org_id Ecto.UUID.generate()

  setup do
    Support.Rbac.create_org_roles(@org_id)

    {:ok, integration} =
      Rbac.Okta.Integration.create_or_update(
        @org_id,
        @creator_id,
        @sso_url,
        @okta_issuer,
        cert,
        false
      )

    {:ok,
     %{
       integration: integration
     }}
  end

  describe "createing user based on the saml_jit request" do
    test "When the org has no custom mapping created", ctx do
      IO.inspect(ctx.integration)
      :error
    end
  end
end
