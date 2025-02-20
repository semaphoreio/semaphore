defmodule Audit.User do
  def name(user_id) do
    alias InternalApi.User.DescribeRequest
    alias InternalApi.User.UserService.Stub

    endpoint = Application.get_env(:audit, :user_grpc_endpoint)
    {:ok, channel} = GRPC.Stub.connect(endpoint)

    req = DescribeRequest.new(user_id: user_id)
    {:ok, res} = Stub.describe(channel, req, timeout: 30_000)

    if res.status.code == :OK do
      {:ok, res.name}
    else
      {:error, "Failed to find the user"}
    end
  end
end
