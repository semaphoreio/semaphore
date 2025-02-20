defmodule Badges.Variant do
  def calculate(nil), do: :unknown

  def calculate(pipeline),
    do: calculate(pipeline.state, pipeline.result)

  def calculate(:DONE, :STOPPED), do: :stopped
  def calculate(:DONE, :CANCELED), do: :canceled
  def calculate(:DONE, :PASSED), do: :passed
  def calculate(:DONE, :FAILED), do: :failed
  def calculate(_, _), do: :pending
end
