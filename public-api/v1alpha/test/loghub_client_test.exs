defmodule PipelinesAPI.LoghubClient.Test do
  use ExUnit.Case
  use Plug.Test

  import ExUnit.CaptureLog

  alias PipelinesAPI.LoghubClient

  @job_id UUID.uuid4()

  setup do
    Support.Stubs.reset()
  end

  describe ".get_log_events" do
    test "successful response" do
      GrpcMock.stub(LoghubMock, :get_log_events, fn _, _ ->
        %InternalApi.Loghub.GetLogEventsResponse{
          status: ok(),
          events: ["first", "second"],
          final: true
        }
      end)

      assert {:ok, events} = LoghubClient.get_log_events(@job_id)
      assert events == ["first", "second"]
    end

    test "not found response returns a not_found error with loghub's message" do
      GrpcMock.stub(LoghubMock, :get_log_events, fn _, _ ->
        %InternalApi.Loghub.GetLogEventsResponse{
          status: not_ok("Log not found neither in the archive nor in the virtual machine"),
          events: [],
          final: true
        }
      end)

      assert {:error,
              {:not_found, "Log not found neither in the archive nor in the virtual machine"}} =
               LoghubClient.get_log_events(@job_id)
    end

    test "not found response without a message falls back to a default message" do
      GrpcMock.stub(LoghubMock, :get_log_events, fn _, _ ->
        %InternalApi.Loghub.GetLogEventsResponse{
          status: not_ok(),
          events: [],
          final: true
        }
      end)

      assert {:error, {:not_found, "Logs not found"}} = LoghubClient.get_log_events(@job_id)
    end

    test "when loghub throws" do
      GrpcMock.stub(LoghubMock, :get_log_events, fn _, _ ->
        raise "oops"
      end)

      assert {:error, {:internal, "Internal error"}} = LoghubClient.get_log_events(@job_id)
    end
  end

  describe ".stream_log_events" do
    test "joins the events of every response, in order" do
      GrpcMock.stub(LoghubMock, :stream_log_events, fn _, stream ->
        for batch <- [["first", "second"], ["third"], ["fourth", "fifth"]] do
          GRPC.Server.send_reply(stream, %InternalApi.Loghub.GetLogEventsResponse{
            status: ok(),
            events: batch,
            final: true
          })
        end
      end)

      assert LoghubClient.stream_log_events(@job_id) ==
               {:ok, ["first", "second", "third", "fourth", "fifth"]}
    end

    test "an empty log is one response with no events" do
      GrpcMock.stub(LoghubMock, :stream_log_events, fn _, stream ->
        GRPC.Server.send_reply(stream, %InternalApi.Loghub.GetLogEventsResponse{
          status: ok(),
          events: [],
          final: true
        })
      end)

      assert LoghubClient.stream_log_events(@job_id) == {:ok, []}
    end

    test "a not found response returns a not_found error with loghub's message" do
      GrpcMock.stub(LoghubMock, :stream_log_events, fn _, stream ->
        GRPC.Server.send_reply(stream, %InternalApi.Loghub.GetLogEventsResponse{
          status: not_ok("Log not found neither in the archive nor in the virtual machine"),
          events: [],
          final: true
        })
      end)

      assert LoghubClient.stream_log_events(@job_id) ==
               {:error,
                {:not_found, "Log not found neither in the archive nor in the virtual machine"}}
    end

    test "an error after some responses fails the whole call" do
      GrpcMock.stub(LoghubMock, :stream_log_events, fn _, stream ->
        GRPC.Server.send_reply(stream, %InternalApi.Loghub.GetLogEventsResponse{
          status: ok(),
          events: ["first"],
          final: true
        })

        raise GRPC.RPCError, status: GRPC.Status.data_loss(), message: "corrupt"
      end)

      capture_log(fn ->
        assert LoghubClient.stream_log_events(@job_id) == {:error, {:internal, "Internal error"}}
      end)
    end

    test "UNAVAILABLE is a retryable error" do
      GrpcMock.stub(LoghubMock, :stream_log_events, fn _, stream ->
        GRPC.Server.send_headers(stream, %{})
        raise GRPC.RPCError, status: GRPC.Status.unavailable(), message: "busy"
      end)

      capture_log(fn ->
        assert LoghubClient.stream_log_events(@job_id) ==
                 {:error, {:unavailable, "Logs are temporarily unavailable, please retry"}}
      end)
    end

    test "a stream with no responses at all is a retryable error, not an empty log" do
      GrpcMock.stub(LoghubMock, :stream_log_events, fn _, stream ->
        GRPC.Server.send_headers(stream, %{})
      end)

      capture_log(fn ->
        assert LoghubClient.stream_log_events(@job_id) ==
                 {:error, {:unavailable, "Logs are temporarily unavailable, please retry"}}
      end)
    end

    test "DATA_LOSS (corrupt stored log) is an internal error, not retryable" do
      GrpcMock.stub(LoghubMock, :stream_log_events, fn _, stream ->
        GRPC.Server.send_headers(stream, %{})
        raise GRPC.RPCError, status: GRPC.Status.data_loss(), message: "corrupt"
      end)

      capture_log(fn ->
        assert LoghubClient.stream_log_events(@job_id) == {:error, {:internal, "Internal error"}}
      end)
    end

    test "the GetLogEvents fallback maps UNAVAILABLE to a retryable error too" do
      GrpcMock.stub(LoghubMock, :stream_log_events, fn _, _ ->
        raise GRPC.RPCError, status: GRPC.Status.unimplemented(), message: "unimplemented"
      end)

      GrpcMock.stub(LoghubMock, :get_log_events, fn _, _ ->
        raise GRPC.RPCError, status: GRPC.Status.unavailable(), message: "busy"
      end)

      capture_log(fn ->
        assert LoghubClient.stream_log_events(@job_id) ==
                 {:error, {:unavailable, "Logs are temporarily unavailable, please retry"}}
      end)
    end

    # A real gRPC server whose service has no StreamLogEvents (like a loghub
    # deployed before it existed). grpc-elixir answers it with UNKNOWN, not
    # UNIMPLEMENTED.
    test "against a loghub without StreamLogEvents, falls back to GetLogEvents" do
      port =
        Support.LegacyLoghub.start(fn _req, _stream ->
          %InternalApi.Loghub.GetLogEventsResponse{
            status: ok(),
            events: ["from", "unary"],
            final: true
          }
        end)

      previous = System.get_env("LOGHUB_API_URL")
      System.put_env("LOGHUB_API_URL", "127.0.0.1:#{port}")

      on_exit(fn ->
        System.put_env("LOGHUB_API_URL", previous)
        Support.LegacyLoghub.stop()
      end)

      log =
        capture_log(fn ->
          assert LoghubClient.stream_log_events(@job_id) == {:ok, ["from", "unary"]}
        end)

      assert log =~ "falling back to GetLogEvents"
    end

    test "falls back to GetLogEvents when loghub doesn't implement the stream" do
      GrpcMock.stub(LoghubMock, :stream_log_events, fn _, _ ->
        raise GRPC.RPCError, status: GRPC.Status.unimplemented(), message: "unimplemented"
      end)

      GrpcMock.stub(LoghubMock, :get_log_events, fn _, _ ->
        %InternalApi.Loghub.GetLogEventsResponse{status: ok(), events: ["unary"], final: true}
      end)

      assert LoghubClient.stream_log_events(@job_id) == {:ok, ["unary"]}
    end
  end

  describe ".stream_log_events timeouts and consistency" do
    test "a status change within the stream ([OK, OK, BAD_PARAM]) is an internal error" do
      GrpcMock.stub(LoghubMock, :stream_log_events, fn _, stream ->
        for events <- [["a"], ["b"]] do
          GRPC.Server.send_reply(stream, %InternalApi.Loghub.GetLogEventsResponse{
            status: ok(),
            events: events,
            final: true
          })
        end

        GRPC.Server.send_reply(stream, %InternalApi.Loghub.GetLogEventsResponse{
          status: not_ok("Log not found neither in the archive nor in the virtual machine"),
          events: [],
          final: true
        })
      end)

      capture_log(fn ->
        assert LoghubClient.stream_log_events(@job_id) == {:error, {:internal, "Internal error"}}
      end)
    end

    test "a stream that outlives the loghub deadline is a retryable error" do
      GrpcMock.stub(LoghubMock, :stream_log_events, fn _, stream ->
        GRPC.Server.send_headers(stream, %{})
        # The test deadline is 1s (config/test.exs).
        Process.sleep(3_000)
      end)

      capture_log(fn ->
        assert LoghubClient.stream_log_events(@job_id) ==
                 {:error, {:unavailable, "Logs are temporarily unavailable, please retry"}}
      end)
    end

    # When the HTTP request goes away, the process calling loghub is killed.
    # gun then closes the connection only after its closing_timeout (15s by
    # default), and until then loghub keeps streaming, holding a fetch slot.
    test "when the caller is killed mid-stream, loghub's handler ends within about 2s" do
      previous = Application.get_env(:pipelines_api, :loghub_stream_timeout)
      Application.put_env(:pipelines_api, :loghub_stream_timeout, 60_000)
      on_exit(fn -> Application.put_env(:pipelines_api, :loghub_stream_timeout, previous) end)

      test = self()

      GrpcMock.stub(LoghubMock, :stream_log_events, fn _, stream ->
        GRPC.Server.send_reply(stream, %InternalApi.Loghub.GetLogEventsResponse{
          status: ok(),
          events: ["first"],
          final: true
        })

        send(test, {:first_batch_sent, self()})
        Process.sleep(60_000)
      end)

      caller = spawn(fn -> LoghubClient.stream_log_events(@job_id) end)

      assert_receive {:first_batch_sent, handler}, 5_000
      ref = Process.monitor(handler)

      Process.exit(caller, :kill)

      assert_receive {:DOWN, ^ref, :process, ^handler, _}, 2_500
    end
  end

  describe ".stream_log_events/3" do
    # gun's own timeout only bounds the wait for each message; a stream that
    # keeps sending small batches would run on without the watchdog.
    test "a stream that keeps sending past the deadline is cut at the deadline" do
      GrpcMock.stub(LoghubMock, :stream_log_events, fn _, stream ->
        for i <- 1..15 do
          GRPC.Server.send_reply(stream, %InternalApi.Loghub.GetLogEventsResponse{
            status: ok(),
            events: ["line #{i}"],
            final: true
          })

          Process.sleep(150)
        end
      end)

      capture_log(fn ->
        # The test deadline is 1s (config/test.exs); the stream takes 2.25s.
        {elapsed, result} = :timer.tc(fn -> LoghubClient.stream_log_events(@job_id) end)

        assert result ==
                 {:error, {:unavailable, "Logs are temporarily unavailable, please retry"}}

        assert elapsed < 1_600_000
      end)
    end

    test "the loghub connection is closed when the call returns" do
      GrpcMock.stub(LoghubMock, :stream_log_events, fn _, stream ->
        GRPC.Server.send_reply(stream, %InternalApi.Loghub.GetLogEventsResponse{
          status: ok(),
          events: ["only"],
          final: true
        })
      end)

      before = gun_connections()
      assert LoghubClient.stream_log_events(@job_id) == {:ok, ["only"]}
      # gun closes asynchronously.
      Process.sleep(100)
      assert gun_connections() == before
    end

    test "fun can stop the call, which cancels the loghub stream" do
      test = self()

      GrpcMock.stub(LoghubMock, :stream_log_events, fn _, stream ->
        for i <- 1..3 do
          GRPC.Server.send_reply(stream, %InternalApi.Loghub.GetLogEventsResponse{
            status: ok(),
            events: ["line #{i}"],
            final: true
          })
        end

        send(test, {:handler, self()})
        Process.sleep(60_000)
      end)

      assert LoghubClient.stream_log_events(@job_id, [], fn events, acc ->
               {:halt, [events | acc]}
             end) == {:halted, [["line 1"]]}

      assert_receive {:handler, handler}, 2_000
      ref = Process.monitor(handler)
      assert_receive {:DOWN, ^ref, :process, ^handler, _}, 1_000
    end
  end

  describe ".stream_log_events errors that must not fall back" do
    # What a current loghub does when its handler fails (e.g. the job API is
    # down): headers first, then the error. That must not look like an older
    # loghub, so no GetLogEvents retry.
    test "a handler that fails after sending headers is an error, without a GetLogEvents retry" do
      GrpcMock.stub(LoghubMock, :stream_log_events, fn _, stream ->
        GRPC.Server.send_headers(stream, %{})
        raise GRPC.RPCError, status: GRPC.Status.unknown(), message: "Internal Server Error"
      end)

      GrpcMock.stub(LoghubMock, :get_log_events, fn _, _ -> flunk("must not fall back") end)

      log =
        capture_log(fn ->
          assert LoghubClient.stream_log_events(@job_id) ==
                   {:error, {:internal, "Internal error"}}
        end)

      refute log =~ "falling back"
    end

    test "UNKNOWN after the stream started is an internal error, without a GetLogEvents retry" do
      GrpcMock.stub(LoghubMock, :stream_log_events, fn _, stream ->
        GRPC.Server.send_headers(stream, %{})
        raise "boom"
      end)

      GrpcMock.stub(LoghubMock, :get_log_events, fn _, _ -> flunk("must not fall back") end)

      capture_log(fn ->
        assert LoghubClient.stream_log_events(@job_id) == {:error, {:internal, "Internal error"}}
      end)
    end

    test "UNAVAILABLE before the stream started is retryable, without a GetLogEvents retry" do
      GrpcMock.stub(LoghubMock, :stream_log_events, fn _, _ ->
        raise GRPC.RPCError, status: GRPC.Status.unavailable(), message: "busy"
      end)

      GrpcMock.stub(LoghubMock, :get_log_events, fn _, _ -> flunk("must not fall back") end)

      capture_log(fn ->
        assert LoghubClient.stream_log_events(@job_id) ==
                 {:error, {:unavailable, "Logs are temporarily unavailable, please retry"}}
      end)
    end
  end

  defp gun_connections, do: :gun_conns_sup |> Supervisor.which_children() |> length()

  defp ok do
    %InternalApi.ResponseStatus{
      code: InternalApi.ResponseStatus.Code.value(:OK),
      message: ""
    }
  end

  defp not_ok(message \\ "") do
    %InternalApi.ResponseStatus{
      code: InternalApi.ResponseStatus.Code.value(:BAD_PARAM),
      message: message
    }
  end
end
