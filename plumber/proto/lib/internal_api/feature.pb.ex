defmodule InternalApi.Feature.ListOrganizationFeaturesRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t()
        }
  defstruct [:org_id]

  field(:org_id, 1, type: :string)
end

defmodule InternalApi.Feature.ListOrganizationFeaturesResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          organization_features: [InternalApi.Feature.OrganizationFeature.t()]
        }
  defstruct [:organization_features]

  field(:organization_features, 1, repeated: true, type: InternalApi.Feature.OrganizationFeature)
end

defmodule InternalApi.Feature.OrganizationFeature do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          feature: InternalApi.Feature.Feature.t(),
          availability: InternalApi.Feature.Availability.t(),
          project_ids: [String.t()],
          requester_id: String.t(),
          created_at: Google.Protobuf.Timestamp.t(),
          updated_at: Google.Protobuf.Timestamp.t()
        }
  defstruct [:feature, :availability, :project_ids, :requester_id, :created_at, :updated_at]

  field(:feature, 1, type: InternalApi.Feature.Feature)
  field(:availability, 2, type: InternalApi.Feature.Availability)
  field(:project_ids, 3, repeated: true, type: :string)
  field(:requester_id, 5, type: :string)
  field(:created_at, 6, type: Google.Protobuf.Timestamp)
  field(:updated_at, 7, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Feature.ListFeaturesRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.Feature.ListFeaturesResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          features: [InternalApi.Feature.Feature.t()]
        }
  defstruct [:features]

  field(:features, 1, repeated: true, type: InternalApi.Feature.Feature)
end

defmodule InternalApi.Feature.Feature do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          type: String.t(),
          availability: InternalApi.Feature.Availability.t(),
          name: String.t(),
          description: String.t()
        }
  defstruct [:type, :availability, :name, :description]

  field(:type, 1, type: :string)
  field(:availability, 2, type: InternalApi.Feature.Availability)
  field(:name, 3, type: :string)
  field(:description, 4, type: :string)
end

defmodule InternalApi.Feature.ListOrganizationMachinesRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t()
        }
  defstruct [:org_id]

  field(:org_id, 1, type: :string)
end

defmodule InternalApi.Feature.ListOrganizationMachinesResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          organization_machines: [InternalApi.Feature.OrganizationMachine.t()],
          default_type: String.t()
        }
  defstruct [:organization_machines, :default_type]

  field(:organization_machines, 1, repeated: true, type: InternalApi.Feature.OrganizationMachine)
  field(:default_type, 2, type: :string)
end

defmodule InternalApi.Feature.OrganizationMachine do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          machine: InternalApi.Feature.Machine.t(),
          availability: InternalApi.Feature.Availability.t(),
          requester_id: String.t(),
          created_at: Google.Protobuf.Timestamp.t(),
          updated_at: Google.Protobuf.Timestamp.t()
        }
  defstruct [:machine, :availability, :requester_id, :created_at, :updated_at]

  field(:machine, 1, type: InternalApi.Feature.Machine)
  field(:availability, 2, type: InternalApi.Feature.Availability)
  field(:requester_id, 3, type: :string)
  field(:created_at, 4, type: Google.Protobuf.Timestamp)
  field(:updated_at, 5, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Feature.ListMachinesRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.Feature.ListMachinesResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          machines: [InternalApi.Feature.Machine.t()]
        }
  defstruct [:machines]

  field(:machines, 1, repeated: true, type: InternalApi.Feature.Machine)
end

defmodule InternalApi.Feature.Machine do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          type: String.t(),
          availability: InternalApi.Feature.Availability.t(),
          platform: integer,
          vcpu: String.t(),
          ram: String.t(),
          disk: String.t(),
          default_os_image: String.t(),
          os_images: [String.t()]
        }
  defstruct [:type, :availability, :platform, :vcpu, :ram, :disk, :default_os_image, :os_images]

  field(:type, 1, type: :string)
  field(:availability, 2, type: InternalApi.Feature.Availability)
  field(:platform, 3, type: InternalApi.Feature.Machine.Platform, enum: true)
  field(:vcpu, 4, type: :string)
  field(:ram, 5, type: :string)
  field(:disk, 6, type: :string)
  field(:default_os_image, 7, type: :string)
  field(:os_images, 8, repeated: true, type: :string)
end

defmodule InternalApi.Feature.Machine.Platform do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:LINUX, 0)
  field(:MAC, 1)
end

defmodule InternalApi.Feature.Availability do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          state: integer,
          quantity: non_neg_integer
        }
  defstruct [:state, :quantity]

  field(:state, 1, type: InternalApi.Feature.Availability.State, enum: true)
  field(:quantity, 2, type: :uint32)
end

defmodule InternalApi.Feature.Availability.State do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:HIDDEN, 0)
  field(:ZERO_STATE, 1)
  field(:ENABLED, 2)
end

defmodule InternalApi.Feature.MachinesChanged do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.Feature.OrganizationMachinesChanged do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t()
        }
  defstruct [:org_id]

  field(:org_id, 1, type: :string)
end

defmodule InternalApi.Feature.FeaturesChanged do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.Feature.OrganizationFeaturesChanged do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t()
        }
  defstruct [:org_id]

  field(:org_id, 1, type: :string)
end

defmodule InternalApi.Feature.FeatureService.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.Feature.FeatureService"

  rpc(
    :ListOrganizationFeatures,
    InternalApi.Feature.ListOrganizationFeaturesRequest,
    InternalApi.Feature.ListOrganizationFeaturesResponse
  )

  rpc(
    :ListFeatures,
    InternalApi.Feature.ListFeaturesRequest,
    InternalApi.Feature.ListFeaturesResponse
  )

  rpc(
    :ListOrganizationMachines,
    InternalApi.Feature.ListOrganizationMachinesRequest,
    InternalApi.Feature.ListOrganizationMachinesResponse
  )

  rpc(
    :ListMachines,
    InternalApi.Feature.ListMachinesRequest,
    InternalApi.Feature.ListMachinesResponse
  )
end

defmodule InternalApi.Feature.FeatureService.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.Feature.FeatureService.Service
end
