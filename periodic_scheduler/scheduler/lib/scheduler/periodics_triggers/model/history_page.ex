defmodule Scheduler.PeriodicsTriggers.Model.HistoryPage do
  @moduledoc """
  Encapsulates queries and logic for scheduler history pagination
  """

  alias Scheduler.PeriodicsTriggers.Model
  alias Model.PeriodicsTriggers, as: Trigger
  alias Scheduler.PeriodicsRepo
  require Ecto.Query

  @default_max_size 10
  @enforce_keys ~w(periodic_id)a

  defstruct periodic_id: nil,
            current_cursor: :FIRST,
            max_size: @default_max_size,
            filters: %{},
            results: nil,
            cursor_before: nil,
            cursor_after: nil

  def load(periodic_id, args) do
    cursor_type = args[:cursor_type] || :FIRST
    cursor_value = args[:cursor_value] || 0
    filters = args[:filters] || %{}

    load(%__MODULE__{
      periodic_id: periodic_id,
      current_cursor: as_cursor(cursor_type, cursor_value),
      max_size: @default_max_size,
      filters: filters
    })
  end

  defp as_cursor(:FIRST, _value), do: :FIRST
  defp as_cursor(type, value), do: {type, value}

  def load(page = %__MODULE__{current_cursor: :FIRST}),
    do: load_page(page)

  def load(page = %__MODULE__{}) do
    load_page(
      if is_latest_page?(page),
        do: %__MODULE__{page | current_cursor: :FIRST},
        else: page
    )
  end

  defp load_page(page = %__MODULE__{}) do
    {triggers, is_last?} = {list_page_triggers(page), is_last_page?(page)}
    {results, {prev, next}} = form_page_result(page, triggers, is_last?)
    %__MODULE__{page | cursor_before: prev, cursor_after: next, results: results}
  end

  # constructing page

  defp is_latest_page?(page = %__MODULE__{current_cursor: {:BEFORE, epoch}}),
    do: count_triggers_after(page.periodic_id, epoch) == 0

  defp is_latest_page?(page = %__MODULE__{current_cursor: {:AFTER, epoch}}),
    do: count_triggers_after(page.periodic_id, epoch) <= page.max_size + 1

  defp is_latest_page?(page = %__MODULE__{current_cursor: :FIRST}) do
    count_triggers_after(
      page.periodic_id,
      DateTime.utc_now() |> DateTime.to_unix(:microsecond)
    ) <= page.max_size
  end

  defp is_last_page?(page = %__MODULE__{current_cursor: :FIRST}) do
    count_triggers_before(
      page.periodic_id,
      DateTime.utc_now() |> DateTime.to_unix(:microsecond)
    ) <= page.max_size
  end

  defp is_last_page?(page = %__MODULE__{current_cursor: {:BEFORE, epoch}}),
    do: count_triggers_before(page.periodic_id, epoch) <= page.max_size + 1

  defp is_last_page?(page = %__MODULE__{current_cursor: {:AFTER, epoch}}),
    do: count_triggers_before(page.periodic_id, epoch) <= 0

  defp form_page_result(page = %__MODULE__{current_cursor: :FIRST}, triggers, _is_last?) do
    {results, prev_items} = Enum.split(triggers, page.max_size)
    {results, {results |> List.last() |> unwrap_cursor(prev_items), nil}}
  end

  defp form_page_result(page = %__MODULE__{current_cursor: {:BEFORE, _}}, triggers, _is_last?) do
    {next_items, results_and_prev} = Enum.split(triggers, 1)
    {results, prev_items} = Enum.split(results_and_prev, page.max_size)

    prev_cursor = results |> List.last() |> unwrap_cursor(prev_items)
    next_cursor = results |> List.first() |> unwrap_cursor(next_items)

    {results, {prev_cursor, next_cursor}}
  end

  defp form_page_result(
         page = %__MODULE__{current_cursor: {:AFTER, _}},
         triggers,
         _is_last? = false
       ) do
    {prev_items, results_and_next} = Enum.split(triggers, 1)
    {results, next_items} = Enum.split(results_and_next, page.max_size)

    prev_cursor = results |> List.first() |> unwrap_cursor(prev_items)
    next_cursor = results |> List.last() |> unwrap_cursor(next_items)

    {Enum.reverse(results), {prev_cursor, next_cursor}}
  end

  defp form_page_result(
         page = %__MODULE__{current_cursor: {:AFTER, _}},
         triggers,
         _is_last? = true
       ) do
    {results, next_items} = triggers |> Enum.split(page.max_size)
    {Enum.reverse(results), {nil, results |> List.last() |> unwrap_cursor(next_items)}}
  end

  defp unwrap_cursor(%Trigger{triggered_at: triggered_at}, [_ | _]),
    do: DateTime.to_unix(triggered_at, :microsecond)

  defp unwrap_cursor(_results, _neighborhood), do: nil

  # Ecto queries

  defp count_triggers_before(periodic_id, epoch) do
    datetime = DateTime.from_unix!(epoch, :microsecond)

    Ecto.Query.from(dt in Trigger)
    |> Ecto.Query.where([dt], dt.periodic_id == ^periodic_id)
    |> Ecto.Query.where([dt], dt.triggered_at <= ^datetime)
    |> PeriodicsRepo.aggregate(:count, :id)
  end

  defp count_triggers_after(periodic_id, epoch) do
    datetime = DateTime.from_unix!(epoch, :microsecond)

    Ecto.Query.from(dt in Trigger)
    |> Ecto.Query.where([dt], dt.periodic_id == ^periodic_id)
    |> Ecto.Query.where([dt], dt.triggered_at >= ^datetime)
    |> PeriodicsRepo.aggregate(:count, :id)
  end

  defp list_page_triggers(page = %__MODULE__{}) do
    base_query(page)
    |> apply_cursor(page)
    |> apply_filters(page)
    |> PeriodicsRepo.all()
  end

  # query builder functions

  defp base_query(page = %__MODULE__{}) do
    Ecto.Query.from(dt in Trigger)
    |> Ecto.Query.where([dt, s], dt.periodic_id == ^page.periodic_id)
  end

  defp apply_cursor(query, %__MODULE__{current_cursor: :FIRST, max_size: max_size}) do
    query
    |> Ecto.Query.order_by([dt], desc: dt.triggered_at)
    |> Ecto.Query.limit(^max_size + 1)
  end

  defp apply_cursor(query, %__MODULE__{
         current_cursor: {:BEFORE, before_epoch},
         max_size: max_size
       }) do
    before_datetime = DateTime.from_unix!(before_epoch, :microsecond)

    query
    |> Ecto.Query.where([dt], dt.triggered_at <= ^before_datetime)
    |> Ecto.Query.order_by([dt], desc: dt.triggered_at)
    |> Ecto.Query.limit(^max_size + 2)
  end

  defp apply_cursor(query, %__MODULE__{current_cursor: {:AFTER, after_epoch}, max_size: max_size}) do
    after_datetime = DateTime.from_unix!(after_epoch, :microsecond)

    query
    |> Ecto.Query.where([dt], dt.triggered_at >= ^after_datetime)
    |> Ecto.Query.order_by([dt], asc: dt.triggered_at)
    |> Ecto.Query.limit(^max_size + 2)
  end

  defp apply_filters(query, %__MODULE__{filters: filters}),
    do: Enum.reduce(filters, query, &apply_filter(&2, &1))

  defp apply_filter(query, {:triggered_by, triggered_by}),
    do: Ecto.Query.where(query, [dt, s], dt.run_now_requester_id == ^triggered_by)

  defp apply_filter(query, {:branch_name, branch_name}),
    do: Ecto.Query.where(query, [dt, s], dt.branch == ^branch_name)

  defp apply_filter(query, {:pipeline_file, pipeline_file}),
    do: Ecto.Query.where(query, [dt, s], dt.pipeline_file == ^pipeline_file)
end
