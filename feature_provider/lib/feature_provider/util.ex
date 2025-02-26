defmodule FeatureProvider.Util do
  @type maybe :: ok | err
  @type maybe(type) :: ok(type) | err
  @type maybe(type, error_type) :: ok(type) | err(error_type)
  @type ok :: {:ok, any()}
  @type ok(type) :: {:ok, type}
  @type err :: {:error, any()} | :error
  @type err(type) :: {:error, type} | :error
  @type callback :: (any() -> any())

  @spec ok(any()) :: ok()
  def ok(item), do: {:ok, item}

  @spec err(any()) :: err()
  def err(item), do: {:error, item}

  def wrap(ok = {:ok, _}), do: ok
  def wrap(err = {:error, _}), do: err
  def wrap(:error), do: err("generic error")
  def wrap(other), do: ok(other)

  @spec unwrap(any() | maybe(), callback()) :: maybe(any())
  def unwrap(:error, _), do: err("generic error")
  def unwrap({:error, _} = error, _), do: error
  def unwrap({:ok, value}, callback) when is_function(callback, 1), do: callback.(value)
  def unwrap(value, callback), do: unwrap(ok(value), callback)

  @spec unwrap!({:ok, value :: any()}) :: any()
  def unwrap!({:ok, value}), do: value

  @spec on_error(result :: maybe(), callback()) :: maybe()
  def on_error({:error, _} = error, callback) when is_function(callback, 1), do: callback.(error)
  def on_error(ok, _), do: ok

  defmacro log_fun(variables_to_log) do
    module = __CALLER__.module
    fun = __CALLER__.function |> elem(0)
    vars = variables_to_log

    quote do
      require Logger

      module =
        unquote(module)
        |> Atom.to_string()
        |> String.trim("Elixir.")

      fun = unquote(fun)
      vars = unquote(vars)

      inspected_values =
        vars
        |> Keyword.drop([:exception])
        |> Enum.map_join(" ", fn {key, value} ->
          "#{key}=#{inspect(value)}"
        end)

      cond do
        vars[:error] ->
          Logger.error("#{module}.#{fun}#fail #{inspected_values}")

        vars[:exception] ->
          Logger.error("#{module}.#{fun}#fail #{inspected_values}\n#{vars[:exception]}")

        true ->
          Logger.info("#{module}.#{fun}#success #{inspected_values}")
      end
    end
  end
end
