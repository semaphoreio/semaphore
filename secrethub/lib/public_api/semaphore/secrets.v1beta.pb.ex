defmodule Semaphore.Secrets.V1beta.Secret.OrgConfig.ProjectsAccess do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3
  @type t :: integer | :ALL | :ALLOWED | :NONE

  field :ALL, 0

  field :ALLOWED, 1

  field :NONE, 2
end

defmodule Semaphore.Secrets.V1beta.Secret.OrgConfig.JobAttachAccess do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3
  @type t :: integer | :JOB_ATTACH_YES | :JOB_ATTACH_NO

  field :JOB_ATTACH_YES, 0

  field :JOB_ATTACH_NO, 2
end

defmodule Semaphore.Secrets.V1beta.Secret.OrgConfig.JobDebugAccess do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3
  @type t :: integer | :JOB_DEBUG_YES | :JOB_DEBUG_NO

  field :JOB_DEBUG_YES, 0

  field :JOB_DEBUG_NO, 2
end

defmodule Semaphore.Secrets.V1beta.ListSecretsRequest.Order do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3
  @type t :: integer | :BY_NAME_ASC | :BY_CREATE_TIME_ASC

  field :BY_NAME_ASC, 0

  field :BY_CREATE_TIME_ASC, 1
end

defmodule Semaphore.Secrets.V1beta.Secret.Metadata do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          id: String.t(),
          create_time: integer,
          update_time: integer,
          checkout_at: integer,
          content_included: boolean
        }

  defstruct [:name, :id, :create_time, :update_time, :checkout_at, :content_included]

  field :name, 1, type: :string
  field :id, 2, type: :string
  field :create_time, 3, type: :int64
  field :update_time, 4, type: :int64
  field :checkout_at, 5, type: :int64
  field :content_included, 6, type: :bool
end

defmodule Semaphore.Secrets.V1beta.Secret.EnvVar do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          value: String.t()
        }

  defstruct [:name, :value]

  field :name, 1, type: :string
  field :value, 2, type: :string
end

defmodule Semaphore.Secrets.V1beta.Secret.File do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          path: String.t(),
          content: String.t()
        }

  defstruct [:path, :content]

  field :path, 1, type: :string
  field :content, 2, type: :string
end

defmodule Semaphore.Secrets.V1beta.Secret.Data do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          env_vars: [Semaphore.Secrets.V1beta.Secret.EnvVar.t()],
          files: [Semaphore.Secrets.V1beta.Secret.File.t()]
        }

  defstruct [:env_vars, :files]

  field :env_vars, 1, repeated: true, type: Semaphore.Secrets.V1beta.Secret.EnvVar
  field :files, 2, repeated: true, type: Semaphore.Secrets.V1beta.Secret.File
end

defmodule Semaphore.Secrets.V1beta.Secret.OrgConfig do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          projects_access: Semaphore.Secrets.V1beta.Secret.OrgConfig.ProjectsAccess.t(),
          project_ids: [String.t()],
          debug_access: Semaphore.Secrets.V1beta.Secret.OrgConfig.JobDebugAccess.t(),
          attach_access: Semaphore.Secrets.V1beta.Secret.OrgConfig.JobAttachAccess.t()
        }

  defstruct [:projects_access, :project_ids, :debug_access, :attach_access]

  field :projects_access, 1,
    type: Semaphore.Secrets.V1beta.Secret.OrgConfig.ProjectsAccess,
    enum: true

  field :project_ids, 2, repeated: true, type: :string

  field :debug_access, 3,
    type: Semaphore.Secrets.V1beta.Secret.OrgConfig.JobDebugAccess,
    enum: true

  field :attach_access, 4,
    type: Semaphore.Secrets.V1beta.Secret.OrgConfig.JobAttachAccess,
    enum: true
end

defmodule Semaphore.Secrets.V1beta.Secret do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: Semaphore.Secrets.V1beta.Secret.Metadata.t() | nil,
          data: Semaphore.Secrets.V1beta.Secret.Data.t() | nil,
          org_config: Semaphore.Secrets.V1beta.Secret.OrgConfig.t() | nil
        }

  defstruct [:metadata, :data, :org_config]

  field :metadata, 1, type: Semaphore.Secrets.V1beta.Secret.Metadata
  field :data, 2, type: Semaphore.Secrets.V1beta.Secret.Data
  field :org_config, 3, type: Semaphore.Secrets.V1beta.Secret.OrgConfig
end

defmodule Semaphore.Secrets.V1beta.ListSecretsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          page_size: integer,
          page_token: String.t(),
          order: Semaphore.Secrets.V1beta.ListSecretsRequest.Order.t()
        }

  defstruct [:page_size, :page_token, :order]

  field :page_size, 1, type: :int32
  field :page_token, 2, type: :string
  field :order, 3, type: Semaphore.Secrets.V1beta.ListSecretsRequest.Order, enum: true
end

defmodule Semaphore.Secrets.V1beta.ListSecretsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          secrets: [Semaphore.Secrets.V1beta.Secret.t()],
          next_page_token: String.t()
        }

  defstruct [:secrets, :next_page_token]

  field :secrets, 1, repeated: true, type: Semaphore.Secrets.V1beta.Secret
  field :next_page_token, 2, type: :string
end

defmodule Semaphore.Secrets.V1beta.GetSecretRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          secret_id_or_name: String.t()
        }

  defstruct [:secret_id_or_name]

  field :secret_id_or_name, 1, type: :string
end

defmodule Semaphore.Secrets.V1beta.UpdateSecretRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          secret_id_or_name: String.t(),
          secret: Semaphore.Secrets.V1beta.Secret.t() | nil
        }

  defstruct [:secret_id_or_name, :secret]

  field :secret_id_or_name, 1, type: :string
  field :secret, 2, type: Semaphore.Secrets.V1beta.Secret
end

defmodule Semaphore.Secrets.V1beta.DeleteSecretRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          secret_id_or_name: String.t()
        }

  defstruct [:secret_id_or_name]

  field :secret_id_or_name, 1, type: :string
end

defmodule Semaphore.Secrets.V1beta.Empty do
  @moduledoc false
  use Protobuf, syntax: :proto3
  @type t :: %__MODULE__{}

  defstruct []
end

defmodule Semaphore.Secrets.V1beta.SecretsApi.Service do
  @moduledoc false
  use GRPC.Service, name: "semaphore.secrets.v1beta.SecretsApi"

  rpc(
    :ListSecrets,
    Semaphore.Secrets.V1beta.ListSecretsRequest,
    Semaphore.Secrets.V1beta.ListSecretsResponse
  )

  rpc(:GetSecret, Semaphore.Secrets.V1beta.GetSecretRequest, Semaphore.Secrets.V1beta.Secret)

  rpc(:CreateSecret, Semaphore.Secrets.V1beta.Secret, Semaphore.Secrets.V1beta.Secret)

  rpc(
    :UpdateSecret,
    Semaphore.Secrets.V1beta.UpdateSecretRequest,
    Semaphore.Secrets.V1beta.Secret
  )

  rpc(:DeleteSecret, Semaphore.Secrets.V1beta.DeleteSecretRequest, Semaphore.Secrets.V1beta.Empty)
end

defmodule Semaphore.Secrets.V1beta.SecretsApi.Stub do
  @moduledoc false
  use GRPC.Stub, service: Semaphore.Secrets.V1beta.SecretsApi.Service
end
