defmodule Gofer.Application do
  @moduledoc false
  use Application

  @children [
    Gofer.EctoRepo,
    Gofer.Engines,
    Gofer.Grpc,
    Gofer.Cache,
    Gofer.Metrics
  ]

  def start(_type, _args) do
    Supervisor.start_link(Enum.filter(@children, &start_child?/1),
      strategy: :one_for_one,
      name: Gofer.Supervisor
    )
  end

  defp start_child?(Gofer.EctoRepo), do: true
  defp start_child?(module), do: Application.fetch_env!(:gofer, to_config_key(module))

  defp to_config_key(module) do
    "start_#{module |> Module.split() |> List.last()}?"
    |> String.downcase()
    |> String.to_existing_atom()
  end
end
