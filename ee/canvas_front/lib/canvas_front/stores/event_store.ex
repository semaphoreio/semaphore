defmodule CanvasFront.Stores.Event do
  def get(params) do
    # hacky implementation to get events from stage store
    CanvasFront.Stores.Stage.get_queue(params)
    |> Enum.find(fn event -> event.id == Map.get(params, :event_id) end)
  end
end
