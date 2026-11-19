defmodule Zebra.Workers.Agent.HostedAgentProviderTest do
  use Zebra.DataCase

  alias Zebra.Models.Job
  alias Zebra.Workers.Agent.HostedAgent
  alias InternalApi.Chmura.Chmura.Stub

  import Mock

  @default_endpoint "localhost:50051"
  @secondary_endpoint "secondary-provider:50051"
  @org_with_feature Ecto.UUID.generate()

  setup do
    on_exit(fn -> Application.delete_env(:zebra, :chmura_secondary_endpoint) end)
    Cachex.clear(:feature_provider_cache)

    Mox.stub(Support.MockedProvider, :provide_features, fn org_id, opts ->
      {:ok, features} = Support.StubbedProvider.provide_features(org_id, opts)
      state = if org_id == @org_with_feature, do: :enabled, else: :hidden

      {:ok,
       features ++ [Support.StubbedProvider.feature("secondary_hosted_agent_provider", [state])]}
    end)

    :ok
  end

  describe ".occupy" do
    test "uses the default provider when no secondary endpoint is configured" do
      {:ok, job} = create_job(:scheduled, org_with_feature())

      with_mocks(endpoint_mocks(self(), {:ok, occupy_response()})) do
        assert {:ok, agent} = HostedAgent.occupy(job)
        assert agent.provider == nil
      end

      assert_received {:occupy, @default_endpoint}
    end

    test "uses the secondary provider for organizations with the feature" do
      Application.put_env(:zebra, :chmura_secondary_endpoint, @secondary_endpoint)
      {:ok, job} = create_job(:scheduled, org_with_feature())

      with_mocks(endpoint_mocks(self(), {:ok, occupy_response()})) do
        assert {:ok, agent} = HostedAgent.occupy(job)
        assert agent.provider == HostedAgent.secondary_provider()
      end

      assert_received {:occupy, @secondary_endpoint}
    end

    test "keeps organizations without the feature on the default provider" do
      Application.put_env(:zebra, :chmura_secondary_endpoint, @secondary_endpoint)
      {:ok, job} = Support.Factories.Job.create(:scheduled)

      with_mocks(endpoint_mocks(self(), {:ok, occupy_response()})) do
        assert {:ok, agent} = HostedAgent.occupy(job)
        assert agent.provider == nil
      end

      assert_received {:occupy, @default_endpoint}
    end

    test "tags the secondary provider's errors" do
      Application.put_env(:zebra, :chmura_secondary_endpoint, @secondary_endpoint)
      {:ok, job} = create_job(:scheduled, org_with_feature())
      error = %GRPC.RPCError{status: 5, message: "No suitable agent found"}

      with_mocks(endpoint_mocks(self(), {:error, error})) do
        assert HostedAgent.occupy(job) == {:error, {:secondary_provider, error}}
      end
    end

    test "returns the default provider's errors untagged" do
      {:ok, job} = Support.Factories.Job.create(:scheduled)
      error = %GRPC.RPCError{status: 5, message: "No suitable agent found"}

      with_mocks(endpoint_mocks(self(), {:error, error})) do
        assert HostedAgent.occupy(job) == {:error, error}
      end
    end
  end

  describe ".release" do
    test "goes to the provider that gave the job its agent" do
      Application.put_env(:zebra, :chmura_secondary_endpoint, @secondary_endpoint)

      {:ok, job} =
        Support.Factories.Job.create(:started, %{
          agent_provider: HostedAgent.secondary_provider()
        })

      with_mocks(endpoint_mocks(self(), {:ok, occupy_response()})) do
        assert HostedAgent.release(job) == :ok
      end

      assert_received {:release, @secondary_endpoint}
    end

    test "goes to the default provider for jobs without a provider" do
      Application.put_env(:zebra, :chmura_secondary_endpoint, @secondary_endpoint)
      {:ok, job} = Support.Factories.Job.create(:started)

      with_mocks(endpoint_mocks(self(), {:ok, occupy_response()})) do
        assert HostedAgent.release(job) == :ok
      end

      assert_received {:release, @default_endpoint}
    end

    test "fails, so the release is retried, when the job's provider has no endpoint" do
      {:ok, job} =
        Support.Factories.Job.create(:started, %{
          agent_provider: HostedAgent.secondary_provider()
        })

      with_mocks(endpoint_mocks(self(), {:ok, occupy_response()})) do
        assert HostedAgent.release(job) ==
                 {:error, "no endpoint is configured for the secondary agent provider"}
      end

      refute_received {:release, _}
    end
  end

  describe "Job.start" do
    test "stores the provider that gave the agent" do
      {:ok, job} = Support.Factories.Job.create(:scheduled)

      agent = %HostedAgent{
        id: Ecto.UUID.generate(),
        name: "",
        ip_address: "1.2.3.4",
        ctrl_port: 80,
        ssh_port: 80,
        auth_token: "token",
        provider: HostedAgent.secondary_provider()
      }

      assert {:ok, _} = Job.start(job, agent)
      assert Job.reload(job).agent_provider == HostedAgent.secondary_provider()
    end
  end

  describe ".provider_for" do
    test "names the secondary provider only for organizations with the feature" do
      Application.put_env(:zebra, :chmura_secondary_endpoint, @secondary_endpoint)
      {:ok, job} = create_job(:pending, org_with_feature())
      {:ok, other_job} = Support.Factories.Job.create(:pending)

      assert HostedAgent.provider_for(job) == HostedAgent.secondary_provider()
      assert HostedAgent.provider_for(other_job) == nil
    end

    test "names the default provider when no secondary endpoint is configured" do
      {:ok, job} = create_job(:pending, org_with_feature())

      assert HostedAgent.provider_for(job) == nil
    end
  end

  defp org_with_feature, do: @org_with_feature

  defp create_job(state, org_id),
    do: Support.Factories.Job.create(state, %{organization_id: org_id})

  defp occupy_response do
    %InternalApi.Chmura.OccupyAgentResponse{
      agent: %InternalApi.Chmura.Agent{
        id: Ecto.UUID.generate(),
        ip_address: "1.2.3.4",
        ctrl_port: 80,
        ssh_port: 80
      }
    }
  end

  # Each RPC receives the endpoint it was connected to as its channel and reports
  # it to the test process (occupy runs in a task).
  defp endpoint_mocks(test_pid, occupy_result) do
    [
      {GRPC.Stub, [:passthrough], [connect: fn endpoint -> {:ok, endpoint} end]},
      {Stub, [],
       [
         occupy_agent: fn endpoint, _request, _opts ->
           send(test_pid, {:occupy, endpoint})
           occupy_result
         end,
         release_agent: fn endpoint, _request, _opts ->
           send(test_pid, {:release, endpoint})
           {:ok, %InternalApi.Chmura.ReleaseAgentResponse{}}
         end
       ]}
    ]
  end
end
