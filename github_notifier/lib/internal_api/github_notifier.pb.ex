defmodule InternalApi.GithubNotifier.BlockStartedRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          pipeline_id: String.t(),
          block_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t() | nil
        }

  defstruct [:pipeline_id, :block_id, :timestamp]

  field(:pipeline_id, 1, type: :string)
  field(:block_id, 2, type: :string)
  field(:timestamp, 3, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.GithubNotifier.BlockStartedResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.ResponseStatus.t() | nil
        }

  defstruct [:status]

  field(:status, 1, type: InternalApi.ResponseStatus)
end

defmodule InternalApi.GithubNotifier.BlockFinishedRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          pipeline_id: String.t(),
          block_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t() | nil
        }

  defstruct [:pipeline_id, :block_id, :timestamp]

  field(:pipeline_id, 1, type: :string)
  field(:block_id, 2, type: :string)
  field(:timestamp, 3, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.GithubNotifier.BlockFinishedResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.ResponseStatus.t() | nil
        }

  defstruct [:status]

  field(:status, 1, type: InternalApi.ResponseStatus)
end

defmodule InternalApi.GithubNotifier.PipelineStartedRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          pipeline_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t() | nil
        }

  defstruct [:pipeline_id, :timestamp]

  field(:pipeline_id, 1, type: :string)
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.GithubNotifier.PipelineStartedResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.ResponseStatus.t() | nil
        }

  defstruct [:status]

  field(:status, 1, type: InternalApi.ResponseStatus)
end

defmodule InternalApi.GithubNotifier.PipelineFinishedRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          pipeline_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t() | nil
        }

  defstruct [:pipeline_id, :timestamp]

  field(:pipeline_id, 1, type: :string)
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.GithubNotifier.PipelineFinishedResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.ResponseStatus.t() | nil
        }

  defstruct [:status]

  field(:status, 1, type: InternalApi.ResponseStatus)
end

defmodule InternalApi.GithubNotifier.GithubNotifier.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.GithubNotifier.GithubNotifier"

  rpc(
    :BlockStarted,
    InternalApi.GithubNotifier.BlockStartedRequest,
    InternalApi.GithubNotifier.BlockStartedResponse
  )

  rpc(
    :BlockFinished,
    InternalApi.GithubNotifier.BlockFinishedRequest,
    InternalApi.GithubNotifier.BlockFinishedResponse
  )

  rpc(
    :PipelineStarted,
    InternalApi.GithubNotifier.PipelineStartedRequest,
    InternalApi.GithubNotifier.PipelineStartedResponse
  )

  rpc(
    :PipelineFinished,
    InternalApi.GithubNotifier.PipelineFinishedRequest,
    InternalApi.GithubNotifier.PipelineFinishedResponse
  )
end

defmodule InternalApi.GithubNotifier.GithubNotifier.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.GithubNotifier.GithubNotifier.Service
end
