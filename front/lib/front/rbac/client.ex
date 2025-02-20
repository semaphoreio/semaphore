defmodule Front.RBAC.Client do
  def channel do
    {:ok, ch} = GRPC.Stub.connect(api_endpoint())
    ch
  end

  def api_endpoint do
    Application.fetch_env!(:front, :rbac_grpc_endpoint)
  end
end
