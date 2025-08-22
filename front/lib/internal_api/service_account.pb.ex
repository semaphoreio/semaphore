defmodule InternalApi.ServiceAccount.CreateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          name: String.t(),
          description: String.t(),
          creator_id: String.t()
        }
  defstruct [:org_id, :name, :description, :creator_id]

  field(:org_id, 1, type: :string)
  field(:name, 2, type: :string)
  field(:description, 3, type: :string)
  field(:creator_id, 4, type: :string)
end

defmodule InternalApi.ServiceAccount.CreateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          service_account: InternalApi.ServiceAccount.ServiceAccount.t(),
          api_token: String.t()
        }
  defstruct [:service_account, :api_token]

  field(:service_account, 1, type: InternalApi.ServiceAccount.ServiceAccount)
  field(:api_token, 2, type: :string)
end

defmodule InternalApi.ServiceAccount.ListRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          page_size: integer,
          page_token: String.t()
        }
  defstruct [:org_id, :page_size, :page_token]

  field(:org_id, 1, type: :string)
  field(:page_size, 2, type: :int32)
  field(:page_token, 3, type: :string)
end

defmodule InternalApi.ServiceAccount.ListResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          service_accounts: [InternalApi.ServiceAccount.ServiceAccount.t()],
          next_page_token: String.t()
        }
  defstruct [:service_accounts, :next_page_token]

  field(:service_accounts, 1, repeated: true, type: InternalApi.ServiceAccount.ServiceAccount)
  field(:next_page_token, 2, type: :string)
end

defmodule InternalApi.ServiceAccount.DescribeRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          service_account_id: String.t()
        }
  defstruct [:service_account_id]

  field(:service_account_id, 1, type: :string)
end

defmodule InternalApi.ServiceAccount.DescribeResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          service_account: InternalApi.ServiceAccount.ServiceAccount.t()
        }
  defstruct [:service_account]

  field(:service_account, 1, type: InternalApi.ServiceAccount.ServiceAccount)
end

defmodule InternalApi.ServiceAccount.DescribeManyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          sa_ids: [String.t()]
        }
  defstruct [:sa_ids]

  field(:sa_ids, 1, repeated: true, type: :string)
end

defmodule InternalApi.ServiceAccount.DescribeManyResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          service_accounts: [InternalApi.ServiceAccount.ServiceAccount.t()]
        }
  defstruct [:service_accounts]

  field(:service_accounts, 1, repeated: true, type: InternalApi.ServiceAccount.ServiceAccount)
end

defmodule InternalApi.ServiceAccount.UpdateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          service_account_id: String.t(),
          name: String.t(),
          description: String.t()
        }
  defstruct [:service_account_id, :name, :description]

  field(:service_account_id, 1, type: :string)
  field(:name, 2, type: :string)
  field(:description, 3, type: :string)
end

defmodule InternalApi.ServiceAccount.UpdateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          service_account: InternalApi.ServiceAccount.ServiceAccount.t()
        }
  defstruct [:service_account]

  field(:service_account, 1, type: InternalApi.ServiceAccount.ServiceAccount)
end

defmodule InternalApi.ServiceAccount.DeactivateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          service_account_id: String.t()
        }
  defstruct [:service_account_id]

  field(:service_account_id, 1, type: :string)
end

defmodule InternalApi.ServiceAccount.DeactivateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.ServiceAccount.ReactivateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          service_account_id: String.t()
        }
  defstruct [:service_account_id]

  field(:service_account_id, 1, type: :string)
end

defmodule InternalApi.ServiceAccount.ReactivateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.ServiceAccount.DestroyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          service_account_id: String.t()
        }
  defstruct [:service_account_id]

  field(:service_account_id, 1, type: :string)
end

defmodule InternalApi.ServiceAccount.DestroyResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.ServiceAccount.RegenerateTokenRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          service_account_id: String.t()
        }
  defstruct [:service_account_id]

  field(:service_account_id, 1, type: :string)
end

defmodule InternalApi.ServiceAccount.RegenerateTokenResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          api_token: String.t()
        }
  defstruct [:api_token]

  field(:api_token, 1, type: :string)
end

defmodule InternalApi.ServiceAccount.ServiceAccount do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          description: String.t(),
          org_id: String.t(),
          creator_id: String.t(),
          created_at: Google.Protobuf.Timestamp.t(),
          updated_at: Google.Protobuf.Timestamp.t(),
          deactivated: boolean
        }
  defstruct [
    :id,
    :name,
    :description,
    :org_id,
    :creator_id,
    :created_at,
    :updated_at,
    :deactivated
  ]

  field(:id, 1, type: :string)
  field(:name, 2, type: :string)
  field(:description, 3, type: :string)
  field(:org_id, 4, type: :string)
  field(:creator_id, 5, type: :string)
  field(:created_at, 6, type: Google.Protobuf.Timestamp)
  field(:updated_at, 7, type: Google.Protobuf.Timestamp)
  field(:deactivated, 8, type: :bool)
end

defmodule InternalApi.ServiceAccount.ServiceAccountService.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.ServiceAccount.ServiceAccountService"

  rpc(
    :Create,
    InternalApi.ServiceAccount.CreateRequest,
    InternalApi.ServiceAccount.CreateResponse
  )

  rpc(:List, InternalApi.ServiceAccount.ListRequest, InternalApi.ServiceAccount.ListResponse)

  rpc(
    :Describe,
    InternalApi.ServiceAccount.DescribeRequest,
    InternalApi.ServiceAccount.DescribeResponse
  )

  rpc(
    :DescribeMany,
    InternalApi.ServiceAccount.DescribeManyRequest,
    InternalApi.ServiceAccount.DescribeManyResponse
  )

  rpc(
    :Update,
    InternalApi.ServiceAccount.UpdateRequest,
    InternalApi.ServiceAccount.UpdateResponse
  )

  rpc(
    :Deactivate,
    InternalApi.ServiceAccount.DeactivateRequest,
    InternalApi.ServiceAccount.DeactivateResponse
  )

  rpc(
    :Reactivate,
    InternalApi.ServiceAccount.ReactivateRequest,
    InternalApi.ServiceAccount.ReactivateResponse
  )

  rpc(
    :Destroy,
    InternalApi.ServiceAccount.DestroyRequest,
    InternalApi.ServiceAccount.DestroyResponse
  )

  rpc(
    :RegenerateToken,
    InternalApi.ServiceAccount.RegenerateTokenRequest,
    InternalApi.ServiceAccount.RegenerateTokenResponse
  )
end

defmodule InternalApi.ServiceAccount.ServiceAccountService.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.ServiceAccount.ServiceAccountService.Service
end
