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

    test "failure response" do
      GrpcMock.stub(LoghubMock, :get_log_events, fn _, _ ->
        %InternalApi.Loghub.GetLogEventsResponse{
          status: not_ok(),
          events: ["first", "second"],
          final: true
        }
      end)

      assert {:error, {:internal, "Internal error"}} = LoghubClient.get_log_events(@job_id)
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

  defp not_ok do
    %InternalApi.ResponseStatus{
      code: InternalApi.ResponseStatus.Code.value(:BAD_PARAM),
      message: ""
    }
  end
end
