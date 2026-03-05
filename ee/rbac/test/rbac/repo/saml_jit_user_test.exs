defmodule Rbac.Repo.SamlJitUser.Test do
  use Rbac.RepoCase, async: true

  alias Rbac.Repo.SamlJitUser

  describe "find_by_email/2" do
    test "finds user with different case than stored email" do
      {:ok, integration} = Support.Factories.OktaIntegration.insert()

      {:ok, user} =
        Support.Factories.SamlJitUser.insert(
          integration_id: integration.id,
          org_id: integration.org_id,
          email: "User@Example.com"
        )

      assert {:ok, found} = SamlJitUser.find_by_email(integration, "user@example.com")
      assert found.id == user.id
    end

    test "finds user when lookup email is all uppercase" do
      {:ok, integration} = Support.Factories.OktaIntegration.insert()

      {:ok, user} =
        Support.Factories.SamlJitUser.insert(
          integration_id: integration.id,
          org_id: integration.org_id,
          email: "test@example.com"
        )

      assert {:ok, found} = SamlJitUser.find_by_email(integration, "TEST@EXAMPLE.COM")
      assert found.id == user.id
    end

    test "returns error when email does not exist" do
      {:ok, integration} = Support.Factories.OktaIntegration.insert()

      assert {:error, :not_found} =
               SamlJitUser.find_by_email(integration, "nonexistent@example.com")
    end
  end
end
