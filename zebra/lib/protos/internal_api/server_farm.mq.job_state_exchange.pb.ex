defmodule InternalApi.ServerFarm.MQ.JobStateExchange.JobStarted do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          job_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t(),
          agent_id: String.t(),
          agent_name: String.t()
        }
  defstruct [:job_id, :timestamp, :agent_id, :agent_name]

  field :job_id, 1, type: :string
  field :timestamp, 2, type: Google.Protobuf.Timestamp
  field :agent_id, 3, type: :string
  field :agent_name, 4, type: :string
end

defmodule InternalApi.ServerFarm.MQ.JobStateExchange.JobFinished do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          job_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t(),
          self_hosted: boolean
        }
  defstruct [:job_id, :timestamp, :self_hosted]

  field :job_id, 1, type: :string
  field :timestamp, 2, type: Google.Protobuf.Timestamp
  field :self_hosted, 3, type: :bool
end
