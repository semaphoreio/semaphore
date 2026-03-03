defmodule FrontWeb.McpOAuthControllerTest do
  use FrontWeb.ConnCase

  setup %{conn: conn} do
    Cacheman.clear(:front)

    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    user = Support.Stubs.User.default()

    conn =
      conn
      |> put_req_header("x-semaphore-user-id", user.id)

    [conn: conn, user: user]
  end

  describe "GET /mcp/oauth/grant-selection" do
    test "renders consent page for valid challenge", %{conn: conn, user: user} do
      challenge_id = Ecto.UUID.generate()

      GrpcMock.stub(McpGrantMock, :describe_consent_challenge, fn request, _stream ->
        assert request.challenge_id == challenge_id
        assert request.user_id == user.id
        describe_consent_response(challenge_id, user.id)
      end)

      conn = get(conn, "/mcp/oauth/grant-selection?consent_challenge=#{challenge_id}")

      assert html_response(conn, 200) =~ "Authorize MCP Access"
      assert html_response(conn, 200) =~ "Test MCP Client"
      assert html_response(conn, 200) =~ "consent_challenge"
    end

    test "returns 404 when challenge is missing or expired", %{conn: conn} do
      GrpcMock.stub(McpGrantMock, :describe_consent_challenge, fn _request, _stream ->
        raise GRPC.RPCError,
          status: GRPC.Status.not_found(),
          message: "Consent challenge not found or expired"
      end)

      conn = get(conn, "/mcp/oauth/grant-selection?consent_challenge=missing")

      assert response(conn, 404) =~ "Consent challenge not found or expired"
    end
  end

  describe "POST /mcp/oauth/grant-selection" do
    test "denies challenge and redirects to OAuth client", %{conn: conn, user: user} do
      challenge_id = Ecto.UUID.generate()
      redirect_url = "https://cli.example.com/callback?error=access_denied&state=abc123"

      GrpcMock.stub(McpGrantMock, :deny_consent_challenge, fn request, _stream ->
        assert request.challenge_id == challenge_id
        assert request.user_id == user.id

        InternalApi.McpGrant.DenyConsentChallengeResponse.new(
          redirect_uri: "https://cli.example.com/callback",
          state: "abc123",
          redirect_url: redirect_url
        )
      end)

      conn =
        post(conn, "/mcp/oauth/grant-selection", %{
          "consent_challenge" => challenge_id,
          "decision" => "deny"
        })

      assert redirected_to(conn, 302) == redirect_url
    end

    test "defaults to deny when decision is unknown", %{conn: conn, user: user} do
      challenge_id = Ecto.UUID.generate()
      redirect_url = "https://cli.example.com/callback?error=access_denied&state=abc123"

      GrpcMock.stub(McpGrantMock, :deny_consent_challenge, fn request, _stream ->
        assert request.challenge_id == challenge_id
        assert request.user_id == user.id

        InternalApi.McpGrant.DenyConsentChallengeResponse.new(
          redirect_uri: "https://cli.example.com/callback",
          state: "abc123",
          redirect_url: redirect_url
        )
      end)

      conn =
        post(conn, "/mcp/oauth/grant-selection", %{
          "consent_challenge" => challenge_id,
          "decision" => "unexpected"
        })

      assert redirected_to(conn, 302) == redirect_url
    end

    test "returns 502 when deny redirect URL is invalid", %{conn: conn, user: user} do
      challenge_id = Ecto.UUID.generate()

      GrpcMock.stub(McpGrantMock, :deny_consent_challenge, fn request, _stream ->
        assert request.challenge_id == challenge_id
        assert request.user_id == user.id

        InternalApi.McpGrant.DenyConsentChallengeResponse.new(
          redirect_uri: "javascript:alert(1)",
          state: "abc123",
          redirect_url: "javascript:alert(1)"
        )
      end)

      conn =
        post(conn, "/mcp/oauth/grant-selection", %{
          "consent_challenge" => challenge_id,
          "decision" => "deny"
        })

      assert response(conn, 502) =~ "Invalid redirect URL returned from authorization server"
    end

    test "approves challenge with sanitized permissions", %{conn: conn, user: user} do
      challenge_id = Ecto.UUID.generate()
      success_redirect = "https://cli.example.com/callback?code=auth-code-1&state=abc123"

      GrpcMock.stub(McpGrantMock, :describe_consent_challenge, fn _request, _stream ->
        describe_consent_response(challenge_id, user.id)
      end)

      GrpcMock.stub(McpGrantMock, :approve_consent_challenge, fn request, _stream ->
        assert request.challenge_id == challenge_id
        assert request.user_id == user.id
        assert request.selection.tool_scopes == ["mcp"]

        assert request.selection.org_grants == [
                 InternalApi.McpGrant.OrgGrantInput.new(
                   org_id: "org-1",
                   can_view: true,
                   can_run_workflows: false
                 )
               ]

        assert request.selection.project_grants == [
                 InternalApi.McpGrant.ProjectGrantInput.new(
                   project_id: "project-1",
                   org_id: "org-1",
                   can_view: true,
                   can_run_workflows: true,
                   can_view_logs: false
                 )
               ]

        InternalApi.McpGrant.ApproveConsentChallengeResponse.new(
          grant_id: Ecto.UUID.generate(),
          authorization_code: "auth-code-1",
          redirect_uri: "https://cli.example.com/callback",
          state: "abc123",
          redirect_url: success_redirect,
          reused_existing_grant: false
        )
      end)

      conn =
        post(conn, "/mcp/oauth/grant-selection", %{
          "consent_challenge" => challenge_id,
          "decision" => "approve",
          "selection" => %{
            "org_grants" => %{
              "org-1" => %{"can_view" => "true", "can_run_workflows" => "true"},
              "org-evil" => %{"can_view" => "true"}
            },
            "project_grants" => %{
              "project-1" => %{
                "can_view" => "true",
                "can_run_workflows" => "true",
                "can_view_logs" => "true"
              },
              "project-evil" => %{
                "can_view" => "true",
                "can_run_workflows" => "true",
                "can_view_logs" => "true"
              }
            }
          }
        })

      assert redirected_to(conn, 302) == success_redirect
    end

    test "returns 502 when approve redirect URL is invalid", %{conn: conn, user: user} do
      challenge_id = Ecto.UUID.generate()

      GrpcMock.stub(McpGrantMock, :describe_consent_challenge, fn _request, _stream ->
        describe_consent_response(challenge_id, user.id)
      end)

      GrpcMock.stub(McpGrantMock, :approve_consent_challenge, fn request, _stream ->
        assert request.challenge_id == challenge_id
        assert request.user_id == user.id

        InternalApi.McpGrant.ApproveConsentChallengeResponse.new(
          grant_id: Ecto.UUID.generate(),
          authorization_code: "auth-code-1",
          redirect_uri: "javascript:alert(1)",
          state: "abc123",
          redirect_url: "javascript:alert(1)",
          reused_existing_grant: false
        )
      end)

      conn =
        post(conn, "/mcp/oauth/grant-selection", %{
          "consent_challenge" => challenge_id,
          "decision" => "approve",
          "selection" => %{}
        })

      assert response(conn, 502) =~ "Invalid redirect URL returned from authorization server"
    end
  end

  defp describe_consent_response(challenge_id, user_id) do
    InternalApi.McpGrant.DescribeConsentChallengeResponse.new(
      challenge:
        InternalApi.McpGrant.ConsentChallenge.new(
          id: challenge_id,
          user_id: user_id,
          client_id: "client-1",
          client_name: "Test MCP Client",
          redirect_uri: "https://cli.example.com/callback",
          code_challenge: "challenge",
          code_challenge_method: "S256",
          state: "abc123",
          requested_scope: "mcp"
        ),
      found_existing_grant: true,
      default_selection:
        InternalApi.McpGrant.GrantSelection.new(
          tool_scopes: ["mcp"],
          org_grants: [
            InternalApi.McpGrant.OrgGrantInput.new(
              org_id: "org-1",
              can_view: true,
              can_run_workflows: false
            )
          ],
          project_grants: [
            InternalApi.McpGrant.ProjectGrantInput.new(
              project_id: "project-1",
              org_id: "org-1",
              can_view: true,
              can_run_workflows: true,
              can_view_logs: false
            )
          ]
        ),
      available_organizations: [
        InternalApi.McpGrant.GrantableOrganization.new(
          org_id: "org-1",
          org_name: "Acme Org",
          can_view: true,
          can_run_workflows: false
        )
      ],
      available_projects: [
        InternalApi.McpGrant.GrantableProject.new(
          project_id: "project-1",
          org_id: "org-1",
          org_name: "Acme Org",
          project_name: "api-service",
          can_view: true,
          can_run_workflows: true,
          can_view_logs: false
        )
      ]
    )
  end
end
