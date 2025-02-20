defmodule PipelinesAPI.Util.ResponseValidation do
  @moduledoc false

  alias PipelinesAPI.Util.Log

  @type ok_t :: {:ok, any()} | Log.internal_error_t()

  def ok?(response = {:ok, _rsp}, _method), do: response

  def ok?({:error, error}, rpc_method),
    do: Log.internal_error(error, rpc_method)
end
