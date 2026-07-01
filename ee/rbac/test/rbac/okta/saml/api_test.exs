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

      wait_for_saml_jit_user_processed(ctx.integration, "denis@example.com")

      {:ok, response} = post("/okta/auth", saml_payload("denis@example.com"))
      location = Enum.find(response.headers, fn h -> elem(h, 0) == "location" end)
      assert response.status_code == 302
      assert location == {"location", "https://me.localhost/account/welcome/okta"}
    end

    test "valid SAML re-adds an existing JIT user who is no longer part of the organization",
         ctx do
      alias Rbac.Events.UserJoinedOrganization

      enable_jit_provisioning(ctx.integration)

      with_mocks [{UserJoinedOrganization, [], [publish: fn _, _ -> :ok end]}] do
        {:ok, saml_jit_user} =
          Rbac.Repo.SamlJitUser.create(ctx.integration, "denis@example.com", %{
            "firstName" => ["Denis"],
            "lastName" => ["Tapia"]
          })

        {:ok, saml_jit_user} = Rbac.Okta.Saml.JitProvisioner.AddUser.run(saml_jit_user)

        {:ok, rbi} =
          Rbac.RoleBindingIdentification.new(
            user_id: saml_jit_user.user_id,
            org_id: @org_id,
            project_id: :is_nil
          )

        {:ok, nil} = Rbac.RoleManagement.retract_roles(rbi)

        refute Rbac.RoleManagement.user_part_of_org?(saml_jit_user.user_id, @org_id)

        {:ok, response} = post("/okta/auth", saml_payload("denis@example.com"))

        assert response.status_code == 302
        assert Rbac.RoleManagement.user_part_of_org?(saml_jit_user.user_id, @org_id)
        assert_called_exactly(UserJoinedOrganization.publish(saml_jit_user.user_id, @org_id), 2)
      end
    end

    test "valid SAML re-provisions a removed JIT user using current assertion claims, not stale stored ones",
         ctx do
      alias Rbac.Events.UserJoinedOrganization

      enable_jit_provisioning(ctx.integration)

      {:ok, admin} = Rbac.Repo.RbacRole.get_role_by_name("Admin", "org_scope", @org_id)
      {:ok, member} = Rbac.Repo.RbacRole.get_role_by_name("Member", "org_scope", @org_id)

      Support.Factories.IdpGroupMapping.insert(
        organization_id: @org_id,
        default_role_id: member.id,
        role_mapping: [%{idp_role_id: "admins", semaphore_role_id: admin.id}]
      )

      with_mocks [{UserJoinedOrganization, [], [publish: fn _, _ -> :ok end]}] do
        # First login: IdP grants an elevated role that maps to Admin.
        {:ok, saml_jit_user} =
          Rbac.Repo.SamlJitUser.create(ctx.integration, "denis@example.com", %{
            "role" => ["admins"]
          })

        {:ok, saml_jit_user} = Rbac.Okta.Saml.JitProvisioner.AddUser.run(saml_jit_user)

        assert_org_role(saml_jit_user.user_id, @org_id, "Admin")

        # The user is removed from the organization.
        {:ok, rbi} =
          Rbac.RoleBindingIdentification.new(
            user_id: saml_jit_user.user_id,
            org_id: @org_id,
            project_id: :is_nil
          )

        {:ok, nil} = Rbac.RoleManagement.retract_roles(rbi)
        refute Rbac.RoleManagement.user_part_of_org?(saml_jit_user.user_id, @org_id)

        # Re-login after the IdP downgraded the user (role no longer maps to Admin).
        {:ok, response} =
          post("/okta/auth", saml_payload("denis@example.com", :okta, [{"role", "members"}]))

        assert response.status_code == 302
        assert Rbac.RoleManagement.user_part_of_org?(saml_jit_user.user_id, @org_id)

        # The re-added user gets the CURRENT (downgraded) role, never the stale elevated one.
        assert_org_role(saml_jit_user.user_id, @org_id, "Member")
        refute_org_role(saml_jit_user.user_id, @org_id, "Admin")

        # Stored attributes were refreshed from the current assertion before re-provisioning.
        {:ok, refreshed} =
          Rbac.Repo.SamlJitUser.find_by_email(ctx.integration, "denis@example.com")

        assert refreshed.attributes == %{"role" => ["members"]}
      end
    end

    test "rapid re-add logins do not enqueue duplicate group add requests", ctx do
      import Ecto.Query
      alias Rbac.Events.UserJoinedOrganization

      enable_jit_provisioning(ctx.integration)

      {:ok, group1} = Support.Factories.Group.insert(organization_id: @org_id)
      {:ok, member} = Rbac.Repo.RbacRole.get_role_by_name("Member", "org_scope", @org_id)

      Support.Factories.IdpGroupMapping.insert(
        organization_id: @org_id,
        default_role_id: member.id,
        group_mapping: [%{idp_group_id: "g1", semaphore_group_id: group1.id}]
      )

      with_mocks [{UserJoinedOrganization, [], [publish: fn _, _ -> :ok end]}] do
        {:ok, saml_jit_user} =
          Rbac.Repo.SamlJitUser.create(ctx.integration, "denis@example.com", %{"member" => ["g1"]})

        # Initial provision queues exactly one :add_user request for the group.
        {:ok, saml_jit_user} = Rbac.Okta.Saml.JitProvisioner.AddUser.run(saml_jit_user)

        {:ok, rbi} =
          Rbac.RoleBindingIdentification.new(
            user_id: saml_jit_user.user_id,
            org_id: @org_id,
            project_id: :is_nil
          )

        {:ok, nil} = Rbac.RoleManagement.retract_roles(rbi)
        refute Rbac.RoleManagement.user_part_of_org?(saml_jit_user.user_id, @org_id)

        # Two rapid re-add logins must not pile on additional :add_user requests.
        {:ok, r1} =
          post("/okta/auth", saml_payload("denis@example.com", :okta, [{"member", "g1"}]))

        {:ok, r2} =
          post("/okta/auth", saml_payload("denis@example.com", :okta, [{"member", "g1"}]))

        assert r1.status_code == 302
        assert r2.status_code == 302

        add_user_requests =
          Rbac.Repo.GroupManagementRequest
          |> where([r], r.user_id == ^saml_jit_user.user_id and r.action == :add_user)
          |> Rbac.Repo.aggregate(:count)

        assert add_user_requests == 1
      end
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

    test "on login it embeds expires_at based on integration session minutes", ctx do
      ctx.integration
      |> Rbac.Repo.OktaIntegration.changeset(%{session_expiration_minutes: 5})
      |> Rbac.Repo.update!()

      assert {:ok, okta_user} = create_okta_user(ctx.integration, "denis@example.com")
      assert :ok = create_user(okta_user)

      started_at = DateTime.utc_now()

      {:ok, response} = post("/okta/auth", saml_payload("denis@example.com"))

      cookie = Enum.find(response.headers, fn h -> elem(h, 0) == "set-cookie" end)
      cookie_value = elem(cookie, 1)

      session_cookie =
        cookie_value
        |> String.split(";")
        |> List.first()
        |> String.split("=", parts: 2)
        |> List.last()

      values = Rbac.Session.decrypt_cookie(session_cookie)
      expires_at = normalize_expires_at(values["expires_at"])

      expected = DateTime.to_unix(started_at) + 5 * 60
      assert abs(expires_at - expected) <= 10
    end

    test "redirect links work when present in cookie", ctx do
      assert_redirect_to_settings(ctx, with_repo_host_account: true)
    end

    test "redirect links work when present in cookie without repo host account", ctx do
      assert_redirect_to_settings(ctx, with_repo_host_account: false)
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

  defp assert_redirect_to_settings(ctx, opts) do
    with_repo_host_account = Keyword.get(opts, :with_repo_host_account, false)

    assert {:ok, okta_user} = create_okta_user(ctx.integration, "denis@example.com")
    assert :ok = create_user(okta_user)

    if with_repo_host_account do
      okta_user = reload_okta_user(okta_user.id)
      {:ok, _} = create_github_connection(okta_user)
    end

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

    wait_for_okta_user_processed(okta_user.id)

    :ok
  end

  defp wait_for_okta_user_processed(okta_user_id) do
    Support.Wait.run("Waiting for #{okta_user_id} to be processed", 30, 200, fn ->
      case Rbac.Repo.get(Rbac.Repo.OktaUser, okta_user_id) do
        nil ->
          false

        okta_user ->
          okta_user.user_id != nil and okta_user.state == :processed and
            Rbac.FrontRepo.get(Rbac.FrontRepo.User, okta_user.user_id) != nil
      end
    end)
  end

  defp wait_for_saml_jit_user_processed(integration, email) do
    Support.Wait.run("Waiting for JIT user #{email} to be processed", 30, 200, fn ->
      case Rbac.Repo.SamlJitUser.find_by_email(integration, email) do
        {:ok, saml_user} ->
          saml_user.user_id != nil and saml_user.state == :processed and
            Rbac.FrontRepo.get(Rbac.FrontRepo.User, saml_user.user_id) != nil

        {:error, :not_found} ->
          false
      end
    end)
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

  defp saml_payload(email, issuer \\ :okta, attributes \\ []) do
    domain = Application.get_env(:rbac, :base_domain)

    Support.Okta.Saml.PayloadBuilder.build(
      %{
        recipient: "https://#{@org_username}.#{domain}/okta/auth",
        audience: "https://#{@org_username}.#{domain}",
        issuer: @okta_issuer,
        email: email,
        attributes: attributes
      },
      issuer
    )
  end

  defp assert_org_role(user_id, org_id, role_name),
    do: assert(org_role_assigned?(user_id, org_id, role_name))

  defp refute_org_role(user_id, org_id, role_name),
    do: refute(org_role_assigned?(user_id, org_id, role_name))

  defp org_role_assigned?(user_id, org_id, role_name) do
    import Ecto.Query

    {:ok, role} = Rbac.Repo.RbacRole.get_role_by_name(role_name, "org_scope", org_id)

    Rbac.Repo.SubjectRoleBinding
    |> where(
      [s],
      s.subject_id == ^user_id and s.org_id == ^org_id and s.role_id == ^role.id and
        is_nil(s.project_id)
    )
    |> Rbac.Repo.exists?()
  end

  defp reload_okta_user(okta_user_id) do
    Rbac.Repo.get(Rbac.Repo.OktaUser, okta_user_id)
  end

  defp normalize_expires_at(value) when is_integer(value), do: value

  defp normalize_expires_at(value) when is_binary(value) do
    {parsed, _} = Integer.parse(value)
    parsed
  end
end
