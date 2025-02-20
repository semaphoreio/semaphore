defmodule Test.Actions.ApplyImpl.Test do
  use ExUnit.Case

  alias Scheduler.Actions.ApplyImpl
  alias Scheduler.Workers.QuantumScheduler
  alias Scheduler.Periodics.Model.PeriodicsQueries

  setup do
    Test.Helpers.truncate_db()
    params = Test.Helpers.seed_front_db()

    start_supervised!(QuantumScheduler)

    {:ok, params}
  end

  test "apply doesn't start quantum job when periodic is non-recurring", ctx do
    yml_definition = """
    apiVersion: v1.1
    kind: Schedule
    metadata:
      name: test periodic
    spec:
      project: Project 1
      recurring: false
      branch: master
      at: ""
      pipeline_file: .semaphore/cron.yml
      parameters:
        - name: example
          description: Exemplary parameter
          required: true
          default_value: option1
          options:
            - option1
            - option2
            - option3
    """

    assert {:ok, periodic_id} =
             ApplyImpl.apply(%{
               organization_id: ctx.org_id,
               requester_id: ctx.usr_id,
               yml_definition: yml_definition
             })

    refute periodic_id |> String.to_atom() |> QuantumScheduler.find_job()
  end

  test "apply does start quantum job when periodic is recurring", ctx do
    yml_definition = """
    apiVersion: v1.1
    kind: Schedule
    metadata:
      name: test periodic
    spec:
      project: Project 1
      recurring: true
      branch: master
      at: "0 0 * * *"
      pipeline_file: .semaphore/cron.yml
      parameters:
        - name: example
          description: Exemplary parameter
          required: true
          default_value: option1
          options:
            - option1
            - option2
            - option3
    """

    assert {:ok, periodic_id} =
             ApplyImpl.apply(%{
               organization_id: ctx.org_id,
               requester_id: ctx.usr_id,
               yml_definition: yml_definition
             })

    assert periodic_id |> String.to_atom() |> QuantumScheduler.find_job()
  end

  test "apply stop quantum job when periodic is modified from recurring to non-recurring", ctx do
    assert {:ok, periodics} = insert_periodics(ctx)
    QuantumScheduler.start_periodic_job(periodics)

    yml_definition = """
    apiVersion: v1.1
    kind: Schedule
    metadata:
      name: test periodic
      id: #{periodics.id}
    spec:
      project: Project 1
      recurring: false
      branch: master
      at: ""
      pipeline_file: .semaphore/cron.yml
      parameters:
        - name: example
          description: Exemplary parameter
          required: true
          default_value: option1
          options:
            - option1
            - option2
            - option3
    """

    assert {:ok, periodic_id} =
             ApplyImpl.apply(%{
               organization_id: ctx.org_id,
               requester_id: ctx.usr_id,
               yml_definition: yml_definition
             })

    refute periodic_id |> String.to_atom() |> QuantumScheduler.find_job()
  end

  test "apply works when required parameters do not have a default value", ctx do
    assert {:ok, periodics} = insert_periodics(ctx)
    QuantumScheduler.start_periodic_job(periodics)

    yml_definition = """
    apiVersion: v1.1
    kind: Schedule
    metadata:
      name: test periodic
      id: #{periodics.id}
    spec:
      project: Project 1
      recurring: false
      branch: master
      at: ""
      pipeline_file: .semaphore/cron.yml
      parameters:
        - name: example
          description: Exemplary parameter
          required: true
          default_value: \"\"
          options:
            - option1
            - option2
            - option3
    """

    assert {:ok, periodic_id} =
             ApplyImpl.apply(%{
               organization_id: ctx.org_id,
               requester_id: ctx.usr_id,
               yml_definition: yml_definition
             })

    refute periodic_id |> String.to_atom() |> QuantumScheduler.find_job()
  end

  defp insert_periodics(ids, extra \\ %{}) do
    %{
      requester_id: ids.usr_id,
      organization_id: ids.org_id,
      name: "Periodic_1",
      project_name: "Project_1",
      recurring: if(is_nil(extra[:recurring]), do: true, else: extra[:recurring]),
      project_id: ids.pr_id,
      branch: extra[:branch] || "master",
      at: extra[:at] || "0 0 * * *",
      paused: if(is_nil(extra[:paused]), do: false, else: extra[:paused]),
      pipeline_file: extra[:pipeline_file] || "deploy.yml",
      parameters: extra[:parameters] || []
    }
    |> PeriodicsQueries.insert()
  end
end
