defmodule Looper.STM.Publisher do
  @moduledoc """
  Module serves to publish state-change events on RabbitMQ.
  """

  alias Util.ToTuple
  alias Looper.Publisher.AMQP, as: AmqpPublisher

  def publish(ids, state, publisher_cb) do
    with state_params           <- %{state: state, timestamp: DateTime.utc_now()},
         {:ok, ids}             <- transform_ids(ids),
         params                 <- Map.merge(ids, state_params),
         {:ok, encoded_event,
               exchange_params} <- publisher_cb.(params)
    do
      exchange_params
      |> Map.put(:message, encoded_event)
      |> AmqpPublisher.publish()
    end
  end

  defp transform_ids(ids) do
     ids
     |> Map.put(:pipeline_id, Map.get(ids, :ppl_id, ""))
     |> Map.delete(:ppl_id)
     |> ToTuple.ok()
  end
end
