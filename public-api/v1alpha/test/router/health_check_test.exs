defmodule Router.HealthCheckTest do
  use ExUnit.Case

  import Test.PipelinesClient, only: [url: 0, headers: 0]

  test "router healt_check responds" do
    assert {:ok, response} = get_health_check()
    assert %{:body => "pong", :status_code => 200} = response
  end

  defp get_health_check(), do: HTTPoison.get(url() <> "/health_check/ping", headers())
end
