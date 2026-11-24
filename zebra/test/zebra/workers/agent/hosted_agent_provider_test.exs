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

    test "occupies from the provider the request was built for" do
      Application.put_env(:zebra, :chmura_secondary_endpoint, @secondary_endpoint)

      {:ok, built_for_secondary} =
        Support.Factories.Job.create(:scheduled, %{request_provider: "secondary"})

      {:ok, built_for_default} =
        Support.Factories.Job.create(:scheduled, %{
          organization_id: org_with_feature(),
          request_provider: "default"
        })

      with_mocks(endpoint_mocks(self(), {:ok, occupy_response()})) do
        assert {:ok, %{provider: "secondary"}} = HostedAgent.occupy(built_for_secondary)
        assert_received {:occupy, @secondary_endpoint}

        assert {:ok, %{provider: nil}} = HostedAgent.occupy(built_for_default)
        assert_received {:occupy, @default_endpoint}
      end
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

    test "stores where the agent runs" do
      {:ok, job} = Support.Factories.Job.create(:scheduled)

      agent = %HostedAgent{
        id: Ecto.UUID.generate(),
        name: "",
        ip_address: "1.2.3.4",
        ctrl_port: 80,
        ssh_port: 80,
        auth_token: "token",
        region: "r1",
        zone: "r1-b"
      }

      assert {:ok, _} = Job.start(job, agent, sanitize_request: true)

      job = Job.reload(job)
      assert job.agent_region == "r1"
      assert job.agent_zone == "r1-b"
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

    test "keeps a job on the provider its request was built for, whatever the feature says now" do
      Application.put_env(:zebra, :chmura_secondary_endpoint, @secondary_endpoint)

      {:ok, built_for_secondary} =
        Support.Factories.Job.create(:scheduled, %{request_provider: "secondary"})

      {:ok, built_for_default} =
        Support.Factories.Job.create(:scheduled, %{
          organization_id: org_with_feature(),
          request_provider: "default"
        })

      assert HostedAgent.provider_for(built_for_secondary) == HostedAgent.secondary_provider()
      assert HostedAgent.provider_for(built_for_default) == nil
    end

    test "jobs built before the provider was stored, or with an unknown one, follow the feature" do
      Application.put_env(:zebra, :chmura_secondary_endpoint, @secondary_endpoint)

      for stored <- [nil, "unknown"] do
        {:ok, job} =
          Support.Factories.Job.create(:scheduled, %{
            organization_id: org_with_feature(),
            request_provider: stored
          })

        {:ok, other_job} = Support.Factories.Job.create(:scheduled, %{request_provider: stored})

        assert HostedAgent.provider_for(job) == HostedAgent.secondary_provider()
        assert HostedAgent.provider_for(other_job) == nil
      end
    end

    test "without a secondary endpoint, every job goes to the default provider" do
      {:ok, job} = Support.Factories.Job.create(:scheduled, %{request_provider: "secondary"})

      assert HostedAgent.provider_for(job) == nil
    end
  end

  describe ".request_provider" do
    test "is the secondary provider for organizations with the feature, the default otherwise" do
      Application.put_env(:zebra, :chmura_secondary_endpoint, @secondary_endpoint)
      {:ok, job} = create_job(:pending, org_with_feature())
      {:ok, other_job} = Support.Factories.Job.create(:pending)

      assert HostedAgent.request_provider(job) == HostedAgent.secondary_provider()
      assert HostedAgent.request_provider(other_job) == "default"
    end

    test "is the default provider when no secondary endpoint is configured" do
      {:ok, job} = create_job(:pending, org_with_feature())

      assert HostedAgent.request_provider(job) == "default"
    end
  end

  describe ".waiting_by_provider" do
    test "counts every job for the default provider when no secondary endpoint is configured" do
      {:ok, job} = create_job(:scheduled, org_with_feature())
      {:ok, other_job} = Support.Factories.Job.create(:scheduled)

      assert HostedAgent.waiting_by_provider([job.id, other_job.id]) == %{
               nil => %{job.id => 2, other_job.id => 1}
             }
    end

    test "splits the jobs by their organization's provider" do
      Application.put_env(:zebra, :chmura_secondary_endpoint, @secondary_endpoint)

      [s1, s2, s3] =
        Enum.map(1..3, fn _ -> elem(create_job(:scheduled, org_with_feature()), 1).id end)

      [d1, d2] = Enum.map(1..2, fn _ -> elem(Support.Factories.Job.create(:scheduled), 1).id end)

      # Dispatch order interleaves the providers; each counts its own jobs.
      assert HostedAgent.waiting_by_provider([s1, d1, s2, d2, s3]) == %{
               HostedAgent.secondary_provider() => %{s1 => 3, s2 => 2, s3 => 1},
               nil => %{d1 => 2, d2 => 1}
             }
    end

    test "groups jobs by the provider their request was built for" do
      Application.put_env(:zebra, :chmura_secondary_endpoint, @secondary_endpoint)

      {:ok, %{id: built_default}} =
        Support.Factories.Job.create(:scheduled, %{
          organization_id: org_with_feature(),
          request_provider: "default"
        })

      {:ok, %{id: built_secondary}} =
        Support.Factories.Job.create(:scheduled, %{request_provider: "secondary"})

      {:ok, %{id: legacy}} = create_job(:scheduled, org_with_feature())

      assert HostedAgent.waiting_by_provider([built_default, built_secondary, legacy]) == %{
               HostedAgent.secondary_provider() => %{built_secondary => 2, legacy => 1},
               nil => %{built_default => 1}
             }
    end

    test "is empty without jobs" do
      Application.put_env(:zebra, :chmura_secondary_endpoint, @secondary_endpoint)

      assert HostedAgent.waiting_by_provider([]) == %{}
    end
  end

  describe ".occupy waiting" do
    test "sends the count of the job's provider" do
      Application.put_env(:zebra, :chmura_secondary_endpoint, @secondary_endpoint)
      {:ok, job} = create_job(:scheduled, org_with_feature())
      counts = %{HostedAgent.secondary_provider() => %{job.id => 7}, nil => %{job.id => 40}}

      with_mocks(request_mocks(self())) do
        HostedAgent.occupy(job, counts)
      end

      assert_received {:waiting, 7}
    end

    test "sends 0 when its provider has no count" do
      {:ok, job} = Support.Factories.Job.create(:scheduled)

      with_mocks(request_mocks(self())) do
        HostedAgent.occupy(job, %{HostedAgent.secondary_provider() => %{job.id => 7}})
        HostedAgent.occupy(job, %{nil => %{Ecto.UUID.generate() => 7}})
        HostedAgent.occupy(job)
      end

      assert_received {:waiting, 0}
      assert_received {:waiting, 0}
      assert_received {:waiting, 0}
    end
  end

  describe ".occupy home region" do
    setup do
      Application.put_env(:zebra, :chmura_secondary_home_region, "home-1")
      on_exit(fn -> Application.delete_env(:zebra, :chmura_secondary_home_region) end)

      Mox.stub(Support.MockedProvider, :provide_features, fn org_id, opts ->
        {:ok, features} = Support.StubbedProvider.provide_features(org_id, opts)

        {:ok,
         features ++
           [
             Support.StubbedProvider.feature("secondary_hosted_agent_provider", [:enabled]),
             Support.StubbedProvider.feature(
               "secondary_hosted_agent_home_region_only",
               [if(org_id == @org_with_feature, do: :enabled, else: :hidden)]
             )
           ]}
      end)

      :ok
    end

    test "allows only the home region for flagged organizations on the secondary provider" do
      Application.put_env(:zebra, :chmura_secondary_endpoint, @secondary_endpoint)
      {:ok, job} = create_job(:scheduled, org_with_feature())
      {:ok, other_job} = Support.Factories.Job.create(:scheduled)

      with_mocks(request_mocks(self())) do
        assert {:ok, %{provider: "secondary"}} = HostedAgent.occupy(job)
        assert {:ok, %{provider: "secondary"}} = HostedAgent.occupy(other_job)
      end

      assert_received {:preferred_regions, @org_with_feature, ["home-1"]}
      other_org = other_job.organization_id
      assert_received {:preferred_regions, ^other_org, []}
    end

    test "never restricts the default provider" do
      {:ok, job} = create_job(:scheduled, org_with_feature())

      with_mocks(request_mocks(self())) do
        assert {:ok, %{provider: nil}} = HostedAgent.occupy(job)
      end

      assert_received {:preferred_regions, @org_with_feature, []}
    end

    test "keeps the job home when the organization's features cannot be read" do
      Application.put_env(:zebra, :chmura_secondary_endpoint, @secondary_endpoint)
      {:ok, job} = Support.Factories.Job.create(:scheduled, %{request_provider: "secondary"})

      Mox.stub(Support.MockedProvider, :provide_features, fn _org_id, _opts ->
        {:error, :unavailable}
      end)

      with_mocks(request_mocks(self())) do
        assert {:ok, %{provider: "secondary"}} = HostedAgent.occupy(job)
      end

      org_id = job.organization_id
      assert_received {:preferred_regions, ^org_id, ["home-1"]}
    end

    test "does not offer a job that must stay home while the home region is not set" do
      Application.put_env(:zebra, :chmura_secondary_endpoint, @secondary_endpoint)
      {:ok, job} = create_job(:scheduled, org_with_feature())
      {:ok, other_job} = Support.Factories.Job.create(:scheduled)

      for home_region <- [nil, " "] do
        Application.put_env(:zebra, :chmura_secondary_home_region, home_region)

        with_mocks(request_mocks(self())) do
          assert HostedAgent.occupy(job) ==
                   {:error, {:secondary_provider, :home_region_not_configured}}

          assert {:ok, %{provider: "secondary"}} = HostedAgent.occupy(other_job)
        end

        refute_received {:preferred_regions, @org_with_feature, _}
        other_org = other_job.organization_id
        assert_received {:preferred_regions, ^other_org, []}
      end
    end
  end

  describe ".occupy placement" do
    test "the agent carries the region and zone its provider reports" do
      {:ok, job} = Support.Factories.Job.create(:scheduled)
      response = occupy_response()
      response = %{response | agent: %{response.agent | region: "r1", zone: "r1-b"}}

      with_mocks(endpoint_mocks(self(), {:ok, response})) do
        assert {:ok, %{region: "r1", zone: "r1-b"}} = HostedAgent.occupy(job)
      end
    end

    test "the agent has no region or zone when its provider reports none" do
      {:ok, job} = Support.Factories.Job.create(:scheduled)

      with_mocks(endpoint_mocks(self(), {:ok, occupy_response()})) do
        assert {:ok, %{region: nil, zone: nil}} = HostedAgent.occupy(job)
      end
    end
  end

  describe ".occupy cost tags" do
    test "sends the job's organization and project" do
      {:ok, job} = Support.Factories.Job.create(:scheduled)

      with_mocks(request_mocks(self())) do
        HostedAgent.occupy(job)
      end

      assert_received {:tags, org_id, project_id}
      assert org_id == job.organization_id
      assert project_id == job.project_id
      assert org_id != "" and project_id != ""
    end

    test "sends empty ids for a job without them" do
      {:ok, job} = Support.Factories.Job.create(:scheduled)
      job = %{job | organization_id: nil, project_id: nil}

      with_mocks(request_mocks(self())) do
        HostedAgent.occupy(job)
      end

      assert_received {:tags, "", ""}
    end
  end

  defp request_mocks(test_pid) do
    [
      {GRPC.Stub, [:passthrough], [connect: fn endpoint -> {:ok, endpoint} end]},
      {Stub, [],
       [
         occupy_agent: fn _endpoint, request, _opts ->
           send(test_pid, {:waiting, request.waiting})
           send(test_pid, {:tags, request.organization_id, request.project_id})

           send(
             test_pid,
             {:preferred_regions, request.organization_id, request.preferred_regions}
           )

           {:ok, occupy_response()}
         end
       ]}
    ]
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
