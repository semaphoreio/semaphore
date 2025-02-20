defmodule DefinitionValidator.Application do
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # Define workers and child supervisors to be supervised
    children = [
      %{
        id: DefinitionValidator.YamlMapValidator,
        start: {DefinitionValidator.YamlMapValidator, :start_link, []}
      }
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: DefinitionValidator.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
