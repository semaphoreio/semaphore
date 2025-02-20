# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule Zebra.Workers.Scheduler.SelectorTest do
  use Zebra.DataCase
  alias Zebra.Workers.Scheduler.Selector

  describe ".select" do
    @org_id Ecto.UUID.generate()
    alias Support.Factories.Job, as: FJ

    def create_job(
          state,
          machine_type \\ "e1-standard-2",
          priority \\ nil,
          machine_os_image \\ "ubuntu1804"
        ) do
      # hack to make sure that job timestamps are linearly increasing, and
      # sorting is predictable in tests
      job_count = Zebra.LegacyRepo.aggregate(Zebra.Models.Job, :count, :id)
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      time = now |> Timex.shift(days: -2)
      time = time |> Timex.shift(minutes: job_count)

      params = %{
        organization_id: @org_id,
        machine_type: machine_type,
        enqueued_at: time,
        machine_os_image: machine_os_image
      }

      params = if is_nil(priority), do: params, else: Map.put(params, :priority, priority)

      {:ok, _} = FJ.create(state, params)
    end

    test "when the max_job_quota is 0 => it returns all jobs for force finish" do
      stub_org_call(total: 0, e2: 2, e4: 2, e8: 0, a4: 8, a8: 0)

      {:ok, j1} = create_job(:enqueued)
      {:ok, j2} = create_job(:enqueued)

      result = Selector.select(@org_id)

      assert result.for_scheduling == []
      assert result.for_force_finish == [j1.id, j2.id]
    end

    test "when the organization is running jobs on unknown machine type => force finish the job" do
      stub_org_call(total: 2, e2: 2, e4: 0, e8: 0, a4: 0, a8: 0)

      Mox.stub(Support.MockedProvider, :provide_machines, fn _, _ ->
        machine =
          Support.StubbedProvider.machine("e1-standard-2", [:enabled, {:quantity, 2}, :linux])

        machines = [%{machine | available_os_images: ["ubuntu2004", "ubuntu2204"]}]

        {:ok, machines}
      end)

      {:ok, j1} = create_job(:enqueued, "e1-standard-2", nil, "ubuntu2204")
      {:ok, j2} = create_job(:enqueued, "e1-standard-2", nil, "ubuntu1804")

      result = Selector.select(@org_id)

      assert result.for_scheduling == [j1.id]
      assert result.for_force_finish == [j2.id]
    end

    test "when the organization is suspended => it returns all jobs for force finish" do
      stub_suspended_org()

      {:ok, j1} = create_job(:enqueued)
      {:ok, j2} = create_job(:enqueued)

      result = Selector.select(@org_id)

      assert result.for_scheduling == []
      assert result.for_force_finish == [j1.id, j2.id]
    end

    test "when a job has machine type quota of 0 => it sets it for force finish" do
      stub_org_call(total: 10, e2: 0, e4: 2, e8: 0, a4: 8, a8: 0)

      {:ok, j1} = create_job(:enqueued)
      {:ok, j2} = create_job(:enqueued)

      result = Selector.select(@org_id)

      assert result.for_scheduling == []
      assert result.for_force_finish == [j1.id, j2.id]
    end

    test "selects jobs upto the max_parallel_job limit" do
      stub_org_call(total: 1, e2: 1000, e4: 1000, e8: 1000, a4: 1000, a8: 0)

      assert Zebra.LegacyRepo.aggregate(Zebra.Models.Job, :count, :id) == 0

      {:ok, j1} = create_job(:enqueued)
      {:ok, _} = create_job(:enqueued)

      result = Selector.select(@org_id)

      assert result.for_scheduling == [j1.id]
      assert result.no_capacity["e1-standard-2"] == 1
      assert result.for_force_finish == []
    end

    test "selects jobs upto the machine type limits" do
      stub_org_call(total: 100, e2: 2, e4: 1, e8: 1000, a4: 1000, a8: 0)

      {:ok, j1} = create_job(:enqueued)
      {:ok, j2} = create_job(:enqueued)
      {:ok, _} = create_job(:enqueued)

      result = Selector.select(@org_id)

      assert result.for_scheduling == [j1.id, j2.id]
      assert result.no_capacity["e1-standard-2"] == 1
      assert result.for_force_finish == []
    end

    test "combined max_limit and machine limits" do
      stub_org_call(total: 3, e2: 2, e4: 2, e8: 1000, a4: 1000, a8: 0)

      {:ok, j1} = create_job(:enqueued, "e1-standard-2")
      {:ok, j2} = create_job(:enqueued, "e1-standard-2")
      # won't fit
      {:ok, _} = create_job(:enqueued, "e1-standard-2")
      {:ok, j4} = create_job(:enqueued, "e1-standard-4")
      # won't fit
      {:ok, _} = create_job(:enqueued, "e1-standard-4")
      # won't fit
      {:ok, _} = create_job(:enqueued, "e1-standard-4")

      result = Selector.select(@org_id)

      assert result.for_scheduling == [j1.id, j2.id, j4.id]
      assert result.no_capacity["e1-standard-2"] == 1
      assert result.no_capacity["e1-standard-4"] == 2
      assert result.for_force_finish == []
    end

    test "unknown machine types immidiately fail" do
      stub_org_call(total: 1, e2: 1, e4: 1, e8: 1, a4: 1, a8: 0)

      {:ok, j1} = create_job(:enqueued, "e1-standard-2")
      {:ok, j2} = create_job(:enqueued, "e1-windows-2")

      result = Selector.select(@org_id)

      assert result.for_scheduling == [j1.id]
      assert result.for_force_finish == [j2.id]
    end

    test "combined running jobs and max_running_jobs" do
      stub_org_call(total: 3, e2: 100, e4: 1, e8: 1, a4: 1, a8: 0)

      {:ok, j1} = create_job(:enqueued, "e1-standard-2")
      # won't fit
      {:ok, _} = create_job(:enqueued, "e1-standard-2")

      {:ok, _} = create_job(:scheduled, "e1-standard-2")
      {:ok, _} = create_job(:started, "e1-standard-2")

      result = Selector.select(@org_id)

      assert result.for_scheduling == [j1.id]
      assert result.for_force_finish == []
    end

    test "combined running jobs and machine quota" do
      stub_org_call(total: 100, e2: 3, e4: 1, e8: 1, a4: 1, a8: 0)

      {:ok, j1} = create_job(:enqueued, "e1-standard-2")
      # won't fit
      {:ok, _} = create_job(:enqueued, "e1-standard-2")

      {:ok, _} = create_job(:scheduled, "e1-standard-2")
      {:ok, _} = create_job(:started, "e1-standard-2")

      result = Selector.select(@org_id)

      assert result.for_scheduling == [j1.id]
      assert result.for_force_finish == []
    end

    test "scheduling every type of machine" do
      stub_org_call(total: 100, e2: 1, e4: 1, e8: 1, a4: 1, a8: 0)

      {:ok, j1} = create_job(:enqueued, "e1-standard-2")
      # won't fit
      {:ok, _} = create_job(:enqueued, "e1-standard-2")

      {:ok, j2} = create_job(:enqueued, "e1-standard-4")
      # won't fit
      {:ok, _} = create_job(:enqueued, "e1-standard-4")

      {:ok, j3} = create_job(:enqueued, "e1-standard-8")
      # won't fit
      {:ok, _} = create_job(:enqueued, "e1-standard-4")

      # machine is hidden
      {:ok, j4} = create_job(:enqueued, "a1-standard-8")

      result = Selector.select(@org_id)

      assert result.for_scheduling == [j1.id, j2.id, j3.id]
      assert result.for_force_finish == [j4.id]
    end

    test "when there are jobs with different priorities => higher priority jobs are selected" do
      stub_org_call(total: 100, e2: 2, e4: 1, e8: 1, a4: 1, a8: 0)

      {:ok, _} = create_job(:enqueued, "e1-standard-2", 30)

      # will be selected
      {:ok, j2} = create_job(:enqueued, "e1-standard-2", 45)

      {:ok, j3} = create_job(:enqueued, "e1-standard-2", 60)

      result = Selector.select(@org_id)

      assert result.for_scheduling == [j3.id, j2.id]
      assert result.no_capacity["e1-standard-2"] == 1
      assert result.for_force_finish == []
    end

    test "when jobs have same priority => the older ones are selected first " do
      stub_org_call(total: 100, e2: 1, e4: 1, e8: 1, a4: 1, a8: 0)

      {:ok, _} = create_job(:enqueued, "e1-standard-2", 30)

      # will be selected
      {:ok, j2} = create_job(:enqueued, "e1-standard-2", 50)

      # won't fit
      {:ok, _} = create_job(:enqueued, "e1-standard-2", 50)

      result = Selector.select(@org_id)

      assert result.for_scheduling == [j2.id]
      assert result.no_capacity["e1-standard-2"] == 2
      assert result.for_force_finish == []
    end

    test "jobs that have no priority set are selected last" do
      stub_org_call(total: 100, e2: 2, e4: 1, e8: 1, a4: 1, a8: 0)

      # will be selected
      {:ok, j1} = create_job(:enqueued, "e1-standard-2", nil)

      # will be selected
      {:ok, j2} = create_job(:enqueued, "e1-standard-2", 5)

      # won't fit
      {:ok, _} = create_job(:enqueued, "e1-standard-2", nil)

      result = Selector.select(@org_id)

      assert result.for_scheduling == [j2.id, j1.id]
      assert result.no_capacity["e1-standard-2"] == 1
      assert result.for_force_finish == []
    end
  end

  describe "selection State" do
    @org_id Ecto.UUID.generate()
    alias Support.Factories.Job, as: FJ

    def load do
      {:ok, _} = FJ.create(:pending, %{organization_id: @org_id})
      {:ok, _} = FJ.create(:enqueued, %{organization_id: @org_id})
      {:ok, _} = FJ.create(:enqueued, %{organization_id: @org_id})
      {:ok, _} = FJ.create(:scheduled, %{organization_id: @org_id})
      {:ok, _} = FJ.create(:started, %{organization_id: @org_id})

      {:ok, _} =
        FJ.create(:started, %{
          organization_id: @org_id,
          machine_type: "e1-standard-4"
        })

      {:ok, _} = FJ.create(:finished, %{organization_id: @org_id})

      Selector.State.initialize_from_db(@org_id)
    end

    test "loading state from DB" do
      state = load()

      assert Selector.State.running_jobs(state, :all) == 3
      assert Selector.State.running_jobs(state, "e1-standard-2") == 2
      assert Selector.State.running_jobs(state, "e1-standard-4") == 1
    end

    test "getting currently known running jobs count" do
      state = load()

      assert Selector.State.running_jobs(state, :all) == 3
    end

    test "getting currently known running jobs with machine type count" do
      state = load()

      assert Selector.State.running_jobs(state, "e1-standard-2") == 2
      assert Selector.State.running_jobs(state, "e1-windows-lol") == 0
    end

    test "recording a job as running" do
      state = load()

      # verifying state before recording
      assert Selector.State.running_jobs(state, :all) == 3
      assert Selector.State.running_jobs(state, "e1-standard-2") == 2
      assert Selector.State.running_jobs(state, "e1-standard-4") == 1

      {:ok, job} = FJ.create(:enqueued, %{organization_id: @org_id})
      state = Selector.State.record(state, job)

      # verifying state after recording
      assert Selector.State.running_jobs(state, :all) == 4
      assert Selector.State.running_jobs(state, "e1-standard-2") == 3
      assert Selector.State.running_jobs(state, "e1-standard-4") == 1
    end
  end

  describe "selection Result" do
    test "initialization" do
      res = Selector.Result.new(%{id: Ecto.UUID.generate(), username: "test-org"})

      assert res.for_scheduling == []
      assert res.for_force_finish == []
    end

    test "adding a job for scheduling" do
      res = Selector.Result.new(%{id: Ecto.UUID.generate(), username: "test-org"})

      job1_id = Ecto.UUID.generate()
      job2_id = Ecto.UUID.generate()

      res = Selector.Result.add_for_scheduling(res, job1_id)
      res = Selector.Result.add_for_scheduling(res, job2_id)

      assert res.for_scheduling == [job1_id, job2_id]
      assert res.for_force_finish == []
    end

    test "adding a job for force finish" do
      res = Selector.Result.new(%{id: Ecto.UUID.generate(), username: "test-org"})

      job1_id = Ecto.UUID.generate()
      job2_id = Ecto.UUID.generate()

      res = Selector.Result.add_for_force_finish(res, job1_id)
      res = Selector.Result.add_for_force_finish(res, job2_id)

      assert res.for_scheduling == []
      assert res.for_force_finish == [job1_id, job2_id]
    end
  end

  describe "organization Quota" do
    alias Zebra.Workers.Scheduler.Org

    test "cold load" do
      org_id = Ecto.UUID.generate()
      stub_org_call(total: 6, e2: 3, e4: 3, e8: 1, a4: 9, a8: 0)

      assert {:ok, _} = Org.load(org_id)
    end

    test "cold load - failures on feature service" do
      org_id = Ecto.UUID.generate()
      stub_org_call(total: 5, e2: 2, e4: 2, e8: 0, a4: 8, a8: 0)
      stub_features_with_failure()

      assert {:ok, _} = Org.load(org_id)
    end

    test "hot load" do
      org_id = Ecto.UUID.generate()
      stub_org_call(total: 6, e2: 3, e4: 3, e8: 1, a4: 9, a8: 0)

      # first time it gets loaded, it gets cached
      assert {:ok, _} = Org.load(org_id)

      # now, even if we stub a failure, it will not take effect
      stub_quotas_with_failure()
      stub_features_with_failure()

      # reads from cache
      assert {:ok, _} = Org.load(org_id)
    end

    test "failures are not cached" do
      org_id = Ecto.UUID.generate()
      stub_quotas_with_failure()
      stub_features_with_failure()

      # first time it gets loaded, it returns error, and does not cache
      assert {:error, _} = Org.load(org_id)

      stub_org_call(total: 6, e2: 3, e4: 3, e8: 1, a4: 9, a8: 0)

      # because the previous was a failure, we didn't cache.
      assert {:ok, _} = Org.load(org_id)
    end

    test "getting max_running_jobs quota" do
      org_id = Ecto.UUID.generate()
      stub_org_call("semaphore", total: 6, e2: 3, e4: 3, e8: 1, a4: 9, a8: 0)

      assert {:ok, _} = Org.load(org_id)

      assert Org.max_running_jobs(org_id) == 6
    end

    test "getting machine_quota for known machine type" do
      org_id = Ecto.UUID.generate()
      stub_org_call(org_id, total: 6, e2: 3, e4: 3, e8: 1, a4: 9, a8: 0)

      assert Org.machine_quota(org_id, "e1-standard-2") == 3
      assert Org.machine_quota(org_id, "e1-standard-4") == 3
      assert Org.machine_quota(org_id, "e1-standard-8") == 1
      assert Org.machine_quota(org_id, "a1-standard-4") == 9
      assert Org.machine_quota(org_id, "a1-standard-8") == 0
    end

    test "getting machine_quota for unknown machine type" do
      org_id = Ecto.UUID.generate()
      stub_org_call("semaphore", total: 6, e2: 3, e4: 3, e8: 1, a4: 9, a8: 0)

      assert {:ok, _org} = Org.load(org_id)

      assert Org.machine_quota(org_id, "w1-windows-2") == 0
    end
  end

  def stub_org_call(name \\ "testing-org", total: total, e2: e2, e4: e4, e8: e8, a4: a4, a8: a8) do
    alias Support.FakeServers.OrganizationApi, as: OrgApi

    GrpcMock.stub(OrgApi, :describe, fn _, _ ->
      InternalApi.Organization.DescribeResponse.new(
        status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
        organization: InternalApi.Organization.Organization.new(org_username: name)
      )
    end)

    alias Support.FakeServers.FeatureApi, as: Api

    Mox.stub(Support.MockedProvider, :provide_machines, fn _, _ ->
      machines =
        Support.StubbedProvider.provide_machines()
        |> case do
          {:ok, machines} -> machines
          {:error, _} -> []
        end
        |> Enum.map(fn
          %FeatureProvider.Machine{type: "e1-standard-2"} = machine ->
            %{machine | quantity: e2}

          %FeatureProvider.Machine{type: "e1-standard-4"} = machine ->
            %{machine | quantity: e4}

          %FeatureProvider.Machine{type: "e1-standard-8"} = machine ->
            %{machine | quantity: e8}

          %FeatureProvider.Machine{type: "a1-standard-4"} = machine ->
            %{machine | quantity: a4}

          %FeatureProvider.Machine{type: "a1-standard-8"} = machine ->
            %{machine | quantity: a8}

          machine ->
            machine
        end)

      {:ok, machines}
    end)

    Mox.stub(Support.MockedProvider, :provide_features, fn _, _ ->
      features =
        Support.StubbedProvider.provide_features()
        |> case do
          {:ok, features} -> features
          {:error, _} -> []
        end
        |> Enum.map(fn
          %FeatureProvider.Feature{type: "max_paralellism_in_org"} = feature ->
            %{feature | quantity: total}

          feature ->
            feature
        end)

      {:ok, features}
    end)
  end

  def stub_suspended_org do
    alias Support.FakeServers.OrganizationApi, as: OrgApi

    GrpcMock.stub(OrgApi, :describe, fn _, _ ->
      InternalApi.Organization.DescribeResponse.new(
        status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
        organization:
          InternalApi.Organization.Organization.new(
            org_username: "testing-org",
            suspended: true
          )
      )
    end)
  end

  def stub_quotas_with_failure do
    alias Support.FakeServers.OrganizationApi, as: OrgApi

    GrpcMock.stub(OrgApi, :describe, fn _, _ ->
      raise "Fail"
    end)
  end

  def stub_features_with_failure do
    alias Support.FakeServers.FeatureApi, as: Api

    GrpcMock.stub(Api, :list_organization_machines, fn _req, _ ->
      raise "Fail"
    end)

    GrpcMock.stub(Api, :list_organization_features, fn _req, _ ->
      raise "Fail"
    end)
  end
end
