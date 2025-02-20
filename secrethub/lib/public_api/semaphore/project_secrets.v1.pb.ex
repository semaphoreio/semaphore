defmodule Semaphore.ProjectSecrets.V1.ListSecretsRequest.Order do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3
  @type t :: integer | :BY_NAME_ASC | :BY_CREATE_TIME_ASC

  field :BY_NAME_ASC, 0

  field :BY_CREATE_TIME_ASC, 1
end

defmodule Semaphore.ProjectSecrets.V1.Secret.Metadata do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          id: String.t(),
          create_time: integer,
          update_time: integer,
          checkout_at: integer,
          project_id_or_name: String.t(),
          content_included: boolean
        }

  defstruct [
    :name,
    :id,
    :create_time,
    :update_time,
    :checkout_at,
    :project_id_or_name,
    :content_included
  ]

  field :name, 1, type: :string
  field :id, 2, type: :string
  field :create_time, 3, type: :int64
  field :update_time, 4, type: :int64
  field :checkout_at, 5, type: :int64
  field :project_id_or_name, 6, type: :string
  field :content_included, 7, type: :bool
end

defmodule Semaphore.ProjectSecrets.V1.Secret.EnvVar do
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

defmodule Semaphore.ProjectSecrets.V1.Secret.File do
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

defmodule Semaphore.ProjectSecrets.V1.Secret.Data do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          env_vars: [Semaphore.ProjectSecrets.V1.Secret.EnvVar.t()],
          files: [Semaphore.ProjectSecrets.V1.Secret.File.t()]
        }

  defstruct [:env_vars, :files]

  field :env_vars, 1, repeated: true, type: Semaphore.ProjectSecrets.V1.Secret.EnvVar
  field :files, 2, repeated: true, type: Semaphore.ProjectSecrets.V1.Secret.File
end

defmodule Semaphore.ProjectSecrets.V1.Secret do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: Semaphore.ProjectSecrets.V1.Secret.Metadata.t() | nil,
          data: Semaphore.ProjectSecrets.V1.Secret.Data.t() | nil
        }

  defstruct [:metadata, :data]

  field :metadata, 1, type: Semaphore.ProjectSecrets.V1.Secret.Metadata
  field :data, 2, type: Semaphore.ProjectSecrets.V1.Secret.Data
end

defmodule Semaphore.ProjectSecrets.V1.ListSecretsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          page_size: integer,
          page_token: String.t(),
          order: Semaphore.ProjectSecrets.V1.ListSecretsRequest.Order.t(),
          project_id_or_name: String.t()
        }

  defstruct [:page_size, :page_token, :order, :project_id_or_name]

  field :page_size, 1, type: :int32
  field :page_token, 2, type: :string
  field :order, 3, type: Semaphore.ProjectSecrets.V1.ListSecretsRequest.Order, enum: true
  field :project_id_or_name, 4, type: :string
end

defmodule Semaphore.ProjectSecrets.V1.ListSecretsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          secrets: [Semaphore.ProjectSecrets.V1.Secret.t()],
          next_page_token: String.t()
        }

  defstruct [:secrets, :next_page_token]

  field :secrets, 1, repeated: true, type: Semaphore.ProjectSecrets.V1.Secret
  field :next_page_token, 2, type: :string
end

defmodule Semaphore.ProjectSecrets.V1.GetSecretRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          secret_id_or_name: String.t(),
          project_id_or_name: String.t()
        }

  defstruct [:secret_id_or_name, :project_id_or_name]

  field :secret_id_or_name, 1, type: :string
  field :project_id_or_name, 2, type: :string
end

defmodule Semaphore.ProjectSecrets.V1.UpdateSecretRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          secret_id_or_name: String.t(),
          project_id_or_name: String.t(),
          secret: Semaphore.ProjectSecrets.V1.Secret.t() | nil
        }

  defstruct [:secret_id_or_name, :project_id_or_name, :secret]

  field :secret_id_or_name, 1, type: :string
  field :project_id_or_name, 2, type: :string
  field :secret, 3, type: Semaphore.ProjectSecrets.V1.Secret
end

defmodule Semaphore.ProjectSecrets.V1.DeleteSecretRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          secret_id_or_name: String.t(),
          project_id_or_name: String.t()
        }

  defstruct [:secret_id_or_name, :project_id_or_name]

  field :secret_id_or_name, 1, type: :string
  field :project_id_or_name, 2, type: :string
end

defmodule Semaphore.ProjectSecrets.V1.Empty do
  @moduledoc false
  use Protobuf, syntax: :proto3
  @type t :: %__MODULE__{}

  defstruct []
end

defmodule Semaphore.ProjectSecrets.V1.ProjectSecretsApi.Service do
  @moduledoc false
  use GRPC.Service, name: "semaphore.project_secrets.v1.ProjectSecretsApi"

  rpc(
    :ListSecrets,
    Semaphore.ProjectSecrets.V1.ListSecretsRequest,
    Semaphore.ProjectSecrets.V1.ListSecretsResponse
  )

  rpc(
    :GetSecret,
    Semaphore.ProjectSecrets.V1.GetSecretRequest,
    Semaphore.ProjectSecrets.V1.Secret
  )

  rpc(:CreateSecret, Semaphore.ProjectSecrets.V1.Secret, Semaphore.ProjectSecrets.V1.Secret)

  rpc(
    :UpdateSecret,
    Semaphore.ProjectSecrets.V1.UpdateSecretRequest,
    Semaphore.ProjectSecrets.V1.Secret
  )

  rpc(
    :DeleteSecret,
    Semaphore.ProjectSecrets.V1.DeleteSecretRequest,
    Semaphore.ProjectSecrets.V1.Empty
  )
end

defmodule Semaphore.ProjectSecrets.V1.ProjectSecretsApi.Stub do
  @moduledoc false
  use GRPC.Stub, service: Semaphore.ProjectSecrets.V1.ProjectSecretsApi.Service
end
