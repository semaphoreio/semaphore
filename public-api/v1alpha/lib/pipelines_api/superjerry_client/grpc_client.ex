defmodule PipelinesAPI.SuperjerryClient.GrpcClient do
  @moduledoc "gRPC calls to the Superjerry service."

  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.Util.Log
  alias PipelinesAPI.Util.ResponseValidation, as: Resp
  alias InternalApi.Superjerry.Superjerry.Stub

  defp url(), do: System.get_env("INTERNAL_API_URL_SUPERJERRY")
  defp opts(), do: [{:timeout, timeout()}]
  defp timeout(), do: Application.get_env(:pipelines_api, :grpc_timeout)

  def list_flaky_tests({:ok, request}) do
    result =
      Wormhole.capture(__MODULE__, :list_flaky_tests_, [request],
        timeout: timeout(),
        stacktrace: true
      )

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "list_flaky_tests")
    end
  end

  def list_flaky_tests(error), do: error

  def list_flaky_tests_(request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.superjerry_client.grpc_client", ["list_flaky_tests"], fn ->
      channel
      |> Stub.list_flaky_tests(request, opts())
      |> Resp.ok?("list_flaky_tests")
    end)
  end

  def flaky_test_details({:ok, request}) do
    result =
      Wormhole.capture(__MODULE__, :flaky_test_details_, [request],
        timeout: timeout(),
        stacktrace: true
      )

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "flaky_test_details")
    end
  end

  def flaky_test_details(error), do: error

  def flaky_test_details_(request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.superjerry_client.grpc_client", ["flaky_test_details"], fn ->
      channel
      |> Stub.flaky_test_details(request, opts())
      |> Resp.ok?("flaky_test_details")
    end)
  end

  def flaky_test_disruptions({:ok, request}) do
    result =
      Wormhole.capture(__MODULE__, :flaky_test_disruptions_, [request],
        timeout: timeout(),
        stacktrace: true
      )

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "flaky_test_disruptions")
    end
  end

  def flaky_test_disruptions(error), do: error

  def flaky_test_disruptions_(request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark(
      "PipelinesAPI.superjerry_client.grpc_client",
      ["flaky_test_disruptions"],
      fn ->
        channel
        |> Stub.flaky_test_disruptions(request, opts())
        |> Resp.ok?("flaky_test_disruptions")
      end
    )
  end

  def list_flaky_history({:ok, request}) do
    result =
      Wormhole.capture(__MODULE__, :list_flaky_history_, [request],
        timeout: timeout(),
        stacktrace: true
      )

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "list_flaky_history")
    end
  end

  def list_flaky_history(error), do: error

  def list_flaky_history_(request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark("PipelinesAPI.superjerry_client.grpc_client", ["list_flaky_history"], fn ->
      channel
      |> Stub.list_flaky_history(request, opts())
      |> Resp.ok?("list_flaky_history")
    end)
  end

  def list_disruption_history({:ok, request}) do
    result =
      Wormhole.capture(__MODULE__, :list_disruption_history_, [request],
        timeout: timeout(),
        stacktrace: true
      )

    case result do
      {:ok, result} -> result
      {:error, reason} -> Log.internal_error(reason, "list_disruption_history")
    end
  end

  def list_disruption_history(error), do: error

  def list_disruption_history_(request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    Metrics.benchmark(
      "PipelinesAPI.superjerry_client.grpc_client",
      ["list_disruption_history"],
      fn ->
        channel
        |> Stub.list_disruption_history(request, opts())
        |> Resp.ok?("list_disruption_history")
      end
    )
  end
end
