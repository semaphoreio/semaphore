defmodule Front.Models.JWTConfigTest do
  use ExUnit.Case
  alias Front.Models.JWTConfig
  alias InternalApi.Secrethub.ClaimConfig

  describe "OIDC Token configuration" do
    test "get/3 returns OIDC Token configuration for organization" do
      org_id = UUID.uuid4()

      {:ok, jwt_config} = JWTConfig.get(org_id, nil)

      assert jwt_config.org_id == org_id
      assert jwt_config.project_id == ""
      assert jwt_config.is_active == true
      assert is_list(jwt_config.claims)

      claims = Enum.map(jwt_config.claims, & &1.name)
      assert "branch" in claims
      assert "prj_id" in claims
    end

    test "get/3 returns OIDC Token configuration for project" do
      org_id = UUID.uuid4()
      project_id = UUID.uuid4()

      {:ok, jwt_config} = JWTConfig.get(org_id, project_id)

      assert jwt_config.org_id == org_id
      assert jwt_config.project_id == project_id
      assert jwt_config.is_active == true
      assert is_list(jwt_config.claims)

      claims = Enum.map(jwt_config.claims, & &1.name)
      assert "branch" in claims
      assert "prj_id" in claims
    end

    test "update/5 successfully updates OIDC Token configuration for organization" do
      org_id = UUID.uuid4()

      claims = [
        %ClaimConfig{
          name: "branch",
          description: "Branch",
          is_active: true,
          is_mandatory: false,
          is_aws_tag: false,
          is_system_claim: true
        },
        %ClaimConfig{
          name: "prj_id",
          description: "Project ID",
          is_active: false,
          is_mandatory: false,
          is_aws_tag: false,
          is_system_claim: true
        }
      ]

      {:ok, :updated} = JWTConfig.update(org_id, nil, true, claims)

      {:ok, jwt_config} = JWTConfig.get(org_id, nil)
      assert jwt_config.org_id == org_id
      assert jwt_config.project_id == ""
      assert jwt_config.is_active == true

      branch_claim = Enum.find(jwt_config.claims, &(&1.name == "branch"))
      assert branch_claim.is_active == true

      prj_id_claim = Enum.find(jwt_config.claims, &(&1.name == "prj_id"))
      assert prj_id_claim.is_active == false
    end

    test "update/5 successfully updates OIDC Token configuration for project" do
      org_id = UUID.uuid4()
      project_id = UUID.uuid4()

      claims = [
        %ClaimConfig{
          name: "branch",
          description: "Branch",
          is_active: true,
          is_mandatory: false,
          is_aws_tag: false,
          is_system_claim: true
        }
      ]

      {:ok, :updated} = JWTConfig.update(org_id, project_id, true, claims)

      {:ok, jwt_config} = JWTConfig.get(org_id, project_id)
      assert jwt_config.org_id == org_id
      assert jwt_config.project_id == project_id
      assert jwt_config.is_active == true

      branch_claim = Enum.find(jwt_config.claims, &(&1.name == "branch"))
      assert branch_claim.is_active == true
    end

    test "change_claims/1 validates claim structure" do
      claims = [
        %ClaimConfig{
          name: "branch",
          description: "Branch",
          is_active: true,
          is_mandatory: false,
          is_aws_tag: false,
          is_system_claim: true
        }
      ]

      changeset = JWTConfig.change_claims(%{claims: claims, is_active: true})
      assert changeset.valid?
    end
  end
end
