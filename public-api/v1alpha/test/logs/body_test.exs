defmodule PipelinesAPI.Logs.Body.Test do
  use ExUnit.Case
  use Plug.Test

  import ExUnit.CaptureLog

  alias PipelinesAPI.Logs.Body

  setup do
    previous = Application.get_env(:pipelines_api, :logs_commit_bytes)
    Application.put_env(:pipelines_api, :logs_commit_bytes, 1)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:pipelines_api, :logs_commit_bytes, previous),
        else: Application.delete_env(:pipelines_api, :logs_commit_bytes)
    end)
  end

  test "an exception after the 200 was sent aborts the response" do
    {:cont, body} = conn(:get, "/") |> Body.new() |> Body.add([~s({"n":1})])
    assert Body.sent?(body)

    capture_log(fn ->
      assert catch_exit(Body.add(body, [:not_iodata])) == :log_stream_aborted
    end)
  end

  test "an exception before anything was sent is raised, so the caller can answer with an error" do
    body = conn(:get, "/") |> Body.new()

    assert_raise ArgumentError, fn -> Body.add(body, [:not_iodata]) end
  end

  test "the body is the same whether it was sent at once or in chunks" do
    batches = [[~s({"n":1}), ~s({"n":2})], [], [~s({"n":3})]]

    chunked =
      batches
      |> Enum.reduce(conn(:get, "/") |> Body.new(), fn events, body ->
        {:cont, body} = Body.add(body, events)
        body
      end)
      |> Body.finish()

    Application.put_env(:pipelines_api, :logs_commit_bytes, 1_000_000)

    whole =
      batches
      |> Enum.reduce(conn(:get, "/") |> Body.new(), fn events, body ->
        {:cont, body} = Body.add(body, events)
        body
      end)
      |> Body.finish()

    assert chunked.state == :chunked
    assert whole.state == :sent
    assert chunked.resp_body == whole.resp_body
    assert whole.resp_body == ~s({ "events": [{"n":1},{"n":2},{"n":3}] })
  end
end
