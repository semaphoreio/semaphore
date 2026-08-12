defmodule GithubNotifier.Services.RetryConfigTest do
  use ExUnit.Case, async: true

  alias GithubNotifier.Services

  @consumers [
    Services.BlockFinishedNotifier,
    Services.PipelineStartedNotifier,
    Services.PipelineFinishedNotifier,
    Services.PipelineSummaryAvailableNotifier
  ]

  # A failed status delivery is redelivered until the retry budget runs out,
  # then dead-lettered. 30 retries spaced 30s apart keep a status alive for
  # ~15 minutes — long enough to ride out a provider outage or a held
  # delivery-guard lease, both of which fail single deliveries for minutes.
  # retry_config/0 exposes the same attributes each consumer passes to
  # Tackle.Consumer, so this pins the effective budget without needing AMQP.
  test "status consumers keep a ~15 minute retry budget" do
    for consumer <- @consumers do
      assert consumer.retry_config() == %{retry_delay: 30, retry_limit: 30},
             "#{inspect(consumer)} retry budget drifted"
    end
  end
end
