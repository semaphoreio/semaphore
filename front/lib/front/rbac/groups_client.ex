defmodule Front.RBAC.GroupsClient do
  def channel do
    {:ok, ch} = GRPC.Stub.connect(api_endpoint())
    ch
  end

  def api_endpoint do
    Application.fetch_env!(:front, :groups_grpc_endpoint)
  end
end
