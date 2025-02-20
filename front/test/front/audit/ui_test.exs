defmodule Front.Audit.UI.Test do
  use FrontWeb.ConnCase

  test ".csv" do
    alias Support.Stubs.{DB, UUID}
    alias InternalApi.Audit.Event.{Medium, Operation, Resource}

    org_id = Ecto.UUID.generate()

    DB.insert(:audit_events, %{
      org_id: org_id,
      resource: Resource.value(:Secret),
      operation: Operation.value(:Added),
      user_id: UUID.gen(),
      username: "shiroyasha",
      ip_address: "189.0.12.2",
      operation_id: UUID.gen(),
      timestamp: Google.Protobuf.Timestamp.new(seconds: 1_522_754_259),
      resource_id: UUID.gen(),
      resource_name: "my-secret",
      metadata: Poison.encode!(%{"hello" => "world"}),
      medium: Medium.value(:API),
      description: "Added a secret"
    })

    DB.insert(:audit_events, %{
      org_id: org_id,
      resource: Resource.value(:Secret),
      operation: Operation.value(:Removed),
      user_id: UUID.gen(),
      username: "shiroyasha",
      ip_address: "189.0.12.2",
      operation_id: UUID.gen(),
      timestamp: Google.Protobuf.Timestamp.new(seconds: 1_522_754_000),
      resource_id: UUID.gen(),
      resource_name: "my-secret",
      metadata: Poison.encode!(%{"hello" => "world"}),
      medium: Medium.value(:Web),
      description: "Removed a secret"
    })

    request = InternalApi.Audit.ListRequest.new(org_id: org_id)

    endpoint = Application.fetch_env!(:front, :audit_grpc_endpoint)

    {:ok, channel} = GRPC.Stub.connect(endpoint)
    {:ok, event_list} = InternalApi.Audit.AuditService.Stub.list(channel, request)

    ev1 = Enum.at(event_list.events, 0)
    ev2 = Enum.at(event_list.events, 1)

    assert Front.Audit.UI.csv(org_id) == [
             "resource,operation,medium,user_id,username,resource_id,resource_name,ip_address,description,metadata,timestamp\r\n",
             "Secret,Added,API,#{ev1.user_id},shiroyasha,#{ev1.resource_id},my-secret,189.0.12.2,Added a secret,\"{\"\"hello\"\":\"\"world\"\"}\",1522754259\r\n",
             "Secret,Removed,Web,#{ev2.user_id},shiroyasha,#{ev2.resource_id},my-secret,189.0.12.2,Removed a secret,\"{\"\"hello\"\":\"\"world\"\"}\",1522754000\r\n"
           ]
  end
end
