defmodule Guard.Utils.OAuthTest do
  use ExUnit.Case, async: true

  alias Guard.Utils.OAuth

  # Bitbucket's response on a genuinely dead grant, captured live.
  @bitbucket_dead_grant %{
    "error" => "unauthorized_client",
    "error_description" => "refresh_token is invalid"
  }

  describe "classify_refresh_response/3 - genuine revocations" do
    test "a 2xx is always :ok" do
      assert OAuth.classify_refresh_response("bitbucket", 200, %{}) == :ok
      assert OAuth.classify_refresh_response("bitbucket", 299, "") == :ok
    end

    test "invalid_grant is a revocation on every provider" do
      assert OAuth.classify_refresh_response("bitbucket", 400, %{"error" => "invalid_grant"}) ==
               :revoked
    end

    test "bad_refresh_token (GitHub) is a revocation" do
      assert OAuth.classify_refresh_response("bitbucket", 400, %{"error" => "bad_refresh_token"}) ==
               :revoked
    end

    test "a raw JSON string body is decoded before classifying" do
      # The Bitbucket token client posts form-urlencoded, so a response body can
      # still reach the classifier undecoded.
      assert OAuth.classify_refresh_response("bitbucket", 400, ~s({"error":"invalid_grant"})) ==
               :revoked

      assert OAuth.classify_refresh_response(
               "bitbucket",
               403,
               Jason.encode!(@bitbucket_dead_grant)
             ) ==
               :revoked
    end

    test "Bitbucket's unauthorized_client + 'refresh_token is invalid' is a revocation" do
      # Previously classified :transient, so a dead Bitbucket connection was
      # retried forever: the row stayed revoked=false, the UI kept showing it as
      # connected, and the people page never offered the re-grant link (it
      # renders that link off the revoked flag). The user could not self-serve.
      assert OAuth.classify_refresh_response("bitbucket", 403, @bitbucket_dead_grant) == :revoked
    end

    test "the description is matched loosely, not byte-exactly" do
      for description <- [
            "refresh_token is invalid",
            "Refresh_Token Is Invalid",
            "The refresh token is invalid or expired",
            "refresh token expired"
          ] do
        body = %{"error" => "unauthorized_client", "error_description" => description}

        assert OAuth.classify_refresh_response("bitbucket", 403, body) == :revoked,
               "expected :revoked for description #{inspect(description)}"
      end
    end
  end

  describe "classify_refresh_response/3 - unauthorized_client must not mass-revoke" do
    # RFC 6749 section 5.2 reserves `unauthorized_client` for "the authenticated
    # CLIENT is not authorized to use this authorization grant type" - our
    # shared OAuth consumer, not one user's grant. Matching the code alone would
    # revoke every account on a provider the moment that consumer is
    # misconfigured or disabled, which is the failure class this classifier
    # exists to prevent. Only a description naming the refresh token may revoke.

    test "a bare unauthorized_client with NO description is transient" do
      assert OAuth.classify_refresh_response("bitbucket", 403, %{"error" => "unauthorized_client"}) ==
               :transient
    end

    test "a client-level unauthorized_client description is transient" do
      for description <- [
            "The client is not authorized to use this authorization grant type",
            "client is disabled",
            "",
            nil
          ] do
        body = %{"error" => "unauthorized_client", "error_description" => description}

        assert OAuth.classify_refresh_response("bitbucket", 403, body) == :transient,
               "expected :transient for description #{inspect(description)}"
      end
    end

    test "a bare unauthorized_client on a 401 is transient" do
      # genuine_grant_revocation?/1 is consulted BEFORE the HTTP 401 guard, so
      # the description check is the only thing standing between a client-level
      # rejection and a mass revoke. It holds on 401 exactly as it does on 403.
      assert OAuth.classify_refresh_response("bitbucket", 401, %{"error" => "unauthorized_client"}) ==
               :transient
    end

    test "even a refresh-token description does NOT revoke on a 401" do
      # 401 is the status an OAuth server returns when it rejects
      # `Authorization: Basic client_id:secret`, which is exactly how the
      # Bitbucket and GitLab token clients authenticate - so it is where
      # client-level wording actually arrives. Both observed dead-grant shapes
      # are 403 and 400, so excluding 401 costs nothing real.
      body = %{
        "error" => "unauthorized_client",
        "error_description" => "refresh_token is invalid"
      }

      assert OAuth.classify_refresh_response("bitbucket", 401, body) == :transient
    end
  end

  describe "C1: client-level wording must not revoke" do
    # Our grant_type is literally `refresh_token`, so RFC 6749 section 5.2's
    # canonical CLIENT-level refusal for our own request names the refresh
    # token. A bare substring test cannot tell that apart from a dead grant,
    # and getting it wrong revokes every account on the provider at once.
    @client_level_descriptions [
      "The client is not authorized to use the refresh_token grant type",
      "Unauthorized grant type: refresh_token",
      "unauthorized_client: refresh_token",
      "Client is not allowed to use grant_type=refresh_token",
      "This OAuth consumer may not use the refresh token grant",
      "invalid client credentials for refresh_token grant",
      "The refresh token grant is not enabled for this application",
      "This application is not permitted to use the refresh token flow"
    ]

    test "every realistic client-level phrasing stays transient" do
      for description <- @client_level_descriptions, status <- [400, 403] do
        body = %{"error" => "unauthorized_client", "error_description" => description}

        assert OAuth.classify_refresh_response("bitbucket", status, body) == :transient,
               "expected :transient on HTTP #{status} for #{inspect(description)}"
      end
    end

    test "a user-level phrasing still revokes" do
      for description <- [
            "refresh_token is invalid",
            "Invalid refresh_token",
            "The refresh token is expired",
            "refresh_token has been revoked",
            "refresh token not found"
          ] do
        body = %{"error" => "unauthorized_client", "error_description" => description}

        assert OAuth.classify_refresh_response("bitbucket", 403, body) == :revoked,
               "expected :revoked for #{inspect(description)}"
      end
    end

    test "naming the token is not enough without an invalidity word" do
      # "not enabled" / "not permitted" are refusals no exclusion list would
      # enumerate - the positive condition is what catches them.
      body = %{
        "error" => "unauthorized_client",
        "error_description" => "refresh_token grant is not enabled"
      }

      assert OAuth.classify_refresh_response("bitbucket", 403, body) == :transient
    end
  end

  describe "C2: invalid_request is the second dead-grant shape" do
    @invalid_request %{
      "error" => "invalid_request",
      "error_description" => "Invalid refresh_token"
    }

    test "it revokes" do
      assert OAuth.classify_refresh_response("bitbucket", 400, @invalid_request) == :revoked
    end

    test "it is gated exactly like unauthorized_client" do
      # Bare code: it is the generic malformed-request code, possibly OUR bug.
      assert OAuth.classify_refresh_response("bitbucket", 400, %{"error" => "invalid_request"}) ==
               :transient

      client_level = %{
        "error" => "invalid_request",
        "error_description" => "invalid client credentials for refresh_token grant"
      }

      assert OAuth.classify_refresh_response("bitbucket", 400, client_level) == :transient
      assert OAuth.classify_refresh_response("bitbucket", 401, @invalid_request) == :transient
    end
  end

  describe "M1: the ambiguous codes are Bitbucket-only" do
    test "GitHub and GitLab never revoke on them" do
      for provider <- ["github", "gitlab"],
          error <- ["unauthorized_client", "invalid_request"] do
        body = %{"error" => error, "error_description" => "refresh_token is invalid"}

        assert OAuth.classify_refresh_response(provider, 403, body) == :transient,
               "expected :transient for #{provider} / #{error}"
      end
    end

    test "the unambiguous codes still work on every provider" do
      for provider <- ["github", "gitlab", "bitbucket"] do
        assert OAuth.classify_refresh_response(provider, 400, %{"error" => "invalid_grant"}) ==
                 :revoked

        assert OAuth.classify_refresh_response(provider, 400, %{"error" => "bad_refresh_token"}) ==
                 :revoked
      end
    end
  end

  describe "a deactivated Bitbucket user" do
    @inactive %{"error" => "access_denied", "error_description" => "User is inactive"}

    test "revokes even on a 401" do
      # Unlike the ambiguous codes, this is a statement about the END USER's
      # account, never about our OAuth consumer - so the 401 exclusion that
      # protects those codes does not apply here.
      assert OAuth.classify_refresh_response("bitbucket", 401, @inactive) == :revoked
    end

    test "a bare access_denied does not revoke" do
      assert OAuth.classify_refresh_response("bitbucket", 401, %{"error" => "access_denied"}) ==
               :transient
    end

    test "it is scoped to Bitbucket like the other observed shapes" do
      assert OAuth.classify_refresh_response("gitlab", 401, @inactive) == :transient
    end
  end

  describe "classify_refresh_response/3 - transient failures stay transient" do
    test "a bare 401 / invalid_client is our credentials, not a user's grant" do
      assert OAuth.classify_refresh_response("bitbucket", 401, %{}) == :transient

      assert OAuth.classify_refresh_response("bitbucket", 401, %{"error" => "invalid_client"}) ==
               :transient
    end

    test "an empty-body 403 (edge/WAF block) is transient" do
      assert OAuth.classify_refresh_response("bitbucket", 403, "") == :transient
    end

    test "throttling and server errors are transient" do
      assert OAuth.classify_refresh_response("bitbucket", 429, %{}) == :transient
      assert OAuth.classify_refresh_response("bitbucket", 500, %{}) == :transient
      assert OAuth.classify_refresh_response("bitbucket", 503, "") == :transient
    end

    test "an undecodable body is transient" do
      assert OAuth.classify_refresh_response("bitbucket", 403, "<html>gateway</html>") ==
               :transient

      assert OAuth.classify_refresh_response("bitbucket", 400, nil) == :transient
    end
  end
end
