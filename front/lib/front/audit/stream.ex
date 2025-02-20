defmodule Front.Audit.Stream do
  def create(org_id) do
    endpoint = Application.fetch_env!(:front, :audit_grpc_endpoint)
    request = InternalApi.Audit.ListRequest.new(org_id: org_id)

    {:ok, channel} = GRPC.Stub.connect(endpoint)
    {:ok, _res} = InternalApi.Audit.AuditService.Stub.list(channel, request)
  end
end
