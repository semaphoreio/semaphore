defmodule Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Filter.State do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:STARTED, 0)
  field(:FINISHED, 1)
end

defmodule Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Notify.Status do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:ACTIVE, 0)
  field(:INACTIVE, 1)
end

defmodule Semaphore.Notifications.V1alpha.ListNotificationsRequest.Order do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:BY_NAME_ASC, 0)
end

defmodule Semaphore.Notifications.V1alpha.Notification.Metadata do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:name, 1, type: :string)
  field(:id, 2, type: :string)
  field(:create_time, 3, type: :int64, json_name: "createTime")
  field(:update_time, 4, type: :int64, json_name: "updateTime")
end

defmodule Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Filter do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:projects, 1, repeated: true, type: :string)
  field(:branches, 2, repeated: true, type: :string)
  field(:pipelines, 3, repeated: true, type: :string)
  field(:blocks, 4, repeated: true, type: :string)

  field(:states, 5,
    repeated: true,
    type: Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Filter.State,
    enum: true
  )

  field(:results, 6, repeated: true, type: :string)
end

defmodule Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Notify.Slack do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:endpoint, 1, type: :string)
  field(:channels, 2, repeated: true, type: :string)
  field(:message, 3, type: :string)

  field(:status, 4,
    type: Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Notify.Status,
    enum: true
  )
end

defmodule Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Notify.Email do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:subject, 1, type: :string)
  field(:cc, 2, repeated: true, type: :string)
  field(:bcc, 3, repeated: true, type: :string)
  field(:content, 4, type: :string)

  field(:status, 5,
    type: Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Notify.Status,
    enum: true
  )
end

defmodule Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Notify.Webhook do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:endpoint, 1, type: :string)
  field(:timeout, 2, type: :int32)
  field(:action, 3, type: :string)
  field(:retries, 4, type: :int32)

  field(:status, 5,
    type: Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Notify.Status,
    enum: true
  )

  field(:secret, 6, type: :string)
end

defmodule Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Notify do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:slack, 2, type: Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Notify.Slack)
  field(:email, 3, type: Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Notify.Email)
  field(:webhook, 4, type: Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Notify.Webhook)
end

defmodule Semaphore.Notifications.V1alpha.Notification.Spec.Rule do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:name, 1, type: :string)
  field(:filter, 2, type: Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Filter)
  field(:notify, 3, type: Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Notify)
end

defmodule Semaphore.Notifications.V1alpha.Notification.Spec do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:rules, 1, repeated: true, type: Semaphore.Notifications.V1alpha.Notification.Spec.Rule)
end

defmodule Semaphore.Notifications.V1alpha.Notification.Status.Failure do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:time, 1, type: :int64)
  field(:message, 2, type: :string)
end

defmodule Semaphore.Notifications.V1alpha.Notification.Status do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:failures, 1,
    repeated: true,
    type: Semaphore.Notifications.V1alpha.Notification.Status.Failure
  )
end

defmodule Semaphore.Notifications.V1alpha.Notification do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:metadata, 1, type: Semaphore.Notifications.V1alpha.Notification.Metadata)
  field(:spec, 2, type: Semaphore.Notifications.V1alpha.Notification.Spec)
  field(:status, 3, type: Semaphore.Notifications.V1alpha.Notification.Status)
end

defmodule Semaphore.Notifications.V1alpha.ListNotificationsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:page_size, 1, type: :int32, json_name: "pageSize")
  field(:page_token, 2, type: :string, json_name: "pageToken")

  field(:order, 3,
    type: Semaphore.Notifications.V1alpha.ListNotificationsRequest.Order,
    enum: true
  )
end

defmodule Semaphore.Notifications.V1alpha.ListNotificationsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:notifications, 1, repeated: true, type: Semaphore.Notifications.V1alpha.Notification)
  field(:next_page_token, 2, type: :string, json_name: "nextPageToken")
end

defmodule Semaphore.Notifications.V1alpha.GetNotificationRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:notification_id_or_name, 1, type: :string, json_name: "notificationIdOrName")
end

defmodule Semaphore.Notifications.V1alpha.UpdateNotificationRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:notification_id_or_name, 1, type: :string, json_name: "notificationIdOrName")
  field(:notification, 2, type: Semaphore.Notifications.V1alpha.Notification)
end

defmodule Semaphore.Notifications.V1alpha.DeleteNotificationRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:notification_id_or_name, 1, type: :string, json_name: "notificationIdOrName")
end

defmodule Semaphore.Notifications.V1alpha.Empty do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"
end

defmodule Semaphore.Notifications.V1alpha.NotificationsApi.Service do
  @moduledoc false

  use GRPC.Service,
    name: "semaphore.notifications.v1alpha.NotificationsApi",
    protoc_gen_elixir_version: "0.13.0"

  rpc(
    :ListNotifications,
    Semaphore.Notifications.V1alpha.ListNotificationsRequest,
    Semaphore.Notifications.V1alpha.ListNotificationsResponse
  )

  rpc(
    :GetNotification,
    Semaphore.Notifications.V1alpha.GetNotificationRequest,
    Semaphore.Notifications.V1alpha.Notification
  )

  rpc(
    :CreateNotification,
    Semaphore.Notifications.V1alpha.Notification,
    Semaphore.Notifications.V1alpha.Notification
  )

  rpc(
    :UpdateNotification,
    Semaphore.Notifications.V1alpha.UpdateNotificationRequest,
    Semaphore.Notifications.V1alpha.Notification
  )

  rpc(
    :DeleteNotification,
    Semaphore.Notifications.V1alpha.DeleteNotificationRequest,
    Semaphore.Notifications.V1alpha.Empty
  )
end

defmodule Semaphore.Notifications.V1alpha.NotificationsApi.Stub do
  @moduledoc false

  use GRPC.Stub, service: Semaphore.Notifications.V1alpha.NotificationsApi.Service
end
