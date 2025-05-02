defmodule Mix.Tasks.Dev.Server do
  use Mix.Task
  @shortdoc "Starts the Phoenix server and initializes support stubs"

  @moduledoc """
  Starts the Phoenix server and runs Support.Stubs.init/0 before boot.
  """

  def run(args) do
    # Ensure the app is started
    # Mix.Task.run("app.start", [])

    # Delegate to the standard Phoenix server task
    Mix.Tasks.Phx.Server.run(args)

    # Attempt to call Support.Stubs.init/0 if it exists
    maybe_init_stubs()
    # Support.Stubs.build_shared_factories()
    user = Support.Stubs.User.create_default()
    Support.Stubs.Organization.create_default(owner_id: user.id)
    Support.Stubs.Delivery.seed_default_data()
  end

  defp maybe_init_stubs do
    try do
      if Code.ensure_loaded?(Support.Stubs) and function_exported?(Support.Stubs, :init, 0) do
        Support.Stubs.init()
      end
    rescue
      _ -> :ok
    end
  end
end
