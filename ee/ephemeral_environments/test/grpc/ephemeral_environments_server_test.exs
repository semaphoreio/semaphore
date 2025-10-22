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
    DescribeRequest
  }

  @org_id Ecto.UUID.generate()
  @user_id Ecto.UUID.generate()
  @grpc_port 50051

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    # Allow the gRPC server process to use this test's DB connection
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})

    # Connect to the gRPC server
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
          max_number_of_instances: 1
        }
      }

      {:error, error} = EphemeralEnvironments.Stub.create(channel, duplicate_request)
      assert %GRPC.RPCError{} = error
      assert error.status == 2
      assert error.message == "duplicate_name: ephemeral environment name has already been taken"
    end

    test "allows same name in different orgs", %{channel: channel} do
      {:ok, _} = Factories.EphemeralEnvironmentsType.insert(org_id: @org_id, name: "Test")

      request = %CreateRequest{
        environment_type: %EphemeralEnvironmentType{
          org_id: Ecto.UUID.generate(),
          name: "Test",
          max_number_of_instances: 1
        }
      }

      assert {:ok, _} = EphemeralEnvironments.Stub.create(channel, request)
    end
  end

  describe "update/2" do
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
