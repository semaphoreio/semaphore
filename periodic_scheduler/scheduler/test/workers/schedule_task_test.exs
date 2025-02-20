defmodule Scheduler.Workers.ScheduleTaskTest do
  use ExUnit.Case, async: true

  describe "calculate_backoff/1" do
    test "when attempts is nil then it returns 1 second" do
      assert 1_000 == Scheduler.Workers.ScheduleTask.calculate_backoff(nil)
      assert is_integer(Scheduler.Workers.ScheduleTask.calculate_backoff(nil))
    end

    test "when attempts is 0 then it returns 1 second" do
      assert 1_000 == Scheduler.Workers.ScheduleTask.calculate_backoff(0)
      assert is_integer(Scheduler.Workers.ScheduleTask.calculate_backoff(0))
    end

    test "when attempts is greater than 0 then calculates backoff" do
      fixtures = [
        {1, 5_000},
        {2, 10_000},
        {3, 20_000},
        {4, 40_000},
        {5, 60_000},
        {10, 60_000}
      ]

      Enum.each(fixtures, fn {attempts, expected} ->
        assert expected == Scheduler.Workers.ScheduleTask.calculate_backoff(attempts)
        assert is_integer(Scheduler.Workers.ScheduleTask.calculate_backoff(attempts))
      end)
    end
  end
end
