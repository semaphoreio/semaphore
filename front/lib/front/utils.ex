defmodule Front.Utils do
  require Logger
  alias Front.Async

  @type maybe_result :: ok_tuple | err_tuple
  @type maybe_result(type) :: ok_tuple(type) | err_tuple
  @type maybe_result(type, error_type) :: ok_tuple(type) | err_tuple(error_type)
  @type ok_tuple :: {:ok, any()}
  @type ok_tuple(type) :: {:ok, type}
  @type err_tuple :: {:error, any()} | {:error, any(), any()} | {:error, any(), any(), any()}
  @type err_tuple(type) :: {:error, type} | {:error, any(), type} | {:error, any(), type, any()}
  @type callback :: (any() -> any())

  @doc ~S"""
  Wraps arbitrary values in a ok tuple.
  ## Examples
      iex> alias Front.Utils, as: ToTuple
      iex> ToTuple.ok("hello")
      {:ok, "hello"}
      iex> alias Front.Utils, as: ToTuple
      iex> ToTuple.ok({:ok, "hello"})
      {:ok, {:ok, "hello"}}
      iex> alias Front.Utils, as: ToTuple
      iex> ToTuple.ok("hello", :world)
      {:ok, {:world, "hello"}}
      iex> alias Front.Utils, as: ToTuple
      iex> ToTuple.ok("hello", "world")
      {:ok, "hello"}
  """
  @spec ok(any()) :: ok_tuple
  def ok(item), do: {:ok, item}

  @spec ok(any(), any()) :: ok_tuple
  def ok(item, atom) when is_atom(atom), do: {:ok, {atom, item}}
  def ok(item, _val), do: {:ok, item}

  @doc ~S"""
  Wraps arbitrary values in a error tuple.
  ## Examples
      iex> alias Front.Utils, as: ToTuple
      iex> ToTuple.error("hello")
      {:error, "hello"}
      iex> alias Front.Utils, as: ToTuple
      iex> ToTuple.error({:error, "hello"})
      {:error, {:error, "hello"}}
      iex> alias Front.Utils, as: ToTuple
      iex> ToTuple.error("hello", :world)
      {:error, {:world, "hello"}}
      iex> alias Front.Utils, as: ToTuple
      iex> ToTuple.error("hello", "world")
      {:error, "hello"}
  """

  @spec error(any()) :: err_tuple
  def error(item), do: {:error, item}

  @spec error(any(), any()) :: err_tuple
  def error(item, atom) when is_atom(atom), do: {:error, {atom, item}}
  def error(item, _val), do: {:error, item}

  @doc ~S"""
  Wraps arbitrary values in a tuple. Ok tuples and error tuples are passed through.
  ## Examples
      iex> alias Front.Utils, as: ToTuple
      iex> ToTuple.wrap({:ok, "hello"})
      {:ok, "hello"}
      iex> alias Front.Utils, as: ToTuple
      iex> ToTuple.wrap({:error, "some error"})
      {:error, "some error"}
      iex> alias Front.Utils, as: ToTuple
      iex> ToTuple.wrap(:error)
      {:error, "generic error"}
      iex> alias Front.Utils, as: ToTuple
      iex> ToTuple.wrap("some value")
      {:ok, "some value"}
  """
  @spec wrap(ok_tuple | err_tuple | any()) :: maybe_result
  def wrap(tuple = {:ok, _}), do: tuple
  def wrap({:error, _, error_value, _}), do: error(error_value)
  def wrap({:error, _, error_value}), do: error(error_value)
  def wrap(error = {:error, _}), do: error
  def wrap(:error), do: {:error, "generic error"}
  def wrap(other), do: {:ok, other}

  @doc ~S"""
  Unwraps a value if tuple is ok and calls the callback with the value.
  ## Examples
      iex> alias Front.Utils, as: ToTuple
      iex> ToTuple.unwrap({:ok, 1}, & &1 + 1)
      2
      iex> alias Front.Utils, as: ToTuple
      iex> ToTuple.unwrap(1, & &1 + 1)
      2
      iex> alias Front.Utils, as: ToTuple
      iex> ToTuple.unwrap({:error, 1}, & &1 + 1)
      {:error, 1}
      iex> alias Front.Utils, as: ToTuple
      iex> ToTuple.unwrap(:error, & &1 + 1)
      {:error, "generic error"}
  """
  @spec unwrap(maybe_result, callback()) :: any
  def unwrap({:error, _, error_value, _}, _), do: error(error_value)
  def unwrap({:error, _, error_value}, _), do: error(error_value)
  def unwrap(error = {:error, _}, _), do: error
  def unwrap(:error, _), do: error("generic error")

  def unwrap({:ok, item}, fun) when is_function(fun, 1) do
    fun.(item)
  end

  def unwrap(other, fun), do: unwrap({:ok, other}, fun)

  @doc """
  Similiar to unwrap/1 but callback is called with error instead
  ## Examples
      iex> alias Front.Utils, as: ToTuple
      iex> ToTuple.unwrap_error({:ok, 1}, & &1 + 1)
      {:ok, 1}
      iex> alias Front.Utils, as: ToTuple
      iex> ToTuple.unwrap_error(1, & &1 + 1)
      {:ok, 1}
      iex> alias Front.Utils, as: ToTuple
      iex> ToTuple.unwrap_error({:error, 1}, fn _ -> {:ok, "It's fine"} end)
      {:ok, "It's fine"}
      iex> alias Front.Utils, as: ToTuple
      iex> ToTuple.unwrap_error({:error, "joe"}, fn a -> {:ok, "It's fine \#{a}"} end)
      {:ok, "It's fine joe"}
      iex> alias Front.Utils, as: ToTuple
      iex> ToTuple.unwrap_error(:error, fn _ -> {:ok, "It's fine"} end)
      {:ok, "It's fine"}
  """
  @spec unwrap_error(maybe_result, callback()) :: any
  def unwrap_error({:error, _, error_value, _}, fun) when is_function(fun, 1) do
    fun.(error_value)
  end

  def unwrap_error({:error, _, error_value}, fun) when is_function(fun, 1) do
    fun.(error_value)
  end

  def unwrap_error({:error, error_value}, fun) when is_function(fun, 1) do
    fun.(error_value)
  end

  def unwrap_error(:error, fun) when is_function(fun, 1) do
    fun.(:error)
  end

  def unwrap_error(ok_tuple = {:ok, _}, _), do: ok_tuple
  def unwrap_error(other_value, _), do: {:ok, other_value}

  @doc ~S"""
  Unwraps a value if tuple is ok. Raises otherwise.
  ## Examples
      iex> alias Front.Utils, as: ToTuple
      iex> ToTuple.unwrap!({:ok, 1})
      1
      iex> alias Front.Utils, as: ToTuple
      iex> ToTuple.unwrap!(1)
      1
      iex> alias Front.Utils, as: ToTuple
      iex> ToTuple.unwrap!({:error, 1})
      ** (RuntimeError) can't unwrap an error
      iex> alias Front.Utils, as: ToTuple
      iex> ToTuple.unwrap!(:error)
      ** (RuntimeError) can't unwrap an error
  """
  @spec unwrap!(maybe_result) :: any
  def unwrap!({:ok, value}), do: value

  def unwrap!({:error, _, _value, _}) do
    raise("can't unwrap an error")
  end

  def unwrap!({:error, _, _value}) do
    raise("can't unwrap an error")
  end

  def unwrap!({:error, _value}) do
    raise("can't unwrap an error")
  end

  def unwrap!(:error) do
    raise("can't unwrap an error")
  end

  def unwrap!(other) do
    other
  end

  def parallel_map(collection, func) do
    collection
    |> Enum.map(fn item -> Async.run(fn -> func.(item) end) end)
    |> Enum.map(fn process ->
      {:ok, returned} = Async.await(process)

      returned
    end)
  end

  def parallel_map_with_index(collection, func) do
    collection
    |> Enum.with_index()
    |> Enum.map(fn {item, idx} -> Async.run(fn -> func.({item, idx}) end) end)
    |> Enum.map(fn process ->
      {:ok, returned} = Async.await(process)

      returned
    end)
  end

  def log_verbose(line), do: Logger.error(fn -> line end)

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def regexp_split(list) do
    list
    |> String.trim()
    |> String.to_charlist()
    |> Enum.reduce([""], fn char, acc ->
      last = List.last(acc)
      char = to_string([char])

      cond do
        char == "," and String.at(last, 0) == "/" ->
          List.replace_at(acc, -1, last <> char)

        char == "," and last == "" ->
          acc

        char == "," ->
          List.insert_at(acc, -1, "")

        char == "/" and last == "" ->
          List.replace_at(acc, -1, "/")

        char == "/" and String.at(last, -1) == "\\" ->
          List.replace_at(acc, -1, last <> char)

        char == "/" and String.at(last, 0) == "/" ->
          acc
          |> List.replace_at(-1, last <> char)
          |> List.insert_at(-1, "")

        true ->
          List.replace_at(acc, -1, last <> char)
      end
    end)
    |> Enum.map(&String.trim/1)
    |> Enum.filter(fn x -> x != "" end)
  end

  @doc """
  Decorates a date in seconds with an ISO format.
  ## Examples
      iex> alias Front.Utils, as: Utils
      iex> Utils.decorate_date(0)
      ""
      iex> Utils.decorate_date(nil)
      ""
      iex> Utils.decorate_date(1616425200)
      "2021-03-22 00:00:00 UTC"
  """
  @spec decorate_date(integer | float | nil) :: String.t()
  def decorate_date(0), do: ""
  def decorate_date(nil), do: ""

  def decorate_date(seconds) do
    seconds
    |> DateTime.from_unix!()
    |> Timex.format!("{ISOdate} {ISOtime} UTC")
  end

  @doc """
  Decorates a date in seconds or a DateTime in a relative format.
  If more than 3 days compared to the current date, display the whole date
  in: Weekday, Day Month Year format.

  ## Examples
      iex> alias Front.Utils, as: Utils
      iex> Utils.decorate_relative(0)
      ""
      iex> Utils.decorate_relative(nil)
      ""
      iex> Utils.decorate_relative(1616425200)
      "2 days ago"

      iex> Utils.decorate_relative(~U[2025-03-07 22:05:26.833945Z])
      "Fri 07th Mar 2025"
  """
  @spec decorate_relative(integer | float | DateTime.t() | nil) :: String.t()
  def decorate_relative(0), do: ""
  def decorate_relative(nil), do: ""

  def decorate_relative(seconds) when is_integer(seconds) do
    seconds
    |> DateTime.from_unix!()
    |> decorate_relative()
  end

  def decorate_relative(date) do
    now = DateTime.utc_now()
    diff_days = Timex.diff(now, date, :days)
    diff_hours = Timex.diff(now, date, :hours)

    unssufixed_date = Timex.format!(date, "%a %d %b %Y", :strftime)
    [weekday, day, month, year] = String.split(unssufixed_date, " ")
    suffixed_day = day <> ordinal_suffix(String.to_integer(day))

    cond do
      diff_days > 3 ->
        "on #{weekday} #{suffixed_day} #{month} #{year}"

      diff_hours >= 1 and diff_days <= 3 ->
        time_part = Timex.format!(date, "%H:%M", :strftime)
        "on #{weekday} #{suffixed_day} #{month} #{year} at #{time_part}"

      true ->
        Timex.format!(date, "{relative}", :relative)
    end
  end

  defp ordinal_suffix(day) when day in [11, 12, 13], do: "th"

  defp ordinal_suffix(day) do
    case rem(day, 10) do
      1 -> "st"
      2 -> "nd"
      3 -> "rd"
      _ -> "th"
    end
  end
end
