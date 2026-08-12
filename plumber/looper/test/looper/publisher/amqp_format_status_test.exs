defmodule Looper.Publisher.AMQPFormatStatusTest do
  use ExUnit.Case, async: true

  @raw_url "amqp://guest:sup3rSecr3t@rabbitmq.internal:5672"

  test "format_status/2 strips the url from the reported state" do
    state = %{url: @raw_url, channel: :fake_channel, exchanges: ["e1"]}

    [{:data, [{_label, sanitized_state}]}] =
      Looper.Publisher.AMQP.format_status(:normal, [[], state])

    refute sanitized_state.url == @raw_url
    refute String.contains?(inspect(sanitized_state), "sup3rSecr3t")
    assert sanitized_state.url == "[FILTERED]"
  end

  test "format_status/2 leaves the other state fields untouched" do
    state = %{url: @raw_url, channel: :fake_channel, exchanges: ["e1", "e2"]}

    [{:data, [{_label, sanitized_state}]}] =
      Looper.Publisher.AMQP.format_status(:normal, [[], state])

    assert sanitized_state.channel == :fake_channel
    assert sanitized_state.exchanges == ["e1", "e2"]
  end
end
