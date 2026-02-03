defmodule Zebra.Machines.BrownoutScheduleTest do
  use ExUnit.Case
  doctest Zebra.Machines.BrownoutSchedule
  alias Zebra.Machines.BrownoutSchedule

  test "creates ubuntu2004 brownout schedule" do
    schedule = BrownoutSchedule.ubuntu2004()

    assert length(schedule) == 81

    [first_event | _] = schedule

    assert first_event == %{
             from: ~U[2026-02-02 00:00:00Z],
             os_images: ["ubuntu2004"],
             to: ~U[2026-02-02 00:15:00Z]
           }

    [last_event | _] = schedule |> Enum.reverse()

    assert last_event == %{
             from: ~U[2026-02-28 15:00:00Z],
             os_images: ["ubuntu2004"],
             to: ~U[2026-02-28 18:00:00Z]
           }
  end

  test "creates macos-xcode14 brownout schedule" do
    schedule = BrownoutSchedule.macosxcode14()

    assert length(schedule) == 96

    [first_event | _] = schedule

    assert first_event == %{
             from: ~U[2024-08-30 00:00:00Z],
             os_images: ["macos-xcode14"],
             to: ~U[2024-08-30 00:15:00Z]
           }

    [last_event | _] = schedule |> Enum.reverse()

    assert last_event == %{
             from: ~U[2024-09-30 15:00:00Z],
             os_images: ["macos-xcode14"],
             to: ~U[2024-09-30 18:00:00Z]
           }
  end

  describe "creating phases" do
    test "work as expected" do
      phase =
        BrownoutSchedule.phase(
          Date.range(~D[2024-01-01], ~D[2024-01-02]),
          [
            {~T[00:00:00], ~T[00:15:00]}
          ],
          ["ubuntu2004"]
        )

      assert phase == [
               %{
                 from: ~U[2024-01-01 00:00:00Z],
                 os_images: ["ubuntu2004"],
                 to: ~U[2024-01-01 00:15:00Z]
               },
               %{
                 from: ~U[2024-01-02 00:00:00Z],
                 os_images: ["ubuntu2004"],
                 to: ~U[2024-01-02 00:15:00Z]
               }
             ]
    end
  end
end
