defmodule AuthTest do
  use ExUnit.Case

  import Plug.Test
  import Plug.Conn

  doctest Auth

  alias InternalApi.Auth.AuthenticateResponse

  @valid_token "tokenX"
  @valid_cookie "cookieX"
  @valid_cookie2 "cookieX2"

  @org_id UUID.uuid4()
  @other_org_id UUID.uuid4()
  @open_restricted_org_id UUID.uuid4()
  @closed_restricted_org_id UUID.uuid4()
  @closed_restricted_org_ip "45.102.201.99"
  @random_ip "35.121.222.37"
  @user_id UUID.uuid4()
  @user_id2 UUID.uuid4()

  @valid_orgs [
    %{
      id: @org_id,
      name: "rt",
      restricted: false,
      allowed_id_providers: [],
      ip_allow_list: []
    },
    %{
      id: @other_org_id,
      name: "semaphore",
      restricted: false,
      allowed_id_providers: ["okta"],
      ip_allow_list: []
    }
  ]

  @restricted_orgs [
    %{
      id: @open_restricted_org_id,
      name: "open-restricted-org",
      restricted: true,
      allowed_id_providers: [],
      ip_allow_list: []
    },
    %{
      id: @closed_restricted_org_id,
      name: "closed-restricted-org",
      restricted: true,
      allowed_id_providers: [],
      ip_allow_list: [
        @closed_restricted_org_ip
      ]
    }
  ]

  @public_orgs [
    %{
      id: UUID.uuid4(),
      name: "public-pages",
      restricted: false,
      allowed_id_providers: [],
      ip_allow_list: []
    }
  ]

  @delete_cookie "_s2_something_=; path=/; domain=.semaphoretest.test; expires=Thu, 01 Jan 1970 00:00:00 GMT; max-age=0; secure; HttpOnly"

  setup do
    FunRegistry.set!(Fake.RbacService, :list_user_permissions, fn _, _ ->
      InternalApi.RBAC.ListUserPermissionsResponse.new(permissions: ["organization.view"])
    end)

    FunRegistry.set!(Fake.FeatureService, :list_organization_features, fn _req, _stream ->
      %InternalApi.Feature.ListOrganizationFeaturesResponse{
        organization_features: [
          %InternalApi.Feature.OrganizationFeature{
            feature: %InternalApi.Feature.Feature{
              type: "can_use_api_token_in_ui",
              name: "can_use_api_token_in_ui"
            },
            availability: %InternalApi.Feature.Availability{
              state: InternalApi.Feature.Availability.State.value(:HIDDEN),
              quantity: 0
            }
          }
        ]
      }
    end)

    FunRegistry.set!(Fake.OrganizationService, :describe, fn req, _stream ->
      org =
        (@valid_orgs ++ @public_orgs ++ @restricted_orgs)
        |> Enum.find(fn org -> org.name == req.org_username end)

      if org do
        InternalApi.Organization.DescribeResponse.new(
          status:
            InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
          organization:
            InternalApi.Organization.Organization.new(
              org_id: org.id,
              org_username: org.name,
              restricted: org.restricted,
              ip_allow_list: org.ip_allow_list,
              allowed_id_providers: org.allowed_id_providers
            )
        )
      else
        raise GRPC.RPCError, status: :not_found, message: "not found"
      end
    end)

    FunRegistry.set!(Fake.AuthenticationService, :authenticate, fn req, _stream ->
      case req.token do
        @valid_token ->
          AuthenticateResponse.new(
            authenticated: true,
            username: "test-user",
            user_id: @user_id,
            id_provider: InternalApi.Auth.IdProvider.value(:ID_PROVIDER_API_TOKEN)
          )

        _ ->
          InternalApi.Auth.AuthenticateResponse.new(authenticated: false)
      end
    end)

    FunRegistry.set!(Fake.AuthenticationService, :authenticate_with_cookie, fn req, _stream ->
      case req.cookie do
        @valid_cookie ->
          AuthenticateResponse.new(
            authenticated: true,
            username: "test-user",
            user_id: @user_id,
            ip_address: @random_ip,
            user_agent: "test-agent",
            id_provider: InternalApi.Auth.IdProvider.value(:ID_PROVIDER_OKTA)
          )

        @valid_cookie2 ->
          AuthenticateResponse.new(
            authenticated: true,
            username: "test-user-2",
            user_id: @user_id2,
            ip_address: @closed_restricted_org_ip,
            user_agent: "test-agent",
            id_provider: InternalApi.Auth.IdProvider.value(:ID_PROVIDER_GITHUB)
          )

        _ ->
          InternalApi.Auth.AuthenticateResponse.new(authenticated: false)
      end
    end)

    Cachex.reset(:grpc_api_cache)
    Cachex.reset(:feature_provider_cache)

    :ok
  end

  describe "/exauth/is_alive" do
    test "returns 200 OK" do
      conn = conn(:get, "/exauth/is_alive")
      conn = Auth.call(conn, [])

      assert conn.status == 200
    end
  end

  describe "/exauth/ambassador/v0/check_alive" do
    test "returns 200 OK" do
      conn = conn(:get, "/exauth/ambassador/v0/check_alive")
      conn = Auth.call(conn, [])

      assert conn.status == 200
    end
  end

  describe "/exauth/ambassador/v0/check_ready" do
    test "returns 200 OK" do
      conn = conn(:get, "/exauth/ambassador/v0/check_ready")
      conn = Auth.call(conn, [])

      assert conn.status == 200
    end
  end

  describe "<org-name>.semaphoreci.com/exauth/badges*path" do
    test "blank request" do
      conn = conn(:get, "https://rt.semaphoretest.test/exauth/badges")
      conn = Auth.call(conn, [])

      assert sent_resp(conn) ==
               {200,
                [
                  {"cache-control", "max-age=0, private, must-revalidate"},
                  {"x-semaphore-org-username", "rt"},
                  {"x-semaphore-org-id", @org_id}
                ], ""}
    end

    test "request non-existing org" do
      conn = conn(:get, "https://lolololololo.semaphoretest.test/exauth/badges")
      conn = Auth.call(conn, [])

      assert sent_resp(conn) ==
               {302,
                [
                  {"cache-control", "max-age=0, private, must-revalidate"},
                  {"location", "https://id.semaphoretest.test"}
                ], "Redirected to https://id.semaphoretest.test"}
    end

    test "request restricted org with empty allow list" do
      conn = conn(:get, "https://open-restricted-org.semaphoretest.test/exauth/badges")
      conn = Auth.call(conn, [])

      assert sent_resp(conn) ==
               {200,
                [
                  {"cache-control", "max-age=0, private, must-revalidate"},
                  {"x-semaphore-org-username", "open-restricted-org"},
                  {"x-semaphore-org-id", @open_restricted_org_id}
                ], ""}
    end

    test "request from not allowed IP is blocked for restricted org" do
      conn =
        Plug.Adapters.Test.Conn.conn(
          %Plug.Conn{req_headers: [{"x-forwarded-for", "35.121.222.37"}]},
          :get,
          "https://closed-restricted-org.semaphoretest.test/exauth/badges",
          nil
        )

      conn = Auth.call(conn, [])

      assert sent_resp(conn) ==
               {404,
                [
                  {"cache-control", "max-age=0, private, must-revalidate"}
                ], blocked_ip_response("35.121.222.37")}
    end

    test "request from allowed IP is not blocked for restricted org" do
      conn =
        Plug.Adapters.Test.Conn.conn(
          %Plug.Conn{req_headers: [{"x-forwarded-for", @closed_restricted_org_ip}]},
          :get,
          "https://closed-restricted-org.semaphoretest.test/exauth/badges",
          nil
        )

      conn = Auth.call(conn, [])

      assert sent_resp(conn) ==
               {200,
                [
                  {"cache-control", "max-age=0, private, must-revalidate"},
                  {"x-semaphore-org-username", "closed-restricted-org"},
                  {"x-semaphore-org-id", @closed_restricted_org_id}
                ], ""}
    end
  end

  describe "<org-name>.semaphoreci.com/exauth/.well-known/*path" do
    test "request from allowed IP is not blocked for restricted org" do
      conn = conn(:get, "https://rt.semaphoretest.test/exauth/.well-known/openid-configuration")
      conn = Auth.call(conn, [])

      assert sent_resp(conn) ==
               {200,
                [
                  {"cache-control", "max-age=0, private, must-revalidate"},
                  {"x-semaphore-org-username", "rt"},
                  {"x-semaphore-org-id", @org_id}
                ], ""}
    end
  end

  describe "<org-name>.semaphoreci.com/exauth/okta/auth" do
    test "post requests to /okta/auth are publicly available" do
      conn = conn(:post, "https://rt.semaphoretest.test/exauth/okta/auth")
      conn = Auth.call(conn, [])

      assert sent_resp(conn) ==
               {200,
                [
                  {"cache-control", "max-age=0, private, must-revalidate"},
                  {"x-semaphore-org-username", "rt"},
                  {"x-semaphore-org-id", @org_id}
                ], ""}
    end
  end

  describe "<org-name>.semaphoreci.com/exauth/okta/scim/*path" do
    test "all requests to /okta/scim are passed for validation down to guard" do
      conn = conn(:get, "https://rt.semaphoretest.test/exauth/okta/scim/Users")
      conn = Auth.call(conn, [])

      assert sent_resp(conn) ==
               {200,
                [
                  {"cache-control", "max-age=0, private, must-revalidate"},
                  {"x-semaphore-org-username", "rt"},
                  {"x-semaphore-org-id", @org_id}
                ], ""}
    end
  end

  describe "<org-name>.semaphoreci.com/exauth/api*path" do
    test "when its invalid api request => returns 401 Unauthorized" do
      conn = conn(:get, "https://rt.semaphoretest.test/exauth/api/v1aplpha/secrets")
      conn = conn |> put_req_header("authorization", "Token XXX")
      conn = Auth.call(conn, [])

      assert sent_resp(conn) ==
               {401, [{"cache-control", "max-age=0, private, must-revalidate"}], "Unauthorized"}
    end

    test "when the headers contain a invalid Authorization Bearer => returns 401 Unauthorized" do
      conn = conn(:get, "https://rt.semaphoretest.test/exauth/api/v1aplpha/secrets")
      conn = conn |> put_req_header("authorization", "Bearer XXX")
      conn = Auth.call(conn, [])

      assert sent_resp(conn) ==
               {401, [{"cache-control", "max-age=0, private, must-revalidate"}], "Unauthorized"}
    end

    test "when the headers contain a valid Authorization Bearer => it sets the x-semaphore-username and returns 200" do
      conn = conn(:get, "https://rt.semaphoretest.test/exauth/api/v1beta/secrets")
      conn = conn |> put_req_header("authorization", "Bearer #{@valid_token}")
      conn = Auth.call(conn, [])

      assert sent_resp(conn) ==
               {200,
                [
                  {"cache-control", "max-age=0, private, must-revalidate"},
                  {"x-semaphore-org-username", "rt"},
                  {"x-semaphore-org-id", @org_id},
                  {"x-semaphore-user-anonymous", "false"},
                  {"x-semaphore-user-id", @user_id}
                ], ""}
    end

    test "when the headers contain a valid Authorization Token => it sets the x-semaphore-username and returns 200" do
      conn = conn(:get, "https://rt.semaphoretest.test/exauth/api/v1beta/secrets")
      conn = conn |> put_req_header("authorization", "Token #{@valid_token}")
      conn = Auth.call(conn, [])

      assert sent_resp(conn) ==
               {200,
                [
                  {"cache-control", "max-age=0, private, must-revalidate"},
                  {"x-semaphore-org-username", "rt"},
                  {"x-semaphore-org-id", @org_id},
                  {"x-semaphore-user-anonymous", "false"},
                  {"x-semaphore-user-id", @user_id}
                ], ""}
    end

    test "request restricted org with empty allow list" do
      conn =
        conn(:get, "https://open-restricted-org.semaphoretest.test/exauth/api/v1beta/secrets")

      conn = conn |> put_req_header("authorization", "Token #{@valid_token}")
      conn = Auth.call(conn, [])

      assert sent_resp(conn) ==
               {200,
                [
                  {"cache-control", "max-age=0, private, must-revalidate"},
                  {"x-semaphore-org-username", "open-restricted-org"},
                  {"x-semaphore-org-id", @open_restricted_org_id},
                  {"x-semaphore-user-anonymous", "false"},
                  {"x-semaphore-user-id", @user_id}
                ], ""}
    end

    test "request from not allowed IP is blocked for restricted org" do
      conn =
        Plug.Adapters.Test.Conn.conn(
          %Plug.Conn{req_headers: [{"x-forwarded-for", "35.121.222.37"}]},
          :get,
          "https://closed-restricted-org.semaphoretest.test/exauth/api/v1beta/secrets",
          nil
        )

      conn = conn |> put_req_header("authorization", "Token #{@valid_token}")
      conn = Auth.call(conn, [])

      assert sent_resp(conn) ==
               {404,
                [
                  {"cache-control", "max-age=0, private, must-revalidate"}
                ], blocked_ip_response("35.121.222.37")}
    end

    test "request from allowed IP is not blocked for restricted org" do
      conn =
        Plug.Adapters.Test.Conn.conn(
          %Plug.Conn{req_headers: [{"x-forwarded-for", @closed_restricted_org_ip}]},
          :get,
          "https://closed-restricted-org.semaphoretest.test/exauth/api/v1beta/secrets",
          nil
        )

      conn = conn |> put_req_header("authorization", "Token #{@valid_token}")
      conn = Auth.call(conn, [])

      assert sent_resp(conn) ==
               {200,
                [
                  {"cache-control", "max-age=0, private, must-revalidate"},
                  {"x-semaphore-org-username", "closed-restricted-org"},
                  {"x-semaphore-org-id", @closed_restricted_org_id},
                  {"x-semaphore-user-anonymous", "false"},
                  {"x-semaphore-user-id", @user_id}
                ], ""}
    end
  end

  describe "<org-name>.semaphoreci.com/exauth*path" do
    test "when its invalid api request => returns 401 Unauthorized" do
      conn = conn(:get, "https://rt.semaphoretest.test/exauth/api/v1aplpha/somepath")
      conn = conn |> put_req_header("authorization", "Token XXX")
      conn = Auth.call(conn, [])

      assert sent_resp(conn) ==
               {401, [{"cache-control", "max-age=0, private, must-revalidate"}], "Unauthorized"}
    end

    test "when the request have an invalid session cookie => it sets the x-semaphore-anonymous and returns 200" do
      cookie = "#{Application.get_env(:auth, :cookie_name)}=lol"

      conn = conn(:get, "https://rt.semaphoretest.test/exauth/somepath")

      conn =
        conn
        |> insert_headers(
          cookie: "#{cookie}",
          "user-agent": "test-agent",
          "x-forwarded-for": @random_ip
        )

      conn = Auth.call(conn, [])

      assert sent_resp(conn) ==
               {200,
                [
                  {"set-cookie", @delete_cookie},
                  {"cache-control", "max-age=0, private, must-revalidate"},
                  {"x-semaphore-org-username", "rt"},
                  {"x-semaphore-org-id", @org_id},
                  {"x-semaphore-user-anonymous", "true"}
                ], ""}
    end

    test "when the headers does not contain any session cookie => it sets the x-semaphore-username to anonymous and returns 200" do
      conn = conn(:get, "https://rt.semaphoretest.test/exauth/somepath")
      conn = Auth.call(conn, [])

      assert sent_resp(conn) ==
               {200,
                [
                  {"cache-control", "max-age=0, private, must-revalidate"},
                  {"x-semaphore-org-username", "rt"},
                  {"x-semaphore-org-id", @org_id},
                  {"x-semaphore-user-anonymous", "true"}
                ], ""}
    end

    test "when x-semaphore-user-id is already set, but not the token => return 401" do
      conn = conn(:get, "https://rt.semaphoretest.test/exauth/api/v1/secrets")
      conn = conn |> put_req_header("x-semaphore-user-id", "malicious-id")
      conn = Auth.call(conn, [])

      assert sent_resp(conn) ==
               {404, [{"cache-control", "max-age=0, private, must-revalidate"}], "Not Found"}
    end

    test "when the headers contain an invalid Authorization Token => it returns 401" do
      conn = conn(:get, "https://rt.semaphoretest.test/exauth/somepath")
      conn = conn |> put_req_header("authorization", "Token lol")
      conn = Auth.call(conn, [])

      assert sent_resp(conn) ==
               {200,
                [
                  {"cache-control", "max-age=0, private, must-revalidate"},
                  {"x-semaphore-org-username", "rt"},
                  {"x-semaphore-org-id", @org_id},
                  {"x-semaphore-user-anonymous", "true"}
                ], ""}
    end

    test "when the headers contain a valid Authorization Token => it sets the x-semaphore-username to anonymous and returns 200" do
      conn = conn(:get, "https://rt.semaphoretest.test/exauth/somepath")
      conn = conn |> put_req_header("authorization", "Token #{@valid_token}")
      conn = Auth.call(conn, [])

      assert sent_resp(conn) ==
               {200,
                [
                  {"cache-control", "max-age=0, private, must-revalidate"},
                  {"x-semaphore-org-username", "rt"},
                  {"x-semaphore-org-id", @org_id},
                  {"x-semaphore-user-anonymous", "true"}
                ], ""}
    end

    test "when the headers contain a valid token and org has feature enabled => sets user ID header and returns 200" do
      FunRegistry.set!(Fake.FeatureService, :list_organization_features, fn _req, _stream ->
        %InternalApi.Feature.ListOrganizationFeaturesResponse{
          organization_features: [
            %InternalApi.Feature.OrganizationFeature{
              feature: %InternalApi.Feature.Feature{
                type: "can_use_api_token_in_ui",
                name: "can_use_api_token_in_ui"
              },
              availability: %InternalApi.Feature.Availability{
                state: InternalApi.Feature.Availability.State.value(:ENABLED),
                quantity: 1
              }
            }
          ]
        }
      end)

      conn = conn(:get, "https://rt.semaphoretest.test/exauth/somepath")
      conn = conn |> put_req_header("authorization", "Token #{@valid_token}")
      conn = Auth.call(conn, [])

      assert sent_resp(conn) ==
               {200,
                [
                  {"cache-control", "max-age=0, private, must-revalidate"},
                  {"x-semaphore-org-username", "rt"},
                  {"x-semaphore-org-id", @org_id},
                  {"x-semaphore-user-anonymous", "false"},
                  {"x-semaphore-user-id", @user_id}
                ], ""}
    end

    test "when the request comes from a deprecated CLI => return 400" do
      conn = conn(:get, "https://rt.semaphoretest.test/exauth/api/v1/somepath")
      conn = conn |> put_req_header("authorization", "Token #{@valid_token}")
      conn = conn |> put_req_header("user-agent", "SemaphoreCLI/v0.10.0 (....)")
      conn = Auth.call(conn, [])

      body =
        Enum.join(
          [
            "{\"message\": \"Call rejected because the client is outdated. ",
            "To continue, upgrade Semaphore CLI with ",
            "'curl https://storage.googleapis.com/sem-cli-releases/get.sh | bash'.",
            "\"}"
          ],
          ""
        )

      assert sent_resp(conn) ==
               {400,
                [
                  {"cache-control", "max-age=0, private, must-revalidate"}
                ], body}
    end

    test "when the request have a valid session cookie => it sets the x-semaphore-user-id and returns 200" do
      cookie = "#{Application.get_env(:auth, :cookie_name)}=#{@valid_cookie}"

      conn = conn(:get, "https://rt.semaphoretest.test/exauth/somepath")

      conn =
        conn
        |> insert_headers(
          cookie: "#{cookie}",
          "user-agent": "test-agent",
          "x-forwarded-for": @random_ip
        )

      conn = Auth.call(conn, [])

      assert sent_resp(conn) ==
               {200,
                [
                  {"cache-control", "max-age=0, private, must-revalidate"},
                  {"x-semaphore-org-username", "rt"},
                  {"x-semaphore-org-id", @org_id},
                  {"x-semaphore-user-anonymous", "false"},
                  {"x-semaphore-user-id", @user_id}
                ], ""}
    end

    test "blank request" do
      conn = conn(:get, "https://rt.semaphoretest.test/exauth/somepath")
      conn = Auth.call(conn, [])

      assert sent_resp(conn) ==
               {200,
                [
                  {"cache-control", "max-age=0, private, must-revalidate"},
                  {"x-semaphore-org-username", "rt"},
                  {"x-semaphore-org-id", @org_id},
                  {"x-semaphore-user-anonymous", "true"}
                ], ""}
    end

    test "request non-existing org" do
      conn = conn(:get, "https://lolololololo.semaphoretest.test/exauth/somepath")
      conn = conn |> put_req_header("authorization", "Token #{@valid_token}")
      conn = Auth.call(conn, [])

      assert sent_resp(conn) ==
               {302,
                [
                  {"cache-control", "max-age=0, private, must-revalidate"},
                  {"location", "https://id.semaphoretest.test"}
                ], "Redirected to https://id.semaphoretest.test"}
    end

    test "do not overwrite canary header for listed organizations" do
      cookie = "#{Application.get_env(:auth, :cookie_name)}=#{@valid_cookie}"

      conn = conn(:get, "https://semaphore.semaphoretest.test/exauth/somepath")

      conn =
        conn
        |> insert_headers(
          cookie: "#{cookie}",
          "user-agent": "test-agent",
          "x-forwarded-for": @random_ip,
          "x-canaty-mode": "canary"
        )

      conn = Auth.call(conn, [])

      assert sent_resp(conn) ==
               {200,
                [
                  {"cache-control", "max-age=0, private, must-revalidate"},
                  {"x-semaphore-org-username", "semaphore"},
                  {"x-semaphore-org-id", @other_org_id},
                  {"x-semaphore-user-anonymous", "false"},
                  {"x-semaphore-user-id", @user_id}
                ], ""}
    end

    test "request restricted org with empty allow list" do
      conn = conn(:get, "https://open-restricted-org.semaphoretest.test/exauth/somepath")
      conn = Auth.call(conn, [])

      assert sent_resp(conn) ==
               {200,
                [
                  {"cache-control", "max-age=0, private, must-revalidate"},
                  {"x-semaphore-org-username", "open-restricted-org"},
                  {"x-semaphore-org-id", @open_restricted_org_id},
                  {"x-semaphore-user-anonymous", "true"}
                ], ""}
    end

    test "request from not allowed IP is blocked for restricted org" do
      conn =
        Plug.Adapters.Test.Conn.conn(
          %Plug.Conn{req_headers: [{"x-forwarded-for", "35.121.222.37"}]},
          :get,
          "https://closed-restricted-org.semaphoretest.test/exauth/somepath",
          nil
        )

      conn = Auth.call(conn, [])

      assert sent_resp(conn) ==
               {404,
                [
                  {"cache-control", "max-age=0, private, must-revalidate"}
                ], blocked_ip_response("35.121.222.37")}
    end

    test "request from allowed IP is not blocked for restricted org" do
      conn =
        Plug.Adapters.Test.Conn.conn(
          %Plug.Conn{req_headers: [{"x-forwarded-for", @closed_restricted_org_ip}]},
          :get,
          "https://closed-restricted-org.semaphoretest.test/exauth/somepath",
          nil
        )

      conn = Auth.call(conn, [])

      assert sent_resp(conn) ==
               {200,
                [
                  {"cache-control", "max-age=0, private, must-revalidate"},
                  {"x-semaphore-org-username", "closed-restricted-org"},
                  {"x-semaphore-org-id", @closed_restricted_org_id},
                  {"x-semaphore-user-anonymous", "true"}
                ], ""}
    end

    test "when a user has a valid session cookie, but tries to use it from a different ip address, set user as anonymous" do
      FunRegistry.set!(Fake.FeatureService, :list_organization_features, fn _req, _stream ->
        %InternalApi.Feature.ListOrganizationFeaturesResponse{
          organization_features: [
            %InternalApi.Feature.OrganizationFeature{
              feature: %InternalApi.Feature.Feature{
                type: "enforce_cookie_validation",
                name: "enforce_cookie_validation"
              },
              availability: %InternalApi.Feature.Availability{
                state: InternalApi.Feature.Availability.State.value(:ENABLED),
                quantity: 1
              }
            }
          ]
        }
      end)

      cookie = "#{Application.get_env(:auth, :cookie_name)}=#{@valid_cookie}"

      conn = conn(:get, "https://rt.semaphoretest.test/exauth/somepath")

      conn =
        conn
        |> insert_headers(
          cookie: "#{cookie}",
          "user-agent": "test-agent",
          "x-forwarded-for": "45.54.45.456"
        )

      conn = Auth.call(conn, [])

      assert sent_resp(conn) ==
               {200,
                [
                  {"set-cookie", @delete_cookie},
                  {"cache-control", "max-age=0, private, must-revalidate"},
                  {"x-semaphore-org-username", "rt"},
                  {"x-semaphore-org-id", @org_id},
                  {"x-semaphore-user-anonymous", "true"}
                ], ""}
    end

    test "when a user has a valid session cookie, but tries to use it from a different ip address within the same subnet, allow it" do
      FunRegistry.set!(Fake.FeatureService, :list_organization_features, fn _req, _stream ->
        %InternalApi.Feature.ListOrganizationFeaturesResponse{
          organization_features: [
            %InternalApi.Feature.OrganizationFeature{
              feature: %InternalApi.Feature.Feature{
                type: "enforce_cookie_validation",
                name: "enforce_cookie_validation"
              },
              availability: %InternalApi.Feature.Availability{
                state: InternalApi.Feature.Availability.State.value(:ENABLED),
                quantity: 1
              }
            }
          ]
        }
      end)

      cookie = "#{Application.get_env(:auth, :cookie_name)}=#{@valid_cookie}"
      new_ip_in_same_subnet = String.slice(@random_ip, 0..-3) <> "11"

      conn = conn(:get, "https://rt.semaphoretest.test/exauth/somepath")

      conn =
        conn
        |> insert_headers(
          cookie: "#{cookie}",
          "user-agent": "test-agent",
          "x-forwarded-for": new_ip_in_same_subnet
        )

      conn = Auth.call(conn, [])

      assert sent_resp(conn) ==
               {200,
                [
                  {"cache-control", "max-age=0, private, must-revalidate"},
                  {"x-semaphore-org-username", "rt"},
                  {"x-semaphore-org-id", @org_id},
                  {"x-semaphore-user-anonymous", "false"},
                  {"x-semaphore-user-id", @user_id}
                ], ""}
    end

    test "when a user has a valid session cookie, but does not have matching ID provider" do
      cookie = "#{Application.get_env(:auth, :cookie_name)}=#{@valid_cookie2}"

      conn = conn(:get, "https://semaphore.semaphoretest.test/exauth/somepath")

      conn =
        conn
        |> insert_headers(
          cookie: "#{cookie}",
          "user-agent": "test-agent",
          "x-forwarded-for": @closed_restricted_org_ip
        )

      conn = Auth.call(conn, [])

      assert sent_resp(conn) ==
               {302,
                [
                  {"set-cookie", @delete_cookie},
                  {"cache-control", "max-age=0, private, must-revalidate"},
                  {"x-semaphore-org-username", "semaphore"},
                  {"x-semaphore-org-id", @other_org_id},
                  {
                    "location",
                    "https://id.semaphoretest.test/login?org_id=#{@other_org_id}&redirect_to=https%3A%2F%2Fsemaphore.semaphoretest.test%2Fsomepath"
                  }
                ],
                "Redirected to https://id.semaphoretest.test/login?org_id=#{@other_org_id}&redirect_to=https%3A%2F%2Fsemaphore.semaphoretest.test%2Fsomepath"}
    end

    test "when a user has a valid session cookie, but tries to use it from a different user-agent" do
      FunRegistry.set!(Fake.FeatureService, :list_organization_features, fn _req, _stream ->
        %InternalApi.Feature.ListOrganizationFeaturesResponse{
          organization_features: [
            %InternalApi.Feature.OrganizationFeature{
              feature: %InternalApi.Feature.Feature{
                type: "enforce_cookie_validation",
                name: "enforce_cookie_validation"
              },
              availability: %InternalApi.Feature.Availability{
                state: InternalApi.Feature.Availability.State.value(:ENABLED),
                quantity: 1
              }
            }
          ]
        }
      end)

      cookie = "#{Application.get_env(:auth, :cookie_name)}=#{@valid_cookie}"

      conn = conn(:get, "https://rt.semaphoretest.test/exauth/somepath")

      conn =
        conn
        |> insert_headers(
          cookie: "#{cookie}",
          "user-agent": "non-existant-user-agent",
          "x-forwarded-for": @random_ip
        )

      conn = Auth.call(conn, [])

      assert sent_resp(conn) ==
               {200,
                [
                  {"set-cookie", @delete_cookie},
                  {"cache-control", "max-age=0, private, must-revalidate"},
                  {"x-semaphore-org-username", "rt"},
                  {"x-semaphore-org-id", @org_id},
                  {"x-semaphore-user-anonymous", "true"}
                ], ""}
    end
  end

  describe "/exauth/github path" do
    test "returns 200 OK for post" do
      conn = conn(:post, "https://hooks.semaphoretest.test/exauth/github")
      conn = Auth.call(conn, [])

      assert conn.status == 200
    end

    test "returns 200 OK for get" do
      conn = conn(:get, "https://hooks.semaphoretest.test/exauth/github")
      conn = Auth.call(conn, [])

      assert conn.status == 200
    end
  end

  describe "/exauth/hooks/bitbucket path" do
    test "returns 200 OK for existing organization" do
      conn = conn(:post, "https://rt.semaphoretest.test/exauth/hooks/bitbucket")
      conn = Auth.call(conn, [])

      assert sent_resp(conn) ==
               {200,
                [
                  {"cache-control", "max-age=0, private, must-revalidate"},
                  {"x-semaphore-org-username", "rt"},
                  {"x-semaphore-org-id", @org_id}
                ], ""}
    end

    test "returns 404 for non existing organization" do
      conn = conn(:post, "https://lol.semaphoretest.test/exauth/hooks/bitbucket")
      conn = Auth.call(conn, [])

      assert conn.status == 404
    end
  end

  describe "id.semaphoreci.com/exauth*path" do
    test "when the resources request have a valid session cookie from user => it returns 302" do
      cookie = "#{Application.get_env(:auth, :cookie_name)}=#{@valid_cookie}"

      conn = conn(:get, "https://id.semaphoretest.test/exauth/resources")

      conn =
        conn
        |> insert_headers(
          cookie: "#{cookie}",
          "user-agent": "test-agent",
          "x-forwarded-for": @random_ip
        )

      conn = Auth.call(conn, [])

      assert sent_resp(conn) ==
               {302,
                [
                  {"cache-control", "max-age=0, private, must-revalidate"},
                  {"location", "https://id.semaphoretest.test"}
                ], "Redirected to https://id.semaphoretest.test"}
    end

    test "when the resources request do not have any credentials => it returns 302" do
      conn = conn(:get, "https://id.semaphoretest.test/exauth/resources")

      conn =
        conn
        |> insert_headers(
          "user-agent": "test-agent",
          "x-forwarded-for": @random_ip
        )

      conn = Auth.call(conn, [])

      assert sent_resp(conn) ==
               {302,
                [
                  {"cache-control", "max-age=0, private, must-revalidate"},
                  {"location", "https://id.semaphoretest.test"}
                ], "Redirected to https://id.semaphoretest.test"}
    end

    test "when the login resources request do not have any credentials => it returns 200" do
      conn = conn(:get, "https://id.semaphoretest.test/exauth/resources/konmb/login")

      conn =
        conn
        |> insert_headers(
          "user-agent": "test-agent",
          "x-forwarded-for": @random_ip
        )

      conn = Auth.call(conn, [])

      assert sent_resp(conn) ==
               {200,
                [
                  {"cache-control", "max-age=0, private, must-revalidate"}
                ], ""}
    end

    test "when the request have a valid session cookie => it sets the x-semaphore-user-id and returns 200" do
      cookie = "#{Application.get_env(:auth, :cookie_name)}=#{@valid_cookie}"

      conn = conn(:get, "https://id.semaphoretest.test/exauth/somepath")

      conn =
        conn
        |> insert_headers(
          cookie: "#{cookie}",
          "user-agent": "test-agent",
          "x-forwarded-for": @random_ip
        )

      conn = Auth.call(conn, [])

      assert sent_resp(conn) ==
               {200,
                [
                  {"cache-control", "max-age=0, private, must-revalidate"},
                  {"x-semaphore-user-id", @user_id}
                ], ""}
    end

    test "when the request have an valid token => it returns 200" do
      conn = conn(:get, "https://id.semaphoretest.test/exauth/somepath")
      conn = conn |> put_req_header("authorization", "Token #{@valid_token}")
      conn = Auth.call(conn, [])

      assert sent_resp(conn) ==
               {200,
                [
                  {"cache-control", "max-age=0, private, must-revalidate"}
                ], ""}
    end

    test "when the request have an invalid token => it returns 200" do
      conn = conn(:get, "https://id.semaphoretest.test/exauth/somepath")
      conn = conn |> put_req_header("authorization", "Token YOLO")
      conn = Auth.call(conn, [])

      assert sent_resp(conn) ==
               {200,
                [
                  {"cache-control", "max-age=0, private, must-revalidate"}
                ], ""}
    end

    test "when the request have an invalid session cookie => it returns 200" do
      cookie = "#{Application.get_env(:auth, :cookie_name)}=lol"

      conn = conn(:get, "https://id.semaphoretest.test/exauth/somepath")

      conn =
        conn
        |> insert_headers(
          cookie: "#{cookie}",
          "user-agent": "test-agent",
          "x-forwarded-for": @random_ip
        )

      conn = Auth.call(conn, [])

      assert sent_resp(conn) ==
               {200,
                [
                  {"set-cookie", @delete_cookie},
                  {"cache-control", "max-age=0, private, must-revalidate"}
                ], ""}
    end

    test "blank request => returns 200" do
      conn = conn(:get, "https://id.semaphoretest.test/exauth/somepath")
      conn = Auth.call(conn, [])

      assert sent_resp(conn) ==
               {200,
                [
                  {"cache-control", "max-age=0, private, must-revalidate"}
                ], ""}
    end
  end

  describe "me.semaphoreci.com/exauth*path" do
    test "when the headers contain a valid Authorization Token => it returns 302" do
      conn = conn(:get, "https://me.semaphoretest.test/exauth/somepath")
      conn = conn |> put_req_header("authorization", "Token #{@valid_token}")
      conn = Auth.call(conn, [])

      {status, headers, _} = check_response(conn)
      assert status == 302

      assert %{
               "location" =>
                 "https://id.semaphoretest.test?redirect_to=https%3A%2F%2Fme.semaphoretest.test%2Fsomepath"
             } = headers
    end

    test "when the headers contain an invalid Authorization Token => it returns 302" do
      conn = conn(:get, "https://me.semaphoretest.test/exauth/somepath")
      conn = conn |> put_req_header("authorization", "Token lol")
      conn = Auth.call(conn, [])

      {status, headers, _} = check_response(conn)

      assert status == 302

      assert %{
               "location" =>
                 "https://id.semaphoretest.test?redirect_to=https%3A%2F%2Fme.semaphoretest.test%2Fsomepath"
             } = headers
    end

    test "when the request have a valid session cookie => it sets the x-semaphore-user-id and returns 200" do
      cookie = "#{Application.get_env(:auth, :cookie_name)}=#{@valid_cookie}"

      conn = conn(:get, "https://me.semaphoretest.test/exauth/somepath")

      conn =
        conn
        |> insert_headers(
          cookie: "#{cookie}",
          "user-agent": "test-agent",
          "x-forwarded-for": @random_ip
        )

      conn = Auth.call(conn, [])

      assert sent_resp(conn) ==
               {200,
                [
                  {"cache-control", "max-age=0, private, must-revalidate"},
                  {"x-semaphore-user-id", @user_id}
                ], ""}
    end

    test "when the request have an invalid session cookie => it returns 302" do
      cookie = "#{Application.get_env(:auth, :cookie_name)}=lol"

      conn = conn(:get, "https://me.semaphoretest.test/exauth/somepath")

      conn =
        conn
        |> insert_headers(
          cookie: "#{cookie}",
          "user-agent": "test-agent",
          "x-forwarded-for": @random_ip
        )

      conn = Auth.call(conn, [])

      {status, headers, _} = check_response(conn)

      assert status == 302

      assert %{"set-cookie" => @delete_cookie} = headers

      assert %{
               "location" =>
                 "https://id.semaphoretest.test?redirect_to=https%3A%2F%2Fme.semaphoretest.test%2Fsomepath"
             } = headers
    end

    test "blank request returns 302" do
      conn = conn(:get, "https://me.semaphoretest.test/exauth/somepath")
      conn = Auth.call(conn, [])

      {status, headers, _} = check_response(conn)

      assert status == 302

      assert %{
               "location" =>
                 "https://id.semaphoretest.test?redirect_to=https%3A%2F%2Fme.semaphoretest.test%2Fsomepath"
             } = headers
    end

    test "request non-existing org returns 302" do
      conn = conn(:get, "https://lolololololo.semaphoretest.test/exauth/somepath")
      conn = conn |> put_req_header("authorization", "Token #{@valid_token}")
      conn = Auth.call(conn, [])

      {status, headers, _} = check_response(conn)

      assert status == 302
      assert %{"location" => "https://id.semaphoretest.test"} = headers
    end
  end

  describe ".parse_request_token" do
    test "when the headers contain the Authorization Token => it returns the token" do
      headers = [
        {"a", 121},
        {"authorization", "Token abcd"}
      ]

      assert Auth.parse_auth_token(headers) == "abcd"
    end

    test "when the headers contain the Authorization but not the token type => it returns nil" do
      headers = [
        {"a", 121},
        {"authorization", "Basic abcd"}
      ]

      assert Auth.parse_auth_token(headers) == nil
    end

    test "when the headers don't have authorization tokens => it returns nil" do
      headers = [{"a", 121}]

      assert Auth.parse_auth_token(headers) == nil
    end
  end

  describe ".org_from_host" do
    test "it returns the username of the organization from the path" do
      assert Auth.org_from_host(%{host: "renderedtext.semaphoretest.test"}) == "renderedtext"
    end
  end

  describe "/exauth/api/v1/self_hosted_agents*path" do
    test "returns 200 OK for existing organization" do
      conn = conn(:post, "https://rt.semaphoretest.test/exauth/api/v1/self_hosted_agents/123")
      conn = Auth.call(conn, [])

      assert conn.status == 200
    end

    test "returns 401 Unauthorized for non existing organization" do
      conn = conn(:get, "https://lol.semaphoretest.test/exauth/api/v1/self_hosted_agents")
      conn = Auth.call(conn, [])

      assert conn.status == 401
    end

    test "request restricted org with empty allow list" do
      conn =
        conn(
          :get,
          "https://open-restricted-org.semaphoretest.test/exauth/api/v1/self_hosted_agents/123"
        )

      conn = Auth.call(conn, [])

      assert conn.status == 200
    end

    test "request from not allowed IP is blocked for restricted org" do
      conn =
        Plug.Adapters.Test.Conn.conn(
          %Plug.Conn{req_headers: [{"x-forwarded-for", "35.121.222.37"}]},
          :get,
          "https://closed-restricted-org.semaphoretest.test/exauth/api/v1/self_hosted_agents/123",
          nil
        )

      conn = Auth.call(conn, [])

      assert conn.status == 404
    end

    test "request from allowed IP is not blocked for restricted org" do
      conn =
        Plug.Adapters.Test.Conn.conn(
          %Plug.Conn{req_headers: [{"x-forwarded-for", @closed_restricted_org_ip}]},
          :get,
          "https://closed-restricted-org.semaphoretest.test/exauth/api/v1/self_hosted_agents/123",
          nil
        )

      conn = Auth.call(conn, [])

      assert conn.status == 200
    end
  end

  describe "/exauth/api/v1/logs*path" do
    test "returns 200 OK for existing organization" do
      conn = conn(:post, "https://rt.semaphoretest.test/exauth/api/v1/logs")
      conn = Auth.call(conn, [])

      assert conn.status == 200
    end

    test "returns 401 Unauthorized for non existing organization" do
      conn = conn(:get, "https://lol.semaphoretest.test/exauth/api/v1/logs")
      conn = Auth.call(conn, [])

      assert conn.status == 401
    end

    test "request restricted org with empty allow list" do
      conn =
        conn(
          :get,
          "https://open-restricted-org.semaphoretest.test/exauth/api/v1/logs"
        )

      conn = Auth.call(conn, [])

      assert conn.status == 200
    end

    test "request from not allowed IP is blocked for restricted org" do
      conn =
        Plug.Adapters.Test.Conn.conn(
          %Plug.Conn{req_headers: [{"x-forwarded-for", "35.121.222.37"}]},
          :get,
          "https://closed-restricted-org.semaphoretest.test/exauth/api/v1/logs",
          nil
        )

      conn = Auth.call(conn, [])

      assert conn.status == 404
    end

    test "request from allowed IP is not blocked for restricted org" do
      conn =
        Plug.Adapters.Test.Conn.conn(
          %Plug.Conn{req_headers: [{"x-forwarded-for", @closed_restricted_org_ip}]},
          :get,
          "https://closed-restricted-org.semaphoretest.test/exauth/api/v1/logs",
          nil
        )

      conn = Auth.call(conn, [])

      assert conn.status == 200
    end
  end

  describe "/exauth/api/v1/artifacts*path" do
    test "returns 200 OK for existing organization" do
      conn = conn(:post, "https://rt.semaphoretest.test/exauth/api/v1/artifacts/123")
      conn = Auth.call(conn, [])

      assert conn.status == 200
    end

    test "returns 401 Unauthorized for non existing organization" do
      conn = conn(:get, "https://lol.semaphoretest.test/exauth/api/v1/artifacts")
      conn = Auth.call(conn, [])

      assert conn.status == 401
    end

    test "request restricted org with empty allow list" do
      conn = conn(:get, "https://open-restricted-org.semaphoretest.test/exauth/api/v1/artifacts")
      conn = Auth.call(conn, [])

      assert conn.status == 200
    end

    test "request from not allowed IP is blocked for restricted org" do
      conn =
        Plug.Adapters.Test.Conn.conn(
          %Plug.Conn{req_headers: [{"x-forwarded-for", "35.121.222.37"}]},
          :get,
          "https://closed-restricted-org.semaphoretest.test/exauth/api/v1/artifacts",
          nil
        )

      conn = Auth.call(conn, [])

      assert conn.status == 404
    end

    test "request from allowed IP is not blocked for restricted org" do
      conn =
        Plug.Adapters.Test.Conn.conn(
          %Plug.Conn{req_headers: [{"x-forwarded-for", @closed_restricted_org_ip}]},
          :get,
          "https://closed-restricted-org.semaphoretest.test/exauth/api/v1/artifacts",
          nil
        )

      conn = Auth.call(conn, [])

      assert conn.status == 200
    end
  end

  ###
  ### Helper functions
  ###

  defp blocked_ip_response(ip) do
    """
      You cannot access this organization from your current IP address (#{ip}) due to the security settings enabled by the organization administrator.
      Please contact the organization owner/administrator if you think this is a mistake or reach out to our support team.
    """
  end

  defp check_response(conn) do
    {status, headers, body} = sent_resp(conn)
    headers = Enum.into(headers, %{})

    {status, headers, body}
  end

  defp insert_headers(conn, headers) do
    Enum.reduce(headers, conn, fn {header_name, header_value}, conn ->
      conn |> put_req_header(Atom.to_string(header_name), header_value)
    end)
  end
end
