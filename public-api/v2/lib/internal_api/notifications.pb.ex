defmodule InternalApi.Notifications.Notification.Rule.Filter.State do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:STARTED, 0)
  field(:FINISHED, 1)
end

defmodule InternalApi.Notifications.Notification.Rule.Filter.Results do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:PASSED, 0)
  field(:STOPPED, 1)
  field(:CANCELED, 2)
  field(:FAILED, 3)
end

defmodule InternalApi.Notifications.Notification.Rule.Notify.Status do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:ACTIVE, 0)
  field(:INACTIVE, 1)
end

defmodule InternalApi.Notifications.ListRequest.Order do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:BY_NAME_ASC, 0)
end

defmodule InternalApi.Notifications.RequestMeta do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:user_id, 2, type: :string, json_name: "userId")
end

defmodule InternalApi.Notifications.Notification.Rule.Filter do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:projects, 1, repeated: true, type: :string)
  field(:branches, 2, repeated: true, type: :string)
  field(:pipelines, 3, repeated: true, type: :string)
  field(:blocks, 4, repeated: true, type: :string)

  field(:states, 5,
    repeated: true,
    type: InternalApi.Notifications.Notification.Rule.Filter.State,
    enum: true
  )

  field(:results, 6,
    repeated: true,
    type: InternalApi.Notifications.Notification.Rule.Filter.Results,
    enum: true
  )
end

defmodule InternalApi.Notifications.Notification.Rule.Notify.Slack do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:endpoint, 1, type: :string)
  field(:channels, 2, repeated: true, type: :string)
  field(:message, 3, type: :string)
  field(:status, 4, type: InternalApi.Notifications.Notification.Rule.Notify.Status, enum: true)
end

defmodule InternalApi.Notifications.Notification.Rule.Notify.Email do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:subject, 1, type: :string)
  field(:cc, 2, repeated: true, type: :string)
  field(:bcc, 3, repeated: true, type: :string)
  field(:content, 4, type: :string)
  field(:status, 5, type: InternalApi.Notifications.Notification.Rule.Notify.Status, enum: true)
end

defmodule InternalApi.Notifications.Notification.Rule.Notify.Webhook do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:endpoint, 1, type: :string)
  field(:timeout, 2, type: :int32)
  field(:action, 3, type: :string)
  field(:retries, 4, type: :int32)
  field(:status, 5, type: InternalApi.Notifications.Notification.Rule.Notify.Status, enum: true)
  field(:secret, 6, type: :string)
end

defmodule InternalApi.Notifications.Notification.Rule.Notify do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:slack, 1, type: InternalApi.Notifications.Notification.Rule.Notify.Slack)
  field(:email, 2, type: InternalApi.Notifications.Notification.Rule.Notify.Email)
  field(:webhook, 3, type: InternalApi.Notifications.Notification.Rule.Notify.Webhook)
end

defmodule InternalApi.Notifications.Notification.Rule do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:name, 1, type: :string)
  field(:filter, 2, type: InternalApi.Notifications.Notification.Rule.Filter)
  field(:notify, 3, type: InternalApi.Notifications.Notification.Rule.Notify)
end

defmodule InternalApi.Notifications.Notification.Status.Failure do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:time, 1, type: :int64)
  field(:message, 2, type: :string)
end

defmodule InternalApi.Notifications.Notification.Status do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:failures, 1, repeated: true, type: InternalApi.Notifications.Notification.Status.Failure)
end

defmodule InternalApi.Notifications.Notification do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:name, 1, type: :string)
  field(:id, 2, type: :string)
  field(:create_time, 3, type: Google.Protobuf.Timestamp, json_name: "createTime")
  field(:update_time, 4, type: Google.Protobuf.Timestamp, json_name: "updateTime")
  field(:rules, 5, repeated: true, type: InternalApi.Notifications.Notification.Rule)
  field(:status, 6, type: InternalApi.Notifications.Notification.Status)
  field(:org_id, 7, type: :string, json_name: "orgId")
end

defmodule InternalApi.Notifications.ListRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:metadata, 1, type: InternalApi.Notifications.RequestMeta)
  field(:page_size, 2, type: :int32, json_name: "pageSize")
  field(:page_token, 3, type: :string, json_name: "pageToken")
  field(:order, 4, type: InternalApi.Notifications.ListRequest.Order, enum: true)
end

defmodule InternalApi.Notifications.ListResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:notifications, 1, repeated: true, type: InternalApi.Notifications.Notification)
  field(:next_page_token, 2, type: :string, json_name: "nextPageToken")
end

defmodule InternalApi.Notifications.DescribeRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:metadata, 1, type: InternalApi.Notifications.RequestMeta)
  field(:id, 2, type: :string)
  field(:name, 3, type: :string)
end

defmodule InternalApi.Notifications.DescribeResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:notification, 1, type: InternalApi.Notifications.Notification)
end

defmodule InternalApi.Notifications.CreateRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:metadata, 1, type: InternalApi.Notifications.RequestMeta)
  field(:notification, 2, type: InternalApi.Notifications.Notification)
end

defmodule InternalApi.Notifications.CreateResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:notification, 1, type: InternalApi.Notifications.Notification)
end

defmodule InternalApi.Notifications.UpdateRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:metadata, 1, type: InternalApi.Notifications.RequestMeta)
  field(:id, 2, type: :string)
  field(:name, 3, type: :string)
  field(:notification, 4, type: InternalApi.Notifications.Notification)
end

defmodule InternalApi.Notifications.UpdateResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:notification, 1, type: InternalApi.Notifications.Notification)
end

defmodule InternalApi.Notifications.DestroyRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:metadata, 1, type: InternalApi.Notifications.RequestMeta)
  field(:id, 2, type: :string)
  field(:name, 3, type: :string)
end

defmodule InternalApi.Notifications.DestroyResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:id, 1, type: :string)
end

defmodule InternalApi.Notifications.NotificationsApi.Service do
  @moduledoc false

  use GRPC.Service,
    name: "InternalApi.Notifications.NotificationsApi",
    protoc_gen_elixir_version: "0.12.0"

  rpc(:List, InternalApi.Notifications.ListRequest, InternalApi.Notifications.ListResponse)

  rpc(
    :Describe,
    InternalApi.Notifications.DescribeRequest,
    InternalApi.Notifications.DescribeResponse
  )

  rpc(:Create, InternalApi.Notifications.CreateRequest, InternalApi.Notifications.CreateResponse)

  rpc(:Update, InternalApi.Notifications.UpdateRequest, InternalApi.Notifications.UpdateResponse)

  rpc(
    :Destroy,
    InternalApi.Notifications.DestroyRequest,
    InternalApi.Notifications.DestroyResponse
  )
end

defmodule InternalApi.Notifications.NotificationsApi.Stub do
  @moduledoc false

  use GRPC.Stub, service: InternalApi.Notifications.NotificationsApi.Service
end
