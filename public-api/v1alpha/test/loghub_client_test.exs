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

    test "falls back to GetLogEvents when loghub doesn't implement the stream" do
      GrpcMock.stub(LoghubMock, :stream_log_events, fn _, stream ->
        GRPC.Server.send_headers(stream, %{})
        raise GRPC.RPCError, status: GRPC.Status.unimplemented(), message: "unimplemented"
      end)

      GrpcMock.stub(LoghubMock, :get_log_events, fn _, _ ->
        %InternalApi.Loghub.GetLogEventsResponse{status: ok(), events: ["unary"], final: true}
      end)

      assert LoghubClient.stream_log_events(@job_id) == {:ok, ["unary"]}
    end
  end

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
