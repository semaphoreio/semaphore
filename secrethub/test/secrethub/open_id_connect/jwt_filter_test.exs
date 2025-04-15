defmodule Secrethub.OpenIDConnect.JWTFilterTest do
  use ExUnit.Case
  use Secrethub.DataCase

  alias Secrethub.OpenIDConnect.{JWTConfiguration, JWTFilter}
  import Mock
  alias Ecto.UUID
  alias Support.FakeServices

  describe "filter_claims/3 with map input" do
    test "returns unmodified claims when filter is disabled" do
      FakeServices.enable_features([])

      claims = %{
        "sub" => "test",
        "extra_claim" => "value",
        "https://aws.amazon.com/tags" => %{
          "principal_tags" => %{
            "prj_id" => ["123"],
            "extra_tag" => ["value"]
          },
          "transitive_tag_keys" => ["prj_id", "extra_tag"]
        }
      }

      assert JWTFilter.filter_claims(claims, "org_id", "project_id") == {:ok, claims}
    end

    test "filters claims based on JWT configuration when filter is enabled" do
      FakeServices.enable_features(["open_id_connect_filter"])

      claims = %{
        "sub" => "test",
        "extra_claim" => "value",
        "prj_id" => "123",
        "iat" => 123_456
      }

      expected = %{
        "sub" => "test",
        "prj_id" => "123",
        "iat" => 123_456
      }

      with_mock(JWTConfiguration, [],
        get_org_config: fn "org_id" ->
          {:ok,
           %{
             claims: [
               %{"name" => "sub", "is_active" => true},
               %{"name" => "prj_id", "is_active" => true},
               %{"name" => "iat", "is_active" => true}
             ]
           }}
        end
      ) do
        assert JWTFilter.filter_claims(claims, "org_id", "project_id") == {:ok, expected}
      end
    end

    test "filters AWS tags based on JWT configuration when filter is enabled" do
      FakeServices.enable_features(["open_id_connect_filter"])

      claims = %{
        "sub" => "test",
        "https://aws.amazon.com/tags" => %{
          "principal_tags" => %{
            "prj_id" => ["123"],
            "branch" => ["main"],
            "extra_tag" => ["value"]
          },
          "transitive_tag_keys" => ["prj_id", "branch", "extra_tag"]
        }
      }

      expected = %{
        "sub" => "test",
        "https://aws.amazon.com/tags" => %{
          "principal_tags" => %{
            "prj_id" => ["123"],
            "branch" => ["main"]
          },
          "transitive_tag_keys" => ["branch", "prj_id"]
        }
      }

      with_mock(JWTConfiguration, [],
        get_org_config: fn "org_id" ->
          {:ok,
           %{
             claims: [
               %{"name" => "sub", "is_active" => true},
               %{"name" => "prj_id", "is_active" => true},
               %{"name" => "branch", "is_active" => true},
               %{"name" => "https://aws.amazon.com/tags", "is_active" => true}
             ]
           }}
        end
      ) do
        assert JWTFilter.filter_claims(claims, "org_id", "project_id") == {:ok, expected}
      end
    end

    test "handles claims without AWS tags when filter is enabled" do
      FakeServices.enable_features(["open_id_connect_filter"])

      claims = %{
        "sub" => "test",
        "prj_id" => "123",
        "extra_claim" => "value"
      }

      expected = %{
        "sub" => "test",
        "prj_id" => "123"
      }

      with_mock(JWTConfiguration, [],
        get_org_config: fn "org_id" ->
          {:ok,
           %{
             claims: [
               %{"name" => "sub", "is_active" => true},
               %{"name" => "prj_id", "is_active" => true}
             ]
           }}
        end
      ) do
        assert JWTFilter.filter_claims(claims, "org_id", "project_id") == {:ok, expected}
      end
    end

    test "returns error for invalid claims" do
      FakeServices.enable_features(["open_id_connect_filter", "open_id_connect_project_filter"])
      assert JWTFilter.filter_claims(nil, "org_id", "project_id") == {:error, :invalid_claims}
    end

    test "propagates JWT configuration errors" do
      FakeServices.enable_features(["open_id_connect_filter"])

      with_mock(JWTConfiguration, [],
        get_org_config: fn "org_id" ->
          {:error, :not_found}
        end
      ) do
        assert JWTFilter.filter_claims(%{"sub" => "test"}, "org_id", "project_id") ==
                 {:error, :not_found}
      end
    end
  end

  describe "get_allowed_claims/2" do
    test "returns active claims from JWT configuration" do
      FakeServices.enable_features(["open_id_connect_filter", "open_id_connect_project_filter"])

      with_mock(JWTConfiguration, [],
        get_project_config: fn "org_id", "project_id" ->
          {:ok,
           %{
             claims: [
               %{"name" => "sub", "is_active" => true},
               %{"name" => "prj_id", "is_active" => true},
               %{"name" => "inactive", "is_active" => false}
             ]
           }}
        end
      ) do
        assert JWTFilter.get_allowed_claims("org_id", "project_id") == {:ok, ["prj_id", "sub"]}
      end
    end

    test "propagates JWT configuration errors" do
      FakeServices.enable_features(["open_id_connect_filter", "open_id_connect_project_filter"])

      with_mock(JWTConfiguration, [],
        get_project_config: fn "org_id", "project_id" ->
          {:error, :not_found}
        end
      ) do
        assert JWTFilter.get_allowed_claims("org_id", "project_id") == {:error, :not_found}
      end
    end
  end

  describe "filter_claims/3 with actual organization configuration" do
    setup do
      org_id = UUID.generate()
      project_id = UUID.generate()
      {:ok, %{org_id: org_id, project_id: project_id}}
    end

    test "filters claims based on default org configuration", %{
      org_id: org_id,
      project_id: project_id
    } do
      with_mock(Secrethub, [], on_prem?: fn -> true end) do
        FakeServices.enable_features(["open_id_connect_filter"])
        # Create default org configuration
        {:ok, _config} = JWTConfiguration.get_org_config(org_id)

        claims = %{
          "sub" => "test",
          "pr_branch" => "feature/test",
          "repo" => "test-repo",
          "prj_id" => "123",
          "iat" => 123_456
        }

        expected = %{
          "sub" => "test",
          "prj_id" => "123",
          "iat" => 123_456
        }

        assert JWTFilter.filter_claims(claims, org_id, project_id) == {:ok, expected}
      end
    end

    test "filter_claims/3 with actual organization configuration filters AWS tags based on actual org configuration",
         %{org_id: org_id, project_id: project_id} do
      FakeServices.enable_features(["open_id_connect_filter"])
      # Create and customize org configuration
      {:ok, config} = JWTConfiguration.get_org_config(org_id)
      claims = config.claims |> Enum.concat([%{"name" => "branch", "is_active" => true}])
      {:ok, _config} = JWTConfiguration.create_or_update_org_config(org_id, claims)

      input_claims = %{
        "sub" => "test",
        "https://aws.amazon.com/tags" => %{
          "principal_tags" => %{
            "prj_id" => ["123"],
            "branch" => ["main"],
            "extra_tag" => ["value"]
          },
          "transitive_tag_keys" => ["prj_id", "branch", "extra_tag"]
        }
      }

      expected = %{
        "sub" => "test",
        "https://aws.amazon.com/tags" => %{
          "principal_tags" => %{
            "prj_id" => ["123"],
            "branch" => ["main"]
          },
          "transitive_tag_keys" => ["branch", "prj_id"]
        }
      }

      assert JWTFilter.filter_claims(input_claims, org_id, project_id) == {:ok, expected}
    end
  end

  describe "filter_claims/3 with actual project configuration" do
    setup do
      org_id = UUID.generate()
      project_id = UUID.generate()
      {:ok, %{org_id: org_id, project_id: project_id}}
    end

    test "project config overrides org config", %{org_id: org_id, project_id: project_id} do
      FakeServices.enable_features(["open_id_connect_filter", "open_id_connect_project_filter"])
      # Create org configuration with certain claims active
      {:ok, org_config} = JWTConfiguration.get_org_config(org_id)

      org_claims =
        org_config.claims |> Enum.concat([%{"name" => "org_claim", "is_active" => true}])

      {:ok, _} = JWTConfiguration.create_or_update_org_config(org_id, org_claims)

      # Create project configuration with different active claims
      project_claims = [
        %{"name" => "sub", "is_active" => true},
        %{"name" => "project_claim", "is_active" => true},
        %{"name" => "inactive_claim", "is_active" => false}
      ]

      {:ok, _} =
        JWTConfiguration.create_or_update_project_config(org_id, project_id, project_claims)

      claims = %{
        "sub" => "test",
        "org_claim" => "org_value",
        "project_claim" => "project_value"
      }

      expected = %{
        "sub" => "test",
        "project_claim" => "project_value"
      }

      assert JWTFilter.filter_claims(claims, org_id, project_id) == {:ok, expected}
    end

    test "handles non-existent project configuration", %{org_id: org_id, project_id: project_id} do
      FakeServices.enable_features(["open_id_connect_filter", "open_id_connect_project_filter"])
      # Create org configuration with active claims
      {:ok, org_config} = JWTConfiguration.get_org_config(org_id)

      org_claims =
        org_config.claims
        |> Enum.concat([%{"name" => "org_specific", "is_active" => true}])

      {:ok, _} = JWTConfiguration.create_or_update_org_config(org_id, org_claims)

      claims = %{
        "sub" => "test",
        "org_specific" => "value",
        "other_claim" => "value"
      }

      expected = %{
        "sub" => "test",
        "org_specific" => "value"
      }

      assert JWTFilter.filter_claims(claims, org_id, project_id) == {:ok, expected}
    end
  end

  describe "get_allowed_claims/2 with actual configuration" do
    setup do
      org_id = UUID.generate()
      project_id = UUID.generate()
      {:ok, %{org_id: org_id, project_id: project_id}}
    end

    test "returns active claims from org configuration", %{org_id: org_id, project_id: project_id} do
      with_mock(Secrethub, [], on_prem?: fn -> true end) do
        FakeServices.enable_features(["open_id_connect_filter"])
        {:ok, config} = JWTConfiguration.get_org_config(org_id)

        claims =
          config.claims
          |> Enum.concat([
            %{"name" => "custom_claim", "is_active" => true},
            %{"name" => "inactive_claim", "is_active" => false}
          ])

        {:ok, _} = JWTConfiguration.create_or_update_org_config(org_id, claims)

        {:ok, allowed_claims} = JWTFilter.get_allowed_claims(org_id, project_id)

        assert "sub" in allowed_claims
        assert "custom_claim" in allowed_claims
        refute "inactive_claim" in allowed_claims
        # disabled in on-prem
        refute "pr_branch" in allowed_claims
        # disabled in on-prem
        refute "repo" in allowed_claims
      end
    end

    test "returns active claims from project configuration", %{
      org_id: org_id,
      project_id: project_id
    } do
      FakeServices.enable_features(["open_id_connect_filter", "open_id_connect_project_filter"])

      project_claims = [
        %{"name" => "sub", "is_active" => true},
        %{"name" => "project_specific", "is_active" => true},
        %{"name" => "inactive_claim", "is_active" => false}
      ]

      {:ok, _} =
        JWTConfiguration.create_or_update_project_config(org_id, project_id, project_claims)

      {:ok, allowed_claims} = JWTFilter.get_allowed_claims(org_id, project_id)

      assert "sub" in allowed_claims
      assert "project_specific" in allowed_claims
      refute "inactive_claim" in allowed_claims
    end
  end
end
