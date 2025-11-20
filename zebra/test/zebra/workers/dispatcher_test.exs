defmodule Zebra.Workers.DispatcherTest do
  use Zebra.DataCase

  alias Zebra.Models.Job
  alias Zebra.Workers.Dispatcher, as: Worker

  import Mock

  @agent_id Ecto.UUID.generate()

  describe ".tick" do
    test "processes only cloud scheduled jobs" do
      System.put_env("DISPATCH_SELF_HOSTED_ONLY", "false")
      System.put_env("DISPATCH_CLOUD_ONLY", "true")

      cloud_jobs =
        Enum.map(1..3, fn _ ->
          {:ok, job} = Support.Factories.Job.create(:scheduled)
          job
        end)

      self_hosted_jobs =
        Enum.map(1..3, fn _ ->
          {:ok, job} =
            Support.Factories.Job.create(:scheduled, %{machine_type: "s1-local-testing"})

          job
        end)

      response = %InternalApi.Chmura.OccupyAgentResponse{
        agent: %InternalApi.Chmura.Agent{
          id: @agent_id,
          ip_address: "1.2.3.4",
          ssh_port: 80,
          ctrl_port: 80,
          auth_token: "asdas"
        }
      }

      GrpcMock.stub(Support.FakeServers.ChmuraApi, :occupy_agent, fn _, _ -> response end)

      with_stubbed_http_calls(fn ->
        Worker.init() |> Zebra.Workers.DbWorker.tick()
      end)

      cloud_jobs
      |> Enum.each(fn job ->
        job = Job.reload(job)

        assert Job.started?(job) == true
        assert job.agent_ip_address == response.agent.ip_address
        assert job.agent_ctrl_port == response.agent.ctrl_port
        assert job.agent_id == response.agent.id
      end)

      self_hosted_jobs
      |> Enum.each(fn job ->
        job = Job.reload(job)
        assert Job.scheduled?(job) == true
      end)
    end

    test "processes only self-hosted scheduled jobs" do
      System.put_env("DISPATCH_SELF_HOSTED_ONLY", "true")
      System.put_env("DISPATCH_CLOUD_ONLY", "false")

      cloud_jobs =
        Enum.map(1..3, fn _ ->
          {:ok, job} = Support.Factories.Job.create(:scheduled)
          job
        end)

      self_hosted_jobs =
        Enum.map(1..3, fn _ ->
          {:ok, job} =
            Support.Factories.Job.create(:scheduled, %{machine_type: "s1-local-testing"})

          job
        end)

      response = %InternalApi.SelfHosted.OccupyAgentResponse{
        agent_id: @agent_id,
        agent_name: "asdasdas"
      }

      GrpcMock.stub(Support.FakeServers.SelfHosted, :occupy_agent, fn _, _ -> response end)

      with_stubbed_http_calls(fn ->
        Worker.init() |> Zebra.Workers.DbWorker.tick()
      end)

      self_hosted_jobs
      |> Enum.each(fn job ->
        job = Job.reload(job)

        assert Job.started?(job) == true
        assert job.agent_id == response.agent_id
      end)

      cloud_jobs
      |> Enum.each(fn job ->
        job = Job.reload(job)
        assert Job.scheduled?(job) == true
      end)
    end

    test "processes all scheduled jobs" do
      System.put_env("DISPATCH_SELF_HOSTED_ONLY", "false")
      System.put_env("DISPATCH_CLOUD_ONLY", "false")

      cloud_jobs =
        Enum.map(1..3, fn _ ->
          {:ok, job} = Support.Factories.Job.create(:scheduled)
          job
        end)

      self_hosted_jobs =
        Enum.map(1..3, fn _ ->
          {:ok, job} =
            Support.Factories.Job.create(:scheduled, %{machine_type: "s1-local-testing"})

          job
        end)

      GrpcMock.stub(Support.FakeServers.ChmuraApi, :occupy_agent, fn _, _ ->
        %InternalApi.Chmura.OccupyAgentResponse{
          agent: %InternalApi.Chmura.Agent{
            id: @agent_id,
            ip_address: "1.2.3.4",
            ssh_port: 80,
            ctrl_port: 80,
            auth_token: "asdas"
          }
        }
      end)

      GrpcMock.stub(Support.FakeServers.SelfHosted, :occupy_agent, fn _, _ ->
        %InternalApi.SelfHosted.OccupyAgentResponse{
          agent_id: @agent_id,
          agent_name: "asdasdas"
        }
      end)

      with_stubbed_http_calls(fn ->
        Worker.init() |> Zebra.Workers.DbWorker.tick()
      end)

      self_hosted_jobs
      |> Enum.each(fn job ->
        job = Job.reload(job)
        assert Job.started?(job) == true
        assert job.agent_id == @agent_id
      end)

      cloud_jobs
      |> Enum.each(fn job ->
        job = Job.reload(job)
        assert Job.started?(job) == true
        assert job.agent_id == @agent_id
      end)
    end

    test "processes all jobs with readily available agents" do
      System.put_env("DISPATCH_SELF_HOSTED_ONLY", "false")
      System.put_env("DISPATCH_CLOUD_ONLY", "false")
      Zebra.Workers.DispatcherTest.Counter.start_link(0)

      # 100 old jobs for e1 machines which are not gonna be available
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      five_mins_ago = now |> Timex.shift(seconds: -300)

      e1_jobs =
        Enum.map(1..100, fn _ ->
          {:ok, job} =
            Support.Factories.Job.create(:scheduled, %{
              machine_type: "e1-standard-2",
              scheduled_at: five_mins_ago
            })

          job
        end)

      # 20 more recent jobs for e2 machines which are available
      e2_jobs =
        Enum.map(1..20, fn _ ->
          {:ok, job} =
            Support.Factories.Job.create(:scheduled, %{
              machine_type: "e2-standard-2",
              scheduled_at: now
            })

          job
        end)

      GrpcMock.stub(Support.FakeServers.ChmuraApi, :occupy_agent, fn req, _ ->
        if req.machine.type == "e2-standard-2" do
          %InternalApi.Chmura.OccupyAgentResponse{
            agent: %InternalApi.Chmura.Agent{
              id: @agent_id,
              ip_address: "1.2.3.4",
              ssh_port: 80,
              ctrl_port: 80,
              auth_token: "asdas"
            }
          }
        else
          Zebra.Workers.DispatcherTest.Counter.increment()
          raise GRPC.RPCError, status: GRPC.Status.not_found(), message: "no agents for you"
        end
      end)

      with_stubbed_http_calls(fn ->
        Worker.init() |> Zebra.Workers.DbWorker.tick()
      end)

      e1_jobs
      |> Enum.each(fn job ->
        job = Job.reload(job)
        assert Job.scheduled?(job)
      end)

      e2_jobs
      |> Enum.each(fn job ->
        job = Job.reload(job)
        assert Job.started?(job) == true
        assert job.agent_id == @agent_id
      end)

      # We verify that we only sent 10 occupy requests (the first batch).
      # The other 90 requests were not sent because we received
      # a NOT_FOUND response from chmura, and stopped trying to occupy agents.
      assert Zebra.Workers.DispatcherTest.Counter.value() == 10
    end

    test "isolates dispatching by both machine_type and os_image" do
      System.put_env("DISPATCH_SELF_HOSTED_ONLY", "false")
      System.put_env("DISPATCH_CLOUD_ONLY", "false")

      # we need to have at least 20 for each os_image to ensure that we
      # don't stop batching when we receive a NOT_FOUND response from chmura
      # and stop trying to occupy agents.

      ubuntu2404_jobs =
        Enum.map(1..20, fn _ ->
          {:ok, job} =
            Support.Factories.Job.create(:scheduled, %{
              machine_type: "e1-standard-2",
              machine_os_image: "ubuntu2404"
            })

          job
        end)

      # Create jobs with same machine_type but different os_images
      ubuntu1804_jobs =
        Enum.map(1..20, fn _ ->
          {:ok, job} =
            Support.Factories.Job.create(:scheduled, %{
              machine_type: "e1-standard-2",
              machine_os_image: "ubuntu1804"
            })

          job
        end)

      ubuntu2004_jobs =
        Enum.map(1..20, fn _ ->
          {:ok, job} =
            Support.Factories.Job.create(:scheduled, %{
              machine_type: "e1-standard-2",
              machine_os_image: "ubuntu2004"
            })

          job
        end)

      # Track which os_images were requested
      agent_requests = Agent.start_link(fn -> [] end)

      GrpcMock.stub(Support.FakeServers.ChmuraApi, :occupy_agent, fn req, _ ->
        Agent.update(elem(agent_requests, 1), fn list ->
          [req.machine.os_image | list]
        end)

        if req.machine.os_image == "ubuntu2404" do
          raise GRPC.RPCError, status: GRPC.Status.not_found(), message: "No suitable agent found"
        else
          %InternalApi.Chmura.OccupyAgentResponse{
            agent: %InternalApi.Chmura.Agent{
              id: Ecto.UUID.generate(),
              ip_address: "1.2.3.4",
              ssh_port: 80,
              ctrl_port: 80,
              auth_token: "asdas"
            }
          }
        end
      end)

      with_stubbed_http_calls(fn ->
        Worker.init() |> Zebra.Workers.DbWorker.tick()
      end)

      # ubuntu1804 and ubuntu2004 jobs should be started
      (ubuntu1804_jobs ++ ubuntu2004_jobs)
      |> Enum.each(fn job ->
        job = Job.reload(job)
        assert Job.started?(job) == true
      end)

      # ubuntu2404 jobs should remain scheduled (no agents available)
      ubuntu2404_jobs
      |> Enum.each(fn job ->
        job = Job.reload(job)
        assert Job.scheduled?(job) == true
      end)

      # Verify that requests were made with the correct os_images
      requested_os_images = Agent.get(elem(agent_requests, 1), & &1)
      assert length(requested_os_images) == 50
      assert Enum.count(requested_os_images, &(&1 == "ubuntu1804")) == 20
      assert Enum.count(requested_os_images, &(&1 == "ubuntu2004")) == 20
      # only one batch requested
      assert Enum.count(requested_os_images, &(&1 == "ubuntu2404")) == 10
    end

    test "dispatches self-hosted jobs when os_image is blank or nil" do
      System.put_env("DISPATCH_SELF_HOSTED_ONLY", "false")
      System.put_env("DISPATCH_CLOUD_ONLY", "false")

      {:ok, blank_image_job} =
        Support.Factories.Job.create(:scheduled, %{
          machine_type: "s1-local-testing",
          machine_os_image: ""
        })

      {:ok, nil_image_job} =
        Support.Factories.Job.create(:scheduled, %{
          machine_type: "s1-local-testing",
          machine_os_image: nil
        })

      response = %InternalApi.SelfHosted.OccupyAgentResponse{
        agent_id: @agent_id,
        agent_name: "self-hosted-agent"
      }

      GrpcMock.stub(Support.FakeServers.SelfHosted, :occupy_agent, fn _, _ -> response end)

      with_stubbed_http_calls(fn ->
        Worker.init() |> Zebra.Workers.DbWorker.tick()
      end)

      blank_image_job = Job.reload(blank_image_job)
      nil_image_job = Job.reload(nil_image_job)

      assert Job.started?(blank_image_job)
      assert Job.started?(nil_image_job)
      assert blank_image_job.agent_id == @agent_id
      assert nil_image_job.agent_id == @agent_id
      assert blank_image_job.machine_os_image == ""
      assert nil_image_job.machine_os_image in [nil, ""]
    end
  end

  describe ".process" do
    test "processes the job with given id => when the job is scheduled" do
      {:ok, job} = Support.Factories.Job.create(:scheduled)

      response = %InternalApi.Chmura.OccupyAgentResponse{
        agent: %InternalApi.Chmura.Agent{
          id: @agent_id,
          ip_address: "1.2.3.4",
          ctrl_port: 80,
          auth_token: "asdas",
          ssh_port: 12_345
        }
      }

      GrpcMock.stub(Support.FakeServers.ChmuraApi, :occupy_agent, fn _, _ -> response end)

      with_stubbed_http_calls(fn ->
        Worker.process(job)
      end)

      job = Job.reload(job)

      assert Job.started?(job)
      assert job.agent_ip_address == response.agent.ip_address
      assert job.agent_ctrl_port == response.agent.ctrl_port
      assert job.agent_auth_token == response.agent.auth_token
      assert job.agent_id == response.agent.id
    end

    test "skips the processing => when the job is not scheduled" do
      {:ok, job} = Support.Factories.Job.create(:started)

      response = %InternalApi.Chmura.OccupyAgentResponse{
        agent: %InternalApi.Chmura.Agent{
          id: @agent_id,
          ip_address: "1.2.3.4",
          ctrl_port: 80,
          auth_token: "asdas",
          ssh_port: 12_345
        }
      }

      GrpcMock.stub(Support.FakeServers.ChmuraApi, :occupy_agent, fn _, _ -> response end)

      with_stubbed_http_calls(fn ->
        Worker.process(job)
      end)

      job = Job.reload(job)

      assert Job.started?(job)
      refute job.agent_ctrl_port == response.agent.ctrl_port
      refute job.agent_id == response.agent.id
    end

    test "skips the processing => when the agent is broken" do
      {:ok, job} = Support.Factories.Job.create(:scheduled)

      response = %InternalApi.Chmura.OccupyAgentResponse{
        agent: %InternalApi.Chmura.Agent{
          id: @agent_id,
          ip_address: "1.2.3.4",
          ctrl_port: 80,
          auth_token: "asdas",
          ssh_port: 12_345
        }
      }

      GrpcMock.stub(Support.FakeServers.ChmuraApi, :occupy_agent, fn _, _ -> response end)

      with_stubbed_http_calls(
        fn ->
          Worker.process(job)
        end,
        500
      )

      job = Job.reload(job)

      assert Job.scheduled?(job)
      refute job.agent_ctrl_port == response.agent.ctrl_port
      refute job.agent_id == response.agent.id
    end

    test "when self-hosted job and agent information is received => job starts" do
      {:ok, job} = Support.Factories.Job.create(:scheduled, %{machine_type: "s1-testing"})

      GrpcMock.stub(Support.FakeServers.SelfHosted, :occupy_agent, fn _, _ ->
        %InternalApi.SelfHosted.OccupyAgentResponse{
          agent_id: @agent_id,
          agent_name: "asdasdas"
        }
      end)

      with_stubbed_http_calls(fn ->
        Worker.process(job)
      end)

      job = Job.reload(job)
      assert Job.started?(job) == true
      assert job.agent_id == @agent_id
      assert job.agent_name == "asdasdas"
    end

    test "when self-hosted job and no agent information is received => job waits" do
      {:ok, job} = Support.Factories.Job.create(:scheduled, %{machine_type: "s1-testing"})

      GrpcMock.stub(Support.FakeServers.SelfHosted, :occupy_agent, fn _, _ ->
        %InternalApi.SelfHosted.OccupyAgentResponse{
          agent_id: "",
          agent_name: ""
        }
      end)

      with_stubbed_http_calls(fn ->
        Worker.process(job)
      end)

      job = Job.reload(job)
      assert Job.waiting_for_agent?(job) == true
      assert is_nil(job.agent_id)
      assert job.agent_name == ""
    end

    test "submits correct metrics" do
      for %FeatureProvider.Machine{type: type, available_os_images: available_os_images} <-
            Zebra.Machines.machines() do
        for os_image <- available_os_images do
          {:ok, job} =
            Support.Factories.Job.create(:scheduled, %{
              machine_type: type,
              machine_os_image: os_image
            })

          response = %InternalApi.Chmura.OccupyAgentResponse{
            agent: %InternalApi.Chmura.Agent{
              id: Ecto.UUID.generate(),
              ip_address: "1.2.3.4",
              ctrl_port: 80,
              auth_token: "asdas",
              ssh_port: 12_345
            }
          }

          GrpcMock.stub(Support.FakeServers.ChmuraApi, :occupy_agent, fn _, _ -> response end)

          with_mock Watchman, [:passthrough], increment: fn _ -> nil end do
            with_stubbed_http_calls(fn ->
              Worker.process(job)
            end)

            assert_called(
              Watchman.increment(
                {"job.dispatching.histogram", [job.organization_id, "#{type}-#{os_image}", :_]}
              )
            )
          end
        end
      end
    end
  end

  defmodule Counter do
    use Agent

    def start_link(initial_value) do
      Agent.start_link(fn -> initial_value end, name: __MODULE__)
    end

    def value do
      Agent.get(__MODULE__, & &1)
    end

    def increment do
      Agent.update(__MODULE__, &(&1 + 1))
    end
  end
end
