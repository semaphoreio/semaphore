defmodule HooksReceiver.Application do
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    alias Plug.Cowboy

    # Define workers and child supervisors to be supervised
    children = [
      # Starts a worker by calling: HooksReceiver.Worker.start_link(arg1, arg2, arg3)
      # worker(HooksReceiver.Worker, [arg1, arg2, arg3]),
      Cowboy.child_spec(
        scheme: :http,
        plug: HooksReceiver.Router,
        options: [port: 4000]
      ),
      # Add Cachex supervisor for license cache
      {Cachex, name: :license_cache}
    ]

    # Disables too verbose logging from amqp supervisors
    :logger.add_primary_filter(
      :ignore_rabbitmq_progress_reports,
      {&:logger_filters.domain/2, {:stop, :equal, [:progress]}}
    )

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: HooksReceiver.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
