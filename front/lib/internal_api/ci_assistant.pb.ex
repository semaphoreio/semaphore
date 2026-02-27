defmodule InternalApi.CiAssistant.StartOnboardingRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          user_id: String.t(),
          project_id: String.t()
        }
  defstruct [:org_id, :user_id, :project_id]

  field(:org_id, 1, type: :string)
  field(:user_id, 2, type: :string)
  field(:project_id, 3, type: :string)
end

defmodule InternalApi.CiAssistant.StartOnboardingResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          session_key: String.t()
        }
  defstruct [:session_key]

  field(:session_key, 1, type: :string)
end

defmodule InternalApi.CiAssistant.GetOnboardingStatusRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          session_key: String.t()
        }
  defstruct [:session_key]

  field(:session_key, 1, type: :string)
end

defmodule InternalApi.CiAssistant.GetOnboardingStatusResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: String.t(),
          yaml_content: String.t(),
          commit_sha: String.t(),
          branch: String.t(),
          error: String.t(),
          tool_log: [String.t()]
        }
  defstruct [:status, :yaml_content, :commit_sha, :branch, :error, tool_log: []]

  field(:status, 1, type: :string)
  field(:yaml_content, 2, type: :string)
  field(:commit_sha, 3, type: :string)
  field(:branch, 4, type: :string)
  field(:error, 5, type: :string)
  field(:tool_log, 6, repeated: true, type: :string)
end

defmodule InternalApi.CiAssistant.Gateway.Service do
  @moduledoc false
  use GRPC.Service, name: "gateway.Gateway"

  rpc(
    :StartOnboarding,
    InternalApi.CiAssistant.StartOnboardingRequest,
    InternalApi.CiAssistant.StartOnboardingResponse
  )

  rpc(
    :GetOnboardingStatus,
    InternalApi.CiAssistant.GetOnboardingStatusRequest,
    InternalApi.CiAssistant.GetOnboardingStatusResponse
  )
end

defmodule InternalApi.CiAssistant.Gateway.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.CiAssistant.Gateway.Service
end
