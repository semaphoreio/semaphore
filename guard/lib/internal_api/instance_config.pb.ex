defmodule InternalApi.InstanceConfig.Config do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          type: integer,
          fields: [InternalApi.InstanceConfig.ConfigField.t()],
          state: integer,
          instruction_fields: [InternalApi.InstanceConfig.ConfigField.t()]
        }

  defstruct [:type, :fields, :state, :instruction_fields]
  field(:type, 1, type: InternalApi.InstanceConfig.ConfigType, enum: true)
  field(:fields, 2, repeated: true, type: InternalApi.InstanceConfig.ConfigField)
  field(:state, 3, type: InternalApi.InstanceConfig.State, enum: true)
  field(:instruction_fields, 4, repeated: true, type: InternalApi.InstanceConfig.ConfigField)
end

defmodule InternalApi.InstanceConfig.ListConfigsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          types: [integer]
        }

  defstruct [:types]
  field(:types, 1, repeated: true, type: InternalApi.InstanceConfig.ConfigType, enum: true)
end

defmodule InternalApi.InstanceConfig.ListConfigsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          configs: [InternalApi.InstanceConfig.Config.t()]
        }

  defstruct [:configs]
  field(:configs, 1, repeated: true, type: InternalApi.InstanceConfig.Config)
end

defmodule InternalApi.InstanceConfig.ConfigField do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          key: String.t(),
          value: String.t()
        }

  defstruct [:key, :value]
  field(:key, 1, type: :string)
  field(:value, 2, type: :string)
end

defmodule InternalApi.InstanceConfig.ModifyConfigRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          config: InternalApi.InstanceConfig.Config.t()
        }

  defstruct [:config]
  field(:config, 1, type: InternalApi.InstanceConfig.Config)
end

defmodule InternalApi.InstanceConfig.ModifyConfigResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.InstanceConfig.State do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:STATE_UNSPECIFIED, 0)

  field(:STATE_EMPTY, 1)

  field(:STATE_CONFIGURED, 2)

  field(:STATE_WITH_ERRORS, 3)
end

defmodule InternalApi.InstanceConfig.ConfigType do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:CONFIG_TYPE_UNSPECIFIED, 0)

  field(:CONFIG_TYPE_GITHUB_APP, 1)

  field(:CONFIG_TYPE_INSTALLATION_DEFAULTS, 2)

  field(:CONFIG_TYPE_BITBUCKET_APP, 3)

  field(:CONFIG_TYPE_GITLAB_APP, 4)
end

defmodule InternalApi.InstanceConfig.ConfigModified do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          type: integer,
          timestamp: Google.Protobuf.Timestamp.t() | nil
        }

  defstruct [:type, :timestamp]
  field(:type, 1, type: InternalApi.InstanceConfig.ConfigType, enum: true)
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.InstanceConfig.InstanceConfigService.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.InstanceConfig.InstanceConfigService"

  rpc(
    :ListConfigs,
    InternalApi.InstanceConfig.ListConfigsRequest,
    InternalApi.InstanceConfig.ListConfigsResponse
  )

  rpc(
    :ModifyConfig,
    InternalApi.InstanceConfig.ModifyConfigRequest,
    InternalApi.InstanceConfig.ModifyConfigResponse
  )
end

defmodule InternalApi.InstanceConfig.InstanceConfigService.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.InstanceConfig.InstanceConfigService.Service
end
