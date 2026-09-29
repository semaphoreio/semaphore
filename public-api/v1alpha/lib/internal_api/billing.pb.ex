defmodule InternalApi.Billing.CanSetupOrganizationRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          owner_id: String.t()
        }
  defstruct [:owner_id]

  field(:owner_id, 1, type: :string)
end

defmodule InternalApi.Billing.CanSetupOrganizationResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          allowed: boolean,
          errors: [String.t()]
        }
  defstruct [:allowed, :errors]

  field(:allowed, 1, type: :bool)
  field(:errors, 2, repeated: true, type: :string)
end

# Client-only subset of InternalApi.Billing: only CanSetupOrganization is used here.
defmodule InternalApi.Billing.BillingService.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.Billing.BillingService"

  rpc(
    :CanSetupOrganization,
    InternalApi.Billing.CanSetupOrganizationRequest,
    InternalApi.Billing.CanSetupOrganizationResponse
  )
end

defmodule InternalApi.Billing.BillingService.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.Billing.BillingService.Service
end
