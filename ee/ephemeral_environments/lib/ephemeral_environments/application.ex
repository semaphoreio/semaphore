defmodule EphemeralEnvironments.Application do
  @moduledoc false

  require Logger
  use Application

  def start(_type, _args) do
    Logger.info(
      "Starting EphemeralEnvironments in '#{Application.get_env(:ephemeral_environments, :env)}' environment"
    )

    children = [EphemeralEnvironments.Repo]

    opts = [strategy: :one_for_one, name: EphemeralEnvironments.Supervisor]
    Enum.each(children, fn child -> Logger.info("Starting #{inspect(child)}") end)
    Supervisor.start_link(children, opts)
  end
end
