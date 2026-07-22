defmodule InternalApi.GithubNotifier.BlockStartedRequest do
  @moduledoc false

  use Protobuf,
    full_name: "InternalApi.GithubNotifier.BlockStartedRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field(:pipeline_id, 1, type: :string, json_name: "pipelineId")
  field(:block_id, 2, type: :string, json_name: "blockId")
  field(:timestamp, 3, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.GithubNotifier.BlockStartedResponse do
  @moduledoc false

  use Protobuf,
    full_name: "InternalApi.GithubNotifier.BlockStartedResponse",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field(:status, 1, type: InternalApi.ResponseStatus)
end

defmodule InternalApi.GithubNotifier.BlockFinishedRequest do
  @moduledoc false

  use Protobuf,
    full_name: "InternalApi.GithubNotifier.BlockFinishedRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field(:pipeline_id, 1, type: :string, json_name: "pipelineId")
  field(:block_id, 2, type: :string, json_name: "blockId")
  field(:timestamp, 3, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.GithubNotifier.BlockFinishedResponse do
  @moduledoc false

  use Protobuf,
    full_name: "InternalApi.GithubNotifier.BlockFinishedResponse",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field(:status, 1, type: InternalApi.ResponseStatus)
end

defmodule InternalApi.GithubNotifier.PipelineStartedRequest do
  @moduledoc false

  use Protobuf,
    full_name: "InternalApi.GithubNotifier.PipelineStartedRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field(:pipeline_id, 1, type: :string, json_name: "pipelineId")
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.GithubNotifier.PipelineStartedResponse do
  @moduledoc false

  use Protobuf,
    full_name: "InternalApi.GithubNotifier.PipelineStartedResponse",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field(:status, 1, type: InternalApi.ResponseStatus)
end

defmodule InternalApi.GithubNotifier.PipelineFinishedRequest do
  @moduledoc false

  use Protobuf,
    full_name: "InternalApi.GithubNotifier.PipelineFinishedRequest",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field(:pipeline_id, 1, type: :string, json_name: "pipelineId")
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.GithubNotifier.PipelineFinishedResponse do
  @moduledoc false

  use Protobuf,
    full_name: "InternalApi.GithubNotifier.PipelineFinishedResponse",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field(:status, 1, type: InternalApi.ResponseStatus)
end

defmodule InternalApi.GithubNotifier.GithubNotifier.Service do
  @moduledoc false

  use GRPC.Service,
    name: "InternalApi.GithubNotifier.GithubNotifier",
    protoc_gen_elixir_version: "0.17.0"

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
