defmodule Guard.GrpcServers.McpGrantServerTest do
  use Guard.RepoCase, async: false

  alias InternalApi.McpGrant
  alias InternalApi.McpGrant.McpGrantService.Stub

  setup do
    {:ok, user} = Support.Factories.RbacUser.insert()

    client_id = "mcp-client-#{System.unique_integer([:positive])}"
    redirect_uri = "https://example.test/callback"

    {:ok, _client} =
      Guard.Store.McpOAuthClient.create(%{
        client_id: client_id,
        client_name: "Test MCP Client",
        redirect_uris: [redirect_uri]
      })

    {:ok, channel} = GRPC.Stub.connect("localhost:50051")

    {:ok, channel: channel, user: user, client_id: client_id, redirect_uri: redirect_uri}
  end

  test "creates, fetches, and revokes an MCP grant", %{
    channel: channel,
    user: user,
    client_id: client_id
  } do
    create_request =
      McpGrant.CreateRequest.new(
        user_id: user.id,
        client_id: client_id,
        client_name: "Test MCP Client",
        tool_scopes: ["mcp"]
      )

    {:ok, create_response} = Stub.create(channel, create_request)
    assert create_response.grant.id != ""
    assert create_response.grant.user_id == user.id
    assert create_response.grant.client_id == client_id

    grant_id = create_response.grant.id

    {:ok, get_response} =
      Stub.get_grant(channel, McpGrant.GetGrantRequest.new(grant_id: grant_id))

    assert get_response.is_valid == true
    assert get_response.grant.id == grant_id

    {:ok, revoke_response} =
      Stub.revoke(channel, McpGrant.RevokeRequest.new(grant_id: grant_id, user_id: user.id))

    assert revoke_response.grant.id == grant_id
    refute is_nil(revoke_response.grant.revoked_at)

    {:ok, revoked_get_response} =
      Stub.get_grant(channel, McpGrant.GetGrantRequest.new(grant_id: grant_id))

    assert revoked_get_response.is_valid == false
  end

  test "creates consent challenge, approves it, and resolves grant", %{
    channel: channel,
    user: user,
    client_id: client_id,
    redirect_uri: redirect_uri
  } do
    create_challenge_request =
      McpGrant.CreateConsentChallengeRequest.new(
        user_id: user.id,
        client_id: client_id,
        client_name: "Test MCP Client",
        redirect_uri: redirect_uri,
        code_challenge: "challenge123",
        code_challenge_method: "S256",
        state: "xyz",
        requested_scope: "mcp"
      )

    {:ok, challenge_response} = Stub.create_consent_challenge(channel, create_challenge_request)
    assert challenge_response.challenge_id != ""

    approve_request =
      McpGrant.ApproveConsentChallengeRequest.new(
        challenge_id: challenge_response.challenge_id,
        user_id: user.id,
        selection: McpGrant.GrantSelection.new(tool_scopes: ["mcp"])
      )

    {:ok, approve_response} = Stub.approve_consent_challenge(channel, approve_request)

    assert approve_response.grant_id != ""
    assert approve_response.authorization_code != ""
    assert approve_response.redirect_uri == redirect_uri
    assert String.contains?(approve_response.redirect_url, "code=")

    resolve_request =
      McpGrant.ResolveGrantForAuthRequest.new(
        grant_id: approve_response.grant_id,
        user_id: user.id
      )

    {:ok, resolve_response} = Stub.resolve_grant_for_auth(channel, resolve_request)

    assert resolve_response.valid == true
    assert resolve_response.grant.id == approve_response.grant_id
    assert "mcp" in resolve_response.tool_scopes

    {:ok, grant_response} =
      Stub.get_grant(channel, McpGrant.GetGrantRequest.new(grant_id: approve_response.grant_id))

    assert grant_response.grant.expires_at != nil

    expires_at = DateTime.from_unix!(grant_response.grant.expires_at.seconds)

    assert DateTime.compare(
             expires_at,
             DateTime.utc_now() |> DateTime.add(29 * 24 * 60 * 60, :second)
           ) ==
             :gt
  end

  test "rejects approval when selection includes unauthorized resources", %{
    channel: channel,
    user: user,
    client_id: client_id,
    redirect_uri: redirect_uri
  } do
    create_challenge_request =
      McpGrant.CreateConsentChallengeRequest.new(
        user_id: user.id,
        client_id: client_id,
        client_name: "Test MCP Client",
        redirect_uri: redirect_uri,
        code_challenge: "challenge123",
        code_challenge_method: "S256",
        state: "xyz",
        requested_scope: "mcp"
      )

    {:ok, challenge_response} = Stub.create_consent_challenge(channel, create_challenge_request)

    unauthorized_org_id = Ecto.UUID.generate()

    approve_request =
      McpGrant.ApproveConsentChallengeRequest.new(
        challenge_id: challenge_response.challenge_id,
        user_id: user.id,
        selection:
          McpGrant.GrantSelection.new(
            tool_scopes: ["mcp"],
            org_grants: [
              McpGrant.OrgGrantInput.new(
                org_id: unauthorized_org_id,
                can_view: true,
                can_run_workflows: false
              )
            ]
          )
      )

    assert {:error,
            %GRPC.RPCError{status: 9, message: "Requested organization grant is not allowed"}} =
             Stub.approve_consent_challenge(channel, approve_request)
  end

  test "denies consent challenge", %{
    channel: channel,
    user: user,
    client_id: client_id,
    redirect_uri: redirect_uri
  } do
    create_challenge_request =
      McpGrant.CreateConsentChallengeRequest.new(
        user_id: user.id,
        client_id: client_id,
        client_name: "Test MCP Client",
        redirect_uri: redirect_uri,
        code_challenge: "challenge123",
        code_challenge_method: "S256",
        state: "xyz",
        requested_scope: "mcp"
      )

    {:ok, challenge_response} = Stub.create_consent_challenge(channel, create_challenge_request)

    deny_request =
      McpGrant.DenyConsentChallengeRequest.new(
        challenge_id: challenge_response.challenge_id,
        user_id: user.id,
        error: "access_denied",
        error_description: "User denied"
      )

    {:ok, deny_response} = Stub.deny_consent_challenge(channel, deny_request)

    assert deny_response.redirect_uri == redirect_uri
    assert String.contains?(deny_response.redirect_url, "error=access_denied")
  end

  test "finds existing valid grant for user/client", %{
    channel: channel,
    user: user,
    client_id: client_id
  } do
    {:ok, create_response} =
      Stub.create(
        channel,
        McpGrant.CreateRequest.new(
          user_id: user.id,
          client_id: client_id,
          client_name: "Test MCP Client",
          tool_scopes: ["mcp"]
        )
      )

    {:ok, find_response} =
      Stub.find_existing_grant(
        channel,
        McpGrant.FindExistingGrantRequest.new(user_id: user.id, client_id: client_id)
      )

    assert find_response.found == true
    assert find_response.grant.id == create_response.grant.id
  end
end
