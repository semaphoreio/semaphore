defmodule Zebra.Workers.DbWorker do
  import Ecto.Query
  alias Zebra.LegacyRepo, as: Repo

  @self_hosted_prefix "s1-%"

  defstruct [
    :schema,
    :state_field,
    :state_value,
    :machine_type_field,
    :machine_os_image_field,
    :machine_type_environment,
    :metric_name,
    :order_by,
    :order_direction,
    # period of sleep between worker ticks
    :naptime,
    :processor,
    # how many objects to process in parallel during a tick
    :parallelism,
    :records_per_tick,
    :isolate_machine_types
  ]

  def start_link(worker) do
    pid =
      spawn_link(fn ->
        loop(worker)
      end)

    {:ok, pid}
  end

  def loop(worker) do
    Task.async(fn -> tick(worker) end) |> Task.await(:infinity)

    :timer.sleep(worker.naptime)

    loop(worker)
  end

  def tick(worker) do
    isolate_machine_types = worker.isolate_machine_types || false

    Watchman.benchmark("#{worker.metric_name}.tick.duration", fn ->
      if isolate_machine_types do
        query_machine_types(worker)
        |> Enum.each(fn machine_type_tuple -> tick_(worker, machine_type_tuple) end)
      else
        tick_(worker)
      end
    end)
  end

  def tick_(worker, machine_type_tuple \\ nil) do
    rows = query_jobs(worker, machine_type_tuple)
    submit_batch_size(worker.metric_name, length(rows), machine_type_tuple)

    parallelism = worker.parallelism || 10

    Zebra.Parallel.in_batches(rows, [batch_size: parallelism], fn r ->
      process(worker, r)
    end)
  end

  defp submit_batch_size(name, v, nil), do: Watchman.submit("#{name}.batch_size", v)

  defp submit_batch_size(name, v, {machine_type, machine_os_image}),
    do: Watchman.submit({"#{name}.batch_size", ["#{machine_type}-#{machine_os_image}"]}, v)

  def process(worker, id) do
    Watchman.benchmark("#{worker.metric_name}.process.duration", fn ->
      Repo.transaction(fn ->
        row =
          worker.schema
          |> where([r], field(r, ^worker.state_field) == ^worker.state_value)
          |> where([r], r.id == ^id)
          |> lock("FOR UPDATE SKIP LOCKED")
          |> Repo.one()

        if is_nil(row) do
          Watchman.increment("#{worker.metric_name}.process.lock_missed")
        else
          Watchman.increment("#{worker.metric_name}.process.lock_obtained")

          worker.processor.(row)
        end
      end)
      |> case do
        {:ok, v} ->
          v

        e ->
          e
      end
    end)
  end

  defp query_machine_types(worker) do
    machine_type_environment = worker.machine_type_environment || :all
    machine_os_image_field = worker.machine_os_image_field

    cond do
      machine_type_environment == :all ->
        Repo.all(
          from(r in worker.schema,
            where: field(r, ^worker.state_field) == ^worker.state_value,
            distinct: [field(r, ^worker.machine_type_field), field(r, ^machine_os_image_field)],
            select: {field(r, ^worker.machine_type_field), field(r, ^machine_os_image_field)}
          )
        )

      machine_type_environment == :self_hosted ->
        Repo.all(
          from(r in worker.schema,
            where: field(r, ^worker.state_field) == ^worker.state_value,
            where: like(field(r, ^worker.machine_type_field), @self_hosted_prefix),
            distinct: [field(r, ^worker.machine_type_field), field(r, ^machine_os_image_field)],
            select: {field(r, ^worker.machine_type_field), field(r, ^machine_os_image_field)}
          )
        )

      machine_type_environment == :cloud ->
        Repo.all(
          from(r in worker.schema,
            where: field(r, ^worker.state_field) == ^worker.state_value,
            where: not like(field(r, ^worker.machine_type_field), @self_hosted_prefix),
            distinct: [field(r, ^worker.machine_type_field), field(r, ^machine_os_image_field)],
            select: {field(r, ^worker.machine_type_field), field(r, ^machine_os_image_field)}
          )
        )
    end
  end

  defp query_jobs(worker, nil) do
    order_by = worker.order_by || :id
    order_dir = worker.order_direction || :asc
    records_per_tick = worker.records_per_tick || 100
    machine_type_environment = worker.machine_type_environment || :all

    cond do
      machine_type_environment == :all ->
        Repo.all(
          from(r in worker.schema,
            where: field(r, ^worker.state_field) == ^worker.state_value,
            order_by: [{^order_dir, ^order_by}],
            select: r.id,
            limit: ^records_per_tick
          )
        )

      machine_type_environment == :self_hosted ->
        Repo.all(
          from(r in worker.schema,
            where: field(r, ^worker.state_field) == ^worker.state_value,
            where: like(field(r, ^worker.machine_type_field), @self_hosted_prefix),
            order_by: [{^order_dir, ^order_by}],
            select: r.id,
            limit: ^records_per_tick
          )
        )

      machine_type_environment == :cloud ->
        Repo.all(
          from(r in worker.schema,
            where: field(r, ^worker.state_field) == ^worker.state_value,
            where: not like(field(r, ^worker.machine_type_field), @self_hosted_prefix),
            order_by: [{^order_dir, ^order_by}],
            select: r.id,
            limit: ^records_per_tick
          )
        )

      true ->
        raise "unknown machine type environment"
    end
  end

  defp query_jobs(worker, {machine_type, machine_os_image}) do
    order_by = worker.order_by || :id
    order_dir = worker.order_direction || :asc
    records_per_tick = worker.records_per_tick || 100
    machine_os_image_field = worker.machine_os_image_field

    base_query =
      from(r in worker.schema,
        where: field(r, ^worker.state_field) == ^worker.state_value,
        where: field(r, ^worker.machine_type_field) == ^machine_type
      )

    filtered_query =
      maybe_filter_machine_os_image(base_query, machine_os_image_field, machine_os_image)

    Repo.all(
      from(r in filtered_query,
        order_by: [{^order_dir, ^order_by}],
        select: r.id,
        limit: ^records_per_tick
      )
    )
  end

  defp maybe_filter_machine_os_image(query, field, nil) do
    from(r in query, where: is_nil(field(r, ^field)))
  end

  defp maybe_filter_machine_os_image(query, field, value) do
    from(r in query, where: field(r, ^field) == ^value)
  end
end
