defmodule Support.Stubs.SecretHubTest do
  use ExUnit.Case

  alias InternalApi.Secrethub.{
    GetJWTConfigResponse,
    UpdateJWTConfigResponse,
    ClaimConfig
  }

  setup do
    Support.Stubs.init()
    Support.Stubs.build_shared_factories()
    :ok
  end

  describe "OIDC Token configuration" do
    test "returns default config when none exists for organization" do
      org_id = UUID.uuid4()

      response =
        Support.Stubs.Secrethub.get_jwt_config(%{
          org_id: org_id,
          project_id: ""
        })

      assert %GetJWTConfigResponse{
               org_id: ^org_id,
               project_id: "",
               is_active: true,
               claims: claims
             } = response

      assert Enum.any?(claims, &(&1.name == "branch"))
      assert Enum.any?(claims, &(&1.name == "prj_id"))
    end

    test "returns default config when none exists for project" do
      org_id = UUID.uuid4()
      project_id = UUID.uuid4()

      response =
        Support.Stubs.Secrethub.get_jwt_config(%{
          org_id: org_id,
          project_id: project_id
        })

      assert %GetJWTConfigResponse{
               org_id: ^org_id,
               project_id: ^project_id,
               is_active: true,
               claims: claims
             } = response

      assert Enum.any?(claims, &(&1.name == "branch"))
      assert Enum.any?(claims, &(&1.name == "prj_id"))
    end

    test "updates and retrieves organization JWT config" do
      org_id = UUID.uuid4()

      claims = [
        %ClaimConfig{
          name: "branch",
          description: "Updated branch",
          is_active: true,
          is_mandatory: true,
          is_aws_tag: false,
          is_system_claim: false
        },
        %ClaimConfig{
          name: "prj_id",
          description: "Updated Project ID",
          is_active: false,
          is_mandatory: false,
          is_aws_tag: false,
          is_system_claim: false
        }
      ]

      update_response =
        Support.Stubs.Secrethub.update_jwt_config(%{
          org_id: org_id,
          project_id: "",
          claims: claims,
          is_active: true
        })

      assert %UpdateJWTConfigResponse{
               org_id: ^org_id,
               project_id: ""
             } = update_response

      get_response =
        Support.Stubs.Secrethub.get_jwt_config(%{
          org_id: org_id,
          project_id: ""
        })

      branch_claim = Enum.find(get_response.claims, &(&1.name == "branch"))
      assert branch_claim.description == "Updated branch"
      assert branch_claim.is_active == true

      prj_id_claim = Enum.find(get_response.claims, &(&1.name == "prj_id"))
      assert prj_id_claim.description == "Updated Project ID"
      assert prj_id_claim.is_active == false
    end

    test "adds new claim to existing configuration" do
      org_id = UUID.uuid4()
      project_id = UUID.uuid4()

      # First set up initial claims
      initial_claims = [
        %ClaimConfig{
          name: "branch",
          description: "Initial branch",
          is_active: true,
          is_mandatory: false,
          is_aws_tag: false,
          is_system_claim: false
        }
      ]

      Support.Stubs.Secrethub.update_jwt_config(%{
        org_id: org_id,
        project_id: project_id,
        claims: initial_claims,
        is_active: true
      })

      # Add a new claim
      updated_claims =
        initial_claims ++
          [
            %ClaimConfig{
              name: "teams",
              description: "Team membership",
              is_active: true,
              is_mandatory: true,
              is_aws_tag: true,
              is_system_claim: false
            }
          ]

      Support.Stubs.Secrethub.update_jwt_config(%{
        org_id: org_id,
        project_id: project_id,
        claims: updated_claims,
        is_active: true
      })

      # Verify both old and new claims exist
      response =
        Support.Stubs.Secrethub.get_jwt_config(%{
          org_id: org_id,
          project_id: project_id
        })

      assert Enum.any?(response.claims, &(&1.name == "branch"))
      assert Enum.any?(response.claims, &(&1.name == "teams"))
      teams_claim = Enum.find(response.claims, &(&1.name == "teams"))
      assert teams_claim.description == "Team membership"
      assert teams_claim.is_mandatory == true
      assert teams_claim.is_aws_tag == true
    end
  end
end
