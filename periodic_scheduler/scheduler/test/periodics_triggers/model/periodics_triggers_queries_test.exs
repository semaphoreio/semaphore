defmodule Scheduler.PeriodicsTriggers.Model.PeriodicsTriggersQueries.Test do
  use ExUnit.Case

  alias Scheduler.Periodics.Model.PeriodicsQueries
  alias Scheduler.PeriodicsTriggers.Model.PeriodicsTriggersQueries

  setup do
    Test.Helpers.truncate_db()

    assert {:ok, periodic} = periodic_params() |> PeriodicsQueries.insert()
    {:ok, %{periodic: periodic}}
  end

  defp periodic_params() do
    %{
      requester_id: "usr_1",
      organization_id: "org_1",
      name: "Periodic_1",
      project_name: "Project_1",
      project_id: "pr1",
      branch: "master",
      at: "* * * * *",
      pipeline_file: "deploy.yml",
      parameters: [
        %{name: "p1", default_value: "v1", required: true},
        %{name: "p2", default_value: "v2", required: true},
        %{name: "p3", required: false, default_value: nil}
      ]
    }
  end

  test "insert new periodics_trigger", ctx do
    ts_before = DateTime.utc_now()

    assert {:ok, ptr} = PeriodicsTriggersQueries.insert(ctx.periodic)

    assert ptr.project_id == ctx.periodic.project_id
    assert ptr.branch == ctx.periodic.branch
    assert ptr.pipeline_file == ctx.periodic.pipeline_file
    assert DateTime.compare(ts_before, ptr.triggered_at) == :lt
    assert ptr.scheduling_status == "running"

    assert ptr.branch == "master"
    assert ptr.pipeline_file == "deploy.yml"
    assert ptr.recurring
    refute ptr.run_now_requester_id

    assert %{"p1" => "v1", "p2" => "v2"} ==
             Map.new(ptr.parameter_values, &{&1.name, &1.value})
  end

  test "insert new periodics_trigger from run now", ctx do
    Test.Helpers.truncate_db()

    assert {:ok, periodic} =
             periodic_params()
             |> Map.drop([:at])
             |> Map.put(:recurring, false)
             |> PeriodicsQueries.insert()

    ts_before = DateTime.utc_now()

    assert {:ok, ptr} =
             PeriodicsTriggersQueries.insert(periodic, %{
               parameter_values: [
                 %{name: "p1", value: "v11"},
                 %{name: "p2", value: "v22"},
                 %{name: "p3", value: "v33"}
               ],
               requester: "some_requester",
               pipeline_file: "cicd.yml",
               branch: "develop"
             })

    assert ptr.project_id == ctx.periodic.project_id
    assert DateTime.compare(ts_before, ptr.triggered_at) == :lt
    assert ptr.scheduling_status == "running"

    assert ptr.branch == "develop"
    assert ptr.pipeline_file == "cicd.yml"
    assert ptr.run_now_requester_id == "some_requester"
    refute ptr.recurring

    assert %{"p1" => "v11", "p2" => "v22", "p3" => "v33"} ==
             Map.new(ptr.parameter_values, &{&1.name, &1.value})
  end

  test "update periodic_trigger with scheduling results", ctx do
    assert {:ok, ptr} = PeriodicsTriggersQueries.insert(ctx.periodic)

    ts_before = DateTime.utc_now()
    params = %{scheduling_status: "passed", scheduled_workflow_id: UUID.uuid4()}

    assert {:ok, ptr_u} = PeriodicsTriggersQueries.update(ptr, params)

    assert ptr_u.project_id == ptr.project_id
    assert ptr_u.branch == ptr.branch
    assert ptr_u.pipeline_file == ptr.pipeline_file
    assert ptr_u.triggered_at == ptr.triggered_at
    assert ptr_u.scheduling_status == "passed"
    assert ptr_u.scheduled_workflow_id == params.scheduled_workflow_id
    assert DateTime.compare(ts_before, ptr_u.scheduled_at) == :lt
  end

  test "get_latest_triggers returns valid results", ctx do
    # first periodic (the one from context) with 3 triggers

    assert {:ok, ptr_1_1} = PeriodicsTriggersQueries.insert(ctx.periodic)
    params = %{scheduling_status: "passed", scheduled_workflow_id: "1"}
    assert {:ok, _ptr_1_1} = PeriodicsTriggersQueries.update(ptr_1_1, params)

    assert {:ok, ptr_1_2} = PeriodicsTriggersQueries.insert(ctx.periodic)
    params = %{scheduling_status: "passed", scheduled_workflow_id: "2"}
    assert {:ok, _ptr_1_2} = PeriodicsTriggersQueries.update(ptr_1_2, params)

    assert {:ok, ptr_1_3} = PeriodicsTriggersQueries.insert(ctx.periodic)
    params = %{scheduling_status: "passed", scheduled_workflow_id: "3"}
    assert {:ok, _ptr_1_3} = PeriodicsTriggersQueries.update(ptr_1_3, params)

    # second periodic with 1 trigger

    assert {:ok, p2} = periodic_params() |> Map.put(:name, "P2") |> PeriodicsQueries.insert()

    assert {:ok, ptr_2_1} = PeriodicsTriggersQueries.insert(p2)
    params = %{scheduling_status: "passed", scheduled_workflow_id: "1"}
    assert {:ok, _ptr_2_1} = PeriodicsTriggersQueries.update(ptr_2_1, params)

    # third periodic - no triggers

    assert {:ok, p3} = periodic_params() |> Map.put(:name, "P3") |> PeriodicsQueries.insert()

    # fourth periodic with 1 trigger, not included in request list

    assert {:ok, p4} = periodic_params() |> Map.put(:name, "P4") |> PeriodicsQueries.insert()

    assert {:ok, ptr_4_1} = PeriodicsTriggersQueries.insert(p4)
    params = %{scheduling_status: "passed", scheduled_workflow_id: "1"}
    assert {:ok, _ptr_4_1} = PeriodicsTriggersQueries.update(ptr_4_1, params)

    # test get_latest_triggers when given first three periodics ids

    ids = [ctx.periodic.id, p2.id, p3.id]

    assert {:ok, list} = PeriodicsTriggersQueries.get_latest_triggers(ids)
    assert length(list) == 2

    assert p1_latest_trigger =
             Enum.find(list, fn elem -> elem["periodic_id"] == ctx.periodic.id end)

    assert p1_latest_trigger["scheduled_workflow_id"] == "3"

    assert p2_latest_trigger = Enum.find(list, fn elem -> elem["periodic_id"] == p2.id end)
    assert p2_latest_trigger["scheduled_workflow_id"] == "1"

    # non-existing periodic in request => empty result list

    assert {:ok, []} == PeriodicsTriggersQueries.get_latest_triggers([UUID.uuid4()])
  end

  test "get all periodic_triggers for periodic with given id", ctx do
    assert {:ok, ptr_1} = PeriodicsTriggersQueries.insert(ctx.periodic)
    assert {:ok, ptr_2} = PeriodicsTriggersQueries.insert(ctx.periodic)

    assert {:ok, resp} = PeriodicsTriggersQueries.get_all_by_periodic_id(ctx.periodic.id)
    assert resp == [ptr_2, ptr_1]
  end
end
