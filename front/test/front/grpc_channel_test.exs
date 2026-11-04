defmodule Front.GrpcChannelTest do
  use FrontWeb.ConnCase, async: false

  alias Front.Clients.Workflow
  alias Front.GrpcChannel
  alias InternalApi.PlumberWF.ListKeysetRequest

  setup do
    original = Application.get_env(:front, GrpcChannel, [])
    :ets.delete_all_objects(GrpcChannel)

    on_exit(fn ->
      Application.put_env(:front, GrpcChannel, original)
      :ets.delete_all_objects(GrpcChannel)
    end)

    {:ok, endpoint: Application.fetch_env!(:front, :workflow_api_grpc_endpoint)}
  end

  defp configure(opts), do: Application.put_env(:front, GrpcChannel, opts)

  defp conn_pid({:ok, %{adapter_payload: %{conn_pid: pid}}}), do: pid

  defp in_new_process(fun), do: Task.async(fun) |> Task.await()

  test "reuses one connection across calls and processes", %{endpoint: endpoint} do
    configure(pool_size: 1)

    pid = in_new_process(fn -> conn_pid(GrpcChannel.connect(endpoint)) end)

    # The connection outlived the process that opened it.
    assert Process.alive?(pid)
    assert conn_pid(GrpcChannel.connect(endpoint)) == pid
    assert in_new_process(fn -> conn_pid(GrpcChannel.connect(endpoint)) end) == pid
  end

  test "RPCs work from many processes over the shared connection" do
    configure(pool_size: 1)

    results =
      1..20
      |> Enum.map(fn _ -> Task.async(fn -> Workflow.list_keyset(ListKeysetRequest.new()) end) end)
      |> Enum.map(&Task.await/1)

    assert Enum.all?(results, &match?({:ok, %InternalApi.PlumberWF.ListKeysetResponse{}}, &1))
    assert :ets.info(GrpcChannel, :size) == 1
  end

  test "spreads callers over the pool", %{endpoint: endpoint} do
    configure(pool_size: 4)

    pids =
      1..40
      |> Enum.map(fn _ -> in_new_process(fn -> conn_pid(GrpcChannel.connect(endpoint)) end) end)
      |> Enum.uniq()

    assert length(pids) > 1
    assert length(pids) <= 4
  end

  test "replaces a connection that went away", %{endpoint: endpoint} do
    configure(pool_size: 1)

    pid = conn_pid(GrpcChannel.connect(endpoint))
    ref = Process.monitor(pid)
    :gun.close(pid)
    assert_receive {:DOWN, ^ref, :process, ^pid, _}

    new_pid = conn_pid(GrpcChannel.connect(endpoint))
    assert new_pid != pid
    assert Process.alive?(new_pid)
    assert {:ok, _} = Workflow.list_keyset(ListKeysetRequest.new())
  end

  test "retires connections older than max age and closes them", %{endpoint: endpoint} do
    configure(pool_size: 1, max_age_ms: 0, close_grace_ms: 0)

    old = conn_pid(GrpcChannel.connect(endpoint))
    ref = Process.monitor(old)

    new = conn_pid(GrpcChannel.connect(endpoint))
    assert new != old
    assert_receive {:DOWN, ^ref, :process, ^old, _}, 5_000
  end

  test "pool size 0 opens a connection per call", %{endpoint: endpoint} do
    configure(pool_size: 0)

    a = conn_pid(GrpcChannel.connect(endpoint))
    b = conn_pid(GrpcChannel.connect(endpoint))

    assert a != b
    assert :ets.info(GrpcChannel, :size) == 0
    assert {:ok, _} = Workflow.list_keyset(ListKeysetRequest.new())
  end

  test "returns the connect error and stores nothing" do
    configure(pool_size: 1)

    assert {:error, _} = GrpcChannel.connect("127.0.0.1:1")
    assert :ets.info(GrpcChannel, :size) == 0
  end
end
