defmodule Guard.Id.Api.Test do
  import Tesla.Mock

  use Guard.RepoCase, async: false
  doctest Guard.Id.Api, import: true

  use Plug.Test

  @port 4003
  @host "http://localhost:#{@port}"

  setup do
    FunRegistry.clear!()
    Guard.FakeServers.setup_responses_for_development()

    Support.Guard.Store.clear!()
    Guard.FrontRepo.delete_all(Guard.FrontRepo.User)

    :ok
  end

  describe "Health Checks" do
    test "Pod Health Check" do
      {:ok, response} = send_login_request(path: "/is_alive")
      assert response.status_code == 200
    end
  end

  describe "/oauth/:provider" do
    test "404 for non existing provider" do
      {:ok, response} = send_login_request(path: "/oauth/foo")

      assert response.status_code == 404
    end

    test "301 to github for github provider" do
      {:ok, response} = send_login_request(path: "/oauth/github")

      assert response.status_code == 302

      assert response.body =~
               "https://github.com/login/oauth/authorize?client_id=github_client_id"
    end

    test "301 to bitbucket for bitbucket provider" do
      {:ok, response} = send_login_request(path: "/oauth/bitbucket")

      assert response.status_code == 302

      assert response.body =~
               "https://bitbucket.org/site/oauth2/authorize?client_id=bitbucket_client_id"
    end

    test "301 to gitlab for gitlab provider" do
      {:ok, response} = send_login_request(path: "/oauth/gitlab")

      assert response.status_code == 302

      assert response.body =~
               "https://gitlab.com/oauth/authorize?client_id=gitlab_client_id"
    end

    test "redirect_to query param present" do
      {:ok, response} =
        send_login_request(
          path: "/oauth/github",
          query: %{redirect_to: "https://#{domain()}/foo"}
        )

      {_, cookie} = Enum.find(response.headers, fn h -> elem(h, 0) == "set-cookie" end)

      assert response.status_code == 302

      assert response.body =~
               "https://github.com/login/oauth/authorize?client_id=github_client_id"

      assert cookie =~ "semaphore_redirect_to="
    end
  end

  describe "/oauth/:provider without ueberauth credentials" do
    setup do
      oauth_creds = Application.get_env(:ueberauth, Ueberauth.Strategy.Github.OAuth)
      Application.put_env(:ueberauth, Ueberauth.Strategy.Github.OAuth, [])
      Cachex.clear(:config_cache)

      on_exit(fn ->
        Application.put_env(:ueberauth, Ueberauth.Strategy.Github.OAuth, oauth_creds)
      end)

      :ok
    end

    test "400 when instance config is empty" do
      {:ok, response} = send_login_request(path: "/oauth/github")

      assert response.status_code == 500
    end

    test "302 when instance config can fetch" do
      setup_integration()
      {:ok, response} = send_login_request(path: "/oauth/github")

      assert response.status_code == 302

      assert response.body =~
               "https://github.com/login/oauth/authorize?client_id=github_app_client_id"

      cleanup_integration()
    end

    defp setup_integration do
      Guard.Mocks.GithubAppApi.github_app_api()
      Application.put_env(:guard, :include_instance_config, true)

      private_key = JOSE.JWK.generate_key({:rsa, 1024})
      {_, pem_private_key} = JOSE.JWK.to_pem(private_key)

      Guard.InstanceConfig.Models.Config.changeset(%Guard.InstanceConfig.Models.Config{}, %{
        name: :CONFIG_TYPE_GITHUB_APP |> Atom.to_string(),
        config: %{
          app_id: "3213",
          slug: "slug",
          name: "name",
          client_id: "github_app_client_id",
          client_secret: "client_secret",
          pem: pem_private_key,
          html_url: "https://github.com",
          webhook_secret: "webhook_secret"
        }
      })
      |> Guard.InstanceConfig.Store.set()
    end

    defp cleanup_integration do
      Application.put_env(:guard, :include_instance_config, false)
      Guard.InstanceConfig.Store.delete(:CONFIG_TYPE_GITHUB_APP)
    end
  end

  describe "/oauth/:provider/callback" do
    setup do
      # Create a user thats already part of the organization, but does not have GH, Bitbucket, nor GitLab connected yet.
      # User's GH account is also already a collaborator on an existing project

      [user_id, org_id, project_id, gh_uid] = Enum.map(1..4, fn _ -> Ecto.UUID.generate() end)

      {:ok, _front_user} = Support.Factories.FrontUser.insert(id: user_id)
      {:ok, _rbac_user} = Support.Factories.RbacUser.insert(user_id)

      Support.Projects.insert(project_id: project_id, org_id: org_id)
      Support.Collaborators.insert(project_id: project_id, github_uid: gh_uid)

      %{
        user_id: user_id,
        org_id: org_id,
        project_id: project_id,
        gh_uid: gh_uid
      }
    end

    test "404 for non existing provider" do
      {:ok, response} = send_login_request(path: "/oauth/foo/callback")

      assert response.status_code == 404
    end

    test "400 for not authenticated user" do
      ["github", "bitbucket", "gitlab"]
      |> Enum.each(fn provider ->
        {:ok, response} = send_login_request(path: "/oauth/#{provider}/callback")

        assert response.status_code == 400
        assert response.body =~ "User is not authenticated"
      end)
    end

    test "error message when callback failed for github", %{user_id: user_id} do
      {:ok, response} =
        send_login_request(
          path: "/oauth/github/callback",
          headers: [{"x-semaphore-user-id", user_id}]
        )

      assert_callback_error_response(response)
    end

    test "error message when callback failed for bitbucket", %{user_id: user_id} do
      {:ok, response} =
        send_login_request(
          path: "/oauth/bitbucket/callback",
          headers: [{"x-semaphore-user-id", user_id}]
        )

      assert_callback_error_response(response)
    end

    test "error message when callback failed for gitlab", %{user_id: user_id} do
      {:ok, response} =
        send_login_request(
          path: "/oauth/gitlab/callback",
          headers: [{"x-semaphore-user-id", user_id}]
        )

      assert_callback_error_response(response)
    end

    test "success when callback pass for github", %{user_id: user_id, gh_uid: gh_uid} do
      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://github.com/login/oauth/access_token"} ->
          json(%{"access_token" => "token"})

        %{method: :get, url: "https://api.github.com/user"} ->
          json(%{"login" => "kjhdda", "name" => "Foo Bar", "id" => gh_uid})

        %{method: :get, url: "https://api.github.com/user/emails"} ->
          json([
            %{
              "email" => "kjhdda@example.com",
              "verified" => true,
              "primary" => true,
              "visibility" => "public"
            }
          ])
      end)

      {:ok, response} =
        send_login_request(
          path: "/oauth/github",
          query: %{redirect_to: "https://me.#{domain()}/foo/bar"},
          headers: [{"x-semaphore-user-id", user_id}]
        )

      {_, location} = Enum.find(response.headers, fn h -> elem(h, 0) == "location" end)

      cookies =
        Enum.filter(response.headers, fn h -> elem(h, 0) == "set-cookie" end)
        |> Enum.map(fn {_, cookie} -> {"cookie", cookie} end)

      schema = URI.parse(location)
      query = URI.decode_query(schema.query)

      {:ok, response} =
        send_login_request(
          path: "/oauth/github/callback",
          query: %{state: query["state"], code: "code"},
          headers:
            [
              {"x-semaphore-user-id", user_id}
            ]
            |> Enum.concat(cookies)
        )

      {_, location} = Enum.find(response.headers, fn h -> elem(h, 0) == "location" end)
      schema = URI.parse(location)
      query = URI.decode_query(schema.query)

      assert response.status_code == 302
      assert schema.host == "me.#{domain()}"
      assert schema.path == "/foo/bar"
      assert query["status"] == "success"
    end

    test "success when callback pass for gitlab", %{user_id: user_id} do
      Tesla.Mock.mock_global(fn
        %{method: :post, url: "https://gitlab.com/oauth/token"} ->
          json(%{"access_token" => "token"})

        %{method: :get, url: "https://gitlab.com/api/v4/user"} ->
          json(%{
            "username" => "kjhdda",
            "name" => "Foo Bar",
            "id" => Ecto.UUID.generate(),
            "location" => "localhost?state=foo"
          })

        %{method: :get, url: "https://gitlab.com/oauth/authorize"} ->
          json(%{"access_token" => "token"})
      end)

      {:ok, response} =
        send_login_request(
          path: "/oauth/gitlab",
          query: %{redirect_to: "https://me.#{domain()}/foo/bar"},
          headers: [{"x-semaphore-user-id", user_id}]
        )

      {_, location} = Enum.find(response.headers, fn h -> elem(h, 0) == "location" end)

      cookies =
        Enum.filter(response.headers, fn h -> elem(h, 0) == "set-cookie" end)
        |> Enum.map(fn {_, cookie} -> {"cookie", cookie} end)

      schema = URI.parse(location)
      query = URI.decode_query(schema.query)

      {:ok, response} =
        send_login_request(
          path: "/oauth/gitlab/callback",
          query: %{state: query["state"], code: "code"},
          headers:
            [
              {"x-semaphore-user-id", user_id}
            ]
            |> Enum.concat(cookies)
        )

      {_, location} = Enum.find(response.headers, fn h -> elem(h, 0) == "location" end)
      schema = URI.parse(location)
      query = URI.decode_query(schema.query)

      assert response.status_code == 302
      assert schema.host == "me.#{domain()}"
      assert schema.path == "/foo/bar"
      assert query["status"] == "success"
    end
  end

  describe "/login" do
    test "no request parameters" do
      {:ok, response} = send_login_request()

      assert response.status_code == 200
      assert response.body =~ "Log in to Semaphore"
    end

    test "redirect_to query param present" do
      {:ok, response} = send_login_request(query: %{redirect_to: "https://#{domain()}"})
      assert response.status_code == 200

      {_, cookie} = List.keyfind(response.headers, "set-cookie", 0)

      assert cookie =~ "semaphore_redirect_to="
      assert cookie =~ "domain=.localhost"
      assert cookie =~ "path=/"
      assert cookie =~ "SameSite=None"
    end

    test "redirect_to query param present, redirects to valid domain only" do
      {:ok, response} =
        send_login_request(query: %{redirect_to: "https://#{domain()}example.com"})

      assert response.status_code == 200

      cookie = List.keyfind(response.headers, "set-cookie", 0)

      refute cookie
    end

    test "redirect_to query param present, redirects to valid domain only, checks host only" do
      {:ok, response} =
        send_login_request(query: %{redirect_to: "https://example.com?foo=#{domain()}"})

      assert response.status_code == 200

      cookie = List.keyfind(response.headers, "set-cookie", 0)

      refute cookie
    end

    test "org_id is present, but that org does not have Okta integration" do
      FunRegistry.set!(
        Support.Fake.OrganizationService,
        :describe,
        InternalApi.Organization.DescribeResponse.new(
          status: Support.Factories.status_ok(),
          organization: Support.Factories.organization()
        )
      )

      {:ok, response} = send_login_request(query: %{org_id: Ecto.UUID.generate()})
      assert response.status_code == 200
      assert response.body =~ "Log in to Semaphore"
    end

    test "organization in question uses okta" do
      organization = Support.Factories.organization(allowed_id_providers: ["okta"])

      FunRegistry.set!(
        Support.Fake.OrganizationService,
        :describe,
        InternalApi.Organization.DescribeResponse.new(
          status: Support.Factories.status_ok(),
          organization: organization
        )
      )

      sso_url = "https://test_org.okta.com/asdf"

      {:ok, response} =
        send_login_request(
          query: %{org_id: organization.org_id, redirect_to: "https://me.#{domain()}"}
        )

      {_, location} = Enum.find(response.headers, fn h -> elem(h, 0) == "location" end)
      {_, cookie} = Enum.find(response.headers, fn h -> elem(h, 0) == "set-cookie" end)

      assert cookie =~ "semaphore_redirect_to="
      assert response.status_code == 302
      assert location == sso_url
    end
  end

  describe "root path /" do
    test "redirects to /login when no query params" do
      {:ok, response} = send_login_request(path: "/")

      assert response.status_code == 302
      {_, location} = Enum.find(response.headers, fn h -> elem(h, 0) == "location" end)
      assert location == "https://id.#{domain()}/login"
    end

    test "redirects to /login with query params preserved" do
      {:ok, response} = send_login_request(path: "/", query: %{foo: "bar", baz: "qux"})

      assert response.status_code == 302
      {_, location} = Enum.find(response.headers, fn h -> elem(h, 0) == "location" end)

      assert location == "https://id.#{domain()}/login?baz=qux&foo=bar"
    end
  end

  describe "/signup" do
    test "shows normal signup page when user is not logged in" do
      {:ok, response} = send_login_request(path: "/signup")

      assert response.status_code == 200
      assert response.body =~ "Get started - Semaphore"
      assert response.body =~ "Try Cloud"
      assert response.body =~ "Signup with GitHub"
      assert response.body =~ "Signup with Bitbucket"
      refute response.body =~ "You're already logged in"
      refute response.body =~ "Continue to"
    end

    test "shows logged-in version when user is already logged in" do
      user_id = Ecto.UUID.generate()
      {:ok, _front_user} = Support.Factories.FrontUser.insert(id: user_id)
      {:ok, _rbac_user} = Support.Factories.RbacUser.insert(user_id)

      {:ok, response} =
        send_login_request(path: "/signup", headers: [{"x-semaphore-user-id", user_id}])

      assert response.status_code == 200
      assert response.body =~ "Get started - Semaphore"
      assert response.body =~ "You're already logged in"
      assert response.body =~ "Continue to"
      assert response.body =~ "https://me.#{domain()}"
      refute response.body =~ "Try Cloud"
      refute response.body =~ "Signup with GitHub"
      refute response.body =~ "Signup with Bitbucket"
    end

    test "renders signup page correctly when redirect_to param is present" do
      {:ok, response} =
        send_login_request(path: "/signup", query: %{redirect_to: "https://#{domain()}"})

      assert response.status_code == 200
      assert response.body =~ "Get started - Semaphore"
      assert response.body =~ "Try Cloud"
      assert response.body =~ "Signup with GitHub"
      assert response.body =~ "Signup with Bitbucket"
    end

    test "shows correct page for logged-in user even with redirect_to param" do
      user_id = Ecto.UUID.generate()
      {:ok, _front_user} = Support.Factories.FrontUser.insert(id: user_id)
      {:ok, _rbac_user} = Support.Factories.RbacUser.insert(user_id)

      {:ok, response} =
        send_login_request(
          path: "/signup",
          query: %{redirect_to: "https://#{domain()}"},
          headers: [{"x-semaphore-user-id", user_id}]
        )

      assert response.status_code == 200
      assert response.body =~ "You're already logged in"
      assert response.body =~ "Continue to"
    end
  end

  describe "when oidc is not configured" do
    setup do
      oidc = Application.get_env(:guard, :oidc)
      Application.put_env(:guard, :oidc, nil)

      on_exit(fn ->
        Application.put_env(:guard, :oidc, oidc)
      end)

      :ok
    end

    test "/oidc/login renders error" do
      {:ok, response} = send_login_request(path: "/oidc/login")

      assert response.status_code == 404
      assert response.body =~ "OIDC configuration is missing"
    end

    test "/oidc/callback redirects to legacy login" do
      {:ok, response} = send_login_request(path: "/oidc/callback")
      {_, location} = Enum.find(response.headers, fn h -> elem(h, 0) == "location" end)

      assert response.status_code == 302
      assert location == "https://id.localhost"
    end
  end

  describe "/oidc/login" do
    setup do
      bypass = Guard.Mocks.OpenIDConnect.discovery_document_server()
      disc_url = "http://localhost:#{bypass.port}/.well-known/openid-configuration"

      oidc = Application.get_env(:guard, :oidc)

      Application.put_env(:guard, :oidc, %{
        discovery_url: disc_url,
        client_id: "test_client_id",
        client_secret: "test_client_secret"
      })

      on_exit(fn ->
        Application.put_env(:guard, :oidc, oidc)
      end)

      :ok
    end

    test "when oidc is configured renders login page with oidc providers" do
      {:ok, response} = send_login_request(path: "/oidc/login")

      assert response.status_code == 200

      {_, cookie} = Enum.find(response.headers, fn h -> elem(h, 0) == "set-cookie" end)

      assert cookie =~ "semaphore_auth_state="
      assert cookie =~ "secure; HttpOnly; SameSite=Lax"

      assert response.body =~ "/protocol/openid-connect/auth"
      assert response.body =~ "localhost"
      assert response.body =~ "test_client_id"
      assert response.body =~ "S256"
      assert response.body =~ "code"
    end
  end

  describe "/oidc/callback" do
    setup do
      bypass = Guard.Mocks.OpenIDConnect.discovery_document_server()
      disc_url = "http://localhost:#{bypass.port}/.well-known/openid-configuration"

      oidc = Application.get_env(:guard, :oidc)

      Application.put_env(:guard, :oidc, %{
        discovery_url: disc_url,
        client_id: "test_client_id",
        client_secret: "test_client_secret"
      })

      on_exit(fn ->
        Application.put_env(:guard, :oidc, oidc)
      end)

      %{bypass: bypass, client_id: "test_client_id"}
    end

    test "when state is missing return 400" do
      {:ok, response} = send_login_request(path: "/oidc/login")
      {_, cookie} = Enum.find(response.headers, fn h -> elem(h, 0) == "set-cookie" end)
      {:ok, response} = send_login_request(path: "/oidc/callback", headers: [{"cookie", cookie}])

      {_, location} = Enum.find(response.headers, fn h -> elem(h, 0) == "location" end)
      assert Enum.find(response.headers, fn h -> elem(h, 0) == "set-cookie" end) == nil

      assert response.status_code == 302
      assert location == "https://id.localhost"
    end

    test "when state do not match saved one return 400" do
      {:ok, response} = send_login_request(path: "/oidc/login")
      {_, cookie} = Enum.find(response.headers, fn h -> elem(h, 0) == "set-cookie" end)

      {:ok, response} =
        send_login_request(
          path: "/oidc/callback",
          headers: [{"cookie", cookie}],
          query: %{state: "test_state"}
        )

      {_, location} = Enum.find(response.headers, fn h -> elem(h, 0) == "location" end)
      assert Enum.find(response.headers, fn h -> elem(h, 0) == "set-cookie" end) == nil

      assert response.status_code == 302
      assert location == "https://id.localhost"
    end

    test "when failed to exchange code for tokens", %{bypass: bypass} do
      Guard.Mocks.OpenIDConnect.expect_fetch_token_failure(bypass, %{"error" => "unauthorized"})

      {:ok, response} = send_login_request(path: "/oidc/login")
      {_, cookie} = Enum.find(response.headers, fn h -> elem(h, 0) == "set-cookie" end)

      {:ok, state} = extract_state_from_body(response.body)

      {:ok, response} =
        send_login_request(
          path: "/oidc/callback",
          headers: [{"cookie", cookie}],
          query: %{state: state}
        )

      {_, location} = Enum.find(response.headers, fn h -> elem(h, 0) == "location" end)
      assert Enum.find(response.headers, fn h -> elem(h, 0) == "set-cookie" end) == nil

      assert response.status_code == 302
      assert location == "https://id.localhost"
    end

    test "when id token is invalid", %{bypass: bypass} do
      {token, _claims} =
        Guard.Mocks.OpenIDConnect.generate_openid_connect_token(
          %{client_id: "wrong_client_id"},
          %{email: "foo@example.com", id: "123", name: "Foo bar"}
        )

      Guard.Mocks.OpenIDConnect.expect_fetch_token(bypass, %{
        "token_type" => "Bearer",
        "id_token" => token,
        "access_token" => "MY_ACCESS_TOKEN",
        "refresh_token" => "OTHER_REFRESH_TOKEN",
        "expires_in" => nil
      })

      {:ok, response} = send_login_request(path: "/oidc/login")
      {_, cookie} = Enum.find(response.headers, fn h -> elem(h, 0) == "set-cookie" end)

      {:ok, state} = extract_state_from_body(response.body)

      {:ok, response} =
        send_login_request(
          path: "/oidc/callback",
          headers: [{"cookie", cookie}],
          query: %{state: state}
        )

      {_, location} = Enum.find(response.headers, fn h -> elem(h, 0) == "location" end)
      assert Enum.find(response.headers, fn h -> elem(h, 0) == "set-cookie" end) == nil

      assert response.status_code == 302
      assert location == "https://id.localhost"
    end

    test "when failed to encrypt the refresh token", %{bypass: bypass, client_id: client_id} do
      encryptor = Application.get_env(:guard, Guard.OIDC.TokenEncryptor)

      Application.put_env(:guard, Guard.OIDC.TokenEncryptor, module: {Guard.FailingEncryptor, []})

      {:ok, user} = Support.Factories.RbacUser.insert()
      {:ok, oidc_user} = Support.Factories.OIDCUser.insert(user.id)

      {:ok, _} =
        Support.Members.insert_user(
          id: user.id,
          email: user.email,
          name: user.name
        )

      {token, _claims} =
        Guard.Mocks.OpenIDConnect.generate_openid_connect_token(%{client_id: client_id}, %{
          id: oidc_user.oidc_user_id,
          name: "Foo Bar",
          email: "foo@example.com"
        })

      Guard.Mocks.OpenIDConnect.expect_fetch_token(bypass, %{
        "token_type" => "Bearer",
        "id_token" => token,
        "access_token" => "MY_ACCESS_TOKEN",
        "refresh_token" => "OTHER_REFRESH_TOKEN",
        "expires_in" => 300
      })

      {:ok, response} = send_login_request(path: "/oidc/login")
      {_, cookie} = Enum.find(response.headers, fn h -> elem(h, 0) == "set-cookie" end)

      {:ok, state} = extract_state_from_body(response.body)

      {:ok, response} =
        send_login_request(
          path: "/oidc/callback",
          headers: [{"cookie", cookie}],
          query: %{state: state}
        )

      assert response.status_code == 302

      {_, location} = Enum.find(response.headers, fn h -> elem(h, 0) == "location" end)
      assert Enum.find(response.headers, fn h -> elem(h, 0) == "set-cookie" end) == nil

      assert location == "https://id.localhost"

      Application.put_env(:guard, Guard.OIDC.TokenEncryptor, encryptor)
    end

    test "when oidc user is not provisioned but user with this email is already present", %{
      bypass: bypass,
      client_id: client_id
    } do
      name = "Foo Bar"
      email = "foo@example.com"
      oidc_user_id = Ecto.UUID.generate()
      url = "#{Application.get_env(:guard, :oidc)[:manage_url]}/users/#{oidc_user_id}"

      Tesla.Mock.mock_global(fn
        %{method: :get, url: ^url} ->
          json(%{
            "id" => oidc_user_id,
            "email" => email,
            "firstName" => "Foo",
            "lastName" => "Bar"
          })
      end)

      {:ok, user} = Support.Factories.RbacUser.insert(Ecto.UUID.generate(), name, email)

      {token, _claims} =
        Guard.Mocks.OpenIDConnect.generate_openid_connect_token(%{client_id: client_id}, %{
          id: oidc_user_id,
          name: user.name,
          email: user.email
        })

      Guard.Mocks.OpenIDConnect.expect_fetch_token(bypass, %{
        "token_type" => "Bearer",
        "id_token" => token,
        "access_token" => "MY_ACCESS_TOKEN",
        "refresh_token" => "OTHER_REFRESH_TOKEN",
        "expires_in" => 300
      })

      {:ok, response} = send_login_request(path: "/oidc/login")
      {_, cookie} = Enum.find(response.headers, fn h -> elem(h, 0) == "set-cookie" end)

      {:ok, state} = extract_state_from_body(response.body)

      {:ok, response} =
        send_login_request(
          path: "/oidc/callback",
          headers: [{"cookie", cookie}],
          query: %{state: state}
        )

      assert response.status_code == 302

      {_, location} = Enum.find(response.headers, fn h -> elem(h, 0) == "location" end)
      assert Enum.find(response.headers, fn h -> elem(h, 0) == "set-cookie" end) == nil

      assert location == "https://id.localhost"
    end

    test "when there is no user and name is empty", %{bypass: bypass, client_id: client_id} do
      name = ""
      email = "foo@example.com"
      oidc_user_id = Ecto.UUID.generate()
      url = "#{Application.get_env(:guard, :oidc)[:manage_url]}/users/#{oidc_user_id}"

      Tesla.Mock.mock_global(fn
        %{method: :get, url: "https://bitbucket.org/api/2.0/users/5a6add182da8542a51d3fbcc"} ->
          json(%{"uuid" => "{babc48bc-fc2c-46f8-aae0-34c5ec255ffb}", "nickname" => "radwo"})

        %{method: :get, url: "https://api.github.com/user/184065"} ->
          json(%{"id" => 184_065, "login" => "radwo"})

        %{method: :get, url: ^url} ->
          json(%{
            "id" => oidc_user_id,
            "email" => email,
            "firstName" => "",
            "lastName" => "",
            "federatedIdentities" => [
              %{"identityProvider" => "github", "userId" => "184065", "userName" => "radwo"},
              %{
                "identityProvider" => "bitbucket",
                "userId" => "5a6add182da8542a51d3fbcc",
                "userName" => "radwo2"
              },
              %{"identityProvider" => "gitlab", "userId" => "123", "userName" => "gitlab_user"}
            ]
          })
      end)

      assert Guard.Store.RbacUser.fetch_by_oidc_id(oidc_user_id) == {:error, :not_found}

      {token, _claims} =
        Guard.Mocks.OpenIDConnect.generate_openid_connect_token(%{client_id: client_id}, %{
          id: oidc_user_id,
          name: name,
          email: email
        })

      Guard.Mocks.OpenIDConnect.expect_fetch_token(bypass, %{
        "token_type" => "Bearer",
        "id_token" => token,
        "access_token" => "MY_ACCESS_TOKEN",
        "refresh_token" => "OTHER_REFRESH_TOKEN",
        "expires_in" => 300
      })

      {:ok, response} = send_login_request(path: "/oidc/login")
      {_, cookie} = Enum.find(response.headers, fn h -> elem(h, 0) == "set-cookie" end)

      {:ok, state} = extract_state_from_body(response.body)

      {:ok, response} =
        send_login_request(
          path: "/oidc/callback",
          headers: [{"cookie", cookie}],
          query: %{state: state}
        )

      assert response.status_code == 302

      {_, location} = Enum.find(response.headers, fn h -> elem(h, 0) == "location" end)
      {_, cookie} = Enum.find(response.headers, fn h -> elem(h, 0) == "set-cookie" end)

      %{
        "id_provider" => "OIDC",
        "oidc_session_id" => session_id
      } = extarct_session_data_from_cookie(cookie)

      {:ok, session} = Guard.Store.OIDCSession.get(session_id)
      {:ok, user} = Guard.Store.RbacUser.fetch_by_oidc_id(oidc_user_id)
      {:ok, rha} = Guard.FrontRepo.RepoHostAccount.get_for_user_by_repo_host(user.id, "github")

      {:ok, rha2} =
        Guard.FrontRepo.RepoHostAccount.get_for_user_by_repo_host(user.id, "bitbucket")

      {:ok, rha3} = Guard.FrontRepo.RepoHostAccount.get_for_user_by_repo_host(user.id, "gitlab")

      assert Guard.FrontRepo.RepoHostAccount.count(user.id) == 3

      assert session.user_id == user.id
      assert session.user_agent == "test-agent"
      assert session.ip_address == "127.0.0.1"

      assert user.name == "foo"
      assert user.email == email

      assert rha3.github_uid == "123"
      assert rha3.login == "gitlab_user"
      assert rha3.permission_scope == "user:email"
      assert rha3.repo_host == "gitlab"
      assert rha3.token == nil
      assert rha3.revoked == false
      assert rha3.name == "gitlab_user"

      assert rha2.github_uid == "{babc48bc-fc2c-46f8-aae0-34c5ec255ffb}"
      assert rha2.login == "radwo"
      assert rha2.permission_scope == "user:email"
      assert rha2.repo_host == "bitbucket"
      assert rha2.token == nil
      assert rha2.revoked == false
      assert rha2.name == "radwo"

      assert rha.github_uid == "184065"
      assert rha.login == "radwo"
      assert rha.permission_scope == "user:email"
      assert rha.repo_host == "github"
      assert rha.token == nil
      assert rha.revoked == false
      assert rha.name == "radwo"

      assert cookie =~ "secure; HttpOnly"
      assert location == "https://me.localhost?signup=true"
    end

    test "when there is no user", %{bypass: bypass, client_id: client_id} do
      name = "Foo Bar"
      email = "foo@example.com"
      oidc_user_id = Ecto.UUID.generate()
      url = "#{Application.get_env(:guard, :oidc)[:manage_url]}/users/#{oidc_user_id}"

      Tesla.Mock.mock_global(fn
        %{method: :get, url: "https://bitbucket.org/api/2.0/users/5a6add182da8542a51d3fbcc"} ->
          json(%{"uuid" => "{babc48bc-fc2c-46f8-aae0-34c5ec255ffb}", "nickname" => "radwo"})

        %{method: :get, url: "https://api.github.com/user/184065"} ->
          json(%{"id" => 184_065, "login" => "radwo"})

        %{method: :get, url: ^url} ->
          json(%{
            "id" => oidc_user_id,
            "email" => email,
            "firstName" => "Foo",
            "lastName" => "Bar",
            "federatedIdentities" => [
              %{"identityProvider" => "github", "userId" => "184065", "userName" => "radwo"},
              %{
                "identityProvider" => "bitbucket",
                "userId" => "5a6add182da8542a51d3fbcc",
                "userName" => "radwo2"
              },
              %{
                "identityProvider" => "gitlab",
                "userId" => "123123",
                "userName" => "gitlab_user"
              }
            ]
          })
      end)

      assert Guard.Store.RbacUser.fetch_by_oidc_id(oidc_user_id) == {:error, :not_found}

      {token, _claims} =
        Guard.Mocks.OpenIDConnect.generate_openid_connect_token(%{client_id: client_id}, %{
          id: oidc_user_id,
          name: name,
          email: email
        })

      Guard.Mocks.OpenIDConnect.expect_fetch_token(bypass, %{
        "token_type" => "Bearer",
        "id_token" => token,
        "access_token" => "MY_ACCESS_TOKEN",
        "refresh_token" => "OTHER_REFRESH_TOKEN",
        "expires_in" => 300
      })

      {:ok, response} = send_login_request(path: "/oidc/login")
      {_, cookie} = Enum.find(response.headers, fn h -> elem(h, 0) == "set-cookie" end)

      {:ok, state} = extract_state_from_body(response.body)

      {:ok, response} =
        send_login_request(
          path: "/oidc/callback",
          headers: [{"cookie", cookie}],
          query: %{state: state}
        )

      assert response.status_code == 302

      {_, location} = Enum.find(response.headers, fn h -> elem(h, 0) == "location" end)
      {_, cookie} = Enum.find(response.headers, fn h -> elem(h, 0) == "set-cookie" end)

      %{
        "id_provider" => "OIDC",
        "oidc_session_id" => session_id
      } = extarct_session_data_from_cookie(cookie)

      {:ok, session} = Guard.Store.OIDCSession.get(session_id)
      {:ok, user} = Guard.Store.RbacUser.fetch_by_oidc_id(oidc_user_id)
      {:ok, rha} = Guard.FrontRepo.RepoHostAccount.get_for_user_by_repo_host(user.id, "github")

      {:ok, rha2} =
        Guard.FrontRepo.RepoHostAccount.get_for_user_by_repo_host(user.id, "bitbucket")

      {:ok, rha3} = Guard.FrontRepo.RepoHostAccount.get_for_user_by_repo_host(user.id, "gitlab")

      assert Guard.FrontRepo.RepoHostAccount.count(user.id) == 3

      assert session.user_id == user.id
      assert session.user_agent == "test-agent"
      assert session.ip_address == "127.0.0.1"

      assert user.name == name
      assert user.email == email

      assert rha3.github_uid == "123123"
      assert rha3.login == "gitlab_user"
      assert rha3.permission_scope == "user:email"
      assert rha3.repo_host == "gitlab"
      assert rha3.token == nil
      assert rha3.revoked == false
      assert rha3.name == "gitlab_user"

      assert rha2.github_uid == "{babc48bc-fc2c-46f8-aae0-34c5ec255ffb}"
      assert rha2.login == "radwo"
      assert rha2.permission_scope == "user:email"
      assert rha2.repo_host == "bitbucket"
      assert rha2.token == nil
      assert rha2.revoked == false
      assert rha2.name == "radwo"

      assert rha.github_uid == "184065"
      assert rha.login == "radwo"
      assert rha.permission_scope == "user:email"
      assert rha.repo_host == "github"
      assert rha.token == nil
      assert rha.revoked == false
      assert rha.name == "radwo"

      assert cookie =~ "secure; HttpOnly"
      assert location == "https://me.localhost?signup=true"
    end

    test "when the user is blocked", %{bypass: bypass, client_id: client_id} do
      {:ok, user} = Support.Factories.RbacUser.insert()
      {:ok, oidc_user} = Support.Factories.OIDCUser.insert(user.id)

      {:ok, _} =
        Support.Members.insert_user(
          id: user.id,
          email: user.email,
          name: user.name,
          blocked_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      {:ok, _} =
        Support.Members.insert_repo_host_account(
          login: "radwo",
          github_uid: "184065",
          user_id: user.id,
          token: "token",
          revoked: false,
          permission_scope: "repo"
        )

      {token, _claims} =
        Guard.Mocks.OpenIDConnect.generate_openid_connect_token(%{client_id: client_id}, %{
          id: oidc_user.oidc_user_id,
          name: "Foo Bar",
          email: "foo@example.com",
          github: %{uid: "184065", login: "radwo"}
        })

      Guard.Mocks.OpenIDConnect.expect_fetch_token(bypass, %{
        "token_type" => "Bearer",
        "id_token" => token,
        "access_token" => "MY_ACCESS_TOKEN",
        "refresh_token" => "OTHER_REFRESH_TOKEN",
        "expires_in" => 300
      })

      {:ok, response} = send_login_request(path: "/oidc/login")
      {_, cookie} = Enum.find(response.headers, fn h -> elem(h, 0) == "set-cookie" end)

      {:ok, state} = extract_state_from_body(response.body)

      {:ok, response} =
        send_login_request(
          path: "/oidc/callback",
          headers: [{"cookie", cookie}],
          query: %{state: state}
        )

      assert response.status_code == 302

      {_, location} = Enum.find(response.headers, fn h -> elem(h, 0) == "location" end)
      nil = Enum.find(response.headers, fn h -> elem(h, 0) == "set-cookie" end)

      assert location == "https://id.localhost/blocked"
    end

    test "when login successful for github", %{bypass: bypass, client_id: client_id} do
      {:ok, user} = Support.Factories.RbacUser.insert()
      {:ok, oidc_user} = Support.Factories.OIDCUser.insert(user.id)

      {:ok, _} =
        Support.Members.insert_user(
          id: user.id,
          email: user.email,
          name: user.name
        )

      {:ok, _} =
        Support.Members.insert_repo_host_account(
          login: "radwo",
          github_uid: "184065",
          user_id: user.id,
          token: "token",
          revoked: false,
          permission_scope: "repo"
        )

      {token, _claims} =
        Guard.Mocks.OpenIDConnect.generate_openid_connect_token(%{client_id: client_id}, %{
          id: oidc_user.oidc_user_id,
          name: "Foo Bar",
          email: "foo@example.com",
          github: %{uid: "184065", login: "radwo"}
        })

      Guard.Mocks.OpenIDConnect.expect_fetch_token(bypass, %{
        "token_type" => "Bearer",
        "id_token" => token,
        "access_token" => "MY_ACCESS_TOKEN",
        "refresh_token" => "OTHER_REFRESH_TOKEN",
        "expires_in" => 300
      })

      {:ok, response} = send_login_request(path: "/oidc/login")
      {_, cookie} = Enum.find(response.headers, fn h -> elem(h, 0) == "set-cookie" end)

      {:ok, state} = extract_state_from_body(response.body)

      {:ok, response} =
        send_login_request(
          path: "/oidc/callback",
          headers: [{"cookie", cookie}],
          query: %{state: state}
        )

      assert response.status_code == 302

      {_, location} = Enum.find(response.headers, fn h -> elem(h, 0) == "location" end)
      {_, cookie} = Enum.find(response.headers, fn h -> elem(h, 0) == "set-cookie" end)

      %{
        "id_provider" => "OIDC",
        "oidc_session_id" => session_id
      } = extarct_session_data_from_cookie(cookie)

      {:ok, session} = Guard.Store.OIDCSession.get(session_id)
      {:ok, rha} = Guard.FrontRepo.RepoHostAccount.get_for_user_by_repo_host(user.id, "github")

      assert Guard.FrontRepo.RepoHostAccount.count(user.id) == 1

      assert session.user_id == user.id
      assert session.user_agent == "test-agent"
      assert session.ip_address == "127.0.0.1"

      assert rha.github_uid == "184065"
      assert rha.login == "radwo"
      assert rha.repo_host == "github"
      assert rha.token == "token"
      assert rha.revoked == false
      assert rha.permission_scope == "repo"

      assert cookie =~ "secure; HttpOnly"
      assert location == "https://me.localhost"
    end

    test "when login successful for gitlab", %{bypass: bypass, client_id: client_id} do
      {:ok, user} = Support.Factories.RbacUser.insert()
      {:ok, oidc_user} = Support.Factories.OIDCUser.insert(user.id)

      {:ok, _} =
        Support.Members.insert_user(
          id: user.id,
          email: user.email,
          name: user.name
        )

      {:ok, _} =
        Support.Members.insert_repo_host_account(
          login: "gitlab_user",
          github_uid: "123",
          user_id: user.id,
          token: "token",
          revoked: false,
          permission_scope: "repo",
          repo_host: "gitlab"
        )

      {token, _claims} =
        Guard.Mocks.OpenIDConnect.generate_openid_connect_token(%{client_id: client_id}, %{
          id: oidc_user.oidc_user_id,
          name: "Foo Bar",
          email: "foo@example.com",
          gitlab: %{uid: "123", login: "gitlab_user"}
        })

      Guard.Mocks.OpenIDConnect.expect_fetch_token(bypass, %{
        "token_type" => "Bearer",
        "id_token" => token,
        "access_token" => "MY_ACCESS_TOKEN",
        "refresh_token" => "OTHER_REFRESH_TOKEN",
        "expires_in" => 300
      })

      {:ok, response} = send_login_request(path: "/oidc/login")
      {_, cookie} = Enum.find(response.headers, fn h -> elem(h, 0) == "set-cookie" end)

      {:ok, state} = extract_state_from_body(response.body)

      {:ok, response} =
        send_login_request(
          path: "/oidc/callback",
          headers: [{"cookie", cookie}],
          query: %{state: state}
        )

      assert response.status_code == 302

      {_, location} = Enum.find(response.headers, fn h -> elem(h, 0) == "location" end)
      {_, cookie} = Enum.find(response.headers, fn h -> elem(h, 0) == "set-cookie" end)

      %{
        "id_provider" => "OIDC",
        "oidc_session_id" => session_id
      } = extarct_session_data_from_cookie(cookie)

      {:ok, session} = Guard.Store.OIDCSession.get(session_id)
      {:ok, rha} = Guard.FrontRepo.RepoHostAccount.get_for_user_by_repo_host(user.id, "gitlab")

      assert Guard.FrontRepo.RepoHostAccount.count(user.id) == 1

      assert session.user_id == user.id
      assert session.user_agent == "test-agent"
      assert session.ip_address == "127.0.0.1"

      assert rha.github_uid == "123"
      assert rha.login == "gitlab_user"
      assert rha.repo_host == "gitlab"
      assert rha.token == "token"
      assert rha.revoked == false
      assert rha.permission_scope == "repo"

      assert cookie =~ "secure; HttpOnly"
      assert location == "https://me.localhost"
    end
  end

  ###
  ### Helper functions
  ###

  defp assert_callback_error_response(response) do
    {_, location} = Enum.find(response.headers, fn h -> elem(h, 0) == "location" end)
    schema = URI.parse(location)
    query = URI.decode_query(schema.query)

    assert response.status_code == 302
    assert schema.host == "me.localhost"
    assert schema.path == nil
    assert query["status"] == "error"

    assert query["message"] ==
             "We're sorry, but your connection attempt was unsuccessful. Please try again. If you continue to experience issues, please contact our support team for assistance."
  end

  defp extarct_session_data_from_cookie(cookie) do
    case Regex.named_captures(~r/_sxtesting_session=(?<session>[\w%-]+);/, cookie) do
      nil -> %{}
      %{"session" => session} -> Guard.Session.decrypt_cookie(session)
    end
  end

  defp extract_state_from_body(body) do
    case Regex.named_captures(~r/state=(?<state>[\w-]+)&/, body) do
      nil -> {:error, nil}
      %{"state" => state} -> {:ok, state}
    end
  end

  defp send_login_request(params \\ []) do
    query_string = parse_query_params(params[:query])
    path = params[:path] || "/login"

    headers =
      (params[:headers] || []) ++ [{"x-forwarded-proto", "https"}, {"user-agent", "test-agent"}]

    "#{@host}/#{path}#{query_string}"
    |> URI.encode()
    |> HTTPoison.get(headers)
  end

  defp parse_query_params(nil), do: ""
  defp parse_query_params(params), do: "?#{URI.encode_query(params)}"

  defp domain, do: Application.get_env(:guard, :base_domain)
end
