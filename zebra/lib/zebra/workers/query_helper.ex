defmodule Zebra.Workers.QueryHelper do
  import Ecto.Query

  # A small module to help with long-running queries.
  # The public methods in this module are supposed to be called
  # from inside of a remote session.
  require Logger

  def distinct_orgs_for_image_in_period(image, days, start_time \\ DateTime.utc_now()) do
    orgs = distinct_orgs_for_image_in_period_(start_time, image, days * 24, [])

    File.write!(
      "/tmp/#{image}-#{days}d.txt",
      Enum.map_join(orgs, "\n", fn {org_id, machine_type, seconds, seconds_60} ->
        "#{org_id},#{machine_type},#{seconds},#{seconds_60}"
      end)
    )
  end

  def distinct_orgs_for_image_in_period_(start_time, image, current_hour, orgs) do
    from = DateTime.add(start_time, -current_hour * 3_600, :second)
    to = DateTime.add(start_time, -(current_hour - 1) * 3_600, :second)
    Logger.info("Searching from #{from} to #{to}...")

    if current_hour > 0 do
      new_orgs = distinct_orgs_for_image_in_hour(from, to, image)

      distinct_orgs_for_image_in_period_(
        start_time,
        image,
        current_hour - 1,
        merge_and_sum(orgs, new_orgs)
      )
    else
      orgs
    end
  end

  def distinct_orgs_for_image_in_hour(from, to, image) do
    Zebra.Models.Job
    |> select(
      [j],
      {j.organization_id, j.machine_type,
       fragment("(SUM(date_part('epoch', finished_at) - date_part('epoch', started_at)))::int"),
       fragment(
         "(SUM(GREATEST(60, date_part('epoch', finished_at) - date_part('epoch', started_at))))::int"
       )}
    )
    |> where([j], j.created_at <= ^to)
    |> where([j], j.created_at > ^from)
    |> where([j], j.machine_os_image == ^image)
    |> group_by([j], [j.machine_type, j.organization_id])
    |> Zebra.LegacyRepo.all(timeout: 30_000)
  end

  def merge_and_sum(arr1, arr2) do
    arr1
    |> Enum.concat(arr2)
    |> Enum.group_by(fn {org_id, machine_type, _, _} -> {org_id, machine_type} end)
    |> Enum.map(fn {{org_id, machine_type}, values} ->
      sum_seconds = Enum.sum(Enum.map(values, fn {_, _, seconds, _} -> seconds || 0 end))
      sum_seconds_60 = Enum.sum(Enum.map(values, fn {_, _, _, seconds_60} -> seconds_60 || 0 end))
      {org_id, machine_type, sum_seconds, sum_seconds_60}
    end)
  end
end
