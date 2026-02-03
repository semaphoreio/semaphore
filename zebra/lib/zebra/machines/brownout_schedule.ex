defmodule Zebra.Machines.BrownoutSchedule do
  @moduledoc """
  This module is responsible for creating a brownout schedules.
  """

  alias Zebra.Machines.Brownout
  @type date_or_range :: [Date.t()] | Date.Range.t()
  @type time_period :: {Time.t(), Time.t()}

  @spec ubuntu2004 :: Brownout.brownout_schedules()
  def ubuntu2004 do
    first_phase =
      phase(
        Date.range(~D[2026-02-02], ~D[2026-02-08]),
        [
          {~T[00:00:00], ~T[00:15:00]},
          {~T[10:00:00], ~T[10:15:00]},
          {~T[15:00:00], ~T[15:15:00]}
        ],
        ["ubuntu2004"]
      )

    second_phase =
      phase(
        Date.range(~D[2026-02-09], ~D[2026-02-15]),
        [
          {~T[00:00:00], ~T[00:30:00]},
          {~T[10:00:00], ~T[10:30:00]},
          {~T[15:00:00], ~T[15:30:00]}
        ],
        ["ubuntu2004"]
      )

    third_phase =
      phase(
        Date.range(~D[2026-02-16], ~D[2026-02-22]),
        [
          {~T[00:00:00], ~T[01:00:00]},
          {~T[10:00:00], ~T[11:00:00]},
          {~T[15:00:00], ~T[16:00:00]}
        ],
        ["ubuntu2004"]
      )

    fourth_phase =
      phase(
        Date.range(~D[2026-02-23], ~D[2026-02-28]),
        [
          {~T[00:00:00], ~T[03:00:00]},
          {~T[10:00:00], ~T[13:00:00]},
          {~T[15:00:00], ~T[18:00:00]}
        ],
        ["ubuntu2004"]
      )

    first_phase ++ second_phase ++ third_phase ++ fourth_phase
  end

  @spec macosxcode14 :: Brownout.brownout_schedules()
  def macosxcode14 do
    first_phase =
      phase(
        Date.range(~D[2024-08-30], ~D[2024-09-06]),
        [
          {~T[00:00:00], ~T[00:15:00]},
          {~T[10:00:00], ~T[10:15:00]},
          {~T[15:00:00], ~T[15:15:00]}
        ],
        ["macos-xcode14"]
      )

    second_phase =
      phase(
        Date.range(~D[2024-09-07], ~D[2024-09-14]),
        [
          {~T[00:00:00], ~T[00:30:00]},
          {~T[10:00:00], ~T[10:30:00]},
          {~T[15:00:00], ~T[15:30:00]}
        ],
        ["macos-xcode14"]
      )

    third_phase =
      phase(
        Date.range(~D[2024-09-15], ~D[2024-09-22]),
        [
          {~T[00:00:00], ~T[01:00:00]},
          {~T[10:00:00], ~T[11:00:00]},
          {~T[15:00:00], ~T[16:00:00]}
        ],
        ["macos-xcode14"]
      )

    fourth_phase =
      phase(
        Date.range(~D[2024-09-23], ~D[2024-09-30]),
        [
          {~T[00:00:00], ~T[03:00:00]},
          {~T[10:00:00], ~T[13:00:00]},
          {~T[15:00:00], ~T[18:00:00]}
        ],
        ["macos-xcode14"]
      )

    first_phase ++ second_phase ++ third_phase ++ fourth_phase
  end

  @doc """
  Creates a brownout schedule for a given date and time range.
  """
  @spec phase(date_or_range, [time_period], [String.t()]) :: Brownout.brownout_schedules()
  def phase(dates, times, os_images) do
    dates
    |> Enum.flat_map(fn date ->
      times
      |> Enum.map(fn {from, to} ->
        from =
          date
          |> NaiveDateTime.new!(from)
          |> DateTime.from_naive!("Etc/UTC")

        to =
          date
          |> NaiveDateTime.new!(to)
          |> DateTime.from_naive!("Etc/UTC")

        Brownout.schedule(from, to, os_images)
      end)
    end)
  end
end
