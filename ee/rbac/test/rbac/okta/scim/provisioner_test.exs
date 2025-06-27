defmodule Rbac.Okta.Scim.ProvisionerTest do
  use Rbac.RepoCase, async: false

  @org_id Ecto.UUID.generate()
  @creator_id Ecto.UUID.generate()
  @sso_url "http://www.okta.com/sso_endpoint"
  @okta_issuer "http://www.okta.com/exk207czditgMeFGI697"

  alias Rbac.Repo.OktaUser
  import Mock

  # Setup global mocks that will be available for all tests
  setup_with_mocks([
    {Rbac.Api.Organization, [],
     [
       find_by_id: fn _ -> {:ok, %{allowed_id_providers: []}} end,
       update: fn _ -> {:ok, %{}} end
     ]}
  ]) do
    Support.Rbac.Store.clear!()
    Support.Rbac.create_org_roles(@org_id)

    {:ok, provisioner} = Rbac.Okta.Scim.Provisioner.start_link()
    on_exit(fn -> Process.exit(provisioner, :kill) end)

    {:ok, cert} = Support.Okta.Saml.PayloadBuilder.test_cert()

    {:ok, integration} =
      Rbac.Okta.Integration.create_or_update(
        @org_id,
        @creator_id,
        @sso_url,
        @okta_issuer,
        cert,
        false
      )

    {:ok, %{integration: integration}}
  end

  describe "perform" do
    test "it loads unprocessed users and processes them", ctx do
      with_mock Rbac.Events.UserCreated, publish: fn _, _ -> :ok end do
        {:ok, okta_user} = create_pending_okta_user(ctx.integration)

        Rbac.Okta.Scim.Provisioner.perform_now()
        :timer.sleep(500)

        okta_user = Rbac.Repo.get(Rbac.Repo.OktaUser, okta_user.id)
        user = Rbac.FrontRepo.get(Rbac.FrontRepo.User, okta_user.user_id)

        assert okta_user.state == :processed
        assert user.creation_source == :okta
        assert user.idempotency_token == "okta-user-#{okta_user.id}"
        assert user.single_org_user
        assert user.org_id == okta_user.org_id
      end
    end
  end

  describe "user creation idempotency" do
    test "when no user is associated with the okta user it creates a new user", ctx do
      with_mock Rbac.Events.UserCreated, publish: fn _, _ -> :ok end do
        assert user_count() == 0

        {:ok, okta_user} = create_pending_okta_user(ctx.integration)

        Rbac.Okta.Scim.Provisioner.perform_now(okta_user.id)
        :timer.sleep(500)

        assert user_count() == 1
      end
    end

    test "when user already exists, it connects that user", ctx do
      with_mock Rbac.Events.UserCreated, publish: fn _, _ -> :ok end do
        {:ok, okta_user} = create_pending_okta_user(ctx.integration)

        assert user_count() == 0

        Rbac.User.Actions.create(%{
          email: OktaUser.email(okta_user),
          name: OktaUser.name(okta_user),
          idempotency_token: "okta-user1-#{okta_user.id}",
          creation_source: :okta,
          single_org_user: true,
          org_id: okta_user.org_id
        })

        assert user_count() == 1

        Rbac.Okta.Scim.Provisioner.perform_now(okta_user.id)
        :timer.sleep(500)

        assert user_count() == 1
      end
    end
  end

  def create_pending_okta_user(integration) do
    username = "user#{:rand.uniform(1000)}@renderedtext.com"

    payload = %{
      "active" => true,
      "displayName" => "Igor Sarcevic",
      "emails" => [
        %{
          "primary" => true,
          "type" => "work",
          "value" => username
        }
      ],
      "externalId" => "00u207apm0oRvgHEE697",
      "groups" => [],
      "locale" => "en-US",
      "name" => %{"familyName" => "Sarcevic", "givenName" => "Igor"},
      "password" => "HaMfe17v",
      "schemas" => ["urn:ietf:params:scim:schemas:core:2.0:User"],
      "userName" => username
    }

    Rbac.Repo.OktaUser.create(integration, payload)
  end

  def user_count do
    Rbac.FrontRepo.aggregate(Rbac.FrontRepo.User, :count, :id)
  end
end
