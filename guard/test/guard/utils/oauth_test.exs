defmodule Guard.Utils.OAuthTest do
  use ExUnit.Case, async: true

  alias Guard.Utils.OAuth

  # Bitbucket's response on a genuinely dead grant, captured live.
  @bitbucket_dead_grant %{
    "error" => "unauthorized_client",
    "error_description" => "refresh_token is invalid"
  }

  describe "classify_refresh_response/2 - genuine revocations" do
    test "a 2xx is always :ok" do
      assert OAuth.classify_refresh_response(200, %{}) == :ok
      assert OAuth.classify_refresh_response(299, "") == :ok
    end

    test "invalid_grant is a revocation on every provider" do
      assert OAuth.classify_refresh_response(400, %{"error" => "invalid_grant"}) == :revoked
    end

    test "bad_refresh_token (GitHub) is a revocation" do
      assert OAuth.classify_refresh_response(400, %{"error" => "bad_refresh_token"}) == :revoked
    end

    test "a raw JSON string body is decoded before classifying" do
      # The Bitbucket token client posts form-urlencoded, so a response body can
      # still reach the classifier undecoded.
      assert OAuth.classify_refresh_response(400, ~s({"error":"invalid_grant"})) == :revoked

      assert OAuth.classify_refresh_response(403, Jason.encode!(@bitbucket_dead_grant)) ==
               :revoked
    end

    test "Bitbucket's unauthorized_client + 'refresh_token is invalid' is a revocation" do
      # Previously classified :transient, so a dead Bitbucket connection was
      # retried forever: the row stayed revoked=false, the UI kept showing it as
      # connected, and the people page never offered the re-grant link (it
      # renders that link off the revoked flag). The user could not self-serve.
      assert OAuth.classify_refresh_response(403, @bitbucket_dead_grant) == :revoked
    end

    test "the description is matched loosely, not byte-exactly" do
      for description <- [
            "refresh_token is invalid",
            "Refresh_Token Is Invalid",
            "The refresh token is invalid or expired",
            "refresh token expired"
          ] do
        body = %{"error" => "unauthorized_client", "error_description" => description}

        assert OAuth.classify_refresh_response(403, body) == :revoked,
               "expected :revoked for description #{inspect(description)}"
      end
    end
  end

  describe "classify_refresh_response/2 - unauthorized_client must not mass-revoke" do
    # RFC 6749 section 5.2 reserves `unauthorized_client` for "the authenticated
    # CLIENT is not authorized to use this authorization grant type" - our
    # shared OAuth consumer, not one user's grant. Matching the code alone would
    # revoke every account on a provider the moment that consumer is
    # misconfigured or disabled, which is the failure class this classifier
    # exists to prevent. Only a description naming the refresh token may revoke.

    test "a bare unauthorized_client with NO description is transient" do
      assert OAuth.classify_refresh_response(403, %{"error" => "unauthorized_client"}) ==
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

        assert OAuth.classify_refresh_response(403, body) == :transient,
               "expected :transient for description #{inspect(description)}"
      end
    end

    test "a bare unauthorized_client on a 401 is transient" do
      # genuine_grant_revocation?/1 is consulted BEFORE the HTTP 401 guard, so
      # the description check is the only thing standing between a client-level
      # rejection and a mass revoke. It holds on 401 exactly as it does on 403.
      assert OAuth.classify_refresh_response(401, %{"error" => "unauthorized_client"}) ==
               :transient
    end

    test "a refresh-token description still revokes on a 401, and that is intended" do
      # The deliberate limit of the rule above: a client-level rejection never
      # says the user's refresh token is invalid, so when the description does
      # say it, the grant is dead whatever the status code.
      body = %{
        "error" => "unauthorized_client",
        "error_description" => "refresh_token is invalid"
      }

      assert OAuth.classify_refresh_response(401, body) == :revoked
    end
  end

  describe "classify_refresh_response/2 - transient failures stay transient" do
    test "a bare 401 / invalid_client is our credentials, not a user's grant" do
      assert OAuth.classify_refresh_response(401, %{}) == :transient
      assert OAuth.classify_refresh_response(401, %{"error" => "invalid_client"}) == :transient
    end

    test "an empty-body 403 (edge/WAF block) is transient" do
      assert OAuth.classify_refresh_response(403, "") == :transient
    end

    test "throttling and server errors are transient" do
      assert OAuth.classify_refresh_response(429, %{}) == :transient
      assert OAuth.classify_refresh_response(500, %{}) == :transient
      assert OAuth.classify_refresh_response(503, "") == :transient
    end

    test "an undecodable body is transient" do
      assert OAuth.classify_refresh_response(403, "<html>gateway</html>") == :transient
      assert OAuth.classify_refresh_response(400, nil) == :transient
    end
  end
end
