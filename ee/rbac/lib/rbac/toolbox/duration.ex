defmodule Rbac.Toolbox.Duration do
  def seconds(n) do
    :timer.seconds(n)
  end

  def minutes(n) do
    seconds(n * 60)
  end

  def hours(n) do
    minutes(n * 60)
  end
end
