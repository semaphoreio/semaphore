defmodule InternalApi.Paparazzo.PutRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          content: String.t(),
          ttl_sec: non_neg_integer
        }
  defstruct [:content, :ttl_sec]

  field(:content, 2, type: :string)
  field(:ttl_sec, 3, type: :uint32)
end

defmodule InternalApi.Paparazzo.PutResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: Google.Rpc.Status.t(),
          id: String.t()
        }
  defstruct [:status, :id]

  field(:status, 1, type: Google.Rpc.Status)
  field(:id, 2, type: :string)
end

defmodule InternalApi.Paparazzo.GetRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t()
        }
  defstruct [:id]

  field(:id, 1, type: :string)
end

defmodule InternalApi.Paparazzo.GetResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: Google.Rpc.Status.t(),
          content: String.t()
        }
  defstruct [:status, :content]

  field(:status, 1, type: Google.Rpc.Status)
  field(:content, 2, type: :string)
end

defmodule InternalApi.Paparazzo.DeleteRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t()
        }
  defstruct [:id]

  field(:id, 1, type: :string)
end

defmodule InternalApi.Paparazzo.DeleteResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: Google.Rpc.Status.t(),
          content: String.t()
        }
  defstruct [:status, :content]

  field(:status, 1, type: Google.Rpc.Status)
  field(:content, 2, type: :string)
end

defmodule InternalApi.Paparazzo.GetFileRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          path: String.t()
        }
  defstruct [:id, :path]

  field(:id, 1, type: :string)
  field(:path, 2, type: :string)
end

defmodule InternalApi.Paparazzo.GetFileResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: Google.Rpc.Status.t(),
          content: String.t()
        }
  defstruct [:status, :content]

  field(:status, 1, type: Google.Rpc.Status)
  field(:content, 2, type: :string)
end

defmodule InternalApi.Paparazzo.SnapshotService.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.Paparazzo.SnapshotService"

  rpc(:Put, InternalApi.Paparazzo.PutRequest, InternalApi.Paparazzo.PutResponse)
  rpc(:Get, InternalApi.Paparazzo.GetRequest, InternalApi.Paparazzo.GetResponse)
  rpc(:Delete, InternalApi.Paparazzo.DeleteRequest, InternalApi.Paparazzo.DeleteResponse)
  rpc(:GetFile, InternalApi.Paparazzo.GetFileRequest, InternalApi.Paparazzo.GetFileResponse)
end

defmodule InternalApi.Paparazzo.SnapshotService.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.Paparazzo.SnapshotService.Service
end
