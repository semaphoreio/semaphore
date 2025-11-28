defmodule Zebra.Workers.JobDeletionPolicyMarkerTest do
  use Zebra.DataCase

  alias Google.Protobuf.Timestamp
  alias InternalApi.Usage.OrganizationPolicyApply
  alias Zebra.Models.Job
  alias Zebra.Workers.JobDeletionPolicyMarker, as: Worker

  describe ".handle_message" do
    setup do
      original_config = Application.get_env(:zebra, Worker)

      on_exit(fn ->
        Application.put_env(:zebra, Worker, original_config)
      end)

      {:ok, original_config: original_config || []}
    end

    test "marks eligible jobs for deletion", %{original_config: original_config} do
      days = 3
      Application.put_env(:zebra, Worker, Keyword.put(original_config, :days, days))

      org_id = Ecto.UUID.generate()

      cutoff_date =
        DateTime.utc_now()
        |> DateTime.add(-3600, :second)
        |> DateTime.truncate(:second)

      older_created_at = DateTime.add(cutoff_date, -3600, :second)
      newer_created_at = DateTime.add(cutoff_date, 3600, :second)

      {:ok, job_to_mark} =
        Support.Factories.Job.create(:finished, %{
          organization_id: org_id,
          created_at: older_created_at,
          updated_at: older_created_at
        })

      {:ok, newer_job} =
        Support.Factories.Job.create(:finished, %{
          organization_id: org_id,
          created_at: newer_created_at,
          updated_at: newer_created_at
        })

      {:ok, other_org_job} =
        Support.Factories.Job.create(:finished, %{
          organization_id: Ecto.UUID.generate(),
          created_at: older_created_at,
          updated_at: older_created_at
        })

      cutoff_timestamp = Timestamp.new(seconds: DateTime.to_unix(cutoff_date))

      message =
        %OrganizationPolicyApply{org_id: org_id, cutoff_date: cutoff_timestamp}
        |> OrganizationPolicyApply.encode()

      Worker.handle_message(message)

      {:ok, updated_job} = Job.find(job_to_mark.id)

      assert updated_job.expires_at
      assert DateTime.diff(updated_job.expires_at, DateTime.utc_now()) > 0

      assert {:ok, newer_job} = Job.find(newer_job.id)
      assert is_nil(newer_job.expires_at)

      assert {:ok, other_org_job} = Job.find(other_org_job.id)
      assert is_nil(other_org_job.expires_at)
    end

    test "raises when cutoff date is missing", %{original_config: original_config} do
      Application.put_env(:zebra, Worker, original_config)

      message =
        %OrganizationPolicyApply{org_id: Ecto.UUID.generate(), cutoff_date: nil}
        |> OrganizationPolicyApply.encode()

      assert_raise ArgumentError, "cutoff_date is missing in policy payload", fn ->
        Worker.handle_message(message)
      end
    end
  end
end
