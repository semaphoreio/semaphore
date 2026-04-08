defmodule Rbac.Okta.Scim.Api.Test do
  use Rbac.RepoCase, async: false

  import Mock

  @port 4002
  @host "http://localhost:#{@port}"
  @org_id Ecto.UUID.generate()
  @creator_id Ecto.UUID.generate()
  @sso_url "http://www.okta.com/sso_endpoint"
  @okta_issuer "http://www.okta.com/exk207czditgMeFGI697"

  @headers [
    "Content-Type": "application/json",
    "x-semaphore-org-id": @org_id
  ]

  setup_with_mocks([
    {Rbac.Api.Organization, [],
     [
       find_by_id: fn _ -> {:ok, %{allowed_id_providers: []}} end,
       update: fn _ -> {:ok, %{}} end
     ]}
  ]) do
    Rbac.FrontRepo.delete_all(Rbac.FrontRepo.User)

    Support.Rbac.create_org_roles(@org_id)
    Support.Rbac.create_project_roles(@org_id)

    {:ok, provisioner} = Rbac.Okta.Scim.Provisioner.start_link()
    on_exit(fn -> Process.exit(provisioner, :kill) end)
  end

  describe "healthcheck endpoints" do
    test "GET /" do
      {:ok, response} = get("/", "")

      assert response.status_code == 200
    end

    test "GET /is_alive" do
      {:ok, response} = get("/is_alive", "")

      assert response.status_code == 200
    end
  end

  describe "authorization" do
    test "unauthorized okta calls return 401" do
      base_path = "#{@host}/okta/scim/Users"
      headers = @headers

      nil_org_id_headers = [
        "Content-Type": "application/json"
      ]

      assert {:ok, resp} = HTTPoison.get(base_path, nil_org_id_headers)
      assert resp.status_code == 401

      assert {:ok, resp} = HTTPoison.get(base_path, headers)
      assert resp.status_code == 401

      assert {:ok, resp} = HTTPoison.post(base_path, "", headers)
      assert resp.status_code == 401

      assert {:ok, resp} = HTTPoison.get("#{base_path}/#{Ecto.UUID.generate()}", headers)
      assert resp.status_code == 401

      assert {:ok, resp} = HTTPoison.put("#{base_path}/#{Ecto.UUID.generate()}", "", headers)
      assert resp.status_code == 401
    end
  end

  describe "GET /Users" do
    setup do
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

      {:ok, token} = Rbac.Okta.Integration.generate_scim_token(integration)

      {:ok, %{integration: integration, token: token}}
    end

    test "no users", %{token: token} do
      assert {:ok, resp} = get("/okta/scim/Users", token, %{"startIndex" => 1, "count" => 10})
      assert resp.status_code == 200

      body = Jason.decode!(resp.body)
      assert body["schemas"] == ["urn:ietf:params:scim:api:messages:2.0:ListResponse"]
      assert body["totalResults"] == 0
      assert body["startIndex"] == 1
      assert body["itemsPerPage"] == 0
      assert body["Resources"] == []
    end

    test "multiple users", %{token: token} do
      create_user(token)
      create_user(token)
      create_user(token)

      assert {:ok, resp} = get("/okta/scim/Users", token, %{"startIndex" => 1, "count" => 10})
      assert resp.status_code == 200

      body = Jason.decode!(resp.body)
      assert body["schemas"] == ["urn:ietf:params:scim:api:messages:2.0:ListResponse"]
      assert body["totalResults"] == 3
      assert body["startIndex"] == 1
      assert body["itemsPerPage"] == 3
      assert length(body["Resources"]) == 3
    end

    test "listing with username filter", %{token: token} do
      create_user(token)
      create_user(token)

      username = create_user(token)["userName"]

      assert {:ok, resp} =
               get("/okta/scim/Users", token, %{
                 "startIndex" => 1,
                 "count" => 10,
                 "filter" => "userName eq \"#{username}\""
               })

      assert resp.status_code == 200

      body = Jason.decode!(resp.body)
      assert body["schemas"] == ["urn:ietf:params:scim:api:messages:2.0:ListResponse"]
      assert body["totalResults"] == 1
      assert body["startIndex"] == 1
      assert body["itemsPerPage"] == 1
      assert length(body["Resources"]) == 1
      assert Enum.at(body["Resources"], 0)["userName"] == username
    end
  end

  describe "GET /Users/:id" do
    setup do
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

      {:ok, token} = Rbac.Okta.Integration.generate_scim_token(integration)

      {:ok, %{integration: integration, token: token}}
    end

    test "user does not exists", %{token: token} do
      assert {:ok, resp} = get("/okta/scim/Users/#{Ecto.UUID.generate()}", token)
      assert resp.status_code == 404

      body = Jason.decode!(resp.body)

      assert body["detail"] == "User not found"
      assert body["schemas"] == ["urn:ietf:params:scim:api:messages:2.0:Error"]
      assert body["status"] == 404
    end

    test "user exists", %{token: token} do
      user = create_user(token)
      user_id = user["id"]

      assert {:ok, resp} = get("/okta/scim/Users/#{user_id}", token)
      assert resp.status_code == 200

      body = Jason.decode!(resp.body)

      assert body["userName"] == user["userName"]
    end
  end

  describe "POST /Users" do
    setup do
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

      {:ok, token} = Rbac.Okta.Integration.generate_scim_token(integration)
      {:ok, %{integration: integration, token: token}}
    end

    test "creating a new user", %{token: token} do
      response = create_user(token)

      assert response["id"] != nil
    end

    test "when user with that email already exists, just connect it to the okta account", %{
      token: token
    } do
      alias Rbac.Events.UserJoinedOrganization

      with_mocks [{UserJoinedOrganization, [], [publish: fn _, _ -> :ok end]}] do
        user_email = "user#{:rand.uniform(1000)}@renderedtext.com"
        user_id = Ecto.UUID.generate()

        {:ok, u} =
          %Rbac.FrontRepo.User{id: user_id, email: user_email, name: "Mark"}
          |> Rbac.FrontRepo.insert()

        Support.Factories.RbacUser.insert(u.id, u.name, u.email)
        assign_admin_role(user_id, @org_id)

        response = create_user(token, user_email)

        # Check that no new users were created
        assert Rbac.Repo.RbacUser |> Rbac.Repo.aggregate(:count, :id) == 1
        assert Rbac.FrontRepo.User |> Rbac.FrontRepo.aggregate(:count, :id) == 1

        {:ok, user} = find_user(user_id)
        assert user.idempotency_token != nil

        okta_user = load_okta_user(response["id"])
        assert okta_user.user_id == user.id

        # Check if assigned role wasn't overwritten
        assert fetch_assigned_role(user_id, @org_id) == "Admin"
        assert_not_called(UserJoinedOrganization.publish(:_))
      end
    end

    test "after a new user is created it associates it with a real user", ctx do
      response = create_user(ctx.token)

      assert {:ok, okta_user} = Rbac.Okta.Integration.find_user(ctx.integration, response["id"])
      assert okta_user.user_id != nil
      assert okta_user.state == :processed

      assert {:ok, user} = find_user(okta_user.user_id)
      assert user.name == Rbac.Repo.OktaUser.name(okta_user)
      assert user.email == Rbac.Repo.OktaUser.email(okta_user)
      assert user.remember_created_at != nil
      assert user.salt != nil
      assert user.org_id == okta_user.org_id
      assert user.idempotency_token == "okta-user-#{okta_user.id}"
      assert user.creation_source == :okta
      assert user.single_org_user
    end

    test "after a new user is created it is assigned the member role in the organization", ctx do
      alias Rbac.Events.UserJoinedOrganization

      with_mocks [{UserJoinedOrganization, [], [publish: fn _, _ -> :ok end]}] do
        response = create_user(ctx.token)

        assert {:ok, okta_user} = Rbac.Okta.Integration.find_user(ctx.integration, response["id"])

        assert okta_user.user_id != nil
        assert okta_user.state == :processed
        assert registered_in_rbac?(okta_user)
        assert has_role?(okta_user, "Member")

        assert_called_exactly(
          UserJoinedOrganization.publish(okta_user.user_id, okta_user.org_id),
          1
        )
      end
    end
  end

  describe "PUT /Users/:id" do
    setup do
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

      {:ok, token} = Rbac.Okta.Integration.generate_scim_token(integration)

      {:ok, %{integration: integration, token: token}}
    end

    test "update user details", ctx do
      user = create_user(ctx.token)

      ###
      ### Assign Admin role
      ###
      alias Rbac.Repo.RbacRole

      {:ok, admin_role} = RbacRole.get_role_by_name("Admin", "org_scope", @org_id)

      okta_user = load_okta_user(user["id"])
      Support.Rbac.assign_org_role(@org_id, okta_user.user_id, admin_role)

      user = put_in(user, ["emails", Access.at(0), "value"], "updated-email@example.org")
      user = put_in(user, ["displayName"], "Veljko Maksimovic")

      assert {:ok, resp} = put("/okta/scim/Users/#{user["id"]}", user, ctx.token)
      assert resp.status_code == 200

      wait_for_provisioner_to_finish(user["id"])
      okta_user = load_okta_user(user["id"])

      assert {:ok, user} = find_user(okta_user.user_id)
      assert user.name == "Veljko Maksimovic"
      assert user.email == "updated-email@example.org"

      assert okta_user.email == "updated-email@example.org"
      ###
      ### Check that admin role wasn't overwritten
      ###
      assert has_role?(okta_user, "Admin")
    end

    test "deactivate a user when created by okta", ctx do
      alias Rbac.Repo.RbacRole
      alias Rbac.Events.UserLeftOrganization

      with_mocks [{UserLeftOrganization, [], [publish: fn _, _ -> :ok end]}] do
        response = create_user(ctx.token)
        user_id = response["id"]

        wait_for_provisioner_to_finish(user_id)
        :timer.sleep(500)
        project_id = Ecto.UUID.generate()

        okta_user = load_okta_user(user_id)

        {:ok, contributor_role} =
          RbacRole.get_role_by_name("Contributor", "project_scope", @org_id)

        Support.Rbac.assign_project_role(@org_id, okta_user.user_id, project_id, contributor_role)

        assert has_role?(okta_user, "Member")
        assert has_role?(okta_user, "Contributor", project_id)
        assert response["active"] == true

        user = Map.put(response, "active", false)
        assert {:ok, resp} = put("/okta/scim/Users/#{user_id}", user, ctx.token)
        assert resp.status_code == 200

        body = Jason.decode!(resp.body)

        assert body["active"] == false

        wait_for_provisioner_to_finish(user["id"])
        okta_user = load_okta_user(user["id"])

        assert {:ok, user} = find_user(okta_user.user_id)
        assert user.name == "Deactivated User #{String.slice(okta_user.id, 0..7)}"
        assert user.email == "deactivated-okta-user-#{okta_user.id}@#{okta_user.id}.com"
        assert user.deactivated
        assert user.deactivated_at != nil

        rbac_user = Rbac.Store.RbacUser.fetch(okta_user.user_id)
        assert rbac_user.name == "Deactivated User #{String.slice(okta_user.id, 0..7)}"
        assert rbac_user.email == "deactivated-okta-user-#{okta_user.id}@#{okta_user.id}.com"

        refute has_role?(okta_user, "Member")
        refute has_role?(okta_user, "Contributor", project_id)

        assert_called_exactly(UserLeftOrganization.publish(user.id, okta_user.org_id), 1)
      end
    end

    test "dont deactivate user when not created by okta", ctx do
      alias Rbac.Events.UserLeftOrganization

      with_mocks [{UserLeftOrganization, [], [publish: fn _, _ -> :ok end]}] do
        user_email = "user#{:rand.uniform(1000)}@renderedtext.com"
        user_id = Ecto.UUID.generate()

        {:ok, u} =
          %Rbac.FrontRepo.User{id: user_id, email: user_email, name: "Mark"}
          |> Rbac.FrontRepo.insert()

        Support.Factories.RbacUser.insert(u.id, u.name, u.email)

        response = create_user(ctx.token, user_email)
        user_id = response["id"]

        wait_for_provisioner_to_finish(user_id)

        assert response["active"] == true

        user = Map.put(response, "active", false)
        assert {:ok, resp} = put("/okta/scim/Users/#{user_id}", user, ctx.token)
        assert resp.status_code == 200

        body = Jason.decode!(resp.body)

        assert body["active"] == false

        wait_for_provisioner_to_finish(user["id"])
        okta_user = load_okta_user(user["id"])

        assert {:ok, user} = find_user(okta_user.user_id)
        assert user.email == user_email

        refute has_role?(okta_user, "Member")
        assert_not_called(UserLeftOrganization.publish(:_))
      end
    end

    test "reactivate a user", ctx do
      alias Rbac.Repo.OktaUser
      alias Rbac.Events.UserJoinedOrganization

      #
      # add user
      #
      response = create_user(ctx.token)
      okta_user = load_okta_user(response["id"])
      wait_for_provisioner_to_finish(okta_user.id)

      #
      # deactivate the user
      #
      user = Map.put(response, "active", false)
      assert {:ok, resp} = put("/okta/scim/Users/#{okta_user.id}", user, ctx.token)
      assert resp.status_code == 200

      wait_for_provisioner_to_finish(user["id"])
      assert {:ok, user} = find_user(okta_user.user_id)
      assert user.deactivated
      refute has_role?(okta_user, "Member")

      with_mocks [{UserJoinedOrganization, [], [publish: fn _, _ -> :ok end]}] do
        #
        # re-activate the user
        #
        user = Map.put(response, "active", true)
        assert {:ok, resp} = put("/okta/scim/Users/#{okta_user.id}", user, ctx.token)
        assert resp.status_code == 200

        wait_for_provisioner_to_finish(okta_user.id)
        okta_user = load_okta_user(okta_user.id)

        assert {:ok, user} = find_user(okta_user.user_id)
        assert user.name == OktaUser.name(okta_user)
        assert user.email == OktaUser.email(okta_user)

        rbac_user = Rbac.Store.RbacUser.fetch(user.id)
        assert rbac_user.name == OktaUser.name(okta_user)
        assert rbac_user.email == OktaUser.email(okta_user)

        refute user.deactivated
        assert user.deactivated_at == nil
        assert has_role?(okta_user, "Member")
        assert_called_exactly(UserJoinedOrganization.publish(user.id, okta_user.org_id), 1)
      end
    end
  end

  defp has_role?(okta_user, role_name, project_id \\ nil) do
    alias Rbac.RoleBindingIdentification
    alias Rbac.RoleManagement
    alias Rbac.Repo.RbacRole

    user_id = okta_user.user_id
    org_id = okta_user.org_id

    {:ok, rbi} =
      RoleBindingIdentification.new(user_id: user_id, org_id: org_id, project_id: project_id)

    scope = if is_nil(project_id), do: "org_scope", else: "project_scope"
    {:ok, role} = RbacRole.get_role_by_name(role_name, scope, okta_user.org_id)

    RoleManagement.has_role(rbi, role.id)
  end

  defp registered_in_rbac?(okta_user) do
    import Ecto.Query
    alias Rbac.Repo.{RbacUser, Subject, OktaUser}
    alias Rbac.Repo

    id = okta_user.user_id
    email = OktaUser.email(okta_user)
    name = OktaUser.name(okta_user)

    subject = Repo.one(from(s in Subject, where: s.id == ^id and s.name == ^name))

    user = Repo.one(from(u in RbacUser, where: u.id == ^id and u.email == ^email))

    subject != nil && user != nil
  end

  defp create_user(token, username \\ "user#{:rand.uniform(1000)}@renderedtext.com") do
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

    resp = post_with_retry("/okta/scim/Users", payload, token)
    body = Jason.decode!(resp.body)

    wait_for_provisioner_to_finish(body["id"])

    body
  end

  defp post_with_retry(path, payload, token, attempts \\ 5)

  defp post_with_retry(_path, _payload, _token, 0) do
    flunk("SCIM create user returned empty response body after retries")
  end

  defp post_with_retry(path, payload, token, attempts) do
    case post(path, payload, token) do
      {:ok, %HTTPoison.Response{status_code: status, body: body} = resp} ->
        cond do
          status in [200, 201] and body not in [nil, ""] ->
            resp

          status in [200, 201] ->
            :timer.sleep(100)
            post_with_retry(path, payload, token, attempts - 1)

          true ->
            flunk("Unexpected SCIM response status=#{status} body=#{inspect(body)}")
        end

      {:error, _error} ->
        :timer.sleep(100)
        post_with_retry(path, payload, token, attempts - 1)
    end
  end

  defp get(path, token, params \\ %{}) do
    HTTPoison.get("#{@host}#{path}?#{URI.encode_query(params)}", with_auth_headers(token))
  end

  defp post(path, body, token) do
    HTTPoison.post("#{@host}#{path}", Jason.encode!(body), with_auth_headers(token))
  end

  defp put(path, body, token) do
    HTTPoison.put("#{@host}#{path}", Jason.encode!(body), with_auth_headers(token))
  end

  defp with_auth_headers(token) do
    @headers ++ [Authorization: "Bearer #{token}"]
  end

  defp find_user(user_id) do
    require Ecto.Query

    alias Rbac.FrontRepo
    alias Rbac.FrontRepo.User
    alias Ecto.Query

    query = Query.where(User, id: ^user_id)

    case FrontRepo.one(query) do
      nil -> {:error, :not_found}
      user -> {:ok, user}
    end
  end

  defp wait_for_provisioner_to_finish(okta_user_id) do
    Support.Wait.run("Waiting for #{okta_user_id} to be processed", fn ->
      load_okta_user(okta_user_id).state == :processed
    end)
  end

  defp load_okta_user(okta_user_id) do
    Rbac.Repo.get(Rbac.Repo.OktaUser, okta_user_id)
  end

  defp assign_admin_role(user_id, org_id) do
    with(
      {:ok, rbi} <- Rbac.RoleBindingIdentification.new(user_id: user_id, org_id: org_id),
      {:ok, role} <- Rbac.Repo.RbacRole.get_role_by_name("Admin", "org_scope", org_id)
    ) do
      Rbac.RoleManagement.assign_role(rbi, role.id, :okta)
    end
  end

  defp fetch_assigned_role(user_id, org_id) do
    with(
      {:ok, rbi} <- Rbac.RoleBindingIdentification.new(user_id: user_id, org_id: org_id),
      {[srb], _total_pages} <- Rbac.RoleManagement.fetch_subject_role_bindings(rbi),
      [role_binding | _] <- srb.role_bindings,
      rbac_role <- Rbac.Repo.RbacRole.get_role_by_id(role_binding["role_id"])
    ) do
      rbac_role.name
    end
  end
end
