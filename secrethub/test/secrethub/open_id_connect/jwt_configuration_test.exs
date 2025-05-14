defmodule Secrethub.OpenIDConnect.JWTConfigurationTest do
  use ExUnit.Case
  use Secrethub.DataCase

  alias Secrethub.OpenIDConnect.{JWTClaim, JWTConfiguration}
  alias Secrethub.Repo

  describe "jwt_configurations" do
    @valid_attrs %{
      org_id: Ecto.UUID.generate(),
      project_id: Ecto.UUID.generate(),
      is_active: true,
      claims: [
        %{
          "name" => "jti",
          "is_active" => true,
          "is_mandatory" => true,
          "is_aws_tag" => false,
          "description" => "JWT ID"
        },
        %{
          "name" => "custom_claim",
          "is_active" => true,
          "is_mandatory" => false,
          "is_aws_tag" => false,
          "description" => "Custom claim description"
        }
      ]
    }
    @invalid_attrs %{org_id: nil, claims: nil}

    test "changeset with valid attributes" do
      changeset = JWTConfiguration.changeset(%JWTConfiguration{}, @valid_attrs)
      assert changeset.valid?
    end

    test "changeset with invalid attributes" do
      changeset = JWTConfiguration.changeset(%JWTConfiguration{}, @invalid_attrs)
      refute changeset.valid?
    end

    test "changeset with invalid claims structure" do
      attrs = %{@valid_attrs | claims: ["invalid_claim"]}
      changeset = JWTConfiguration.changeset(%JWTConfiguration{}, attrs)
      refute changeset.valid?
    end

    test "changeset with is_active set to false" do
      attrs = %{@valid_attrs | is_active: false}
      changeset = JWTConfiguration.changeset(%JWTConfiguration{}, attrs)
      assert changeset.valid?
      assert get_change(changeset, :is_active) == false
    end

    test "changeset defaults is_active to true when not provided" do
      attrs = Map.delete(@valid_attrs, :is_active)
      changeset = JWTConfiguration.changeset(%JWTConfiguration{}, attrs)
      assert changeset.valid?
      assert get_field(changeset, :is_active) == true
    end

    test "changeset with empty claims" do
      attrs = %{@valid_attrs | claims: []}
      changeset = JWTConfiguration.changeset(%JWTConfiguration{}, attrs)
      assert changeset.valid?
      assert get_field(changeset, :claims) == []
    end

    test "create_or_update_org_config creates new config" do
      org_id = Ecto.UUID.generate()

      claims = [
        %{
          "name" => "test_claim",
          "is_active" => true,
          "is_mandatory" => false,
          "is_aws_tag" => false,
          "description" => "Test claim"
        }
      ]

      assert {:ok, config} = JWTConfiguration.create_or_update_org_config(org_id, claims)

      assert config.org_id == org_id
      assert config.claims == Enum.map(claims, &Map.merge(&1, %{"is_system_claim" => false}))
      assert config.is_active == true
    end

    test "create_or_update_project_config creates new config" do
      org_id = Ecto.UUID.generate()
      project_id = Ecto.UUID.generate()

      claims = [
        %{
          "name" => "test_claim",
          "is_active" => true,
          "is_mandatory" => false,
          "is_aws_tag" => false,
          "description" => "Test claim"
        }
      ]

      assert {:ok, config} =
               JWTConfiguration.create_or_update_project_config(org_id, project_id, claims)

      assert config.org_id == org_id
      assert config.project_id == project_id
      assert config.claims == Enum.map(claims, &Map.merge(&1, %{"is_system_claim" => false}))
      assert config.is_active == true
    end

    test "get_org_config creates default config when none exists" do
      org_id = Ecto.UUID.generate()

      {:ok, config} = JWTConfiguration.get_org_config(org_id)

      assert config.org_id == org_id
      assert is_nil(config.project_id)
      assert config.is_active == true
      assert Enum.count(config.claims) > 0
    end

    test "get_project_config returns org config when no project config exists" do
      org_id = Ecto.UUID.generate()
      project_id = Ecto.UUID.generate()

      # First create org config
      {:ok, org_config} =
        JWTConfiguration.create_or_update_org_config(org_id, @valid_attrs.claims)

      # Then get project config
      {:ok, project_config} = JWTConfiguration.get_project_config(org_id, project_id)

      assert project_config.org_id == org_id
      assert project_config.claims == org_config.claims
    end

    test "create_or_update_org_config with invalid claims structure" do
      org_id = Ecto.UUID.generate()

      invalid_claims = [
        "not a map",
        123
      ]

      assert {:error, :invalid_claims} =
               JWTConfiguration.create_or_update_org_config(org_id, invalid_claims)
    end

    test "create_or_update_project_config with invalid claims structure" do
      org_id = Ecto.UUID.generate()
      project_id = Ecto.UUID.generate()

      invalid_claims = [
        "not a map",
        123
      ]

      assert {:error, :invalid_claims} =
               JWTConfiguration.create_or_update_project_config(
                 org_id,
                 project_id,
                 invalid_claims
               )
    end

    test "create_or_update_org_config with missing name field" do
      org_id = Ecto.UUID.generate()

      invalid_claims = [
        %{
          "is_active" => true,
          "description" => "Test claim"
          # Missing "name" field
        }
      ]

      assert {:error, :invalid_claims} =
               JWTConfiguration.create_or_update_org_config(org_id, invalid_claims)
    end
  end

  describe "organization JWT configuration" do
    test "get_org_config with non-existent org creates default config with standard claims" do
      org_id = Ecto.UUID.generate()
      {:ok, config} = JWTConfiguration.get_org_config(org_id)

      assert config.org_id == org_id
      assert is_nil(config.project_id)
      assert config.is_active == true

      # Verify standard claims are present
      standard_claims = JWTClaim.standard_claims()

      Enum.each(standard_claims, fn {name, claim} ->
        assert Enum.any?(config.claims, fn claim_config ->
                 claim_config["name"] == name &&
                   claim_config["description"] == claim.description &&
                   claim_config["is_mandatory"] == claim.is_mandatory &&
                   claim_config["is_aws_tag"] == claim.is_aws_tag &&
                   claim_config["is_system_claim"] == claim.is_system_claim &&
                   claim_config["is_active"] == claim.is_active
               end)
      end)
    end

    test "create_or_update_org_config with custom claims" do
      org_id = Ecto.UUID.generate()

      custom_claims = [
        %{
          "name" => "custom_claim",
          "description" => "Custom claim for testing",
          "is_active" => true,
          "is_mandatory" => false,
          "is_aws_tag" => false,
          "is_system_claim" => false
        },
        %{
          "name" => "custom_aws_tag",
          "description" => "Custom AWS tag",
          "is_active" => true,
          "is_mandatory" => false,
          "is_aws_tag" => true,
          "is_system_claim" => false
        }
      ]

      {:ok, config} = JWTConfiguration.create_or_update_org_config(org_id, custom_claims)
      assert config.org_id == org_id
      assert config.claims == custom_claims
      assert config.is_active == true

      # Verify the configuration is persisted
      {:ok, stored_config} = JWTConfiguration.get_org_config(org_id)
      assert stored_config.claims == custom_claims
    end

    test "update existing org configuration" do
      org_id = Ecto.UUID.generate()

      # Create initial configuration
      initial_claims = [
        %{
          "name" => "initial_claim",
          "description" => "Initial claim",
          "is_active" => true,
          "is_mandatory" => false,
          "is_aws_tag" => false,
          "is_system_claim" => false
        }
      ]

      {:ok, initial_config} = JWTConfiguration.create_or_update_org_config(org_id, initial_claims)

      # Update with new claims
      updated_claims = [
        %{
          "name" => "updated_claim",
          "description" => "Updated claim",
          "is_active" => true,
          "is_mandatory" => false,
          "is_aws_tag" => false,
          "is_system_claim" => false
        }
      ]

      {:ok, updated_config} = JWTConfiguration.create_or_update_org_config(org_id, updated_claims)

      assert updated_config.org_id == initial_config.org_id
      assert updated_config.is_active == initial_config.is_active
      assert updated_config.project_id == initial_config.project_id
      assert updated_config.claims == updated_claims
      refute updated_config.claims == initial_claims
    end

    test "create_or_update_org_config with invalid org_id" do
      assert {:error, :org_id_required} = JWTConfiguration.create_or_update_org_config(nil, [])
    end

    test "create_or_update_org_config with invalid claims structure" do
      org_id = Ecto.UUID.generate()

      invalid_claims = [
        "not a map",
        123
      ]

      {:error, error} = JWTConfiguration.create_or_update_org_config(org_id, invalid_claims)
      assert error == :invalid_claims
    end

    test "get_org_config maintains mandatory claims" do
      org_id = Ecto.UUID.generate()

      # Create config with some mandatory claims disabled
      claims =
        JWTClaim.standard_claims()
        |> Enum.reduce([], fn {name, claim}, acc ->
          [
            %{
              "name" => name,
              "description" => claim.description,
              # Try to disable all claims
              "is_active" => false,
              "is_mandatory" => claim.is_mandatory,
              "is_aws_tag" => claim.is_aws_tag,
              "is_system_claim" => claim.is_system_claim
            }
            | acc
          ]
        end)

      {:ok, config} = JWTConfiguration.create_or_update_org_config(org_id, claims)

      # Verify that mandatory claims are still active
      Enum.each(config.claims, fn claim ->
        original_claim = Enum.find(claims, fn c -> c["name"] == claim["name"] end)

        if original_claim["is_mandatory"] do
          assert claim["is_active"] == true,
                 "Mandatory claim #{claim["name"]} should always be active"
        else
          assert claim["is_active"] == false,
                 "Non-mandatory claim #{claim["name"]} should remain inactive"
        end
      end)
    end

    test "delete_org_config with invalid org_id returns error" do
      assert {:error, :org_id_required} = JWTConfiguration.delete_org_config(nil)
    end

    test "delete_org_config with non-existent org_id returns not found" do
      assert {:error, :not_found} = JWTConfiguration.delete_org_config(Ecto.UUID.generate())
    end

    test "delete_org_config successfully deletes existing configuration" do
      # First create a configuration
      org_id = Ecto.UUID.generate()

      claims = [
        %{
          "name" => "test_claim",
          "description" => "Test claim",
          "is_active" => true,
          "is_mandatory" => false,
          "is_aws_tag" => false,
          "is_system_claim" => false
        }
      ]

      {:ok, _config} = JWTConfiguration.create_or_update_org_config(org_id, claims)

      # Then delete it
      assert {:ok, :deleted} = JWTConfiguration.delete_org_config(org_id)

      # Verify it's deleted
      assert {:error, :not_found} = JWTConfiguration.delete_org_config(org_id)
      refute Repo.get_by(JWTConfiguration, org_id: org_id)
    end

    test "delete_org_config deletes only the specified organization config" do
      # Create two configurations
      org_id1 = Ecto.UUID.generate()
      org_id2 = Ecto.UUID.generate()

      claims = [
        %{
          "name" => "test_claim",
          "description" => "Test claim",
          "is_active" => true,
          "is_mandatory" => false,
          "is_aws_tag" => false,
          "is_system_claim" => false
        }
      ]

      {:ok, _config1} = JWTConfiguration.create_or_update_org_config(org_id1, claims)
      {:ok, _config2} = JWTConfiguration.create_or_update_org_config(org_id2, claims)

      # Delete first config
      assert {:ok, _} = JWTConfiguration.delete_org_config(org_id1)

      # Verify only first config is deleted
      refute Repo.get_by(JWTConfiguration, org_id: org_id1)
      assert Repo.get_by(JWTConfiguration, org_id: org_id2)
    end

    test "delete_org_config deletes associated project configurations" do
      # Create org config with a project config
      org_id = Ecto.UUID.generate()
      project_id = Ecto.UUID.generate()

      claims = [
        %{
          "name" => "test_claim",
          "description" => "Test claim",
          "is_active" => true,
          "is_mandatory" => false,
          "is_aws_tag" => false,
          "is_system_claim" => false
        }
      ]

      {:ok, _} = JWTConfiguration.create_or_update_org_config(org_id, claims)
      {:ok, _} = JWTConfiguration.create_or_update_project_config(org_id, project_id, claims)

      # Delete org config
      assert {:ok, _} = JWTConfiguration.delete_org_config(org_id)

      # Verify both configs are deleted
      refute Repo.get_by(JWTConfiguration, org_id: org_id)
      refute Repo.get_by(JWTConfiguration, org_id: org_id, project_id: project_id)
    end

    test "delete_project_config with invalid ids returns error" do
      assert {:error, :org_id_required} =
               JWTConfiguration.delete_project_config(nil, Ecto.UUID.generate())

      assert {:error, :project_id_required} =
               JWTConfiguration.delete_project_config(Ecto.UUID.generate(), nil)
    end

    test "delete_project_config with non-existent ids returns not found" do
      assert {:error, :not_found} =
               JWTConfiguration.delete_project_config(Ecto.UUID.generate(), Ecto.UUID.generate())
    end

    test "delete_project_config successfully deletes project config while preserving org config" do
      # Create org config with a project config
      org_id = Ecto.UUID.generate()
      project_id = Ecto.UUID.generate()

      claims = [
        %{
          "name" => "test_claim",
          "description" => "Test claim",
          "is_active" => true,
          "is_mandatory" => false,
          "is_aws_tag" => false,
          "is_system_claim" => false
        }
      ]

      {:ok, _org_config} = JWTConfiguration.create_or_update_org_config(org_id, claims)

      {:ok, project_config} =
        JWTConfiguration.create_or_update_project_config(org_id, project_id, claims)

      # Delete project config
      assert {:ok, deleted_config} = JWTConfiguration.delete_project_config(org_id, project_id)
      assert deleted_config.id == project_config.id

      # Verify only project config is deleted
      assert Repo.get_by(JWTConfiguration, org_id: org_id)
      refute Repo.get_by(JWTConfiguration, org_id: org_id, project_id: project_id)
    end
  end

  describe "project configuration scenarios" do
    test "get_project_config when neither org nor project config exists" do
      org_id = Ecto.UUID.generate()
      project_id = Ecto.UUID.generate()

      {:ok, config} = JWTConfiguration.get_project_config(org_id, project_id)
      assert config.org_id == org_id
      assert is_nil(config.project_id)
      assert config.is_active == true

      # Should have standard claims
      standard_claims = JWTClaim.standard_claims()

      Enum.each(standard_claims, fn {name, _claim} ->
        assert Enum.any?(config.claims, fn claim -> claim["name"] == name end)
      end)
    end

    test "get_project_config when org config exists but no project config" do
      org_id = Ecto.UUID.generate()
      project_id = Ecto.UUID.generate()

      org_claims = [
        %{
          "name" => "org_specific",
          "description" => "Org specific claim",
          "is_active" => true,
          "is_mandatory" => false,
          "is_aws_tag" => false,
          "is_system_claim" => false
        }
      ]

      {:ok, org_config} = JWTConfiguration.create_or_update_org_config(org_id, org_claims)

      {:ok, config} = JWTConfiguration.get_project_config(org_id, project_id)
      assert config.id == org_config.id
      assert config.org_id == org_id
      assert is_nil(config.project_id)
      assert config.claims == org_claims
    end

    test "get_project_config when both org and project configs exist" do
      org_id = Ecto.UUID.generate()
      project_id = Ecto.UUID.generate()

      org_claims = [
        %{
          "name" => "org_specific",
          "description" => "Org specific claim",
          "is_active" => true,
          "is_mandatory" => false,
          "is_aws_tag" => false,
          "is_system_claim" => false
        }
      ]

      project_claims = [
        %{
          "name" => "project_specific",
          "description" => "Project specific claim",
          "is_active" => true,
          "is_mandatory" => false,
          "is_aws_tag" => false,
          "is_system_claim" => false
        }
      ]

      {:ok, _org_config} = JWTConfiguration.create_or_update_org_config(org_id, org_claims)

      {:ok, project_config} =
        JWTConfiguration.create_or_update_project_config(org_id, project_id, project_claims)

      {:ok, config} = JWTConfiguration.get_project_config(org_id, project_id)
      assert config.id == project_config.id
      assert config.org_id == org_id
      assert config.project_id == project_id
      assert config.claims == project_claims
      refute config.claims == org_claims
    end

    test "delete_project_config when neither org nor project config exists" do
      org_id = Ecto.UUID.generate()
      project_id = Ecto.UUID.generate()

      assert {:error, :not_found} = JWTConfiguration.delete_project_config(org_id, project_id)
    end

    test "delete_project_config when org exists but no project config" do
      org_id = Ecto.UUID.generate()
      project_id = Ecto.UUID.generate()

      {:ok, _org_config} = JWTConfiguration.create_or_update_org_config(org_id, [])

      assert {:error, :not_found} = JWTConfiguration.delete_project_config(org_id, project_id)
      # Verify org config still exists
      assert Repo.get_by(JWTConfiguration, org_id: org_id)
    end

    test "delete_project_config when project config exists" do
      org_id = Ecto.UUID.generate()
      project_id = Ecto.UUID.generate()

      {:ok, _org_config} = JWTConfiguration.create_or_update_org_config(org_id, [])

      {:ok, project_config} =
        JWTConfiguration.create_or_update_project_config(org_id, project_id, [])

      assert {:ok, deleted_config} = JWTConfiguration.delete_project_config(org_id, project_id)
      assert deleted_config.id == project_config.id

      # Verify project config is deleted but org config remains
      assert Repo.get_by(JWTConfiguration, org_id: org_id)
      refute Repo.get_by(JWTConfiguration, org_id: org_id, project_id: project_id)
    end
  end

  describe "editing JWT configuration" do
    test "editing claim description and properties preserves system claim defaults" do
      org_id = Ecto.UUID.generate()

      # Create initial configuration with a mix of system and custom claims
      initial_claims = [
        %{
          # system claim
          "name" => "jti",
          "description" => "Modified JTI description",
          "is_active" => false,
          "is_mandatory" => false,
          "is_system_claim" => true,
          "is_aws_tag" => false
        },
        %{
          "name" => "custom_claim",
          "description" => "Initial description",
          "is_active" => true,
          "is_mandatory" => false,
          "is_system_claim" => false,
          "is_aws_tag" => false
        }
      ]

      {:ok, _config} = JWTConfiguration.create_or_update_org_config(org_id, initial_claims)

      # Update configuration with modified descriptions and properties
      updated_claims = [
        %{
          # system claim
          "name" => "jti",
          "description" => "New JTI description",
          # trying to modify system claim properties
          "is_active" => false,
          "is_mandatory" => false,
          "is_system_claim" => false,
          "is_aws_tag" => false
        },
        %{
          "name" => "custom_claim",
          "description" => "Updated description",
          "is_active" => false,
          "is_mandatory" => true,
          "is_system_claim" => true,
          "is_aws_tag" => false
        }
      ]

      {:ok, _updated_config} =
        JWTConfiguration.create_or_update_org_config(org_id, updated_claims)

      # Get the final configuration to verify the changes
      {:ok, final_config} = JWTConfiguration.get_org_config(org_id)

      # Find the claims in the final configuration
      jti_claim = Enum.find(final_config.claims, &(&1["name"] == "jti"))
      custom_claim = Enum.find(final_config.claims, &(&1["name"] == "custom_claim"))

      # Verify system claim (jti) preserved its default values
      # description can't be updated
      assert jti_claim["description"] ==
               "JWT ID - Unique identifier that can be used to prevent the JWT from being replayed"

      # preserved default value
      assert jti_claim["is_active"] == true
      # preserved default value
      assert jti_claim["is_mandatory"] == true
      # preserved default value
      assert jti_claim["is_system_claim"] == true

      # Verify custom claim was fully updated
      assert custom_claim["description"] == "Updated description"
      assert custom_claim["is_active"] == false
      # can't set is_mandatory to true
      assert custom_claim["is_mandatory"] == false
      # can't set is_system_claim to true
      assert custom_claim["is_system_claim"] == false
    end
  end

  describe "duplicate configurations" do
    setup do
      org_id = Ecto.UUID.generate()
      project_id = Ecto.UUID.generate()

      claims = [
        %{
          "name" => "sub",
          "is_active" => true
        }
      ]

      # Different claims for concurrent tests
      concurrent_claims = [
        %{
          "name" => "sub",
          "is_active" => true,
          "description" => "Concurrent update"
        }
      ]

      {:ok,
       %{
         org_id: org_id,
         project_id: project_id,
         claims: claims,
         concurrent_claims: concurrent_claims
       }}
    end

    test "handles concurrent org config creations", %{
      org_id: org_id,
      claims: claims,
      concurrent_claims: concurrent_claims
    } do
      # Start multiple concurrent operations
      tasks =
        for _ <- 1..20 do
          Task.async(fn ->
            JWTConfiguration.create_or_update_org_config(org_id, claims)
          end)
        end

      # Add a concurrent update with different claims
      update_task =
        Task.async(fn ->
          JWTConfiguration.create_or_update_org_config(org_id, concurrent_claims)
        end)

      # Wait for all tasks to complete
      results = Task.await_many([update_task | tasks], 5000)

      # All operations should succeed
      assert Enum.all?(results, fn {:ok, _} -> true end)

      # Verify only one configuration exists
      configs = Repo.all(JWTConfiguration)
      org_configs = Enum.filter(configs, &is_nil(&1.project_id))
      assert length(org_configs) == 1

      # The final state should be consistent
      {:ok, final_config} = JWTConfiguration.get_org_config(org_id)
      assert final_config.org_id == org_id
      assert is_nil(final_config.project_id)
    end

    test "handles concurrent project config creations", %{
      org_id: org_id,
      project_id: project_id,
      claims: claims,
      concurrent_claims: concurrent_claims
    } do
      # Start multiple concurrent operations
      tasks =
        for _ <- 1..10 do
          Task.async(fn ->
            JWTConfiguration.create_or_update_project_config(org_id, project_id, claims)
          end)
        end

      # Add a concurrent update with different claims
      update_task =
        Task.async(fn ->
          JWTConfiguration.create_or_update_project_config(org_id, project_id, concurrent_claims)
        end)

      # Wait for all tasks to complete
      results = Task.await_many([update_task | tasks], 5000)

      # All operations should succeed
      assert Enum.all?(results, fn {:ok, _} -> true end)

      # Verify only one configuration exists for this project
      configs = Repo.all(JWTConfiguration)
      project_configs = Enum.filter(configs, &(&1.project_id == project_id))
      assert length(project_configs) == 1

      # The final state should be consistent
      {:ok, final_config} = JWTConfiguration.get_project_config(org_id, project_id)
      assert final_config.org_id == org_id
      assert final_config.project_id == project_id
    end

    test "allows updating existing org config", %{org_id: org_id, claims: claims} do
      # First creation
      {:ok, config1} = JWTConfiguration.create_or_update_org_config(org_id, claims)
      assert config1.org_id == org_id
      assert is_nil(config1.project_id)

      # Second creation with same data
      {:ok, config2} = JWTConfiguration.create_or_update_org_config(org_id, claims)
      assert config2.id == config1.id
      assert config2.org_id == org_id
      assert is_nil(config2.project_id)

      # Update with different claims
      updated_claims = [%{"name" => "new_claim", "is_active" => true} | claims]
      {:ok, config3} = JWTConfiguration.create_or_update_org_config(org_id, updated_claims)
      assert config3.id == config1.id
      assert Enum.any?(config3.claims, fn claim -> claim["name"] == "new_claim" end)
    end

    test "allows updating existing project config", %{
      org_id: org_id,
      project_id: project_id,
      claims: claims
    } do
      # First creation
      {:ok, config1} =
        JWTConfiguration.create_or_update_project_config(org_id, project_id, claims)

      assert config1.org_id == org_id
      assert config1.project_id == project_id

      # Second creation with same data
      {:ok, config2} =
        JWTConfiguration.create_or_update_project_config(org_id, project_id, claims)

      assert config2.id == config1.id
      assert config2.org_id == org_id
      assert config2.project_id == project_id

      # Update with different claims
      updated_claims = [%{"name" => "new_claim", "is_active" => true} | claims]

      {:ok, config3} =
        JWTConfiguration.create_or_update_project_config(org_id, project_id, updated_claims)

      assert config3.id == config1.id
      assert Enum.any?(config3.claims, fn claim -> claim["name"] == "new_claim" end)
    end

    test "allows having both org and project configs", %{
      org_id: org_id,
      project_id: project_id,
      claims: claims
    } do
      # Create org config
      {:ok, org_config} = JWTConfiguration.create_or_update_org_config(org_id, claims)
      assert is_nil(org_config.project_id)

      # Create project config
      {:ok, proj_config} =
        JWTConfiguration.create_or_update_project_config(org_id, project_id, claims)

      assert proj_config.project_id == project_id

      # Verify both exist and are different
      refute org_config.id == proj_config.id

      # Verify we can get both
      {:ok, fetched_org} = JWTConfiguration.get_org_config(org_id)
      assert fetched_org.id == org_config.id

      {:ok, fetched_proj} = JWTConfiguration.get_project_config(org_id, project_id)
      assert fetched_proj.id == proj_config.id
    end
  end

  describe "claim validation" do
    test "create_or_update_org_config rejects claims with empty names" do
      org_id = Ecto.UUID.generate()

      claims = [
        %{
          "name" => "",
          "description" => "Empty name claim",
          "is_active" => true,
          "is_mandatory" => false,
          "is_aws_tag" => false,
          "is_system_claim" => false
        }
      ]

      assert {:error, :invalid_claims} =
               JWTConfiguration.create_or_update_org_config(org_id, claims)
    end

    test "create_or_update_project_config rejects claims with empty names" do
      org_id = Ecto.UUID.generate()
      project_id = Ecto.UUID.generate()

      claims = [
        %{
          "name" => "",
          "description" => "Empty name claim",
          "is_active" => true,
          "is_mandatory" => false,
          "is_aws_tag" => false,
          "is_system_claim" => false
        }
      ]

      assert {:error, :invalid_claims} =
               JWTConfiguration.create_or_update_project_config(org_id, project_id, claims)
    end

    test "create_or_update_project_config accepts valid claims" do
      org_id = Ecto.UUID.generate()
      project_id = Ecto.UUID.generate()

      claims = [
        %{
          "name" => "test_claim",
          "description" => "Valid claim",
          "is_active" => true,
          "is_mandatory" => false,
          "is_aws_tag" => false,
          "is_system_claim" => false
        }
      ]

      assert {:ok, config} =
               JWTConfiguration.create_or_update_project_config(org_id, project_id, claims)

      assert config.claims == claims
    end

    test "create_or_update_org_config with non-boolean is_active" do
      org_id = Ecto.UUID.generate()

      claims = [
        %{
          "name" => "test_claim",
          # String instead of boolean
          "is_active" => "true",
          "is_mandatory" => false,
          "is_aws_tag" => false,
          "description" => "Test claim"
        }
      ]

      assert {:error, :invalid_claims} =
               JWTConfiguration.create_or_update_org_config(org_id, claims)
    end
  end

  describe "claim field validation" do
    test "drops unsupported fields from claims" do
      org_id = Ecto.UUID.generate()

      # Create configuration with supported and unsupported fields
      claims = [
        %{
          "name" => "custom_claim",
          "description" => "Test claim",
          "is_active" => true,
          "is_mandatory" => false,
          "is_system_claim" => false,
          "is_aws_tag" => false,
          "unsupported_field" => "some value",
          "x" => 1,
          "extra_data" => %{"nested" => "value"}
        }
      ]

      {:ok, _config} = JWTConfiguration.create_or_update_org_config(org_id, claims)

      # Get the saved configuration
      {:ok, saved_config} = JWTConfiguration.get_org_config(org_id)
      saved_claim = List.first(saved_config.claims)

      # Verify only supported fields are present
      assert Map.has_key?(saved_claim, "name")
      assert Map.has_key?(saved_claim, "description")
      assert Map.has_key?(saved_claim, "is_active")
      assert Map.has_key?(saved_claim, "is_mandatory")
      assert Map.has_key?(saved_claim, "is_system_claim")
      assert Map.has_key?(saved_claim, "is_aws_tag")

      # Verify unsupported fields are dropped
      refute Map.has_key?(saved_claim, "unsupported_field")
      refute Map.has_key?(saved_claim, "x")
      refute Map.has_key?(saved_claim, "extra_data")

      # Verify the values of supported fields are preserved
      assert saved_claim["name"] == "custom_claim"
      assert saved_claim["description"] == "Test claim"
      assert saved_claim["is_active"] == true
      assert saved_claim["is_mandatory"] == false
      assert saved_claim["is_system_claim"] == false
      assert saved_claim["is_aws_tag"] == false
    end
  end
end
