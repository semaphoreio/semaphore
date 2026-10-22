defmodule Zebra.Workers.Scheduler.SelectorEquivalenceTest do
  #
  # Compares Selector.select/1 against the previous selection algorithm, which
  # walked every enqueued job of the organization in priority order. The
  # bounded selection must produce exactly the same result on random data.
  #
  use Zebra.DataCase, async: false

  import Ecto.Query

  alias Support.StubbedProvider
  alias Zebra.Workers.Scheduler.{Org, Selector}
  alias Zebra.Workers.Scheduler.Selector.{Result, State}

  @machine_types [
    "e1-standard-2",
    "e1-standard-4",
    "e1-standard-8",
    "a1-standard-4",
    "a1-standard-8",
    "e1-windows-2",
    "s1-test"
  ]

  @os_images ["ubuntu1804", "ubuntu2204", "ubuntu1604", "macos-xcode14", ""]

  @priorities [nil, 10, 50, 50, 90]

  @iterations 150

  test "matches the previous selection algorithm on random organizations" do
    :rand.seed(:exsss, {1, 2, 3})

    configs = for _ <- 1..@iterations, into: %{}, do: {Ecto.UUID.generate(), random_config()}

    stub_providers(configs)

    results =
      Enum.map(configs, fn {org_id, config} ->
        seed_jobs(org_id, config)

        expected = reference_select(org_id)
        actual = Selector.select(org_id)

        assert actual == expected, """
        selection differs for config #{inspect(config, pretty: true)}

        expected: #{inspect(expected, pretty: true)}
        actual: #{inspect(actual, pretty: true)}
        """

        actual
      end)

    # make sure the random data exercises every outcome, mixed together
    scheduled = Enum.count(results, &(length(&1.for_scheduling) > 1))
    force_finished = Enum.count(results, &(&1.for_force_finish != []))
    no_capacity = Enum.count(results, fn r -> Enum.any?(r.no_capacity, &(elem(&1, 1) > 0)) end)

    all_three =
      Enum.count(results, fn r ->
        r.for_scheduling != [] and r.for_force_finish != [] and
          Enum.any?(r.no_capacity, &(elem(&1, 1) > 0))
      end)

    assert scheduled > 20
    assert force_finished > 20
    assert no_capacity > 20
    assert all_three > 5
  end

  defp random_config do
    %{
      suspended: :rand.uniform(15) == 1,
      total: Enum.random([0, 1, 2, 3, 5, 8, 20, 500]),
      quotas: %{
        "e1-standard-2" => Enum.random(0..6),
        "e1-standard-4" => Enum.random(0..6),
        "e1-standard-8" => Enum.random(0..3),
        "a1-standard-4" => Enum.random(0..4)
      },
      self_hosted: Enum.random([:disabled, 0, 2, 10]),
      enqueued: Enum.random([0, 1, 3, 10, 25, 40]),
      running: Enum.random([0, 1, 3, 6, 10])
    }
  end

  defp seed_jobs(org_id, config) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    base = Timex.shift(now, days: -2)
    spec = Zebra.Models.Job.encode_spec(Support.Factories.Job.spec())

    row = fn state, i ->
      %{
        id: Ecto.UUID.generate(),
        organization_id: org_id,
        project_id: Ecto.UUID.generate(),
        build_id: Ecto.UUID.generate(),
        index: 0,
        name: "job",
        spec: spec,
        aasm_state: state,
        machine_type: Enum.random(@machine_types),
        machine_os_image: Enum.random(@os_images),
        priority: Enum.random(@priorities),
        created_at: base,
        updated_at: base,
        # unique, so the order is fully determined by the old ORDER BY too
        enqueued_at: Timex.shift(base, seconds: i)
      }
    end

    running =
      if config.running > 0,
        do: for(i <- 1..config.running, do: row.(Enum.random(["scheduled", "started"]), i)),
        else: []

    enqueued =
      if config.enqueued > 0,
        do: for(i <- 1..config.enqueued, do: row.("enqueued", 100 + i)),
        else: []

    Zebra.LegacyRepo.insert_all(Zebra.Models.Job, running ++ enqueued)
  end

  defp stub_providers(configs) do
    alias Support.FakeServers.OrganizationApi, as: OrgApi

    GrpcMock.stub(OrgApi, :describe, fn req, _ ->
      InternalApi.Organization.DescribeResponse.new(
        status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
        organization:
          InternalApi.Organization.Organization.new(
            org_username: "testing-org",
            suspended: configs[req.org_id].suspended
          )
      )
    end)

    Mox.stub(Support.MockedProvider, :provide_machines, fn org_id, opts ->
      quotas = configs[org_id].quotas
      {:ok, machines} = StubbedProvider.provide_machines(opts)

      {:ok,
       Enum.map(machines, fn machine ->
         case Map.fetch(quotas, machine.type) do
           {:ok, quota} -> %{machine | quantity: quota}
           :error -> machine
         end
       end)}
    end)

    Mox.stub(Support.MockedProvider, :provide_features, fn org_id, opts ->
      config = configs[org_id]
      {:ok, features} = StubbedProvider.provide_features(org_id, opts)

      features =
        Enum.map(features, fn
          %FeatureProvider.Feature{type: "max_paralellism_in_org"} = feature ->
            %{feature | quantity: config.total}

          feature ->
            feature
        end)

      self_hosted =
        case config.self_hosted do
          :disabled -> StubbedProvider.feature("self_hosted_agents", [:hidden])
          n -> StubbedProvider.feature("self_hosted_agents", [:enabled, {:quantity, n}])
        end

      {:ok, [self_hosted | features]}
    end)
  end

  #
  # The previous algorithm, kept verbatim apart from the row lock.
  #

  defp reference_select(org_id) do
    jobs =
      Zebra.Models.Job
      |> where([j], j.aasm_state == "enqueued")
      |> where([j], j.organization_id == ^org_id)
      |> order_by([j], fragment("? DESC NULLS LAST, ? ASC", j.priority, j.enqueued_at))
      |> select([j], [:id, :machine_type, :machine_os_image])
      |> Zebra.LegacyRepo.all()

    {:ok, org} = Org.load(org_id)
    state = State.initialize_from_db(org_id)
    result = Result.new(org)

    reference_select(jobs, org, state, result) |> Result.finalize()
  end

  defp reference_select([], _, _, result), do: result

  defp reference_select(jobs = [job | rest], org, state, result) do
    running_jobs_for_machine_type = State.running_jobs(state, job.machine_type)
    machine_quota = Selector.get_machine_quota_for_job(job, org.id)
    org_id = org.id

    cond do
      Org.max_running_jobs(org_id) == 0 ->
        Result.add_for_force_finish(result, Enum.map(jobs, fn j -> j.id end))

      org.suspended == true ->
        Result.add_for_force_finish(result, Enum.map(jobs, fn j -> j.id end))

      machine_quota == 0 ->
        result = Result.add_for_force_finish(result, job.id)
        reference_select(rest, org, state, result)

      State.running_jobs(state, :all) >= Org.max_running_jobs(org_id) ->
        result = Result.add_no_capacity(result, job.machine_type)
        reference_select(rest, org, state, result)

      running_jobs_for_machine_type < machine_quota ->
        state = State.record(state, job)
        result = Result.add_for_scheduling(result, job.id)
        reference_select(rest, org, state, result)

      running_jobs_for_machine_type >= machine_quota ->
        result = Result.add_no_capacity(result, job.machine_type)
        reference_select(rest, org, state, result)
    end
  end
end
