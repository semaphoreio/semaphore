defmodule Gofer.EctoRepo.Migrations.PopulateGitRefFromSwitchesToDeploymentTriggers do
  use Ecto.Migration
  import Ecto.Query

  @disable_ddl_transaction true
  @disable_migration_lock true

  @default_last_pos "00000000-0000-0000-0000-000000000000"
  @batch_size 1000
  @throttle_ms 100

  def up, do: bulk_change(Ecto.UUID.dump!(@default_last_pos))
  def down, do: :ok

  defp bulk_change(last_pos) do
    bulk_rows = repo().all(page_query(last_pos), log: :info, timeout: :infinity)

    if not Enum.empty?(bulk_rows) do
      next_pos = do_change(bulk_rows)
      Process.sleep(@throttle_ms)
      bulk_change(next_pos)
    else
      :ok
    end
  end

  def do_change(batch_of_ids) do
    {_updated, returned_ids} = repo().update_all(update_query(batch_of_ids), [])

    MapSet.new(batch_of_ids)
    |> MapSet.difference(MapSet.new(returned_ids))
    |> Enum.each(fn id ->
      raise "deployment_triggers: #{inspect(id)} was not updated"
    end)

    returned_ids |> Enum.sort() |> List.last()
  end

  defp page_query(last_id) do
    from(
      dt in "deployment_triggers",
      where:
        is_nil(dt.git_ref_label) and
          dt.id > ^last_id,
      order_by: [asc: dt.id],
      limit: @batch_size,
      select: dt.id
    )
  end

  defp update_query(batch_of_ids) do
    from(
      dt in "deployment_triggers",
      join: s in "switches",
      on: dt.switch_id == s.id,
      where: dt.id in ^batch_of_ids,
      select: dt.id,
      update: [
        set: [
          git_ref_type: s.git_ref_type,
          git_ref_label: s.label
        ]
      ]
    )
  end
end
