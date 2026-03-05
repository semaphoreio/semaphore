defmodule Rbac.Repo.OktaUser.Test do
  use Rbac.RepoCase, async: true

  alias Rbac.Repo.OktaUser

  describe "find_by_email/2" do
    test "finds user with different case than stored email" do
      {:ok, integration} = Support.Factories.OktaIntegration.insert()

      {:ok, user} =
        Support.Factories.OktaUser.insert(
          integration_id: integration.id,
          org_id: integration.org_id,
          email: "User@Example.com"
        )

      assert {:ok, found} = OktaUser.find_by_email(integration, "user@example.com")
      assert found.id == user.id
    end

    test "finds user when lookup email is all uppercase" do
      {:ok, integration} = Support.Factories.OktaIntegration.insert()

      {:ok, user} =
        Support.Factories.OktaUser.insert(
          integration_id: integration.id,
          org_id: integration.org_id,
          email: "test@example.com"
        )

      assert {:ok, found} = OktaUser.find_by_email(integration, "TEST@EXAMPLE.COM")
      assert found.id == user.id
    end

    test "returns error when email does not exist" do
      {:ok, integration} = Support.Factories.OktaIntegration.insert()

      assert {:error, :not_found} = OktaUser.find_by_email(integration, "nonexistent@example.com")
    end
  end

  describe "email_from_payload/1" do
    test "returns nil when payload has no primary email" do
      payload = %{"emails" => [%{"primary" => false, "value" => "other@example.com"}]}
      user = OktaUser.new(%{id: Ecto.UUID.generate(), org_id: Ecto.UUID.generate()}, payload)
      assert user.email == nil
    end
  end
end
