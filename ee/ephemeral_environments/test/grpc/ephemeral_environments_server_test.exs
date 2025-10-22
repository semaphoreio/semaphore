defmodule EphemeralEnvironments.Grpc.EphemeralEnvironmentsServerTest do
  use ExUnit.Case, async: false

  alias EphemeralEnvironments.Repo
  alias EphemeralEnvironments.Repo.EphemeralEnvironmentType, as: Schema

  alias InternalApi.EphemeralEnvironments.{
    CreateRequest,
    EphemeralEnvironmentType,
    EphemeralEnvironments
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
  end

  describe "describe/2" do
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

      # Validate database record exists
      assert Repo.get(Schema, env_type.id)
    end

    test "fails to create environment type with duplicate name in same org", %{channel: channel} do
      {:ok, _} = Support.Factories.EphemeralEnvironmentsType.insert(org_id: @org_id, name: "Test")

      duplicate_request = %CreateRequest{
        environment_type: %EphemeralEnvironmentType{
          org_id: @org_id,
          name: "Test",
          max_number_of_instances: 1,
          created_by: @user_id
        }
      }

      {:error, error} = EphemeralEnvironments.Stub.create(channel, duplicate_request)
      assert %GRPC.RPCError{} = error
      assert error.status == 2
      assert error.message == "duplicate_name: ephemeral environment name has already been taken"
    end

    test "allows same name in different orgs", %{channel: channel} do
      {:ok, _} = Support.Factories.EphemeralEnvironmentsType.insert(org_id: @org_id, name: "Test")

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
