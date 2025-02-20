defmodule Test.Support.Mocks.PFCServer do
  use GRPC.Server, service: InternalApi.PreFlightChecksHub.PreFlightChecksService.Service
  alias InternalApi.PreFlightChecksHub.{DescribeRequest, DescribeResponse}

  def describe(_request, _stream) do
    %{status: %{code: :NOT_FOUND}}
    |> Util.Proto.deep_new!(DescribeResponse)
  end
end
