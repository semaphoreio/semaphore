defmodule Guard.Utils.OAuthTest do
  use ExUnit.Case, async: true

  alias Guard.Utils.OAuth

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

    test "Bitbucket's three dead-grant signatures are revocations" do
      for {status, error, description} <- [
            {403, "unauthorized_client", "refresh_token is invalid"},
            {400, "invalid_request", "Invalid refresh_token"},
            {401, "access_denied", "User is inactive"}
          ] do
        body = %{"error" => error, "error_description" => description}

        assert OAuth.classify_refresh_response("bitbucket", status, body) == :revoked,
               "expected :revoked for #{error} / #{inspect(description)}"
      end
    end

    test "a signature is normalised for case, surrounding space and a trailing period" do
      for description <- [
            "refresh_token is invalid",
            "REFRESH_TOKEN IS INVALID",
            "  refresh_token is invalid  ",
            "refresh_token is invalid."
          ] do
        body = %{"error" => "unauthorized_client", "error_description" => description}

        assert OAuth.classify_refresh_response("bitbucket", 403, body) == :revoked,
               "expected :revoked for #{inspect(description)}"
      end
    end
  end

  describe "classify_refresh_response/3 - ambiguous codes need an exact signature" do
    # unauthorized_client, invalid_request and access_denied all describe
    # CLIENT-level or malformed-request faults in RFC 6749. Bitbucket reuses
    # them for a dead grant, so only its exact wording may revoke - anything
    # else would disconnect accounts over our own fault or a generic error.
    @client_and_request_level [
      {403, "unauthorized_client",
       "Application credentials are invalid for refresh_token requests"},
      {401, "access_denied", "OAuth client is inactive for this user"},
      {400, "invalid_request", "invalid_request: refresh_token"},
      {400, "invalid_request", "Invalid request: refresh_token parameter is missing"},
      {500, "invalid_request",
       "An unknown error occurred while processing the refresh_token request"},
      {403, "unauthorized_client",
       "The client is not authorized to use the refresh_token grant type"},
      {403, "unauthorized_client", "This OAuth consumer may not use the refresh token grant"},
      {403, "unauthorized_client", "The refresh token grant is not enabled for this application"},
      {400, "invalid_request", "refresh_token parameter is malformed"}
    ]

    test "none of them revoke" do
      for {status, error, description} <- @client_and_request_level do
        body = %{"error" => error, "error_description" => description}

        assert OAuth.classify_refresh_response("bitbucket", status, body) == :transient,
               "expected :transient on HTTP #{status} for #{error} / #{inspect(description)}"
      end
    end

    test "an unrecognised ambiguous code is logged so a rewording surfaces" do
      # Without this the grants would loop indefinitely with nothing to show
      # for it, which is the failure mode this whole change exists to remove.
      body = %{
        "error" => "unauthorized_client",
        "error_description" => "some wording we have never seen"
      }

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          assert OAuth.classify_refresh_response("bitbucket", 403, body) == :transient
        end)

      assert log =~ "Unrecognised bitbucket unauthorized_client wording"
    end

    test "a bare ambiguous code with no description is transient" do
      for error <- ["unauthorized_client", "invalid_request", "access_denied"] do
        assert OAuth.classify_refresh_response("bitbucket", 403, %{"error" => error}) ==
                 :transient
      end
    end

    test "an empty or nil description is transient" do
      for description <- ["", nil] do
        body = %{"error" => "unauthorized_client", "error_description" => description}
        assert OAuth.classify_refresh_response("bitbucket", 403, body) == :transient
      end
    end
  end

  describe "classify_refresh_response/3 - HTTP 401" do
    test "the two client-fault codes are refused there" do
      # 401 is what a provider returns when it rejects our
      # `Authorization: Basic client_id:secret`, so it is where client-level
      # wording actually arrives.
      for error <- ["unauthorized_client", "invalid_request"] do
        body = %{
          "error" => error,
          "error_description" =>
            if(error == "unauthorized_client",
              do: "refresh_token is invalid",
              else: "Invalid refresh_token"
            )
        }

        assert OAuth.classify_refresh_response("bitbucket", 401, body) == :transient,
               "expected :transient on 401 for #{error}"
      end
    end

    test "access_denied is still trusted there, because it describes the end user" do
      body = %{"error" => "access_denied", "error_description" => "User is inactive"}

      assert OAuth.classify_refresh_response("bitbucket", 401, body) == :revoked
    end
  end

  describe "classify_refresh_response/3 - the ambiguous codes are Bitbucket-only" do
    test "GitHub and GitLab never revoke on them" do
      for provider <- ["github", "gitlab"],
          {status, error, description} <- [
            {403, "unauthorized_client", "refresh_token is invalid"},
            {400, "invalid_request", "Invalid refresh_token"},
            {401, "access_denied", "User is inactive"}
          ] do
        body = %{"error" => error, "error_description" => description}

        assert OAuth.classify_refresh_response(provider, status, body) == :transient,
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
