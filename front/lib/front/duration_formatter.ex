defmodule Front.DurationFormatter do
  @seconds_per_minute 60
  @seconds_per_hour @seconds_per_minute * 60
  @seconds_per_day @seconds_per_hour * 24

  def format(seconds) do
    days = div(seconds, @seconds_per_day)
    hours = div(rem(seconds, @seconds_per_day), @seconds_per_hour)
    minutes = div(rem(seconds, @seconds_per_hour), @seconds_per_minute)
    seconds = rem(seconds, @seconds_per_minute)

    format(days, hours, minutes, seconds)
  end

  def format(days, hours, minutes, seconds)

  def format(0, 0, minutes, seconds),
    do: "#{two_digits(minutes)}:#{two_digits(seconds)}"

  def format(0, hours, minutes, seconds),
    do: "#{two_digits(hours)}:#{two_digits(minutes)}:#{two_digits(seconds)}"

  def format(days, hours, minutes, seconds),
    do: "#{days}d #{two_digits(hours)}:#{two_digits(minutes)}:#{two_digits(seconds)}"

  defp two_digits(number) do
    if number < 10 do
      "0#{number}"
    else
      "#{number}"
    end
  end
end
