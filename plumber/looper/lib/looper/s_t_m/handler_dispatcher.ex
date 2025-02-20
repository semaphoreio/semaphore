defmodule Looper.STM.HandlerDispatcher do
@moduledoc """
Invokes STM handlers:
- only termination_request handler,
- only scheduling handler or
- first termination_request handler and scheduling handler second

"""

  def call(termination_request, item, tr_handler, scheduling_handler) do
    termination_request
    |> call_tr_handler(item, tr_handler)
    |> call_scheduling_handler(scheduling_handler, item)
  end

  defp call_tr_handler(tr, _item, _tr_handler) when is_nil(tr) or tr == "", do:
    {:ok, :continue}
  defp call_tr_handler(termination_request, item, tr_handler), do:
    tr_handler.(item, termination_request)

  defp call_scheduling_handler({:ok, :continue}, scheduling_handler, item), do:
    scheduling_handler.(item)
  defp call_scheduling_handler(tr_handler_response, _scheduling_handler, _item) do
    tr_handler_response
  end
end
