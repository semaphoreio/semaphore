defmodule Zebra.UsagePublisher do
  def start_link do
    {:ok, spawn_link(&loop/0)}
  end

  def loop do
    Task.async(fn -> tick() end) |> Task.await(:infinity)

    :timer.sleep(10_000)

    loop()
  end

  def tick do
    load()
    |> Enum.map(fn j ->
      tags = [j.org_name, j.machine_type, j.aasm_state]

      Watchman.submit({"usage", tags}, j.count, :timing)
      Watchman.submit({"usage.quota", tags}, j.quota, :timing)
    end)
  end

  def load do
    jobs = query() |> Zebra.LegacyRepo.all()

    jobs =
      jobs
      |> Enum.map(fn job ->
        {:ok, org} = Zebra.Workers.Scheduler.Org.load(job.org_id)

        Map.merge(job, %{
          org_name: org.username,
          quota: FeatureProvider.machine_quota(job.machine_type, param: job.org_id)
        })
      end)

    jobs
  end

  def query do
    import Ecto.Query, only: [from: 2]

    from(j in Zebra.Models.Job,
      where: j.aasm_state in ["enqueued", "scheduled", "started"],
      group_by: [j.organization_id, j.machine_type, j.aasm_state],
      select: %{
        count: count(j.id),
        org_id: j.organization_id,
        machine_type: j.machine_type,
        aasm_state: j.aasm_state
      }
    )
  end
end
