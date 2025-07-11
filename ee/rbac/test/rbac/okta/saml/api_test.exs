defmodule Rbac.Okta.Saml.Api.Test do
  use Rbac.RepoCase, async: false
  import Mock

  @port 4001
  @host "http://localhost:#{@port}"
  @org_id Ecto.UUID.generate()
  @org_username "testing123"
  @okta_issuer "http://www.okta.com/exk207czditgMeFGI697"

  @headers [
    "Content-Type": "application/x-www-form-urlencoded",
    "x-semaphore-org-id": @org_id,
    "x-semaphore-org-username": @org_username
  ]

  setup do
    Support.Rbac.create_org_roles(@org_id)
    {:ok, provisioner} = Rbac.Okta.Scim.Provisioner.start_link()

    on_exit(fn -> Process.exit(provisioner, :kill) end)
  end

  describe "healthcheck endpoints" do
    test "GET /" do
      {:ok, response} = get("/")

      assert response.status_code == 200
    end

    test "GET /is_alive" do
      {:ok, response} = get("/is_alive")

      assert response.status_code == 200
    end
  end

  describe "/okta/auth" do
    setup do
      {:ok, integration} = Support.Factories.OktaIntegration.insert(org_id: @org_id)
      {:ok, %{integration: integration}}
    end

    test "valid SAML but user does not exist, JIT provisioning disabled" do
      {:ok, response} = post("/okta/auth", saml_payload("denis@example.com"))

      assert response.status_code == 404
    end

    test "valid SAML but user does not exist, JIT provisioning enabled", ctx do
      alias Rbac.Events.UserJoinedOrganization

      enable_jit_provisioning(ctx.integration)

      with_mocks [{UserJoinedOrganization, [], [publish: fn _, _ -> :ok end]}] do
        {:ok, response} = post("/okta/auth", saml_payload("denis@example.com"))
        assert response.status_code == 200
        assert response.body == "User provisioning started, try again in a minute"
      end

      {:ok, response} = post("/okta/auth", saml_payload("denis@example.com"))
      location = Enum.find(response.headers, fn h -> elem(h, 0) == "location" end)
      assert response.status_code == 302
      assert location == {"location", "https://me.localhost/account/welcome/okta"}
    end

    test "valid SAML, okta user exists, but semaphore user does not", ctx do
      assert {:ok, _} = create_okta_user(ctx.integration, "denis@example.com")

      {:ok, response} = post("/okta/auth", saml_payload("denis@example.com"))

      assert response.status_code == 404
    end

    test "valid SAML, okta user exists, semaphore user exists", ctx do
      assert {:ok, okta_user} = create_okta_user(ctx.integration, "denis@example.com")
      assert :ok = create_user(okta_user)

      {:ok, response} = post("/okta/auth", saml_payload("denis@example.com"))

      assert response.status_code == 302

      location = Enum.find(response.headers, fn h -> elem(h, 0) == "location" end)

      assert location == {"location", "https://me.localhost/account/welcome/okta"}
    end

    test "valid SAML, okta user exists, semaphore user exists, semaphore user has github account",
         ctx do
      assert {:ok, okta_user} = create_okta_user(ctx.integration, "denis@example.com")
      assert :ok = create_user(okta_user)

      okta_user = reload_okta_user(okta_user.id)
      {:ok, _} = create_github_connection(okta_user)

      {:ok, response} = post("/okta/auth", saml_payload("denis@example.com"))

      assert response.status_code == 302

      location = Enum.find(response.headers, fn h -> elem(h, 0) == "location" end)

      assert location == {"location", "/"}
    end

    test "after user logs out, okta login is able to log back in", ctx do
      assert {:ok, okta_user} = create_okta_user(ctx.integration, "denis@example.com")
      assert :ok = create_user(okta_user)

      #
      # when a user logs out, the remember_created_at is set to NULL
      # in order to successfully log back in, the remember_created_at must be not NULL
      # and the current time must be bigger than the timestampt
      #
      # Every Okta login should set this remember_created_at to a real value
      #
      okta_user = reload_okta_user(okta_user.id)
      user = load_user(okta_user.user_id) |> log_out_user()

      assert user.remember_created_at == nil

      {:ok, _response} = post("/okta/auth", saml_payload("denis@example.com"))

      user = load_user(okta_user.user_id)
      assert user.remember_created_at != nil
    end

    test "on login it sets the session cookie", ctx do
      assert {:ok, okta_user} = create_okta_user(ctx.integration, "denis@example.com")
      assert :ok = create_user(okta_user)

      {:ok, response} = post("/okta/auth", saml_payload("denis@example.com"))

      cookie = Enum.find(response.headers, fn h -> elem(h, 0) == "set-cookie" end)

      assert cookie != nil

      cookie_value = elem(cookie, 1)
      cookie_parts = String.split(cookie_value, "; ")

      assert Enum.at(cookie_parts, 0) =~ ~r/_sxtesting_session=.*/
      assert Enum.at(cookie_parts, 1) == "path=/"
      assert Enum.at(cookie_parts, 2) == "domain=.localhost"
      assert Enum.at(cookie_parts, 3) == "secure"
      assert Enum.at(cookie_parts, 4) == "HttpOnly"
    end

    test "redirect links work when present in cookie", ctx do
      assert {:ok, okta_user} = create_okta_user(ctx.integration, "denis@example.com")
      assert :ok = create_user(okta_user)

      okta_user = reload_okta_user(okta_user.id)
      {:ok, _} = create_github_connection(okta_user)

      with_mocks([
        {Rbac.Utils.Http, [:passthrough],
         [fetch_redirect_value: fn _, _ -> "#{@host}/settings" end]}
      ]) do
        {:ok, response} = post("/okta/auth", saml_payload("denis@example.com"))

        assert response.status_code == 302

        location = Enum.find(response.headers, fn h -> elem(h, 0) == "location" end)

        assert location == {"location", "#{@host}/settings"}
      end
    end
  end

  ###
  ### Helper functions
  ###

  defp enable_jit_provisioning(integration) do
    integration
    |> Rbac.Repo.OktaIntegration.changeset(%{jit_provisioning_enabled: true})
    |> Rbac.Repo.update!()
  end

  defp log_out_user(user) do
    cs = Rbac.FrontRepo.User.changeset(user, %{remember_created_at: nil})
    {:ok, user} = Rbac.FrontRepo.update(cs)
    user
  end

  defp create_okta_user(integration, email) do
    Rbac.Repo.OktaUser.create(integration, %{
      "active" => true,
      "displayName" => "Denis Tapia",
      "emails" => [
        %{
          "primary" => true,
          "type" => "work",
          "value" => email
        }
      ]
    })
  end

  defp create_user(okta_user) do
    Rbac.Okta.Scim.Provisioner.perform_now(okta_user.id)

    Support.Wait.run("Waiting for #{okta_user.id} to be processed", fn ->
      Rbac.Repo.get(Rbac.Repo.OktaUser, okta_user.id).user_id != nil
    end)

    :ok
  end

  defp load_user(user_id) do
    Rbac.FrontRepo.get(Rbac.FrontRepo.User, user_id)
  end

  def create_github_connection(okta_user) do
    %Rbac.FrontRepo.RepoHostAccount{
      login: "pegasus",
      github_uid: "1",
      repo_host: "github",
      user_id: okta_user.user_id
    }
    |> Rbac.FrontRepo.insert()
  end

  defp get(path) do
    HTTPoison.get("#{@host}#{path}", @headers)
  end

  defp post(path, body, headers \\ [], opts \\ []) do
    HTTPoison.post("#{@host}#{path}", body, @headers ++ headers, opts)
  end

  defp saml_payload(email, issuer \\ :okta) do
    domain = Application.get_env(:rbac, :base_domain)

    Support.Okta.Saml.PayloadBuilder.build(
      %{
        recipient: "https://#{@org_username}.#{domain}/okta/auth",
        audience: "https://#{@org_username}.#{domain}",
        issuer: @okta_issuer,
        email: email
      },
      issuer
    )
  end

  defp reload_okta_user(okta_user_id) do
    Rbac.Repo.get(Rbac.Repo.OktaUser, okta_user_id)
  end
end
