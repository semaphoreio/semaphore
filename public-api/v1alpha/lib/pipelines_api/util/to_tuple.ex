defmodule PipelinesAPI.Util.ToTuple do
  @moduledoc false

  @spec ok(any()) :: {:ok, any()}
  def ok(item), do: {:ok, item}

  @spec error(any()) :: {:error, any()}
  def error(item), do: {:error, item}

  @type user_error_t :: {:error, {:user, any()}}
  @spec user_error(any()) :: user_error_t
  def user_error(item), do: {:user, item} |> error()

  @type refused_error_t :: {:error, {:refused, any()}}
  @spec refused_error(any()) :: refused_error_t
  def refused_error(item), do: {:refused, item} |> error()

  @type not_found_error_t :: {:error, {:not_found, any()}}
  @spec not_found_error(any()) :: not_found_error_t
  def not_found_error(item), do: {:not_found, item} |> error()

  @type internal_error_t :: {:error, {:internal, any()}}
  @spec internal_error(any()) :: internal_error_t
  def internal_error(item), do: {:internal, item} |> error()
end
