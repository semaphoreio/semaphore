defmodule Front.GrpcChannelTest do
  use FrontWeb.ConnCase, async: false

  alias Front.Clients.Workflow
  alias Front.GrpcChannel
  alias InternalApi.PlumberWF.ListKeysetRequest

  setup do
    original = Application.get_env(:front, GrpcChannel, [])
    clear_pool()

    on_exit(fn ->
      Application.put_env(:front, GrpcChannel, original)
      clear_pool()
    end)

    {:ok, endpoint: Application.fetch_env!(:front, :workflow_api_grpc_endpoint)}
  end

  # The table is recreated when the holder restarts.
  defp clear_pool(attempts \\ 50) do
    :ets.delete_all_objects(GrpcChannel)
  rescue
    ArgumentError ->
      if attempts > 0 do
        Process.sleep(20)
        clear_pool(attempts - 1)
      end
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

  test "one caller refreshes an expired connection, the rest keep the old one", %{
    endpoint: endpoint
  } do
    configure(pool_size: 1, max_age_ms: 60_000, close_grace_ms: 60_000)
    {:ok, old_channel} = GrpcChannel.connect(endpoint)
    old = conn_pid({:ok, old_channel})

    configure(pool_size: 1, max_age_ms: 200, close_grace_ms: 60_000)
    Process.sleep(250)

    pids =
      1..30
      |> Enum.map(fn _ -> Task.async(fn -> conn_pid(GrpcChannel.connect(endpoint)) end) end)
      |> Enum.map(&Task.await/1)
      |> Enum.uniq()

    new = conn_pid(GrpcChannel.connect(endpoint))
    assert new != old
    assert Enum.all?(pids, &(&1 in [old, new]))

    # The replaced connection still serves calls during the grace period.
    assert Process.alive?(old)
    assert {:ok, _} = rpc(old_channel, endpoint)
  end

  test "different endpoints never share a connection", %{endpoint: endpoint} do
    configure(pool_size: 1)
    other = Application.fetch_env!(:front, :repo_proxy_grpc_endpoint)

    assert endpoint != other
    assert conn_pid(GrpcChannel.connect(endpoint)) != conn_pid(GrpcChannel.connect(other))
    assert :ets.info(GrpcChannel, :size) == 2
  end

  test "a gun_down evicts and closes the connection", %{endpoint: endpoint} do
    configure(pool_size: 1)
    pid = conn_pid(GrpcChannel.connect(endpoint))
    ref = Process.monitor(pid)

    send(Process.whereis(GrpcChannel), {:gun_down, pid, :http2, :closed, []})
    assert_receive {:DOWN, ^ref, :process, ^pid, _}, 5_000

    assert conn_pid(GrpcChannel.connect(endpoint)) != pid
  end

  test "release closes the channel only when pooling is off", %{endpoint: endpoint} do
    configure(pool_size: 1)
    {:ok, pooled} = GrpcChannel.connect(endpoint)
    assert :ok = GrpcChannel.release(pooled)
    assert Process.alive?(conn_pid({:ok, pooled}))

    configure(pool_size: 0)
    {:ok, own} = GrpcChannel.connect(endpoint)
    pid = conn_pid({:ok, own})
    ref = Process.monitor(pid)
    assert :ok = GrpcChannel.release(own)
    assert_receive {:DOWN, ^ref, :process, ^pid, _}, 5_000
  end

  test "call retries once on a fresh connection after a transport error", %{endpoint: endpoint} do
    configure(pool_size: 1)
    {:ok, attempts} = Agent.start_link(fn -> [] end)

    result =
      GrpcChannel.call(endpoint, fn channel ->
        Agent.update(attempts, &[conn_pid({:ok, channel}) | &1])

        if length(Agent.get(attempts, & &1)) == 1 do
          {:error, GRPC.RPCError.exception(GRPC.Status.unknown(), ":stream_error: :closed")}
        else
          rpc(channel, endpoint)
        end
      end)

    assert {:ok, _} = result
    assert [second, first] = Agent.get(attempts, & &1)
    assert second != first
  end

  test "call does not retry server errors or deadlines", %{endpoint: endpoint} do
    configure(pool_size: 1)

    for error <- [
          GRPC.RPCError.exception(GRPC.Status.internal(), "boom from the server"),
          GRPC.RPCError.exception(
            GRPC.Status.deadline_exceeded(),
            "timeout when waiting for server"
          ),
          GRPC.RPCError.exception(GRPC.Status.unavailable(), "down for maintenance")
        ] do
      {:ok, calls} = Agent.start_link(fn -> 0 end)

      assert {:error, ^error} =
               GrpcChannel.call(endpoint, fn _ ->
                 Agent.update(calls, &(&1 + 1))
                 {:error, error}
               end)

      assert Agent.get(calls, & &1) == 1
    end
  end

  test "call does not retry when pooling is off", %{endpoint: endpoint} do
    configure(pool_size: 0)
    {:ok, calls} = Agent.start_link(fn -> 0 end)
    error = GRPC.RPCError.exception(GRPC.Status.unknown(), ":down: :noproc")

    assert {:error, ^error} =
             GrpcChannel.call(endpoint, fn _ ->
               Agent.update(calls, &(&1 + 1))
               {:error, error}
             end)

    assert Agent.get(calls, & &1) == 1
  end

  test "call returns the connect error without calling fun" do
    configure(pool_size: 1)
    assert {:error, _} = GrpcChannel.call("127.0.0.1:1", fn _ -> flunk("called") end)
  end

  test "transport_error? only matches errors raised by the client transport" do
    assert GrpcChannel.transport_error?({:error, GRPC.RPCError.exception(2, ":down: :normal")})
    assert GrpcChannel.transport_error?({:error, GRPC.RPCError.exception(13, ":stream_error: x")})

    assert GrpcChannel.transport_error?(
             {:error, GRPC.RPCError.exception(2, ":connection_error: y")}
           )

    refute GrpcChannel.transport_error?({:error, GRPC.RPCError.exception(13, "server said no")})
    refute GrpcChannel.transport_error?({:error, GRPC.RPCError.exception(14, ":down: :normal")})
    refute GrpcChannel.transport_error?({:error, "Error when opening connection: :timeout"})
    refute GrpcChannel.transport_error?({:ok, :anything})
  end

  test "keeps working while the holder restarts", %{endpoint: endpoint} do
    configure(pool_size: 1)
    holder = Process.whereis(GrpcChannel)
    ref = Process.monitor(holder)
    Process.exit(holder, :kill)
    assert_receive {:DOWN, ^ref, :process, ^holder, _}

    # Either the fallback or the restarted pool answers; nothing raises.
    assert {:ok, _} = GrpcChannel.connect(endpoint)
    assert {:ok, _} = Workflow.list_keyset(ListKeysetRequest.new())
  end

  defp rpc(channel, _endpoint) do
    InternalApi.PlumberWF.WorkflowService.Stub.list_keyset(channel, ListKeysetRequest.new())
  end
end
