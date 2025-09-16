defmodule Test.Actions.PersistImpl.Test do
  use ExUnit.Case

  alias Scheduler.Actions.PersistImpl
  alias Scheduler.Workers.QuantumScheduler
  alias InternalApi.PeriodicScheduler, as: API
  alias API.Periodic.Parameter

  setup do
    Test.Helpers.truncate_db()
    params = Test.Helpers.seed_front_db()

    start_supervised!(QuantumScheduler)

    {:ok, params}
  end

  test "perist doesn't start quantum job when periodic is non-recurring", ctx do
    request =
      API.PersistRequest.new(
        name: "test periodic",
        description: "test periodic desc",
        recurring: false,
        organization_id: ctx.org_id,
        project_id: ctx.pr_id,
        requester_id: ctx.usr_id,
        reference: "master",
        pipeline_file: ".semaphore/cron.yml",
        at: "",
        parameters: [
          Parameter.new(
            name: "example",
            description: "Exemplary parameter",
            required: true,
            default_value: "option1",
            options: ["option1", "option2", "option3"]
          )
        ]
      )

    assert {:ok, periodic} = PersistImpl.persist(request)

    assert periodic.name == "test periodic"
    assert periodic.description == "test periodic desc"
    assert periodic.recurring == false
    assert periodic.organization_id == ctx.org_id
    assert periodic.project_name == "Project 1"
    assert periodic.project_id == ctx.pr_id
    assert periodic.requester_id == ctx.usr_id
    assert periodic.reference == "master"
    assert periodic.pipeline_file == ".semaphore/cron.yml"
    refute periodic.at

    assert periodic.parameters == [
             %{
               name: "example",
               description: "Exemplary parameter",
               required: true,
               default_value: "option1",
               options: ["option1", "option2", "option3"]
             }
           ]

    refute periodic.id |> String.to_atom() |> QuantumScheduler.find_job()
  end

  test "persist does start quantum job when periodic is recurring", ctx do
    request =
      API.PersistRequest.new(
        name: "test periodic",
        recurring: true,
        organization_id: ctx.org_id,
        project_id: ctx.pr_id,
        requester_id: ctx.usr_id,
        reference: "master",
        pipeline_file: ".semaphore/cron.yml",
        at: "0 0 * * *",
        parameters: []
      )

    assert {:ok, periodic} = PersistImpl.persist(request)

    assert periodic.name == "test periodic"
    refute periodic.description
    assert periodic.recurring == true
    assert periodic.organization_id == ctx.org_id
    assert periodic.project_name == "Project 1"
    assert periodic.project_id == ctx.pr_id
    assert periodic.requester_id == ctx.usr_id
    assert periodic.reference == "master"
    assert periodic.pipeline_file == ".semaphore/cron.yml"
    assert periodic.at == "0 0 * * *"
    assert periodic.parameters == []

    assert periodic.id |> String.to_atom() |> QuantumScheduler.find_job()
  end

  test "persist stop quantum job when periodic is modified from recurring to non-recurring",
       ctx do
    assert {:ok, periodic: periodics} =
             Test.Support.Factory.setup_periodic(ctx,
               organization_id: ctx.org_id,
               project_id: ctx.pr_id,
               requester_id: ctx.usr_id
             )

    QuantumScheduler.start_periodic_job(periodics)

    request =
      API.PersistRequest.new(
        id: periodics.id,
        name: "test periodic new",
        recurring: false,
        requester_id: UUID.uuid4(),
        reference: "master",
        pipeline_file: ".semaphore/cron.yml",
        at: "",
        parameters: [
          Parameter.new(
            name: "example",
            description: "Exemplary parameter",
            required: true,
            default_value: "option1",
            options: ["option1", "option2", "option3"]
          )
        ]
      )

    assert {:ok, periodic} = PersistImpl.persist(request)

    assert periodic.id == periodics.id
    assert periodic.name == "test periodic new"
    refute periodic.description
    assert periodic.recurring == false
    assert periodic.organization_id == ctx.org_id
    assert periodic.project_name == "Project"
    assert periodic.project_id == ctx.pr_id
    assert periodic.requester_id != ctx.usr_id
    assert periodic.reference == "master"
    assert periodic.pipeline_file == ".semaphore/cron.yml"
    refute periodic.at

    assert periodic.parameters == [
             %{
               name: "example",
               description: "Exemplary parameter",
               required: true,
               default_value: "option1",
               options: ["option1", "option2", "option3"]
             }
           ]

    refute periodic.id |> String.to_atom() |> QuantumScheduler.find_job()
  end

  test "persist works when required parameters do not have a default value", ctx do
    assert {:ok, periodic: periodics} =
             Test.Support.Factory.setup_periodic(ctx,
               organization_id: ctx.org_id,
               project_id: ctx.pr_id,
               requester_id: ctx.usr_id
             )

    QuantumScheduler.start_periodic_job(periodics)

    request =
      API.PersistRequest.new(
        id: periodics.id,
        name: "test periodic new",
        recurring: false,
        requester_id: UUID.uuid4(),
        reference: "master",
        pipeline_file: ".semaphore/cron.yml",
        at: "",
        parameters: [
          Parameter.new(
            name: "example",
            description: "Exemplary parameter",
            required: true,
            default_value: "",
            options: ["option1", "option2", "option3"]
          )
        ]
      )

    assert {:ok, periodics} = PersistImpl.persist(request)
    refute periodics.id |> String.to_atom() |> QuantumScheduler.find_job()
  end
end
