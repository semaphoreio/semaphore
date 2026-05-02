defmodule Secrethub.OpenIDConnect.JWTTest do
  use Secrethub.DataCase

  import Mock

  alias Secrethub.OpenIDConnect.{JWT, JWTConfiguration}
  alias Support.FakeServices

  defp base_req(extra \\ %{}) do
    org_id = Ecto.UUID.generate()
    project_id = Ecto.UUID.generate()
    repo = "web"
    ref_type = "branch"
    git_ref = "refs/heads/main"

    %{
      org_id: org_id,
      org_username: "testera",
      project_id: project_id,
      project_name: "my-project",
      workflow_id: Ecto.UUID.generate(),
      pipeline_id: Ecto.UUID.generate(),
      job_id: Ecto.UUID.generate(),
      repository_name: repo,
      git_tag: "",
      git_ref: git_ref,
      git_ref_type: ref_type,
      git_branch_name: "main",
      git_pull_request_number: "",
      git_pull_request_branch: "",
      job_type: "pipeline_job",
      repo_slug: "renderedtext/#{repo}",
      triggerer: "h:f,i:f",
      subject:
        "org:testera:project:#{project_id}:repo:#{repo}:ref_type:#{ref_type}:ref:#{git_ref}",
      user_id: Ecto.UUID.generate(),
      expires_in: 3600
    }
    |> Map.merge(extra)
  end

  describe "generate_and_sign/1 audience handling" do
    setup do
      FakeServices.enable_features([])
      :ok
    end

    test "defaults to org URL when audience is absent" do
      req = base_req()
      domain = Application.fetch_env!(:secrethub, :domain)
      expected_iss = "https://#{req.org_username}.#{domain}"

      assert {:ok, token} = JWT.generate_and_sign(req)
      assert {true, jwt, _} = JWT.verify(token)

      assert Map.get(jwt.fields, "aud") == "https://#{req.org_username}.#{domain}"
      assert Map.get(jwt.fields, "iss") == expected_iss
    end

    test "defaults to org URL when audience is an empty list" do
      req = base_req(%{audience: []})
      domain = Application.fetch_env!(:secrethub, :domain)

      assert {:ok, token} = JWT.generate_and_sign(req)
      assert {true, jwt, _} = JWT.verify(token)

      assert Map.get(jwt.fields, "aud") == "https://#{req.org_username}.#{domain}"
    end

    test "uses default org URL when audience is nil" do
      req = base_req() |> Map.put(:audience, nil)
      domain = Application.fetch_env!(:secrethub, :domain)

      assert {:ok, token} = JWT.generate_and_sign(req)
      assert {true, jwt, _} = JWT.verify(token)

      assert Map.get(jwt.fields, "aud") == "https://#{req.org_username}.#{domain}"
    end

    test "uses single string when audience is a single-element list (RFC 7519 convention)" do
      req = base_req(%{audience: ["pypi"]})
      domain = Application.fetch_env!(:secrethub, :domain)
      expected_iss = "https://#{req.org_username}.#{domain}"

      assert {:ok, token} = JWT.generate_and_sign(req)
      assert {true, jwt, _} = JWT.verify(token)

      assert Map.get(jwt.fields, "aud") == "pypi"
      assert Map.get(jwt.fields, "iss") == expected_iss
    end

    test "uses JSON array when audience is a multi-element list" do
      req = base_req(%{audience: ["pypi", "https://other.example"]})
      domain = Application.fetch_env!(:secrethub, :domain)
      expected_iss = "https://#{req.org_username}.#{domain}"

      assert {:ok, token} = JWT.generate_and_sign(req)
      assert {true, jwt, _} = JWT.verify(token)

      assert Map.get(jwt.fields, "aud") == ["pypi", "https://other.example"]
      assert Map.get(jwt.fields, "iss") == expected_iss
    end
  end

  describe "generate_and_sign/1 with :open_id_connect_filter enabled" do
    setup do
      FakeServices.enable_features(["open_id_connect_filter"])
      :ok
    end

    test "preserves audience override when aud is allowlisted and strips non-allowlisted claims" do
      req = base_req(%{audience: ["pypi"]})

      # Configure the JWT filter to allowlist `aud` (and the other claims used
      # by build_oidc_claims that we want surfaced for the test). When the
      # :open_id_connect_filter feature flag is enabled, only allowlisted
      # claims survive into the signed token.
      #
      # Deliberately omit `sub` from the allowlist to prove the filter actually
      # ran: a regression that turned the filter into a no-op would leave `sub`
      # in the JWT and fail the refute below.
      with_mock(JWTConfiguration, [],
        get_org_config: fn _org_id ->
          {:ok,
           %{
             claims: [
               %{"name" => "aud", "is_active" => true},
               %{"name" => "iss", "is_active" => true},
               %{"name" => "exp", "is_active" => true},
               %{"name" => "iat", "is_active" => true},
               %{"name" => "nbf", "is_active" => true}
             ]
           }}
        end
      ) do
        assert {:ok, token} = JWT.generate_and_sign(req)
        assert {true, jwt, _} = JWT.verify(token)

        assert Map.get(jwt.fields, "aud") == "pypi"
        # Proves the filter ran: `sub` is in build_oidc_claims but not in the
        # allowlist above, so it must have been stripped.
        refute Map.has_key?(jwt.fields, "sub")
      end
    end

    test "strips audience override when aud is not allowlisted" do
      req = base_req(%{audience: ["pypi"]})

      # Allowlist excludes `aud`. The filter strips any non-allowlisted claim
      # unconditionally (see JWTFilter._filter_claims/3), so even though the
      # user requested a custom audience, `aud` is dropped from the signed
      # token.
      with_mock(JWTConfiguration, [],
        get_org_config: fn _org_id ->
          {:ok,
           %{
             claims: [
               %{"name" => "iss", "is_active" => true},
               %{"name" => "sub", "is_active" => true},
               %{"name" => "exp", "is_active" => true},
               %{"name" => "iat", "is_active" => true},
               %{"name" => "nbf", "is_active" => true}
             ]
           }}
        end
      ) do
        assert {:ok, token} = JWT.generate_and_sign(req)
        assert {true, jwt, _} = JWT.verify(token)

        refute Map.has_key?(jwt.fields, "aud")
      end
    end
  end
end
