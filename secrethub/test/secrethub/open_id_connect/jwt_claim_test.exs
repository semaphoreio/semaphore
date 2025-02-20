defmodule Secrethub.OpenIDConnect.JWTClaimTest do
  use Secrethub.DataCase

  alias Secrethub.OpenIDConnect.JWTClaim

  describe "jwt_claims" do
    @valid_attrs %{
      name: "test_claim",
      description: "Test claim description",
      is_mandatory: true,
      is_aws_tag: false,
      is_system_claim: true
    }
    @invalid_attrs %{name: nil, description: nil}

    test "changeset with valid attributes" do
      changeset = JWTClaim.changeset(%JWTClaim{}, @valid_attrs)
      assert changeset.valid?
    end

    test "changeset with invalid attributes" do
      changeset = JWTClaim.changeset(%JWTClaim{}, @invalid_attrs)
      refute changeset.valid?
    end

    test "changeset requires name and description" do
      changeset = JWTClaim.changeset(%JWTClaim{}, %{})
      assert "can't be blank" in errors_on(changeset).name
      assert "can't be blank" in errors_on(changeset).description
    end

    test "standard_claims returns merged mandatory and optional claims" do
      claims = JWTClaim.standard_claims()

      # Check that it includes both mandatory and optional claims
      # mandatory claim
      assert Map.has_key?(claims, "jti")
      # optional claim
      assert Map.has_key?(claims, "prj_id")

      # Verify no duplicates
      assert map_size(claims) ==
               map_size(JWTClaim.mandatory_claims()) + map_size(JWTClaim.optional_claims())
    end

    test "mandatory_claims returns required JWT claims" do
      claims = JWTClaim.mandatory_claims()

      # Check for presence of required standard JWT claims
      required_claims = ~w(jti aud iss exp nbf iat)

      for claim <- required_claims do
        assert Map.has_key?(claims, claim)
        claim_struct = Map.get(claims, claim)
        assert claim_struct.is_mandatory
        assert claim_struct.is_system_claim
        refute claim_struct.is_aws_tag
      end
    end

    test "optional_claims returns workflow-specific claims" do
      claims = JWTClaim.optional_claims()

      # Check for presence of some workflow-specific claims
      workflow_claims = ~w(prj_id wf_id ppl_id job_id repo branch)

      for claim <- workflow_claims do
        assert Map.has_key?(claims, claim)
        claim_struct = Map.get(claims, claim)
        refute claim_struct.is_mandatory
        assert claim_struct.is_system_claim
      end
    end

    test "optional_claims includes AWS tag claims" do
      claims = JWTClaim.optional_claims()

      aws_tag_claims =
        claims
        |> Enum.filter(fn {_name, claim} -> claim.is_aws_tag end)
        |> Enum.map(fn {name, _} -> name end)
        |> MapSet.new()

      expected_aws_tags =
        MapSet.new(~w(prj_id repo ref_type branch pr_branch repo_slug job_type trg))

      assert MapSet.equal?(aws_tag_claims, expected_aws_tags)
    end
  end
end
