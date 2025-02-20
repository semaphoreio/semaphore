# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule Zebra.UsagePublisherTest do
  use Zebra.DataCase

  test "stat collection" do
    org1_id = Ecto.UUID.generate()
    org2_id = Ecto.UUID.generate()

    stub_quotas()

    {:ok, _} = create_job(org1_id, :started)
    {:ok, _} = create_job(org1_id, :scheduled)
    {:ok, _} = create_job(org2_id, :enqueued)
    {:ok, _} = create_job(org2_id, :started, "e1-standard-8")

    org1_started =
      Zebra.UsagePublisher.load()
      |> Enum.find(fn j ->
        j.org_id == org1_id && j.machine_type == "e1-standard-2" &&
          j.aasm_state == "started"
      end)

    assert org1_started.count == 1
  end

  def stub_quotas do
    alias Support.FakeServers.OrganizationApi, as: OrgApi

    GrpcMock.stub(OrgApi, :describe, fn _, _ ->
      InternalApi.Organization.DescribeResponse.new(
        status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
        organization: InternalApi.Organization.Organization.new(org_username: "testing-org")
      )
    end)
  end

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
end
