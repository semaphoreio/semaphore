defmodule Test.Support.GrpcServerHelper do
  @moduledoc """
  Helper module for managing GRPC servers in tests.
  Provides functionality to start servers on random available ports and handle cleanup.
  """

  @doc """
  Starts a GRPC server on a random available port.
  Returns {:ok, port} on success, {:error, reason} on failure.
  """
  def start_server(server_module) do
    port = get_available_port()
    case GRPC.Server.start(server_module, port) do
      {:ok, _, ^port} -> {:ok, port}
      error -> error
    end
  end

  @doc """
  Starts a GRPC server and registers cleanup in ExUnit.
  Returns {:ok, %{port: port}} for use in test context.
  """
  def start_server_with_cleanup(server_module) do
    case start_server(server_module) do
      {:ok, port} ->
        ExUnit.Callbacks.on_exit(fn ->
          try do
            GRPC.Server.stop(server_module)
          catch
            :exit, _ -> :ok
          end
        end)
        {:ok, %{port: port}}

      error ->
        raise "Failed to start GRPC server: #{inspect(error)}"
    end
  end

  @doc """
  Sets up the environment variable for a GRPC service URL.
  """
  def setup_service_url(env_var_name, port) do
    System.put_env(env_var_name, "localhost:#{port}")
  end

  # Helper to find an available port
  defp get_available_port do
    {:ok, socket} = :gen_tcp.listen(0, [])
    {:ok, port} = :inet.port(socket)
    :gen_tcp.close(socket)
    port
  end
end
