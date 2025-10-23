defmodule EphemeralEnvironments.Grpc.EphemeralEnvironmentsServerTest do
  use ExUnit.Case, async: false

  alias EphemeralEnvironments.Repo
  alias EphemeralEnvironments.Repo.EphemeralEnvironmentType, as: Schema
  alias Support.Factories

  alias InternalApi.EphemeralEnvironments.{
    CreateRequest,
    EphemeralEnvironmentType,
    EphemeralEnvironments,
    ListRequest,
    DescribeRequest,
    UpdateRequest
  }

  @org_id Ecto.UUID.generate()
  @user_id Ecto.UUID.generate()
  @grpc_port 50_051

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    # Allow the gRPC server process to use this test's DB connection
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})

    {:ok, channel} = GRPC.Stub.connect("localhost:#{@grpc_port}")
    {:ok, channel: channel}
  end

  describe "list/2" do
    test "returns empty list when no environment types exist", %{channel: channel} do
      request = %ListRequest{org_id: @org_id}
      {:ok, response} = EphemeralEnvironments.Stub.list(channel, request)
      assert response.environment_types == []
    end

    test "returns all environment types for a specific org", %{channel: channel} do
      # Create environment types for the test org
      {:ok, _} = Factories.EphemeralEnvironmentsType.insert(org_id: @org_id, name: "Development")
      {:ok, _} = Factories.EphemeralEnvironmentsType.insert(org_id: @org_id, name: "Staging")
      # Create environment type for a different org (should not be returned)
      {:ok, _} = Factories.EphemeralEnvironmentsType.insert(org_id: Ecto.UUID.generate())

      request = %ListRequest{org_id: @org_id}
      {:ok, response} = EphemeralEnvironments.Stub.list(channel, request)

      assert length(response.environment_types) == 2

      dev_env = Enum.find(response.environment_types, &(&1.name == "Development"))
      assert dev_env.org_id == @org_id
      assert dev_env.name == "Development"

      staging_env = Enum.find(response.environment_types, &(&1.name == "Staging"))
      assert staging_env.org_id == @org_id
      assert staging_env.name == "Staging"
    end

    test "handles multiple orgs correctly", %{channel: channel} do
      org2_id = Ecto.UUID.generate()
      {:ok, _} = Factories.EphemeralEnvironmentsType.insert(org_id: @org_id)
      {:ok, _} = Factories.EphemeralEnvironmentsType.insert(org_id: @org_id)
      # Create environment types for org2
      {:ok, _} = Factories.EphemeralEnvironmentsType.insert(org_id: org2_id)

      # Request for org1
      request1 = %ListRequest{org_id: @org_id}
      {:ok, response1} = EphemeralEnvironments.Stub.list(channel, request1)
      assert length(response1.environment_types) == 2
      assert Enum.all?(response1.environment_types, &(&1.org_id == @org_id))

      # Request for org2
      request2 = %ListRequest{org_id: org2_id}
      {:ok, response2} = EphemeralEnvironments.Stub.list(channel, request2)
      assert length(response2.environment_types) == 1
      assert Enum.all?(response2.environment_types, &(&1.org_id == org2_id))
    end
  end

  describe "describe/2" do
    test "returns environment type when it exists", %{channel: channel} do
      {:ok, env_type} =
        Factories.EphemeralEnvironmentsType.insert(
          org_id: @org_id,
          name: "Production",
          description: "Production environment",
          created_by: @user_id,
          state: :ready,
          max_number_of_instances: 20
        )

      request = %DescribeRequest{id: env_type.id, org_id: @org_id}

      {:ok, response} = EphemeralEnvironments.Stub.describe(channel, request)

      assert response.environment_type.id == env_type.id
      assert response.environment_type.org_id == @org_id
      assert response.environment_type.name == "Production"
      assert response.environment_type.description == "Production environment"
      assert response.environment_type.created_by == @user_id
      assert response.environment_type.last_updated_by == @user_id
      assert response.environment_type.state == :TYPE_STATE_READY
      assert response.environment_type.max_number_of_instances == 20
      assert_recent_timestamp(DateTime.from_unix!(response.environment_type.created_at.seconds))
      assert_recent_timestamp(DateTime.from_unix!(response.environment_type.updated_at.seconds))
      assert response.instances == []
    end

    test "returns not_found error when environment type doesn't exist", %{channel: channel} do
      request = %DescribeRequest{id: Ecto.UUID.generate(), org_id: @org_id}

      {:error, %GRPC.RPCError{} = error} = EphemeralEnvironments.Stub.describe(channel, request)
      assert error.status == 5
      assert error.message == "Environment type not found"
    end

    test "returns not_found when querying with wrong org_id", %{channel: channel} do
      {:ok, env_type} = Factories.EphemeralEnvironmentsType.insert(org_id: @org_id)
      request = %DescribeRequest{id: env_type.id, org_id: Ecto.UUID.generate()}

      {:error, %GRPC.RPCError{} = error} = EphemeralEnvironments.Stub.describe(channel, request)
      assert error.status == 5
      assert error.message == "Environment type not found"
    end
  end

  describe "create/2" do
    test "creates the environment and ignores invalid request attributes", %{channel: channel} do
      # Build request with invalid attributes that should be ignored:
      # - wrong last_updated_by (should use created_by)
      # - wrong state (should default to :draft)
      # - old timestamps (should use current DB timestamps)
      request = %CreateRequest{
        environment_type: %EphemeralEnvironmentType{
          org_id: @org_id,
          name: "Test Environment",
          description: "A test environment type",
          created_by: @user_id,
          last_updated_by: Ecto.UUID.generate(),
          state: :TYPE_STATE_CORDONED,
          max_number_of_instances: 5,
          created_at: build_old_timestamp(),
          updated_at: build_old_timestamp()
        }
      }

      # Make the actual gRPC call through the stub (goes through all interceptors)
      {:ok, response} = EphemeralEnvironments.Stub.create(channel, request)
      env_type = response.environment_type

      # Validate response - invalid attributes were corrected
      assert env_type.org_id == @org_id
      assert env_type.name == "Test Environment"
      assert env_type.description == "A test environment type"
      assert env_type.created_by == @user_id
      assert env_type.last_updated_by == @user_id
      assert env_type.state == :TYPE_STATE_DRAFT
      assert env_type.max_number_of_instances == 5
      assert_recent_timestamp(DateTime.from_unix!(env_type.updated_at.seconds))
      assert_recent_timestamp(DateTime.from_unix!(env_type.created_at.seconds))

      # Validate database record exists
      assert Repo.get(Schema, env_type.id)
    end

    test "fails to create environment type with duplicate name in same org", %{channel: channel} do
      {:ok, _} = Factories.EphemeralEnvironmentsType.insert(org_id: @org_id, name: "Test")

      duplicate_request = %CreateRequest{
        environment_type: %EphemeralEnvironmentType{
          org_id: @org_id,
          name: "Test",
          max_number_of_instances: 1,
          created_by: @user_id
        }
      }

      {:error, %GRPC.RPCError{} = error} =
        EphemeralEnvironments.Stub.create(channel, duplicate_request)

      assert error.status == 2
      assert error.message == "duplicate_name: ephemeral environment name has already been taken"
    end

    test "allows same name in different orgs", %{channel: channel} do
      {:ok, _} = Factories.EphemeralEnvironmentsType.insert(org_id: @org_id, name: "Test")

      request = %CreateRequest{
        environment_type: %EphemeralEnvironmentType{
          org_id: Ecto.UUID.generate(),
          name: "Test",
          max_number_of_instances: 1,
          created_by: @user_id
        }
      }

      assert {:ok, _} = EphemeralEnvironments.Stub.create(channel, request)
    end
  end

  describe "update/2" do
    test "updates environment type successfully", %{channel: channel} do
      {:ok, env_type} =
        Factories.EphemeralEnvironmentsType.insert(
          org_id: @org_id,
          name: "Original Name",
          description: "Original description",
          created_by: @user_id,
          state: :draft,
          max_number_of_instances: 5
        )

      updater_id = Ecto.UUID.generate()

      request = %UpdateRequest{
        environment_type: %EphemeralEnvironmentType{
          id: env_type.id,
          org_id: @org_id,
          name: "Updated Name",
          description: "Updated description",
          last_updated_by: updater_id,
          state: :TYPE_STATE_READY,
          max_number_of_instances: 10
        }
      }

      {:ok, response} = EphemeralEnvironments.Stub.update(channel, request)

      assert response.environment_type.id == env_type.id
      assert response.environment_type.org_id == @org_id
      assert response.environment_type.name == "Updated Name"
      assert response.environment_type.description == "Updated description"
      assert response.environment_type.last_updated_by == updater_id
      assert response.environment_type.state == :TYPE_STATE_READY
      assert response.environment_type.max_number_of_instances == 10
      # created_by should remain unchanged
      assert response.environment_type.created_by == @user_id

      # Verify database record was updated
      db_record = Repo.get(Schema, env_type.id)
      assert db_record.name == "Updated Name"
      assert db_record.description == "Updated description"
      assert db_record.last_updated_by == updater_id
      assert db_record.state == :ready
    end

    test "updates only provided fields", %{channel: channel} do
      {:ok, env_type} =
        Factories.EphemeralEnvironmentsType.insert(
          org_id: @org_id,
          name: "Original Name",
          description: "Original description",
          created_by: @user_id,
          state: :draft,
          max_number_of_instances: 5
        )

      updater_id = Ecto.UUID.generate()

      # Only update name and last_updated_by
      request = %UpdateRequest{
        environment_type: %EphemeralEnvironmentType{
          id: env_type.id,
          org_id: @org_id,
          name: "New Name",
          last_updated_by: updater_id
        }
      }

      {:ok, response} = EphemeralEnvironments.Stub.update(channel, request)

      assert response.environment_type.name == "New Name"
      assert response.environment_type.last_updated_by == updater_id
      # Other fields should remain unchanged
      assert response.environment_type.description == "Original description"
      assert response.environment_type.state == :TYPE_STATE_DRAFT
      assert response.environment_type.max_number_of_instances == 5
    end

    test "returns not_found when environment type doesn't exist", %{channel: channel} do
      request = %UpdateRequest{
        environment_type: %EphemeralEnvironmentType{
          id: Ecto.UUID.generate(),
          org_id: @org_id,
          name: "Updated Name",
          last_updated_by: @user_id
        }
      }

      {:error, %GRPC.RPCError{} = error} = EphemeralEnvironments.Stub.update(channel, request)
      assert error.status == 5
      assert error.message == "Environment type not found"
    end

    test "returns not_found when updating with wrong org_id", %{channel: channel} do
      {:ok, env_type} = Factories.EphemeralEnvironmentsType.insert(org_id: @org_id, name: "1")
      different_org_id = Ecto.UUID.generate()

      request = %UpdateRequest{
        environment_type: %EphemeralEnvironmentType{
          id: env_type.id,
          org_id: different_org_id,
          name: "Updated Name",
          last_updated_by: @user_id
        }
      }

      {:error, %GRPC.RPCError{} = error} = EphemeralEnvironments.Stub.update(channel, request)
      assert error.status == 5
      assert error.message == "Environment type not found"
    end

    test "fails validation when updating with duplicate name in same org", %{channel: channel} do
      {:ok, _} = Factories.EphemeralEnvironmentsType.insert(org_id: @org_id, name: "1")
      {:ok, env2} = Factories.EphemeralEnvironmentsType.insert(org_id: @org_id, name: "2")

      # Try to rename env2 to env1's name
      request = %UpdateRequest{
        environment_type: %EphemeralEnvironmentType{
          id: env2.id,
          org_id: @org_id,
          name: "1",
          last_updated_by: @user_id
        }
      }

      {:error, %GRPC.RPCError{} = error} = EphemeralEnvironments.Stub.update(channel, request)
      assert error.status == 2
      assert error.message == "duplicate_name: ephemeral environment name has already been taken"
    end

    test "allows updating to same name in different org", %{channel: channel} do
      {:ok, _} = Factories.EphemeralEnvironmentsType.insert(org_id: @org_id, name: "1")
      org2_id = Ecto.UUID.generate()
      {:ok, env2} = Factories.EphemeralEnvironmentsType.insert(org_id: org2_id, name: "2")

      # Update env2 to use the same name as env1 (but different org)
      request = %UpdateRequest{
        environment_type: %EphemeralEnvironmentType{
          id: env2.id,
          org_id: org2_id,
          name: "1",
          last_updated_by: @user_id
        }
      }

      assert {:ok, response} = EphemeralEnvironments.Stub.update(channel, request)
      assert response.environment_type.name == "1"
    end

    test "updates timestamp when updating", %{channel: channel} do
      {:ok, env_type} = Factories.EphemeralEnvironmentsType.insert(org_id: @org_id)
      # Wait a bit to ensure timestamp changes
      :timer.sleep(100)

      request = %UpdateRequest{
        environment_type: %EphemeralEnvironmentType{
          id: env_type.id,
          org_id: @org_id,
          name: "Updated Name",
          last_updated_by: @user_id
        }
      }

      {:ok, response} = EphemeralEnvironments.Stub.update(channel, request)

      # created_at should be the original timestamp
      original_created_at = DateTime.from_naive!(env_type.inserted_at, "Etc/UTC")
      response_created_at = DateTime.from_unix!(response.environment_type.created_at.seconds)
      assert DateTime.diff(response_created_at, original_created_at, :second) == 0
      assert_recent_timestamp(DateTime.from_unix!(response.environment_type.updated_at.seconds))
    end
  end

  describe "delete/2" do
  end

  describe "cordon/2" do
  end

  ###
  ### Helper functions
  ###

  defp build_old_timestamp do
    one_hour_ago = DateTime.utc_now() |> DateTime.add(-3600, :second)
    %Google.Protobuf.Timestamp{seconds: DateTime.to_unix(one_hour_ago), nanos: 0}
  end

  defp assert_recent_timestamp(datetime) do
    assert DateTime.diff(DateTime.utc_now(), datetime, :second) < 5
  end
end
