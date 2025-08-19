defmodule Semaphore.Notifications.V1alpha.Notification do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: Semaphore.Notifications.V1alpha.Notification.Metadata.t(),
          spec: Semaphore.Notifications.V1alpha.Notification.Spec.t(),
          status: Semaphore.Notifications.V1alpha.Notification.Status.t()
        }
  defstruct [:metadata, :spec, :status]

  field(:metadata, 1, type: Semaphore.Notifications.V1alpha.Notification.Metadata)
  field(:spec, 2, type: Semaphore.Notifications.V1alpha.Notification.Spec)
  field(:status, 3, type: Semaphore.Notifications.V1alpha.Notification.Status)
end

defmodule Semaphore.Notifications.V1alpha.Notification.Metadata do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          id: String.t(),
          create_time: integer,
          update_time: integer,
          creator_id: String.t()
        }
  defstruct [:name, :id, :create_time, :update_time, :creator_id]

  field(:name, 1, type: :string)
  field(:id, 2, type: :string)
  field(:create_time, 3, type: :int64)
  field(:update_time, 4, type: :int64)
  field(:creator_id, 5, type: :string)
end

defmodule Semaphore.Notifications.V1alpha.Notification.Spec do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          rules: [Semaphore.Notifications.V1alpha.Notification.Spec.Rule.t()]
        }
  defstruct [:rules]

  field(:rules, 1, repeated: true, type: Semaphore.Notifications.V1alpha.Notification.Spec.Rule)
end

defmodule Semaphore.Notifications.V1alpha.Notification.Spec.Rule do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          filter: Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Filter.t(),
          notify: Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Notify.t()
        }
  defstruct [:name, :filter, :notify]

  field(:name, 1, type: :string)
  field(:filter, 2, type: Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Filter)
  field(:notify, 3, type: Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Notify)
end

defmodule Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Filter do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          projects: [String.t()],
          branches: [String.t()],
          pipelines: [String.t()],
          blocks: [String.t()],
          states: [integer],
          results: [String.t()]
        }
  defstruct [:projects, :branches, :pipelines, :blocks, :states, :results]

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

defmodule Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Filter.State do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:STARTED, 0)
  field(:FINISHED, 1)
end

defmodule Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Notify do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          slack: Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Notify.Slack.t(),
          email: Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Notify.Email.t(),
          webhook: Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Notify.Webhook.t()
        }
  defstruct [:slack, :email, :webhook]

  field(:slack, 2, type: Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Notify.Slack)
  field(:email, 3, type: Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Notify.Email)
  field(:webhook, 4, type: Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Notify.Webhook)
end

defmodule Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Notify.Slack do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          endpoint: String.t(),
          channels: [String.t()],
          message: String.t(),
          status: integer
        }
  defstruct [:endpoint, :channels, :message, :status]

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
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          subject: String.t(),
          cc: [String.t()],
          bcc: [String.t()],
          content: String.t(),
          status: integer
        }
  defstruct [:subject, :cc, :bcc, :content, :status]

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
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          endpoint: String.t(),
          timeout: integer,
          action: String.t(),
          retries: integer,
          status: integer,
          secret: String.t()
        }
  defstruct [:endpoint, :timeout, :action, :retries, :status, :secret]

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

defmodule Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Notify.Status do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:ACTIVE, 0)
  field(:INACTIVE, 1)
end

defmodule Semaphore.Notifications.V1alpha.Notification.Status do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          failures: [Semaphore.Notifications.V1alpha.Notification.Status.Failure.t()]
        }
  defstruct [:failures]

  field(:failures, 1,
    repeated: true,
    type: Semaphore.Notifications.V1alpha.Notification.Status.Failure
  )
end

defmodule Semaphore.Notifications.V1alpha.Notification.Status.Failure do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          time: integer,
          message: String.t()
        }
  defstruct [:time, :message]

  field(:time, 1, type: :int64)
  field(:message, 2, type: :string)
end

defmodule Semaphore.Notifications.V1alpha.ListNotificationsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          page_size: integer,
          page_token: String.t(),
          order: integer
        }
  defstruct [:page_size, :page_token, :order]

  field(:page_size, 1, type: :int32)
  field(:page_token, 2, type: :string)

  field(:order, 3,
    type: Semaphore.Notifications.V1alpha.ListNotificationsRequest.Order,
    enum: true
  )
end

defmodule Semaphore.Notifications.V1alpha.ListNotificationsRequest.Order do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:BY_NAME_ASC, 0)
end

defmodule Semaphore.Notifications.V1alpha.ListNotificationsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          notifications: [Semaphore.Notifications.V1alpha.Notification.t()],
          next_page_token: String.t()
        }
  defstruct [:notifications, :next_page_token]

  field(:notifications, 1, repeated: true, type: Semaphore.Notifications.V1alpha.Notification)
  field(:next_page_token, 2, type: :string)
end

defmodule Semaphore.Notifications.V1alpha.GetNotificationRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          notification_id_or_name: String.t()
        }
  defstruct [:notification_id_or_name]

  field(:notification_id_or_name, 1, type: :string)
end

defmodule Semaphore.Notifications.V1alpha.UpdateNotificationRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          notification_id_or_name: String.t(),
          notification: Semaphore.Notifications.V1alpha.Notification.t()
        }
  defstruct [:notification_id_or_name, :notification]

  field(:notification_id_or_name, 1, type: :string)
  field(:notification, 2, type: Semaphore.Notifications.V1alpha.Notification)
end

defmodule Semaphore.Notifications.V1alpha.DeleteNotificationRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          notification_id_or_name: String.t()
        }
  defstruct [:notification_id_or_name]

  field(:notification_id_or_name, 1, type: :string)
end

defmodule Semaphore.Notifications.V1alpha.Empty do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule Semaphore.Notifications.V1alpha.NotificationsApi.Service do
  @moduledoc false
  use GRPC.Service, name: "semaphore.notifications.v1alpha.NotificationsApi"

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
