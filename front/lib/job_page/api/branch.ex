defmodule JobPage.Api.Branch do
  alias JobPage.GrpcConfig

  def fetch(branch_id, tracing_headers \\ nil) do
    Watchman.benchmark("fetch_branch.duration", fn ->
      req = InternalApi.Branch.DescribeRequest.new(branch_id: branch_id)

      {:ok, channel} = GRPC.Stub.connect(GrpcConfig.endpoint(:branch_api_grpc_endpoint))

      {:ok, response} =
        InternalApi.Branch.BranchService.Stub.describe(channel, req,
          metadata: tracing_headers,
          timeout: 30_000
        )

      if response.status.code == 0 do
        response
      else
        nil
      end
    end)
  end
end
