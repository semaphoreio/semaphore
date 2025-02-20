defmodule JobPage.Api.User do
  alias JobPage.GrpcConfig

  def fetch(id) do
    Watchman.benchmark("fetch_user.duration", fn ->
      req = InternalApi.User.DescribeRequest.new(user_id: id)

      {:ok, channel} = GRPC.Stub.connect(GrpcConfig.endpoint(:user_grpc_endpoint))
      {:ok, res} = InternalApi.User.UserService.Stub.describe(channel, req, timeout: 30_000)

      if res.status.code == 0 do
        res
      else
        nil
      end
    end)
  end
end
