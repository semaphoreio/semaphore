defmodule InternalApi.Notifications.Notification.Rule.Filter.State do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3
  @type t :: integer | :STARTED | :FINISHED

  field(:STARTED, 0)

  field(:FINISHED, 1)
end

defmodule InternalApi.Notifications.Notification.Rule.Filter.Results do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3
  @type t :: integer | :PASSED | :STOPPED | :CANCELED | :FAILED

  field(:PASSED, 0)

  field(:STOPPED, 1)

  field(:CANCELED, 2)

  field(:FAILED, 3)
end

defmodule InternalApi.Notifications.Notification.Rule.Notify.Status do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3
  @type t :: integer | :ACTIVE | :INACTIVE

  field(:ACTIVE, 0)

  field(:INACTIVE, 1)
end

defmodule InternalApi.Notifications.ListRequest.Order do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3
  @type t :: integer | :BY_NAME_ASC

  field(:BY_NAME_ASC, 0)
end

defmodule InternalApi.Notifications.RequestMeta do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          user_id: String.t()
        }

  defstruct [:org_id, :user_id]

  field(:org_id, 1, type: :string)
  field(:user_id, 2, type: :string)
end

defmodule InternalApi.Notifications.Notification.Rule.Filter do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          projects: [String.t()],
          branches: [String.t()],
          pipelines: [String.t()],
          blocks: [String.t()],
          states: [[InternalApi.Notifications.Notification.Rule.Filter.State.t()]],
          results: [[InternalApi.Notifications.Notification.Rule.Filter.Results.t()]],
          tags: [String.t()]
        }

  defstruct [:projects, :branches, :pipelines, :blocks, :states, :results, :tags]

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

  field(:tags, 7, repeated: true, type: :string)
end

defmodule InternalApi.Notifications.Notification.Rule.Notify.Slack do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          endpoint: String.t(),
          channels: [String.t()],
          message: String.t(),
          status: InternalApi.Notifications.Notification.Rule.Notify.Status.t()
        }

  defstruct [:endpoint, :channels, :message, :status]

  field(:endpoint, 1, type: :string)
  field(:channels, 2, repeated: true, type: :string)
  field(:message, 3, type: :string)
  field(:status, 4, type: InternalApi.Notifications.Notification.Rule.Notify.Status, enum: true)
end

defmodule InternalApi.Notifications.Notification.Rule.Notify.Email do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          subject: String.t(),
          cc: [String.t()],
          bcc: [String.t()],
          content: String.t(),
          status: InternalApi.Notifications.Notification.Rule.Notify.Status.t()
        }

  defstruct [:subject, :cc, :bcc, :content, :status]

  field(:subject, 1, type: :string)
  field(:cc, 2, repeated: true, type: :string)
  field(:bcc, 3, repeated: true, type: :string)
  field(:content, 4, type: :string)
  field(:status, 5, type: InternalApi.Notifications.Notification.Rule.Notify.Status, enum: true)
end

defmodule InternalApi.Notifications.Notification.Rule.Notify.Webhook do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          endpoint: String.t(),
          timeout: integer,
          action: String.t(),
          retries: integer,
          status: InternalApi.Notifications.Notification.Rule.Notify.Status.t(),
          secret: String.t()
        }

  defstruct [:endpoint, :timeout, :action, :retries, :status, :secret]

  field(:endpoint, 1, type: :string)
  field(:timeout, 2, type: :int32)
  field(:action, 3, type: :string)
  field(:retries, 4, type: :int32)
  field(:status, 5, type: InternalApi.Notifications.Notification.Rule.Notify.Status, enum: true)
  field(:secret, 6, type: :string)
end

defmodule InternalApi.Notifications.Notification.Rule.Notify do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          slack: InternalApi.Notifications.Notification.Rule.Notify.Slack.t() | nil,
          email: InternalApi.Notifications.Notification.Rule.Notify.Email.t() | nil,
          webhook: InternalApi.Notifications.Notification.Rule.Notify.Webhook.t() | nil
        }

  defstruct [:slack, :email, :webhook]

  field(:slack, 1, type: InternalApi.Notifications.Notification.Rule.Notify.Slack)
  field(:email, 2, type: InternalApi.Notifications.Notification.Rule.Notify.Email)
  field(:webhook, 3, type: InternalApi.Notifications.Notification.Rule.Notify.Webhook)
end

defmodule InternalApi.Notifications.Notification.Rule do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          filter: InternalApi.Notifications.Notification.Rule.Filter.t() | nil,
          notify: InternalApi.Notifications.Notification.Rule.Notify.t() | nil
        }

  defstruct [:name, :filter, :notify]

  field(:name, 1, type: :string)
  field(:filter, 2, type: InternalApi.Notifications.Notification.Rule.Filter)
  field(:notify, 3, type: InternalApi.Notifications.Notification.Rule.Notify)
