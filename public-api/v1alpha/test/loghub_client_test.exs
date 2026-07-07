defmodule PipelinesAPI.LoghubClient.Test do
  use ExUnit.Case
  use Plug.Test

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

      assert {:error, {:not_found, "Log not found neither in the archive nor in the virtual machine"}} =
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
