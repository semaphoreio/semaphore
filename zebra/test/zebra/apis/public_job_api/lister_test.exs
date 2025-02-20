defmodule Zebra.Apis.PublicJobApi.ListerTest do
  use Zebra.DataCase

  alias Semaphore.Jobs.V1alpha.ListJobsRequest, as: Request
  alias Zebra.Apis.PublicJobApi.Lister

  describe ".list_jobs" do
    test "filtering jobs by state" do
      {:ok, job1} =
        Support.Factories.Job.create(:pending, %{created_at: Support.Time.ago(minutes: 1)})

      {:ok, job2} =
        Support.Factories.Job.create(:scheduled, %{created_at: Support.Time.ago(minutes: 2)})

      {:ok, job3} =
        Support.Factories.Job.create(:started, %{created_at: Support.Time.ago(minutes: 3)})

      {:ok, job4} =
        Support.Factories.Job.create(:finished, %{created_at: Support.Time.ago(minutes: 4)})

      req = %{
        page_token: "",
        order: Request.Order.value(:BY_CREATE_TIME_DESC),
        states: [
          Semaphore.Jobs.V1alpha.Job.Status.State.value(:PENDING),
          Semaphore.Jobs.V1alpha.Job.Status.State.value(:RUNNING)
        ]
      }

      org_id = job1.organization_id
      project_ids = [job1.project_id, job2.project_id, job3.project_id, job4.project_id]
      page_size = 15

      {:ok, jobs, _} = Lister.list_jobs(org_id, page_size, project_ids, req)

      assert Enum.map(jobs, & &1.id) == [job1.id, job3.id]
    end

    test "continuing the listing with a page_token" do
      {:ok, job1} =
        Support.Factories.Job.create(:pending, %{created_at: Support.Time.ago(minutes: 1)})

      {:ok, job2} =
        Support.Factories.Job.create(:pending, %{created_at: Support.Time.ago(minutes: 2)})

      {:ok, job3} =
        Support.Factories.Job.create(:pending, %{created_at: Support.Time.ago(minutes: 3)})

      {:ok, job4} =
        Support.Factories.Job.create(:pending, %{created_at: Support.Time.ago(minutes: 4)})

      req = %{
        page_token: "",
        order: Request.Order.value(:BY_CREATE_TIME_DESC),
        states: [Semaphore.Jobs.V1alpha.Job.Status.State.value(:PENDING)]
      }

      org_id = job1.organization_id
      project_ids = [job1.project_id, job2.project_id, job3.project_id, job4.project_id]
      page_size = 2

      {:ok, first_batch, next_page_token} = Lister.list_jobs(org_id, page_size, project_ids, req)

      assert Enum.map(first_batch, & &1.id) == [job1.id, job2.id]

      req = %{req | page_token: next_page_token}

      {:ok, second_batch, _} = Lister.list_jobs(org_id, 2, project_ids, req)

      assert Enum.map(second_batch, & &1.id) == [job3.id, job4.id]
    end

    test "filtering by project id" do
      {:ok, job1} =
        Support.Factories.Job.create(:pending, %{
          project_id: Ecto.UUID.generate(),
          created_at: Support.Time.ago(minutes: 1)
        })

      {:ok, _job2} =
        Support.Factories.Job.create(:scheduled, %{created_at: Support.Time.ago(minutes: 2)})

      {:ok, job3} =
        Support.Factories.Job.create(:started, %{
          project_id: Ecto.UUID.generate(),
          created_at: Support.Time.ago(minutes: 3)
        })

      {:ok, _job4} =
        Support.Factories.Job.create(:finished, %{created_at: Support.Time.ago(minutes: 4)})

      req = %{
        page_token: "",
        order: Request.Order.value(:BY_CREATE_TIME_DESC),
        states: [
          Semaphore.Jobs.V1alpha.Job.Status.State.value(:PENDING),
          Semaphore.Jobs.V1alpha.Job.Status.State.value(:RUNNING)
        ]
      }

      org_id = job1.organization_id
      project_ids = [job1.project_id, job3.project_id]
      page_size = 15

      {:ok, jobs, _} = Lister.list_jobs(org_id, page_size, project_ids, req)

      assert Enum.map(jobs, & &1.id) == [job1.id, job3.id]
    end
  end

  describe ".extract_page_size" do
    test "when page size is 0 => returns 30" do
      assert Lister.extract_page_size(%{page_size: 0}) == {:ok, 30}
    end

    test "when page size is less then limit => returns page size" do
      assert Lister.extract_page_size(%{page_size: 15}) == {:ok, 15}
    end

    test "when page size is less then limit => returns error" do
      assert Lister.extract_page_size(%{page_size: 45}) == {
               :error,
               :precondition_failed,
               "Page size can't exceed 30"
             }
    end
  end

  test ".map_state_names" do
    assert Lister.map_state_names(%{
             states: [
               Semaphore.Jobs.V1alpha.Job.Status.State.value(:PENDING),
               Semaphore.Jobs.V1alpha.Job.Status.State.value(:QUEUED),
               Semaphore.Jobs.V1alpha.Job.Status.State.value(:RUNNING),
               Semaphore.Jobs.V1alpha.Job.Status.State.value(:FINISHED)
             ]
           }) == [
             "pending",
             "enqueued",
             "scheduled",
             "waiting-for-agent",
             "started",
             "finished"
           ]
  end
end
