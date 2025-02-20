defmodule InternalApi.Plumber.TerminateAllRequest.Reason do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :ADMIN_ACTION, 0
  field :BRANCH_DELETION, 1
end

defmodule InternalApi.Plumber.GetYamlRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :ppl_id, 1, type: :string, json_name: "pplId"
end

defmodule InternalApi.Plumber.GetYamlResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :response_status, 1, type: InternalApi.Plumber.ResponseStatus, json_name: "responseStatus"
  field :yaml, 2, type: :string
end

defmodule InternalApi.Plumber.TerminateAllRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :requester_token, 1, type: :string, json_name: "requesterToken"
  field :project_id, 2, type: :string, json_name: "projectId"
  field :branch_name, 3, type: :string, json_name: "branchName"
  field :reason, 4, type: InternalApi.Plumber.TerminateAllRequest.Reason, enum: true
end

defmodule InternalApi.Plumber.TerminateAllResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :response_status, 1, type: InternalApi.Plumber.ResponseStatus, json_name: "responseStatus"
end

defmodule InternalApi.Plumber.Admin.Service do
  @moduledoc false

  use GRPC.Service, name: "InternalApi.Plumber.Admin", protoc_gen_elixir_version: "0.13.0"

  rpc :TerminateAll,
      InternalApi.Plumber.TerminateAllRequest,
      InternalApi.Plumber.TerminateAllResponse

  rpc :GetYaml, InternalApi.Plumber.GetYamlRequest, InternalApi.Plumber.GetYamlResponse
end

defmodule InternalApi.Plumber.Admin.Stub do
  @moduledoc false

  use GRPC.Stub, service: InternalApi.Plumber.Admin.Service
end