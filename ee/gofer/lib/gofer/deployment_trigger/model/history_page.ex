defmodule Gofer.DeploymentTrigger.Model.HistoryPage do
  @moduledoc """
  Encapsulates queries and logic for deployment history pagination
  """

  alias Gofer.DeploymentTrigger.Model
  alias Model.DeploymentTrigger, as: Trigger
  alias Gofer.EctoRepo
  require Ecto.Query
  require Logger

  @default_max_size 10
  @enforce_keys ~w(deployment_id)a
  # Detects if a string contains only regex special characters (disjunction from wildcards)
  @regex_special_chars ~r/[\.\+\?\[\]\{\}\|\\]/

  # Detects (a+)+ or ([a-zA-Z]+)*
  # Detects (a|aa)+ or (a|a?)+
  # Detects large range quantifiers {10,}
  # Detects lookaheads/lookbehinds (?:...)
  @unsafe_regex_patterns ~r/
    (\([^\)]*[\+\*][^\)]*\)[\+\*])
    | (\([^)]*\|[^)]*\)[+*])
    | (\{\d{2,},\d*\})
    | (\(\?.*?\))
/x

  # Maximum allowed length for pattern inputs to prevent DoS
  @max_pattern_length 100
  # Timeout for regex test matching in milliseconds
  @regex_timeout 100
  # Test string length for regex performance check
  @test_string_length 300

  defstruct deployment_id: nil,
            current_cursor: :FIRST,
            max_size: @default_max_size,
            filters: %{},
            results: nil,
            cursor_before: nil,
            cursor_after: nil

  def load(deployment_id, args) do
    cursor_type = args[:cursor_type] || :FIRST
    cursor_value = args[:cursor_value] || 0
    filters = args[:filters] || %{}

    load(%__MODULE__{
      deployment_id: deployment_id,
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
    do: count_triggers_after(page.deployment_id, epoch) == 0

  defp is_latest_page?(page = %__MODULE__{current_cursor: {:AFTER, epoch}}),
    do: count_triggers_after(page.deployment_id, epoch) <= page.max_size + 1

  defp is_latest_page?(page = %__MODULE__{current_cursor: :FIRST}) do
    count_triggers_after(
      page.deployment_id,
      DateTime.utc_now() |> DateTime.to_unix(:microsecond)
    ) <= page.max_size
  end

  defp is_last_page?(page = %__MODULE__{current_cursor: :FIRST}) do
    count_triggers_before(
      page.deployment_id,
      DateTime.utc_now() |> DateTime.to_unix(:microsecond)
    ) <= page.max_size
  end

  defp is_last_page?(page = %__MODULE__{current_cursor: {:BEFORE, epoch}}),
    do: count_triggers_before(page.deployment_id, epoch) <= page.max_size + 1

  defp is_last_page?(page = %__MODULE__{current_cursor: {:AFTER, epoch}}),
    do: count_triggers_before(page.deployment_id, epoch) <= 0

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

  defp count_triggers_before(deployment_id, epoch) do
    datetime = DateTime.from_unix!(epoch, :microsecond)

    Ecto.Query.from(dt in Trigger)
    |> Ecto.Query.where([dt], dt.deployment_id == ^deployment_id)
    |> Ecto.Query.where([dt], dt.triggered_at <= ^datetime)
    |> EctoRepo.aggregate(:count, :id)
  end

  defp count_triggers_after(deployment_id, epoch) do
    datetime = DateTime.from_unix!(epoch, :microsecond)

    Ecto.Query.from(dt in Trigger)
    |> Ecto.Query.where([dt], dt.deployment_id == ^deployment_id)
    |> Ecto.Query.where([dt], dt.triggered_at >= ^datetime)
    |> EctoRepo.aggregate(:count, :id)
  end

  defp list_page_triggers(page = %__MODULE__{}) do
    base_query(page)
    |> apply_cursor(page)
    |> apply_filters(page)
    |> EctoRepo.all()
  end

  # query builder functions

  defp base_query(page = %__MODULE__{}) do
    Ecto.Query.from(dt in Trigger)
    |> Ecto.Query.join(:inner, [dt], s in assoc(dt, :switch))
    |> Ecto.Query.where([dt, s], dt.deployment_id == ^page.deployment_id)
    |> Ecto.Query.preload([dt, s], switch: s)
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
    do: Ecto.Query.where(query, [dt, s], dt.triggered_by == ^triggered_by)

  defp apply_filter(query, {:git_ref_type, git_ref_type}),
    do: Ecto.Query.where(query, [dt, s], dt.git_ref_type == ^git_ref_type)

  defp apply_filter(query, {:git_ref_label, git_ref_label}),
    do: Ecto.Query.where(query, [dt, s], dt.git_ref_label == ^git_ref_label)

  defp apply_filter(query, {:parameter1, parameter1}),
    do: apply_pattern_filter(query, :parameter1, parameter1)

  defp apply_filter(query, {:parameter2, parameter2}),
    do: apply_pattern_filter(query, :parameter2, parameter2)

  defp apply_filter(query, {:parameter3, parameter3}),
    do: apply_pattern_filter(query, :parameter3, parameter3)

  defp apply_pattern_filter(query, field, value)
       when is_binary(value) and byte_size(value) <= @max_pattern_length do
    cond do
      valid_regex?(value) -> apply_regex_match(query, field, value)
      wildcard?(value) -> apply_like_match(query, field, value)
      true -> apply_exact_match(query, field, value)
    end
  end

  defp apply_pattern_filter(query, field, value)
       when is_binary(value) and byte_size(value) <= @max_pattern_length do
    cond do
      valid_regex?(value) -> apply_regex_match(query, field, value)
      wildcard?(value) -> apply_like_match(query, field, value)
      true -> apply_exact_match(query, field, value)
    end
  end

  defp apply_pattern_filter(query, _field, value) do
    Logger.warning("History Search Pattern too long: #{inspect(value)}")
    Ecto.Query.where(query, [_], false)
  end

  defp apply_like_match(query, field, value) when byte_size(value) <= @max_pattern_length do
    like_value = String.replace(value, "*", "%")
    Ecto.Query.where(query, [dt], fragment("? LIKE ?", field(dt, ^field), ^like_value))
  end

  defp apply_like_match(query, _field, value) do
    Logger.warning("History Search Pattern too long: #{inspect(value)}")
    Ecto.Query.where(query, [_], false)
  end

  defp apply_regex_match(query, field, value) do
    strict_regex = "^#{value}$"
    Ecto.Query.where(query, [dt], fragment("? ~ ?", field(dt, ^field), ^strict_regex))
  end

  defp apply_exact_match(query, field, value) do
    Ecto.Query.where(query, [dt], field(dt, ^field) == ^value)
  end

  defp wildcard?(string) when is_binary(string) do
    String.contains?(string, ["*", "%"])
  end

  defp valid_regex?(string) do
    regex?(string) and regex_safe?(string) and regex_compilable?(string) and
      regex_performance_safe?(string)
  end

  defp regex?(string) when is_binary(string) do
    Regex.match?(@regex_special_chars, string) and regex_compilable?(string)
  end

  defp regex?(_), do: false

  defp regex_compilable?(string) when is_binary(string) do
    case Regex.compile(string) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  defp regex_compilable?(_), do: false

  defp regex_safe?(string) do
    not Regex.match?(@unsafe_regex_patterns, string)
  end

  # Test regex performance against a sample string with timeout
  defp regex_performance_safe?(string) do
    case Regex.compile(string) do
      {:ok, regex} ->
        test_string = String.duplicate("a", @test_string_length)
        task = Task.async(fn -> Regex.match?(regex, test_string) end)

        case Task.yield(task, @regex_timeout) do
          {:ok, _result} ->
            true

          nil ->
            false
        end

      {:error, _} ->
        Logger.warning("Invalid regex: #{inspect(string)}")
        false
    end
  end
end