end

defmodule InternalApi.Notifications.Notification.Status.Failure do
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

defmodule InternalApi.Notifications.Notification.Status do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          failures: [InternalApi.Notifications.Notification.Status.Failure.t()]
        }

  defstruct [:failures]

  field(:failures, 1, repeated: true, type: InternalApi.Notifications.Notification.Status.Failure)
end

defmodule InternalApi.Notifications.Notification do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          id: String.t(),
          create_time: Google.Protobuf.Timestamp.t() | nil,
          update_time: Google.Protobuf.Timestamp.t() | nil,
          rules: [InternalApi.Notifications.Notification.Rule.t()],
          status: InternalApi.Notifications.Notification.Status.t() | nil,
          org_id: String.t(),
          creator_id: String.t()
        }

  defstruct [:name, :id, :create_time, :update_time, :rules, :status, :org_id, :creator_id]

  field(:name, 1, type: :string)
  field(:id, 2, type: :string)
  field(:create_time, 3, type: Google.Protobuf.Timestamp)
  field(:update_time, 4, type: Google.Protobuf.Timestamp)
  field(:rules, 5, repeated: true, type: InternalApi.Notifications.Notification.Rule)
  field(:status, 6, type: InternalApi.Notifications.Notification.Status)
  field(:org_id, 7, type: :string)
  field(:creator_id, 8, type: :string)
end

defmodule InternalApi.Notifications.ListRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Notifications.RequestMeta.t() | nil,
          page_size: integer,
          page_token: String.t(),
          order: InternalApi.Notifications.ListRequest.Order.t()
        }

  defstruct [:metadata, :page_size, :page_token, :order]

  field(:metadata, 1, type: InternalApi.Notifications.RequestMeta)
  field(:page_size, 2, type: :int32)
  field(:page_token, 3, type: :string)
  field(:order, 4, type: InternalApi.Notifications.ListRequest.Order, enum: true)
end

defmodule InternalApi.Notifications.ListResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          notifications: [InternalApi.Notifications.Notification.t()],
          next_page_token: String.t()
        }

  defstruct [:notifications, :next_page_token]

  field(:notifications, 1, repeated: true, type: InternalApi.Notifications.Notification)
  field(:next_page_token, 2, type: :string)
end

defmodule InternalApi.Notifications.DescribeRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Notifications.RequestMeta.t() | nil,
          id: String.t(),
          name: String.t()
        }

  defstruct [:metadata, :id, :name]

  field(:metadata, 1, type: InternalApi.Notifications.RequestMeta)
  field(:id, 2, type: :string)
  field(:name, 3, type: :string)
end

defmodule InternalApi.Notifications.DescribeResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          notification: InternalApi.Notifications.Notification.t() | nil
        }

  defstruct [:notification]

  field(:notification, 1, type: InternalApi.Notifications.Notification)
end

defmodule InternalApi.Notifications.CreateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Notifications.RequestMeta.t() | nil,
          notification: InternalApi.Notifications.Notification.t() | nil
        }

  defstruct [:metadata, :notification]

  field(:metadata, 1, type: InternalApi.Notifications.RequestMeta)
  field(:notification, 2, type: InternalApi.Notifications.Notification)
end

defmodule InternalApi.Notifications.CreateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          notification: InternalApi.Notifications.Notification.t() | nil
        }

  defstruct [:notification]

  field(:notification, 1, type: InternalApi.Notifications.Notification)
end

defmodule InternalApi.Notifications.UpdateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Notifications.RequestMeta.t() | nil,
          id: String.t(),
          name: String.t(),
          notification: InternalApi.Notifications.Notification.t() | nil
        }

  defstruct [:metadata, :id, :name, :notification]

  field(:metadata, 1, type: InternalApi.Notifications.RequestMeta)
  field(:id, 2, type: :string)
  field(:name, 3, type: :string)
  field(:notification, 4, type: InternalApi.Notifications.Notification)
end

defmodule InternalApi.Notifications.UpdateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          notification: InternalApi.Notifications.Notification.t() | nil
        }

  defstruct [:notification]

  field(:notification, 1, type: InternalApi.Notifications.Notification)
end

defmodule InternalApi.Notifications.DestroyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Notifications.RequestMeta.t() | nil,
          id: String.t(),
          name: String.t()
        }

  defstruct [:metadata, :id, :name]

  field(:metadata, 1, type: InternalApi.Notifications.RequestMeta)
  field(:id, 2, type: :string)
  field(:name, 3, type: :string)
end

defmodule InternalApi.Notifications.DestroyResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t()
        }

  defstruct [:id]

  field(:id, 1, type: :string)
end

defmodule InternalApi.Notifications.NotificationsApi.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.Notifications.NotificationsApi"

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
