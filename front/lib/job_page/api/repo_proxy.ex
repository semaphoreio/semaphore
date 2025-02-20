defmodule JobPage.Api.RepoProxy do
  alias JobPage.GrpcConfig

  def fetch(hook_id, tracing_headers \\ nil) do
    Watchman.benchmark("fetch_commit.duration", fn ->
      req = InternalApi.RepoProxy.DescribeRequest.new(hook_id: hook_id)

      {:ok, channel} = GRPC.Stub.connect(GrpcConfig.endpoint(:repo_proxy_grpc_endpoint))

      {:ok, response} =
        InternalApi.RepoProxy.RepoProxyService.Stub.describe(channel, req,
          metadata: tracing_headers,
          timeout: 30_000
        )

      if response.status.code == 0 do
        response.hook
      else
        nil
      end
    end)
  end
end
