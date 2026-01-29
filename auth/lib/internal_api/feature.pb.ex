defmodule InternalApi.Feature.Machine.Platform do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :LINUX, 0
  field :MAC, 1
end

defmodule InternalApi.Feature.Availability.State do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :HIDDEN, 0
  field :ZERO_STATE, 1
  field :ENABLED, 2
end

defmodule InternalApi.Feature.ListOrganizationFeaturesRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :org_id, 1, type: :string, json_name: "orgId"
end

defmodule InternalApi.Feature.ListOrganizationFeaturesResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :organization_features, 1,
    repeated: true,
    type: InternalApi.Feature.OrganizationFeature,
    json_name: "organizationFeatures"
end

defmodule InternalApi.Feature.OrganizationFeature do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :feature, 1, type: InternalApi.Feature.Feature
  field :availability, 2, type: InternalApi.Feature.Availability
  field :project_ids, 3, repeated: true, type: :string, json_name: "projectIds"
  field :requester_id, 5, type: :string, json_name: "requesterId"
  field :created_at, 6, type: Google.Protobuf.Timestamp, json_name: "createdAt"
  field :updated_at, 7, type: Google.Protobuf.Timestamp, json_name: "updatedAt"
end

defmodule InternalApi.Feature.ListFeaturesRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"
end

defmodule InternalApi.Feature.ListFeaturesResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :features, 1, repeated: true, type: InternalApi.Feature.Feature
end

defmodule InternalApi.Feature.Feature do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :type, 1, type: :string
  field :availability, 2, type: InternalApi.Feature.Availability
  field :name, 3, type: :string
  field :description, 4, type: :string
end

defmodule InternalApi.Feature.ListOrganizationMachinesRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :org_id, 1, type: :string, json_name: "orgId"
end

defmodule InternalApi.Feature.ListOrganizationMachinesResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :organization_machines, 1,
    repeated: true,
    type: InternalApi.Feature.OrganizationMachine,
    json_name: "organizationMachines"

  field :default_type, 2, type: :string, json_name: "defaultType"
end

defmodule InternalApi.Feature.OrganizationMachine do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :machine, 1, type: InternalApi.Feature.Machine
  field :availability, 2, type: InternalApi.Feature.Availability
  field :requester_id, 3, type: :string, json_name: "requesterId"
  field :created_at, 4, type: Google.Protobuf.Timestamp, json_name: "createdAt"
  field :updated_at, 5, type: Google.Protobuf.Timestamp, json_name: "updatedAt"
end

defmodule InternalApi.Feature.ListMachinesRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"
end

defmodule InternalApi.Feature.ListMachinesResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :machines, 1, repeated: true, type: InternalApi.Feature.Machine
end

defmodule InternalApi.Feature.Machine do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :type, 1, type: :string
  field :availability, 2, type: InternalApi.Feature.Availability
  field :platform, 3, type: InternalApi.Feature.Machine.Platform, enum: true
  field :vcpu, 4, type: :string
  field :ram, 5, type: :string
  field :disk, 6, type: :string
  field :default_os_image, 7, type: :string, json_name: "defaultOsImage"
  field :os_images, 8, repeated: true, type: :string, json_name: "osImages"
end

defmodule InternalApi.Feature.Availability do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :state, 1, type: InternalApi.Feature.Availability.State, enum: true
  field :quantity, 2, type: :uint32
end

defmodule InternalApi.Feature.MachinesChanged do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"
end

defmodule InternalApi.Feature.OrganizationMachinesChanged do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :org_id, 1, type: :string, json_name: "orgId"
end

defmodule InternalApi.Feature.FeaturesChanged do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"
end

defmodule InternalApi.Feature.OrganizationFeaturesChanged do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :org_id, 1, type: :string, json_name: "orgId"
end

defmodule InternalApi.Feature.FeatureService.Service do
  @moduledoc false

  use GRPC.Service,
    name: "InternalApi.Feature.FeatureService",
    protoc_gen_elixir_version: "0.12.0"

  rpc :ListOrganizationFeatures,
      InternalApi.Feature.ListOrganizationFeaturesRequest,
      InternalApi.Feature.ListOrganizationFeaturesResponse

  rpc :ListFeatures,
      InternalApi.Feature.ListFeaturesRequest,
      InternalApi.Feature.ListFeaturesResponse

  rpc :ListOrganizationMachines,
      InternalApi.Feature.ListOrganizationMachinesRequest,
      InternalApi.Feature.ListOrganizationMachinesResponse

  rpc :ListMachines,
      InternalApi.Feature.ListMachinesRequest,
      InternalApi.Feature.ListMachinesResponse
end

defmodule InternalApi.Feature.FeatureService.Stub do
  @moduledoc false

  use GRPC.Stub, service: InternalApi.Feature.FeatureService.Service
end