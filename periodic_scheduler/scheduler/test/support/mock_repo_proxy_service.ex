defmodule Test.MockRepoProxyService do
  @moduledoc """
    Mocks RepoProxyService GRPC server.
  """

  use GRPC.Server, service: InternalApi.RepoProxy.RepoProxyService.Service
  use ExUnit.Case

  alias InternalApi.RepoProxy.CreateResponse
  alias Util.Proto

  def create(%{triggered_by: :SCHEDULE}, _stream) do
    response_type = Application.get_env(:scheduler, :mock_repo_proxy_service_response)
    respond(response_type)
  end

  defp respond("ok") do
    %{workflow_id: UUID.uuid4(), pipeline_id: UUID.uuid4(), hook_id: UUID.uuid4()}
    |> Proto.deep_new!(CreateResponse)
  end

  defp respond("invalid_argument") do
    msg = "Invalid argument"
    raise GRPC.RPCError, status: GRPC.Status.invalid_argument(), message: msg
  end

  defp respond("timeout") do
    :timer.sleep(16_000)
    Proto.deep_new!(%{}, CreateResponse)
  end
end
