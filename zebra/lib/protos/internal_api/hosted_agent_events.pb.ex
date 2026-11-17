defmodule InternalApi.HostedAgentEvents.AgentLost do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          agent_id: String.t(),
          job_id: String.t(),
          reason: integer,
          at: Google.Protobuf.Timestamp.t(),
          agent_type: String.t()
        }
  defstruct [:agent_id, :job_id, :reason, :at, :agent_type]

  field(:agent_id, 1, type: :string)
  field(:job_id, 2, type: :string)
  field(:reason, 3, type: InternalApi.HostedAgentEvents.AgentLost.Reason, enum: true)
  field(:at, 4, type: Google.Protobuf.Timestamp)
  field(:agent_type, 6, type: :string)
end

defmodule InternalApi.HostedAgentEvents.AgentLost.Reason do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:REASON_UNSPECIFIED, 0)
  field(:PREEMPTED, 1)
  field(:MACHINE_TERMINATED, 2)
  field(:MACHINE_MISSING, 3)
end
