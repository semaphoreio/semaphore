defmodule PipelinesAPI.Util.Log do
  @moduledoc false

  alias LogTee, as: LT
  alias PipelinesAPI.Util.ToTuple

  @type error_t :: internal_error_t | user_error_t
  @type internal_error_t :: {:error, {:internal, String.t()}}
  @spec internal_error(any(), String.t(), String.t()) :: internal_error_t
  def internal_error(reason, rpc_method, service \\ "Pipelines") do
    reason |> LT.error("#{service} service responded to #{rpc_method} with:")
    ToTuple.internal_error("Internal error")
  end

  @type user_error_t :: ToTuple.user_error_t()
  @spec user_error(any()) :: user_error_t
  def user_error(reason), do: ToTuple.user_error(reason)
end
