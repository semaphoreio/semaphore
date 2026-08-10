defmodule GithubNotifier.Services.RetryConfigTest do
  use ExUnit.Case, async: false

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
  test "status consumers retry deliveries for ~15 minutes before dead-lettering" do
    for consumer <- @consumers do
      pid = Process.whereis(consumer)
      assert pid, "#{inspect(consumer)} is not running (START_CONSUMERS not set?)"

      state = :sys.get_state(pid)

      assert state.retry_limit == 30, "#{inspect(consumer)} retry_limit"
      assert String.ends_with?(state.delay_queue, ".delay.30"), "#{inspect(consumer)} delay"
    end
  end
end
