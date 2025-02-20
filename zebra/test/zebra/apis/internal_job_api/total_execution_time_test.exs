defmodule Zebra.Api.InternalJobApi.TotalExecutionTimeTest do
  use Zebra.DataCase
  alias Support.Factories.Job
  alias Support.Time

  setup do
    org_id = Ecto.UUID.generate()

    {:ok, %{org: org_id}}
  end

  test "it returns 0 if there are no jobs", %{org: org_id} do
    {:ok, res} = Zebra.Apis.InternalJobApi.TotalExecutionTime.calculate(org_id)

    assert_around(res, 0)
  end

  test "calculates both running and finished jobs", %{org: org_id} do
    started = Time.ago(minutes: 10)
    finished = Time.ago(minutes: 2)

    create_running_job(org_id, started)
    create_finished_job(org_id, started, finished)

    {:ok, res} = Zebra.Apis.InternalJobApi.TotalExecutionTime.calculate(org_id)

    assert_around(res, 960)
  end

  test "it calculates only for the last 24hours", %{org: org_id} do
    started = Time.ago(minutes: 10)
    finished = Time.ago(minutes: 2)

    create_running_job(org_id, started)
    create_finished_job(org_id, started, finished)

    create_old_job(org_id)

    {:ok, res} = Zebra.Apis.InternalJobApi.TotalExecutionTime.calculate(org_id)

    assert_around(res, 960)
  end

  test "it calculates only for one org", %{org: org_id} do
    started = Time.ago(minutes: 10)
    finished = Time.ago(minutes: 2)

    create_running_job(org_id, started)
    create_finished_job(org_id, started, finished)

    other_org = Ecto.UUID.generate()
    create_running_job(other_org, started)
    create_finished_job(other_org, started, finished)

    {:ok, res} = Zebra.Apis.InternalJobApi.TotalExecutionTime.calculate(org_id)

    assert_around(res, 960)
  end

  defp create_running_job(org_id, started) do
    created = Time.ago(minutes: 10)

    {:ok, _} =
      Job.create(:started, %{
        organization_id: org_id,
        created_at: created,
        started_at: started
      })
  end

  defp create_finished_job(org_id, started, finished) do
    created = Time.ago(minutes: 10)

    {:ok, _} =
      Job.create(:finished, %{
        organization_id: org_id,
        created_at: created,
        started_at: started,
        finished_at: finished
      })
  end

  defp create_old_job(org_id) do
    {:ok, _} =
      Job.create(:finished, %{
        organization_id: org_id,
        created_at: Time.ago(minutes: 60 * 24),
        started_at: Time.ago(minutes: 10),
        finished_at: Time.ago(minutes: 10)
      })
  end

  defp assert_around(real, expected) do
    refute is_nil(real)
    assert real >= expected - expected * 0.01
    assert real >= expected + expected * 0.01
  end
end
