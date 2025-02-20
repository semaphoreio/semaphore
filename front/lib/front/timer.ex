defmodule Front.Timer do
  def duration(pipeline) do
    cond do
      pipeline.running_at.nanos == 0 ->
        0

      pipeline.done_at.nanos == 0 ->
        :os.system_time(:seconds) - pipeline.running_at.seconds

      true ->
        pipeline.done_at.seconds - pipeline.running_at.seconds
    end
  end
end
