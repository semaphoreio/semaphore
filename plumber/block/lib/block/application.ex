defmodule Block.Application do
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  import Supervisor.Spec, warn: false

  require Logger

  def start(_type, _args) do
    Logger.info("Running block in #{get_env()} environment")

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Block.Supervisor]
    get_env() |> children() |> Supervisor.start_link(opts)
  end

  def children(:test) do
    [
      supervisor(Block.EctoRepo, [])
    ]
  end

  def children(_), do: Enum.concat(children(:test), children_())

  def children_ do
    [
      Block.Sup.STM,
      worker(Block.Tasks.TaskEventsConsumer, []),
    ]
  end

  defp get_env do
    Application.get_env(:ppl, :environment) || Application.get_env(:block, :environment)
  end
end
