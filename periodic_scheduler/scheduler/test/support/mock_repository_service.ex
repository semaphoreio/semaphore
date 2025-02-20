defmodule Test.MockRepositoryService do
  @moduledoc """
  Mocks ProjectService GRPC server.
  """

  use GRPC.Server, service: InternalApi.Repository.RepositoryService.Service
  alias InternalApi.Repository, as: API

  def describe_revision(_request, _stream) do
    response_type = Application.get_env(:scheduler, :mock_repository_service_response)
    respond(response_type)
  end

  defp respond("ok") do
    Util.Proto.deep_new!(API.DescribeRevisionResponse, %{commit: commit_for_response()})
  end

  defp respond("not_found") do
    raise GRPC.RPCError, status: GRPC.Status.not_found(), message: "Not found"
  end

  defp respond("failed_precondition") do
    raise GRPC.RPCError, status: GRPC.Status.failed_precondition(), message: "Failed precondition"
  end

  defp respond("timeout") do
    :timer.sleep(13_000)

    Util.Proto.deep_new!(API.DescribeRevisionResponse, %{commit: commit_for_response()})
  end

  defp commit_for_response do
    %{sha: "1234566", msg: "commit message"}
  end
end
