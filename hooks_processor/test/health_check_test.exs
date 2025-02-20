defmodule HooksProcessor.HealthCheck.Test do
  use ExUnit.Case

  alias HooksProcessor.Hooks.Processing.WorkersSupervisor
  alias HooksProcessor.Hooks.Processing.Resurrector
  alias HooksProcessor.Supervisor, as: AppSup

  test "route healt_check responds 200 when all workers are running" do
    Supervisor.start_child(AppSup, {WorkersSupervisor, []})
    Supervisor.start_child(AppSup, {Resurrector, []})

    assert {:ok, response} = get_health_check()
    assert %{:body => "pong", :status_code => 200} = response

    Supervisor.terminate_child(AppSup, WorkersSupervisor)
    Supervisor.delete_child(AppSup, WorkersSupervisor)

    Supervisor.terminate_child(AppSup, Resurrector)
    Supervisor.delete_child(AppSup, Resurrector)

    assert 6 == Supervisor.which_children(AppSup) |> length()
  end

  test "route healt_check responds with 502 and active workers list if not all are running" do
    assert {:ok, response} = get_health_check()
    assert %{:body => message, :status_code => 502} = response

    assert message ==
             "Some workers are not running. Running workers: HealthCheck.HTTP," <>
               " RabbitMQConsumer, WorkersRegistry, EctoRepo, SentryEventSupervisor, GRPC.Server.Supervisor"
  end

  test "base route returns 200" do
    assert {:ok, response} = get_base_route()
    assert %{:body => "pong", :status_code => 200} = response
  end

  test "invalid url returns 404" do
    assert {:ok, response} = HTTPoison.get(url() <> "/invalid_path", headers())
    assert %{:body => "oops", :status_code => 404} = response
  end

  def url, do: "localhost:4000"

  def headers, do: [{"Content-type", "application/json"}]

  defp get_health_check, do: HTTPoison.get(url() <> "/health_check/ping", headers())

  defp get_base_route, do: HTTPoison.get(url(), headers())
end
