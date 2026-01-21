defmodule Zebra.MonitorTest do
  use Zebra.DataCase, async: false

  alias Zebra.Monitor

  setup do
    GrpcMock.stub(Support.FakeServers.OrganizationApi, :describe, fn _, _ ->
      InternalApi.Organization.DescribeResponse.new(
        status:
          InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
        organization:
          InternalApi.Organization.Organization.new(
            org_username: "test-org",
            suspended: false
          )
      )
    end)

    :ok
  end

  describe ".stop_jobs_on_suspended_orgs" do
    test "stop job for suspended orgs" do
      stub_org(true)

      {:ok, job} = create_job()

      Zebra.Monitor.stop_jobs_on_suspended_orgs()

      assert {:ok, _} = Zebra.Models.JobStopRequest.find_by_job_id(job.id)
    end

    test "doesn't stop job for non-suspended orgs" do
      stub_org(false)

      {:ok, job} = create_job()

      Zebra.Monitor.stop_jobs_on_suspended_orgs()

      assert {:error, :not_found} = Zebra.Models.JobStopRequest.find_by_job_id(job.id)
    end

    def create_job do
      alias Support.Factories.Job, as: FJ

      twenty_mins_ago =
        DateTime.utc_now() |> DateTime.truncate(:second) |> Timex.shift(minutes: -20)

      FJ.create(:started, %{started_at: twenty_mins_ago})
    end

    def stub_org(suspended) do
      alias Support.FakeServers.OrganizationApi, as: OrgApi

      GrpcMock.stub(OrgApi, :describe, fn _, _ ->
        InternalApi.Organization.DescribeResponse.new(
          status:
            InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
          organization:
            InternalApi.Organization.Organization.new(
              org_username: "testing-org",
              suspended: suspended
            )
        )
      end)

      alias Support.FakeServers.FeatureApi, as: Api

      alias InternalApi.Feature.{
        OrganizationMachine,
        OrganizationFeature,
        Availability,
        Machine,
        Feature
      }

      GrpcMock.stub(Api, :list_organization_features, fn _, _ ->
        InternalApi.Feature.ListOrganizationFeaturesResponse.new(
          organization_features: [
            OrganizationFeature.new(
              feature: Feature.new(type: "max_paralellism_in_org"),
              availability:
                Availability.new(quantity: 25, state: Availability.State.value(:ENABLED))
            )
          ]
        )
      end)

      GrpcMock.stub(Api, :list_organization_machines, fn _, _ ->
        InternalApi.Feature.ListOrganizationMachinesResponse.new(
          organization_machines: [
            OrganizationMachine.new(
              machine: Machine.new(type: "e1-standard-2"),
              availability:
                Availability.new(quantity: 5, state: Availability.State.value(:ENABLED))
            ),
            OrganizationMachine.new(
              machine: Machine.new(type: "e1-standard-4"),
              availability:
                Availability.new(quantity: 5, state: Availability.State.value(:ENABLED))
            ),
            OrganizationMachine.new(
              machine: Machine.new(type: "e1-standard-8"),
              availability:
                Availability.new(quantity: 5, state: Availability.State.value(:ENABLED))
            ),
            OrganizationMachine.new(
              machine: Machine.new(type: "a1-standard-4"),
              availability:
                Availability.new(quantity: 5, state: Availability.State.value(:ENABLED))
            ),
            OrganizationMachine.new(
              machine: Machine.new(type: "a1-standard-8"),
              availability:
                Availability.new(quantity: 5, state: Availability.State.value(:ENABLED))
            )
          ]
        )
      end)
    end
  end

  describe "count_stuck_jobs" do
    alias Support.Factories.Job

    test "when the jobs don't have an execution_time_limit" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      four_hours_ago = now |> Timex.shift(minutes: -240)
      one_hour_ago = now |> Timex.shift(minutes: -60)
      two_mins_ago = now |> Timex.shift(minutes: -2)

      {:ok, _} =
        Job.create(:started, %{
          started_at: four_hours_ago,
          execution_time_limit: nil
        })

      {:ok, _} =
        Job.create(:started, %{
          started_at: one_hour_ago,
          execution_time_limit: nil
        })

      {:ok, _} =
        Job.create(:started, %{
          started_at: two_mins_ago,
          execution_time_limit: nil
        })

      assert Monitor.count_stuck_jobs() == 1
    end

    test "when the jobs have an execution_time_limit" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      four_hours_ago = now |> Timex.shift(minutes: -240)
      one_hour_ago = now |> Timex.shift(minutes: -60)
      two_mins_ago = now |> Timex.shift(minutes: -2)

      # 30 mins
      limit = 30 * 60

      {:ok, _} =
        Job.create(:started, %{
          started_at: four_hours_ago,
          execution_time_limit: limit
        })

      {:ok, _} =
        Job.create(:started, %{
          started_at: one_hour_ago,
          execution_time_limit: limit
        })

      {:ok, _} =
        Job.create(:started, %{
          started_at: two_mins_ago,
          execution_time_limit: limit
        })

      assert Monitor.count_stuck_jobs() == 2
    end
  end

  test "measure waiting times" do
    alias Support.Factories.Job

    now = DateTime.utc_now() |> DateTime.truncate(:second)
    t = now |> Timex.shift(seconds: -240)
    {:ok, _} = Job.create(:scheduled, %{scheduled_at: t})

    assert Monitor.waiting_times() == %{
             "a1-standard-4" => %{
               "from_0s_to_3s" => 0,
               "from_10m_to_inf" => 0,
               "from_10s_to_30s" => 0,
               "from_1m_to_3m" => 0,
               "from_30s_to_1m" => 0,
               "from_3m_to_10m" => 0,
               "from_3s_to_10s" => 0
             },
             "a1-standard-8" => %{
               "from_0s_to_3s" => 0,
               "from_10m_to_inf" => 0,
               "from_10s_to_30s" => 0,
               "from_1m_to_3m" => 0,
               "from_30s_to_1m" => 0,
               "from_3m_to_10m" => 0,
               "from_3s_to_10s" => 0
             },
             "ax1-standard-4" => %{
               "from_0s_to_3s" => 0,
               "from_10m_to_inf" => 0,
               "from_10s_to_30s" => 0,
               "from_1m_to_3m" => 0,
               "from_30s_to_1m" => 0,
               "from_3m_to_10m" => 0,
               "from_3s_to_10s" => 0
             },
             "e1-standard-2" => %{
               "from_0s_to_3s" => 0,
               "from_10m_to_inf" => 0,
               "from_10s_to_30s" => 0,
               "from_1m_to_3m" => 0,
               "from_30s_to_1m" => 0,
               "from_3m_to_10m" => 1,
               "from_3s_to_10s" => 0
             },
             "e1-standard-4" => %{
               "from_0s_to_3s" => 0,
               "from_10m_to_inf" => 0,
               "from_10s_to_30s" => 0,
               "from_1m_to_3m" => 0,
               "from_30s_to_1m" => 0,
               "from_3m_to_10m" => 0,
               "from_3s_to_10s" => 0
             },
             "e1-standard-8" => %{
               "from_0s_to_3s" => 0,
               "from_10m_to_inf" => 0,
               "from_10s_to_30s" => 0,
               "from_1m_to_3m" => 0,
               "from_30s_to_1m" => 0,
               "from_3m_to_10m" => 0,
               "from_3s_to_10s" => 0
             },
             "g1-standard-2" => %{
               "from_0s_to_3s" => 0,
               "from_10m_to_inf" => 0,
               "from_10s_to_30s" => 0,
               "from_1m_to_3m" => 0,
               "from_30s_to_1m" => 0,
               "from_3m_to_10m" => 0,
               "from_3s_to_10s" => 0
             },
             "g1-standard-3" => %{
               "from_0s_to_3s" => 0,
               "from_10m_to_inf" => 0,
               "from_10s_to_30s" => 0,
               "from_1m_to_3m" => 0,
               "from_30s_to_1m" => 0,
               "from_3m_to_10m" => 0,
               "from_3s_to_10s" => 0
             },
             "g1-standard-4" => %{
               "from_0s_to_3s" => 0,
               "from_10m_to_inf" => 0,
               "from_10s_to_30s" => 0,
               "from_1m_to_3m" => 0,
               "from_30s_to_1m" => 0,
               "from_3m_to_10m" => 0,
               "from_3s_to_10s" => 0
             },
             "f1-standard-2" => %{
               "from_0s_to_3s" => 0,
               "from_10m_to_inf" => 0,
               "from_10s_to_30s" => 0,
               "from_1m_to_3m" => 0,
               "from_30s_to_1m" => 0,
               "from_3m_to_10m" => 0,
               "from_3s_to_10s" => 0
             },
             "f1-standard-4" => %{
               "from_0s_to_3s" => 0,
               "from_10m_to_inf" => 0,
               "from_10s_to_30s" => 0,
               "from_1m_to_3m" => 0,
               "from_30s_to_1m" => 0,
               "from_3m_to_10m" => 0,
               "from_3s_to_10s" => 0
             },
             "c1-standard-1" => %{
               "from_0s_to_3s" => 0,
               "from_10m_to_inf" => 0,
               "from_10s_to_30s" => 0,
               "from_1m_to_3m" => 0,
               "from_30s_to_1m" => 0,
               "from_3m_to_10m" => 0,
               "from_3s_to_10s" => 0
             },
             "e2-standard-2" => %{
               "from_0s_to_3s" => 0,
               "from_10m_to_inf" => 0,
               "from_10s_to_30s" => 0,
               "from_1m_to_3m" => 0,
               "from_30s_to_1m" => 0,
               "from_3m_to_10m" => 0,
               "from_3s_to_10s" => 0
             },
             "e2-standard-4" => %{
               "from_0s_to_3s" => 0,
               "from_10m_to_inf" => 0,
               "from_10s_to_30s" => 0,
               "from_1m_to_3m" => 0,
               "from_30s_to_1m" => 0,
               "from_3m_to_10m" => 0,
               "from_3s_to_10s" => 0
             }
           }
  end

  test "count_pending_jobs" do
    {:ok, _} = Support.Factories.Job.create(:pending)

    assert Monitor.count_pending_jobs() == 1
  end

  test "count_enqueued_jobs" do
    {:ok, _} = Support.Factories.Job.create(:enqueued)

    assert Monitor.count_enqueued_jobs() == 1
  end

  test "count_scheduled_jobs" do
    {:ok, _} = Support.Factories.Job.create(:scheduled, %{machine_type: "e1-standard-2"})
    {:ok, _} = Support.Factories.Job.create(:scheduled, %{machine_type: "e1-standard-2"})
    {:ok, _} = Support.Factories.Job.create(:scheduled, %{machine_type: "e1-standard-4"})
    {:ok, _} = Support.Factories.Job.create(:scheduled, %{machine_type: "e1-standard-4"})
    {:ok, _} = Support.Factories.Job.create(:scheduled, %{machine_type: "e1-standard-4"})
    {:ok, _} = Support.Factories.Job.create(:scheduled, %{machine_type: "e1-standard-8"})
    {:ok, _} = Support.Factories.Job.create(:scheduled, %{machine_type: "s1-local-testing"})

    assert Monitor.count_scheduled_jobs() == {
             [
               %{
                 machine_type: "e1-standard-2",
                 count: 2
               },
               %{
                 machine_type: "e1-standard-4",
                 count: 3
               },
               %{
                 machine_type: "e1-standard-8",
                 count: 1
               }
             ],
             1
           }
  end

  test "count_waiting_for_agent_jobs" do
    {:ok, _} = Support.Factories.Job.create(:"waiting-for-agent")
    {:ok, _} = Support.Factories.Job.create(:"waiting-for-agent")

    assert Monitor.count_waiting_for_agent_jobs() == 2
  end

  test "count_started_jobs" do
    {:ok, _} = Support.Factories.Job.create(:started)
    {:ok, _} = Support.Factories.Job.create(:started)
    {:ok, _} = Support.Factories.Job.create(:started, %{machine_type: "s1-local-testing"})

    assert Monitor.count_started_jobs() == {2, 1}
  end

  test "count_running_tasks" do
    {:ok, _} = Support.Factories.Task.create()

    assert Monitor.count_running_tasks() == 1
  end

  test "count_pending_job_stop_requests" do
    assert Monitor.count_pending_job_stop_requests() == 0
  end

  test "count_inconsistent_jobs" do
    alias Support.Factories.Job

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {:ok, _} = Job.create(:finished, %{result: nil, created_at: now})
    {:ok, _} = Job.create(:started, %{result: "stopped", created_at: now})

    assert Monitor.count_inconsistent_jobs() == 1
  end
end
