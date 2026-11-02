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

    test "interleaves self-hosted jobs across organizations so one org's backlog can't starve another" do
      System.put_env("DISPATCH_SELF_HOSTED_ONLY", "true")
      System.put_env("DISPATCH_CLOUD_ONLY", "false")

      org_a = Ecto.UUID.generate()
      org_b = Ecto.UUID.generate()

      now = DateTime.utc_now() |> DateTime.truncate(:second)

      org_a_jobs =
        Enum.map(1..5, fn i ->
          {:ok, job} =
            Support.Factories.Job.create(:scheduled, %{
              organization_id: org_a,
              machine_type: "s1-local-testing",
              machine_os_image: "ubuntu2004",
              scheduled_at: Timex.shift(now, seconds: -300 + i)
            })

          job
        end)

      {:ok, org_b_job} =
        Support.Factories.Job.create(:scheduled, %{
          organization_id: org_b,
          machine_type: "s1-local-testing",
          machine_os_image: "ubuntu2004",
          scheduled_at: now
        })

      GrpcMock.stub(Support.FakeServers.SelfHosted, :occupy_agent, fn _, _ ->
        %InternalApi.SelfHosted.OccupyAgentResponse{
          agent_id: @agent_id,
          agent_name: "self-hosted-agent"
        }
      end)

      worker = %{Worker.init() | records_per_tick: 3}

      with_stubbed_http_calls(fn ->
        Zebra.Workers.DbWorker.tick(worker)
      end)

      assert Job.started?(Job.reload(org_b_job)) == true

      started_org_a = Enum.filter(org_a_jobs, fn job -> Job.started?(Job.reload(job)) end)
      assert started_org_a == Enum.take(org_a_jobs, 2)
    end

    test "interleaves self-hosted jobs across agent types within one organization" do
      System.put_env("DISPATCH_SELF_HOSTED_ONLY", "true")
      System.put_env("DISPATCH_CLOUD_ONLY", "false")

      now = DateTime.utc_now() |> DateTime.truncate(:second)

      Enum.each(1..5, fn _ ->
        {:ok, _} =
          Support.Factories.Job.create(:scheduled, %{
            machine_type: "s1-big-backlog",
            scheduled_at: Timex.shift(now, seconds: -300)
          })
      end)

      {:ok, other_type_job} =
        Support.Factories.Job.create(:scheduled, %{
          machine_type: "s1-other",
          scheduled_at: now
        })

      GrpcMock.stub(Support.FakeServers.SelfHosted, :occupy_agent, fn _, _ ->
        %InternalApi.SelfHosted.OccupyAgentResponse{
          agent_id: @agent_id,
          agent_name: "self-hosted-agent"
        }
      end)

      worker = %{Worker.init() | records_per_tick: 2}

      with_stubbed_http_calls(fn ->
        Zebra.Workers.DbWorker.tick(worker)
      end)

      assert Job.started?(Job.reload(other_type_job)) == true

      started =
        Zebra.LegacyRepo.one(
          from(j in Job, where: j.aasm_state == "started", select: count(j.id))
        )

      assert started == 2
    end

    test "dispatches self-hosted jobs with a blank or nil os_image in self-hosted-only mode" do
      System.put_env("DISPATCH_SELF_HOSTED_ONLY", "true")
      System.put_env("DISPATCH_CLOUD_ONLY", "false")

      {:ok, nil_image_job} =
        Support.Factories.Job.create(:scheduled, %{
          machine_type: "s1-local-testing",
          machine_os_image: nil
        })

      {:ok, blank_image_job} =
        Support.Factories.Job.create(:scheduled, %{
          machine_type: "s1-local-testing",
          machine_os_image: ""
        })

      GrpcMock.stub(Support.FakeServers.SelfHosted, :occupy_agent, fn _, _ ->
        %InternalApi.SelfHosted.OccupyAgentResponse{
          agent_id: @agent_id,
          agent_name: "self-hosted-agent"
        }
      end)

      with_stubbed_http_calls(fn ->
        Worker.init() |> Zebra.Workers.DbWorker.tick()
      end)

      Enum.each([nil_image_job, blank_image_job], fn job ->
        assert Job.started?(Job.reload(job)) == true
      end)
    end

    test "cloud dispatching is not interleaved per organization" do
      System.put_env("DISPATCH_SELF_HOSTED_ONLY", "false")
      System.put_env("DISPATCH_CLOUD_ONLY", "true")

      org_a = Ecto.UUID.generate()
      org_b = Ecto.UUID.generate()

      now = DateTime.utc_now() |> DateTime.truncate(:second)
      older = Timex.shift(now, seconds: -300)

      org_a_jobs =
        Enum.map(1..3, fn _ ->
          {:ok, job} =
            Support.Factories.Job.create(:scheduled, %{
              organization_id: org_a,
              machine_type: "e1-standard-2",
              machine_os_image: "ubuntu2004",
              scheduled_at: older
            })

          job
        end)

      org_b_jobs =
        Enum.map(1..3, fn _ ->
          {:ok, job} =
            Support.Factories.Job.create(:scheduled, %{
              organization_id: org_b,
              machine_type: "e1-standard-2",
              machine_os_image: "ubuntu2004",
              scheduled_at: now
            })

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

      worker = %{Worker.init() | records_per_tick: 3}

      with_stubbed_http_calls(fn ->
        Zebra.Workers.DbWorker.tick(worker)
      end)

      Enum.each(org_a_jobs, fn job ->
        assert Job.started?(Job.reload(job)) == true
      end)

      Enum.each(org_b_jobs, fn job ->
        assert Job.scheduled?(Job.reload(job)) == true
      end)
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

  describe ".duration_bucket" do
    test "maps each duration to its own bucket" do
      assert Worker.duration_bucket(0) == "from_0s_to_3s"
      assert Worker.duration_bucket(2.999) == "from_0s_to_3s"
      assert Worker.duration_bucket(3) == "from_3s_to_10s"
      assert Worker.duration_bucket(9.999) == "from_3s_to_10s"
      assert Worker.duration_bucket(10) == "from_10s_to_30s"
      assert Worker.duration_bucket(29.999) == "from_10s_to_30s"
      assert Worker.duration_bucket(30) == "from_30s_to_60s"
      assert Worker.duration_bucket(59.999) == "from_30s_to_60s"
      assert Worker.duration_bucket(60) == "from_60s_to_180s"
      assert Worker.duration_bucket(179.999) == "from_60s_to_180s"
      assert Worker.duration_bucket(180) == "from_180s_to_600s"
      assert Worker.duration_bucket(599.999) == "from_180s_to_600s"
      assert Worker.duration_bucket(600) == "from_600s_to_inf"
      assert Worker.duration_bucket(10_000) == "from_600s_to_inf"
    end

    test "every bucket is reachable and distinct" do
      buckets = Enum.map([0, 3, 10, 30, 60, 180, 600], &Worker.duration_bucket/1)

      assert buckets == Enum.uniq(buckets)
      assert length(buckets) == 7
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
