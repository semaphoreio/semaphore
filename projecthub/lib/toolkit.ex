defmodule Toolkit do
  @moduledoc """
  Utility functions used across the codebase.
  """

  @type maybe_result :: ok_tuple | err_tuple
  @type maybe_result(type) :: ok_tuple(type) | err_tuple
  @type maybe_result(type, error_type) :: ok_tuple(type) | err_tuple(error_type)
  @type ok_tuple :: {:ok, any()}
  @type ok_tuple(type) :: {:ok, type}
  @type err_tuple :: {:error, any()}
  @type err_tuple(type) :: {:error, type}
  @type callback :: (any() -> any())

  @doc ~S"""
  Unwraps a value if tuple is ok and calls the callback with the value.

  ## Examples

    iex> unwrap({:ok, 1}, & &1 + 1)
    2

    iex> unwrap(1, & &1 + 1)
    2

    iex> unwrap({:error, 1}, & &1 + 1)
    {:error, 1}

    iex> unwrap(:error, & &1 + 1)
    {:error, "generic error"}
  """
  @spec unwrap(ok_tuple | err_tuple | any, callback()) :: any
  def unwrap({:error, _} = error, _), do: error
  def unwrap(:error, _), do: {:error, "generic error"}

  def unwrap({:ok, item}, fun) when is_function(fun, 1) do
    fun.(item)
  end

  def unwrap(other, fun), do: unwrap({:ok, other}, fun)

  @doc """
  Similiar to unwrap/1 but callback is called with error tuple instead

  ## Examples

    iex> unwrap_error({:ok, 1}, & &1 + 1)
    {:ok, 1}

    iex> unwrap_error(1, & &1 + 1)
    {:ok, 1}

    iex> unwrap_error({:error, 1}, fn _ -> {:ok, "It's fine"} end)
    {:ok, "It's fine"}

    iex> unwrap_error({:error, "joe"}, fn a -> {:ok, "It's fine \#{a}"} end)
    {:ok, "It's fine joe"}

    iex> unwrap_error(:error, fn _ -> {:ok, "It's fine"} end)
    {:ok, "It's fine"}

  """
  @spec unwrap_error(ok_tuple | err_tuple | any, callback()) :: any
  def unwrap_error({:error, error_value}, fun) when is_function(fun, 1) do
    fun.(error_value)
  end

  def unwrap_error(:error, fun) when is_function(fun, 1) do
    fun.(:error)
  end

  def unwrap_error({:ok, _} = ok_tuple, _), do: ok_tuple
  def unwrap_error(other_value, _), do: {:ok, other_value}

  @doc ~S"""
  Unwraps a value if tuple is ok. Raises otherwise.

  ## Examples

    iex> unwrap!({:ok, 1})
    1

    iex> unwrap!(1)
    1

    iex> unwrap!({:error, 1})
    ** (RuntimeError) can't unwrap an error

    iex> unwrap!(:error)
    ** (RuntimeError) can't unwrap an error
  """
  @spec unwrap!(ok_tuple | err_tuple | any) :: any
  def unwrap!({:ok, value}), do: value

  def unwrap!({:error, _value}) do
    raise("can't unwrap an error")
  end

  def unwrap!(:error) do
    raise("can't unwrap an error")
  end

  def unwrap!(other) do
    other
  end

  @doc ~S"""
  Wraps arbitrary values in a tuple. Ok tuples and error tuples are passed through.

  ## Examples

      iex> wrap({:ok, "hello"})
      {:ok, "hello"}

      iex> wrap({:error, "some error"})
      {:error, "some error"}

      iex> wrap(:error)
      {:error, "generic error"}

      iex> wrap("some value")
      {:ok, "some value"}
  """
  @spec wrap(ok_tuple | err_tuple | any()) :: ok_tuple | err_tuple
  def wrap({:ok, _} = tuple), do: tuple
  def wrap({:error, _} = error), do: error
  def wrap(:error), do: {:error, "generic error"}
  def wrap(other), do: {:ok, other}

  @doc ~S"""
  Wraps given string in `t:err_tuple()`
  ## Examples

    iex> error("test")
    {:error, "test"}
  """
  @spec error(message :: String.t()) :: err_tuple(String.t())
  def error(message), do: {:error, message}

  @doc ~S"""
  Merges two keywords together. Used for supplying default values

  ## Examples

      iex> with_defaults([other_default: 100, some_other_value: "value"], [some_default: "value", other_default: 1])
      [some_default: "value", other_default: 100, some_other_value: "value"]

  """
  @spec with_defaults(keyword, keyword) :: keyword
  def with_defaults(params, defaults) do
    Keyword.merge(defaults, params)
  end

  @doc ~S"""
  Consolidates errors contained in a changeset returning list of errors.
  """
  @spec consolidate_changeset_errors(Ecto.Changeset.t()) :: String.t()
  def consolidate_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map_join(
      ", ",
      fn {key, messages} ->
        messages
        |> Enum.map_join(", ", fn message ->
          "#{key} #{message}"
        end)
      end
    )
  end

  @doc ~S"""
  Converts a given argument to string

  ## Examples

      iex> safe_string("some value")
      "some value"
      iex> safe_string(nil)
      ""
      iex> safe_string(1234)
      "1234"
      iex> safe_string(:test)
      "test"
      iex> safe_string({1,2,3,4})
      ""
      iex> safe_string(true)
      "true"
      iex> safe_string(1234.567)
      "1234.567"
  """
  @spec safe_string(any()) :: String.t()
  def safe_string(value) do
    cond do
      is_bitstring(value) -> value
      is_number(value) -> "#{value}"
      is_atom(value) -> "#{value}"
      true -> ""
    end
  end

  @doc ~S"""
  Traverses the map and converts non-string keys to strings.

  ## Examples:

    iex> stringify_keys(%{1 => "one", 2 => "two", "3" => "three"})
    %{"1" => "one", "2" => "two", "3" => "three"}

    iex> stringify_keys(%{user: %{email: "email@example.com"}, password: "secret", permissions: %{admin: true}})
    %{"user" => %{"email" => "email@example.com"}, "password" => "secret", "permissions" => %{"admin" => true}}

    iex> stringify_keys("test")
    "test"

    iex> stringify_keys([1, 2, 3, %{one: "two", three: [%{four: "five"}]}])
    [1, 2, 3, %{"one" => "two", "three" => [%{"four" => "five"}]}]

  """
  @spec stringify_keys(map) :: map
  def stringify_keys(value_to_convert) do
    stringify = fn
      value when is_bitstring(value) ->
        value

      value when is_atom(value) ->
        Atom.to_string(value)

      value ->
        inspect(value)
    end

    cond do
      is_map(value_to_convert) ->
        value_to_convert
        |> Enum.reduce(%{}, fn
          {key, value}, converted_map ->
            Map.put(converted_map, stringify.(key), stringify_keys(value))
        end)

      is_list(value_to_convert) ->
        Enum.map(value_to_convert, &stringify_keys/1)

      true ->
        value_to_convert
    end
  end

  def log_error(result, logger_opts \\ []) do
    require Logger

    result
    |> unwrap_error(fn error ->
      error
      |> inspect
      |> log(Keyword.put(logger_opts, :level, :error))

      error(error)
    end)
  end

  def generate_request_id do
    [request_id | _] =
      Ecto.UUID.generate()
      |> String.split("-")
      |> Enum.reverse()

    request_id
  end

  def log(result, opts \\ []) do
    require Logger

    level = Keyword.get(opts, :level, :info)
    env = Keyword.get(opts, :env, %{})

    logger_opts = opts |> Enum.filter(&match?({:label, _}, &1))

    metadata =
      []
      |> then(fn meta ->
        env
        |> Map.get(:function)
        |> case do
          {name, arity} -> Keyword.put(meta, :function, "#{name}/#{arity}")
          _ -> meta
        end
      end)
      |> then(fn meta ->
        env
        |> Map.get(:module)
        |> case do
          name when is_atom(name) -> Keyword.put(meta, :module, "#{name}")
          _ -> meta
        end
      end)

    result
    |> then(fn
      result when is_bitstring(result) ->
        result

      result ->
        inspect(result)
    end)
    |> tap(fn result ->
      Logger.metadata(metadata)
      Logger.log(level, result, logger_opts)

      metadata
      |> Enum.map(fn {key, _value} -> {key, nil} end)
      |> Logger.metadata()
    end)
  end
end
