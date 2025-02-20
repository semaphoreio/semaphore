defmodule HooksProcessor.HealthCheck do
  @moduledoc """
  Exposes health_check endpoint over HTTP that checks wether all workers are running.
  This endpoint is required for liveness probe on Kubernetes cluster.
  """

  use Plug.Router

  plug(:match)
  plug(:dispatch)

  get "/health_check/ping" do
    children =
      HooksProcessor.Supervisor
      |> Supervisor.which_children()
      |> Enum.reduce([], fn {id, child, _type, _modules}, acc ->
        if is_pid(child), do: acc ++ [normalize_name(id)], else: acc
      end)

    if running?(children, "EctoRepo") and
         running?(children, "RabbitMQConsumer") and
         running?(children, "WorkersRegistry") and
         running?(children, "WorkersSupervisor") and
         running?(children, "Resurrector") do
      send_resp(conn, 200, "pong")
    else
      message =
        "Some workers are not running. " <>
          "Running workers: #{Enum.join(children, ", ")}"

      send_resp(conn, 502, message)
    end
  end

  # Root path has to return 200 OK in order to pass health checks made by ingress
  # on Kubernets
  get "/" do
    send_resp(conn, 200, "pong")
  end

  match _ do
    send_resp(conn, 404, "oops")
  end

  defp normalize_name(tuple) when is_tuple(tuple) do
    tuple |> elem(1) |> normalize_name()
  end

  defp normalize_name(atom) when is_atom(atom) do
    atom |> Atom.to_string() |> normalize_name()
  end

  defp normalize_name("Elixir.HooksProcessor.Hooks.Processing." <> name), do: name

  defp normalize_name("Elixir.HooksProcessor." <> name), do: name

  defp normalize_name("Elixir." <> name), do: name

  defp normalize_name(name), do: name

  defp running?(list, worker) do
    Enum.any?(list, fn name -> name == worker end)
  end
end
