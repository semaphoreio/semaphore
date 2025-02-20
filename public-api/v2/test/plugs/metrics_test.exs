defmodule PublicAPI.Plugs.MetricsTest do
  use ExUnit.Case
  use Plug.Test
  import Mock

  defmodule FastTestPlug do
    use Plug.Builder
    plug(PublicAPI.Plugs.Metrics, name: "fast", tags: ["tom", "jerry"])
    plug(:send_resp, 200)

    defp send_resp(conn, status) do
      Plug.Conn.send_resp(conn, status, "response")
    end
  end

  defmodule SlowTestPlug do
    use Plug.Builder
    plug(PublicAPI.Plugs.Metrics, tags: ["coyote", "roadrunner"])
    plug(:send_resp, 200)

    defp send_resp(conn, status) do
      :timer.sleep(1000)
      Plug.Conn.send_resp(conn, status, "response")
    end
  end

  defmodule ErroringTestPlug do
    use Plug.Builder
    plug(PublicAPI.Plugs.Metrics, tags: ["popeye"])
    plug(:send_resp, 500)

    defp send_resp(conn, status) do
      Plug.Conn.send_resp(conn, status, "error response")
    end
  end

  test "fast plug metric is submitted with name and tags" do
    with_mock(Watchman, [:passthrough], submit: fn _, _, _ -> :ok end) do
      conn = conn(:get, "/")
      conn = FastTestPlug.call(conn, [])
      assert conn.status == 200

      assert_called(
        Watchman.submit(
          {"fast", ["tom", "jerry"]},
          :meck.is(fn time ->
            assert time < 10
          end),
          :timing
        )
      )
    end
  end

  test "slow plug metric is submitted with tags" do
    with_mock(Watchman, [:passthrough], submit: fn _, _, _ -> :ok end) do
      conn = conn(:get, "/")
      conn = SlowTestPlug.call(conn, [])
      assert conn.status == 200

      assert_called(
        Watchman.submit(
          {"PublicAPI.router", ["coyote", "roadrunner"]},
          :meck.is(fn time ->
            assert time < 1020
            assert time > 999
          end),
          :timing
        )
      )
    end
  end

  test "crashing plug is submitting timing and error metric" do
    with_mocks([
      {Watchman, [:passthrough], [submit: fn _, _, _ -> :ok end, increment: fn _ -> :ok end]}
    ]) do
      conn(:get, "/") |> ErroringTestPlug.call([])

      assert_called(
        Watchman.submit(
          {"PublicAPI.router", ["popeye"]},
          :meck.is(fn time ->
            assert time < 10
          end),
          :timing
        )
      )

      assert_called(Watchman.increment({"PublicAPI.router", ["server_error", "popeye"]}))
    end
  end
end
