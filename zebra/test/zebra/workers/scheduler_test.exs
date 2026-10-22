# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule Zebra.Workers.SchedulerTest do
  use Zebra.DataCase, async: false

  import Mox
  setup :set_mox_global

  def create_job(org_id, state, machine_type \\ "e1-standard-2") do
    alias Support.Factories.Job, as: FJ

    # hack to make sure that job timestamps are linearly increasing, and
    # sorting is predictable in tests
    job_count = Zebra.LegacyRepo.aggregate(Zebra.Models.Job, :count, :id)
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    time = now |> Timex.shift(days: -2)
    time = time |> Timex.shift(minutes: job_count)

    {:ok, _} =
      FJ.create(state, %{
        organization_id: org_id,
        machine_type: machine_type,
        enqueued_at: time
      })
  end

  test "scheduler" do
    org1_id = Ecto.UUID.generate()
    org2_id = Ecto.UUID.generate()

    stub_quotas(%{
      org1_id => [total: 3, e2: 3, e4: 2, e8: 0, a4: 8, a8: 0],
      org2_id => [total: 500, e2: 1, e4: 2, e8: 0, a4: 8, a8: 0]
    })

    # two jobs running in first org, quota allows for one more
    {:ok, j1} = create_job(org1_id, :started)
    {:ok, j2} = create_job(org1_id, :scheduled)
    {:ok, j3} = create_job(org1_id, :enqueued)
    {:ok, j4} = create_job(org1_id, :enqueued)

    # two jobs running in first org, quota allows for no more
    {:ok, j5} = create_job(org2_id, :started)
    {:ok, j6} = create_job(org2_id, :scheduled)
    {:ok, j7} = create_job(org2_id, :enqueued)

    Zebra.Workers.Scheduler.tick()

    assert Zebra.Models.Job.reload(j1).aasm_state == "started"
    assert Zebra.Models.Job.reload(j2).aasm_state == "scheduled"
    # transition!
    assert Zebra.Models.Job.reload(j3).aasm_state == "scheduled"
    # no room
    assert Zebra.Models.Job.reload(j4).aasm_state == "enqueued"

    assert Zebra.Models.Job.reload(j5).aasm_state == "started"
    assert Zebra.Models.Job.reload(j6).aasm_state == "scheduled"
    # no room
    assert Zebra.Models.Job.reload(j7).aasm_state == "enqueued"
  end

  test "calling the scheduler for a specific org" do
    org1_id = Ecto.UUID.generate()

    stub_quotas(%{
      org1_id => [total: 3, e2: 3, e4: 2, e8: 0, a4: 8, a8: 0]
    })

    # two jobs running in first org, quota allows for one more
    {:ok, j1} = create_job(org1_id, :started)
    {:ok, j2} = create_job(org1_id, :scheduled)
    {:ok, j3} = create_job(org1_id, :enqueued)
    {:ok, j4} = create_job(org1_id, :enqueued)

    Zebra.Workers.Scheduler.lock_and_process_async(org1_id)

    :timer.sleep(500)

    assert Zebra.Models.Job.reload(j1).aasm_state == "started"
    assert Zebra.Models.Job.reload(j2).aasm_state == "scheduled"
    # transition!
    assert Zebra.Models.Job.reload(j3).aasm_state == "scheduled"
    # no room
    assert Zebra.Models.Job.reload(j4).aasm_state == "enqueued"
  end

  describe "concurrent scheduling requests" do
    test "never schedule more jobs than the quota allows" do
      org_id = Ecto.UUID.generate()
      stub_quotas(%{org_id => [total: 3, e2: 10, e4: 2, e8: 0, a4: 8, a8: 0]})

      jobs = for _ <- 1..10, do: elem(create_job(org_id, :enqueued), 1)

      for _ <- 1..20, do: Zebra.Workers.Scheduler.lock_and_process_async(org_id)

      1..20
      |> Enum.map(fn i ->
        mode = if rem(i, 2) == 0, do: :try, else: {:wait, 2_000}
        Task.async(fn -> Zebra.Workers.Scheduler.lock_and_process(org_id, mode) end)
      end)
      |> Enum.each(&Task.await(&1, 10_000))

      :timer.sleep(1_000)

      states = jobs |> Enum.map(&Zebra.Models.Job.reload(&1).aasm_state) |> Enum.frequencies()
      assert states == %{"scheduled" => 3, "enqueued" => 7}

      # the three oldest
      assert jobs
             |> Enum.take(3)
             |> Enum.all?(&(Zebra.Models.Job.reload(&1).aasm_state == "scheduled"))
    end

    test "a request while another pass holds the lock is not lost" do
      org_id = Ecto.UUID.generate()
      stub_quotas(%{org_id => [total: 3, e2: 3, e4: 2, e8: 0, a4: 8, a8: 0]})

      holder = hold_scheduling_lock(org_id)

      {:ok, job} = create_job(org_id, :enqueued)
      Zebra.Workers.Scheduler.lock_and_process_async(org_id)

      # the first attempt loses the lock and waits for it
      :timer.sleep(400)
      assert Zebra.Models.Job.reload(job).aasm_state == "enqueued"

      release_scheduling_lock(holder)

      assert eventually(fn -> Zebra.Models.Job.reload(job).aasm_state == "scheduled" end)
    end

    test "waiting for the lock gives up after the timeout" do
      org_id = Ecto.UUID.generate()
      stub_quotas(%{org_id => [total: 3, e2: 3, e4: 2, e8: 0, a4: 8, a8: 0]})

      holder = hold_scheduling_lock(org_id)
      {:ok, job} = create_job(org_id, :enqueued)

      assert {:error, :lock_timeout} ==
               Zebra.Workers.Scheduler.lock_and_process(org_id, {:wait, 200})

      assert Zebra.Models.Job.reload(job).aasm_state == "enqueued"

      release_scheduling_lock(holder)
    end

    test "waiting for a free lock schedules right away" do
      org_id = Ecto.UUID.generate()
      stub_quotas(%{org_id => [total: 3, e2: 3, e4: 2, e8: 0, a4: 8, a8: 0]})

      {:ok, job} = create_job(org_id, :enqueued)

      assert {:ok, {:lock_obtained, _}} =
               Zebra.Workers.Scheduler.lock_and_process(org_id, {:wait, 200})

      assert Zebra.Models.Job.reload(job).aasm_state == "scheduled"
    end

    test "without a running trigger, requests still schedule" do
      org_id = Ecto.UUID.generate()
      stub_quotas(%{org_id => [total: 3, e2: 3, e4: 2, e8: 0, a4: 8, a8: 0]})

      {:ok, job} = create_job(org_id, :enqueued)

      Zebra.Workers.Scheduler.Trigger.request(org_id, :no_trigger_running_here)

      assert eventually(fn -> Zebra.Models.Job.reload(job).aasm_state == "scheduled" end)
    end
  end

  # Holds the organization's scheduling lock in another transaction, like a
  # pass running in another node.
  defp hold_scheduling_lock(org_id) do
    test = self()

    holder =
      spawn(fn ->
        Zebra.LegacyRepo.transaction(fn ->
          Zebra.LegacyRepo.query!("SELECT pg_advisory_xact_lock(#{:erlang.crc32(org_id)})")
          send(test, :lock_held)

          receive do
            :release -> :ok
          after
            10_000 -> :ok
          end
        end)

        send(test, :lock_released)
      end)

    assert_receive :lock_held, 5_000
    holder
  end

  defp release_scheduling_lock(holder) do
    send(holder, :release)
    assert_receive :lock_released, 5_000
  end

  defp eventually(fun, attempts \\ 50) do
    cond do
      fun.() -> true
      attempts == 0 -> false
      true -> :timer.sleep(50) && eventually(fun, attempts - 1)
    end
  end

  def stub_quotas(org_quotas) do
    alias Support.FakeServers.OrganizationApi, as: OrgApi

    GrpcMock.stub(OrgApi, :describe, fn _req, _ ->
      InternalApi.Organization.DescribeResponse.new(
        status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
        organization: InternalApi.Organization.Organization.new(org_username: "testing-org")
      )
    end)

    Mox.stub(Support.MockedProvider, :provide_machines, fn org_id, opts ->
      quota = org_quotas[org_id]

      machines =
        Support.StubbedProvider.provide_machines(opts)
        |> case do
          {:ok, machines} -> machines
          {:error, _} -> []
        end
        |> Enum.map(fn
          %FeatureProvider.Machine{type: "e1-standard-2"} = machine ->
            %{machine | quantity: quota[:e2]}

          %FeatureProvider.Machine{type: "e1-standard-4"} = machine ->
            %{machine | quantity: quota[:e4]}

          %FeatureProvider.Machine{type: "e1-standard-8"} = machine ->
            %{machine | quantity: quota[:e8]}

          %FeatureProvider.Machine{type: "a1-standard-4"} = machine ->
            %{machine | quantity: quota[:a4]}

          %FeatureProvider.Machine{type: "a1-standard-8"} = machine ->
            %{machine | quantity: quota[:a8]}

          machine ->
            machine
        end)

      {:ok, machines}
    end)

    Mox.stub(Support.MockedProvider, :provide_features, fn org_id, opts ->
      quota = org_quotas[org_id]

      features =
        Support.StubbedProvider.provide_features(org_id, opts)
        |> case do
          {:ok, features} -> features
          {:error, _} -> []
        end
        |> Enum.map(fn
          %FeatureProvider.Feature{type: "max_paralellism_in_org"} = feature ->
            %{feature | quantity: quota[:total]}

          feature ->
            feature
        end)

      {:ok, features}
    end)
  end
end
