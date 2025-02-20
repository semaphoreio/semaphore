defmodule Ppl.Grpc.InFlightCounter do
  @moduledoc false

  alias Ppl.Grpc.ProcessCounter
  alias GRPC.{RPCError, Status}

  @metric_name "Ppl.InFlightCounter"

  def start_link(args), do: ProcessCounter.start_link(args)

  def child_spec(opts) do
    ProcessCounter.child_spec(opts)
  end

  def register(type) do
    ProcessCounter.register(type)
    |> case do
      :accept ->
        :accept

      :reject ->
        Watchman.increment({@metric_name, [type, :resources_exhausted]})

        raise RPCError.exception(
          Status.resource_exhausted(),
          "Too many requests, resources exhausted, try again later."
        )
    end
  end

  def count(type), do: ProcessCounter.count(type)

  def set_limit(type, limit), do: ProcessCounter.set_limit(type, limit)
end
