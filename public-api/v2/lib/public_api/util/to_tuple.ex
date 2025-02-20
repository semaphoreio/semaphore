defmodule PublicAPI.Util.ToTuple do
  @moduledoc false

  @type maybe_result :: ok_tuple | err_tuple
  @type maybe_result(type) :: ok_tuple(type) | err_tuple
  @type maybe_result(type, error_type) :: ok_tuple(type) | err_tuple(error_type)
  @type ok_tuple :: {:ok, any()}
  @type ok_tuple(type) :: {:ok, type}
  @type err_tuple :: {:error, any()} | {:error, any(), any()} | {:error, any(), any(), any()}
  @type err_tuple(type) :: {:error, type} | {:error, any(), type} | {:error, any(), type, any()}
  @type callback :: (any() -> any())

  @type user_error_t :: {:error, {:user, any()}}
  @spec user_error(any()) :: user_error_t
  def user_error(item), do: {:user, item} |> error()

  @type not_found_error_t :: {:error, {:not_found, any()}}
  @spec not_found_error(any()) :: not_found_error_t
  def not_found_error(item), do: {:not_found, item} |> error()

  @type internal_error_t :: {:error, {:internal, any()}}
  @spec internal_error(any()) :: internal_error_t
  def internal_error(item), do: {:internal, item} |> error()

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
  def unwrap_error({:error, error_value}, fun) when is_function(fun, 1) do
    fun.(error_value)
  end

  def unwrap_error(:error, fun) when is_function(fun, 1) do
    fun.(:error)
  end

  def unwrap_error(ok_tuple = {:ok, _}, _), do: ok_tuple
  def unwrap_error(other_value, _), do: {:ok, other_value}
end
