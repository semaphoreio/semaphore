defmodule InternalApi.Hooks.ReceivedWebhook do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:received_at, 1, type: Google.Protobuf.Timestamp, json_name: "receivedAt")
  field(:webhook, 2, type: :string)
  field(:repository_id, 3, type: :string, json_name: "repositoryId")
  field(:project_id, 4, type: :string, json_name: "projectId")
  field(:organization_id, 5, type: :string, json_name: "organizationId")
  field(:webhook_signature, 6, type: :string, json_name: "webhookSignature")
  field(:webhook_raw_payload, 7, type: :string, json_name: "webhookRawPayload")
end
