defmodule Zebra.Workers.DbWorker do
  import Ecto.Query
  require Logger
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
    :isolate_machine_types,
    # :batches (default) processes rows in chunks of `parallelism` and waits
    # for the whole chunk before starting the next one. It supports halting
    # a tick by returning {:halt, _} from the processor.
    #
    # :continuous keeps `parallelism` rows in flight at all times: as soon as
    # one row is done, the next one starts. Rows that lose the lock to another
    # pod finish in milliseconds, so they no longer leave slots idle while the
    # slowest row of a chunk is still running. {:halt, _} is not supported.
    :concurrency_mode,
    # :continuous mode only: how long one row may take, in milliseconds. It is
    # also the row's transaction timeout, so the DB checkout deadline and the
    # task kill agree. A row that runs past it is killed or loses its
    # connection, its transaction is rolled back, and it is retried on a
    # later tick without aborting the rest of the tick. External calls the
    # processor already made are not undone.
    :process_timeout
  ]

  @default_process_timeout 15_000

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

    case worker.concurrency_mode || :batches do
      :batches ->
        Zebra.Parallel.in_batches(rows, [batch_size: parallelism], fn r ->
          process(worker, r)
        end)

      :continuous ->
        process_continuously(worker, rows, parallelism)

      other ->
        raise ArgumentError,
              "#{worker.metric_name}: unknown concurrency_mode #{inspect(other)}, " <>
                "expected :batches or :continuous"
    end
  end

  defp process_continuously(worker, rows, parallelism) do
    rows
    |> Zebra.Parallel.stream(
      [
        max_concurrency: parallelism,
        timeout: process_timeout(worker),
        metadata: [worker: worker.metric_name]
      ],
      fn r -> process_or_skip(worker, r) end
    )
    |> Enum.map(fn
      {_id, {:ok, {:halt, _} = result}} ->
        Logger.warning("#{worker.metric_name}: {:halt, _} is ignored in :continuous mode")
        result

      {_id, {:ok, result}} ->
        result

      {_id, {:error, :timeout}} ->
        Watchman.increment("#{worker.metric_name}.process.timeout")
        {:error, :timeout}
    end)
  end

  # DBConnection raises this when the checkout waits too long in the pool
  # queue, when the transaction outlives its timeout, or when the connection
  # drops. The transaction is already rolled back or gone by then, so skip
  # the row, which is retried on a later tick, instead of crashing the tick.
  defp process_or_skip(worker, id) do
    process(worker, id)
  rescue
    e in DBConnection.ConnectionError ->
      reason = to_string(e.reason)

      Watchman.increment({"#{worker.metric_name}.process.db_connection_error", [reason]})

      Logger.warning(
        "#{worker.metric_name}: DB connection error for #{id}, reason=#{reason}: " <>
          Exception.message(e)
      )

      {:error, :db_connection}
  end

  defp process_timeout(worker), do: worker.process_timeout || @default_process_timeout

  defp transaction_opts(%{concurrency_mode: :continuous} = worker),
    do: [timeout: process_timeout(worker)]

  defp transaction_opts(_worker), do: []

  defp submit_batch_size(name, v, nil), do: Watchman.submit("#{name}.batch_size", v)

  defp submit_batch_size(name, v, {machine_type, machine_os_image}),
    do: Watchman.submit({"#{name}.batch_size", ["#{machine_type}-#{machine_os_image}"]}, v)

  def process(worker, id) do
    Watchman.benchmark("#{worker.metric_name}.process.duration", fn ->
      Repo.transaction(
        fn ->
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
        end,
        transaction_opts(worker)
      )
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
            windows: [
              per_org: [
                partition_by: [r.organization_id, field(r, ^worker.machine_type_field)],
                order_by: [
                  {^order_dir, field(r, ^order_by)},
                  {:desc_nulls_last, r.priority},
                  {:asc, r.id}
                ]
              ]
            ],
            order_by: [asc: over(row_number(), :per_org)],
            order_by: [{^order_dir, field(r, ^order_by)}],
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
