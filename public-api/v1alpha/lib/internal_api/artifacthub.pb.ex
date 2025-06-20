defmodule InternalApi.Artifacthub.HealthCheckRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.Artifacthub.HealthCheckResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.Artifacthub.RetentionPolicy do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_level_retention_policies: [
            InternalApi.Artifacthub.RetentionPolicy.RetentionPolicyRule.t()
          ],
          workflow_level_retention_policies: [
            InternalApi.Artifacthub.RetentionPolicy.RetentionPolicyRule.t()
          ],
          job_level_retention_policies: [
            InternalApi.Artifacthub.RetentionPolicy.RetentionPolicyRule.t()
          ],
          scheduled_for_cleaning_at: Google.Protobuf.Timestamp.t(),
          last_cleaned_at: Google.Protobuf.Timestamp.t()
        }
  defstruct [
    :project_level_retention_policies,
    :workflow_level_retention_policies,
    :job_level_retention_policies,
    :scheduled_for_cleaning_at,
    :last_cleaned_at
  ]

  field(:project_level_retention_policies, 1,
    repeated: true,
    type: InternalApi.Artifacthub.RetentionPolicy.RetentionPolicyRule
  )

  field(:workflow_level_retention_policies, 2,
    repeated: true,
    type: InternalApi.Artifacthub.RetentionPolicy.RetentionPolicyRule
  )

  field(:job_level_retention_policies, 3,
    repeated: true,
    type: InternalApi.Artifacthub.RetentionPolicy.RetentionPolicyRule
  )

  field(:scheduled_for_cleaning_at, 4, type: Google.Protobuf.Timestamp)
  field(:last_cleaned_at, 5, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Artifacthub.RetentionPolicy.RetentionPolicyRule do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          selector: String.t(),
          age: integer
        }
  defstruct [:selector, :age]

  field(:selector, 1, type: :string)
  field(:age, 2, type: :int64)
end

defmodule InternalApi.Artifacthub.UpdateRetentionPolicyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          artifact_id: String.t(),
          retention_policy: InternalApi.Artifacthub.RetentionPolicy.t()
        }
  defstruct [:artifact_id, :retention_policy]

  field(:artifact_id, 1, type: :string)
  field(:retention_policy, 2, type: InternalApi.Artifacthub.RetentionPolicy)
end

defmodule InternalApi.Artifacthub.UpdateRetentionPolicyResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          retention_policy: InternalApi.Artifacthub.RetentionPolicy.t()
        }
  defstruct [:retention_policy]

  field(:retention_policy, 1, type: InternalApi.Artifacthub.RetentionPolicy)
end

defmodule InternalApi.Artifacthub.CreateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          request_token: String.t(),
          retention_policy: InternalApi.Artifacthub.RetentionPolicy.t()
        }
  defstruct [:request_token, :retention_policy]

  field(:request_token, 1, type: :string)
  field(:retention_policy, 2, type: InternalApi.Artifacthub.RetentionPolicy)
end

defmodule InternalApi.Artifacthub.CreateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          artifact: InternalApi.Artifacthub.Artifact.t()
        }
  defstruct [:artifact]

  field(:artifact, 1, type: InternalApi.Artifacthub.Artifact)
end

defmodule InternalApi.Artifacthub.DescribeRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          artifact_id: String.t(),
          include_retention_policy: boolean
        }
  defstruct [:artifact_id, :include_retention_policy]

  field(:artifact_id, 1, type: :string)
  field(:include_retention_policy, 2, type: :bool)
end

defmodule InternalApi.Artifacthub.DescribeResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          artifact: InternalApi.Artifacthub.Artifact.t(),
          retention_policy: InternalApi.Artifacthub.RetentionPolicy.t()
        }
  defstruct [:artifact, :retention_policy]

  field(:artifact, 1, type: InternalApi.Artifacthub.Artifact)
  field(:retention_policy, 2, type: InternalApi.Artifacthub.RetentionPolicy)
end

defmodule InternalApi.Artifacthub.DestroyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          artifact_id: String.t()
        }
  defstruct [:artifact_id]

  field(:artifact_id, 1, type: :string)
end

defmodule InternalApi.Artifacthub.DestroyResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.Artifacthub.ListPathRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          artifact_id: String.t(),
          path: String.t(),
          unwrap_directories: boolean
        }
  defstruct [:artifact_id, :path, :unwrap_directories]

  field(:artifact_id, 1, type: :string)
  field(:path, 2, type: :string)
  field(:unwrap_directories, 3, type: :bool)
end

defmodule InternalApi.Artifacthub.ListPathResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          items: [InternalApi.Artifacthub.ListItem.t()]
        }
  defstruct [:items]

  field(:items, 1, repeated: true, type: InternalApi.Artifacthub.ListItem)
end

defmodule InternalApi.Artifacthub.DeletePathRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          artifact_id: String.t(),
          path: String.t()
        }
  defstruct [:artifact_id, :path]

  field(:artifact_id, 1, type: :string)
  field(:path, 2, type: :string)
end

defmodule InternalApi.Artifacthub.DeletePathResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.Artifacthub.CleanupRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.Artifacthub.CleanupResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.Artifacthub.GetSignedURLRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          artifact_id: String.t(),
          path: String.t(),
          method: String.t()
        }
  defstruct [:artifact_id, :path, :method]

  field(:artifact_id, 1, type: :string)
  field(:path, 2, type: :string)
  field(:method, 3, type: :string)
end

defmodule InternalApi.Artifacthub.GetSignedURLResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          url: String.t()
        }
  defstruct [:url]

  field(:url, 1, type: :string)
end

defmodule InternalApi.Artifacthub.ListBucketsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          ids: [String.t()]
        }
  defstruct [:ids]

  field(:ids, 1, repeated: true, type: :string)
end

defmodule InternalApi.Artifacthub.ListBucketsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          bucket_names_for_ids: %{String.t() => String.t()}
        }
  defstruct [:bucket_names_for_ids]

  field(:bucket_names_for_ids, 1,
    repeated: true,
    type: InternalApi.Artifacthub.ListBucketsResponse.BucketNamesForIdsEntry,
    map: true
  )
end

defmodule InternalApi.Artifacthub.ListBucketsResponse.BucketNamesForIdsEntry do
  @moduledoc false
  use Protobuf, map: true, syntax: :proto3

  @type t :: %__MODULE__{
          key: String.t(),
          value: String.t()
        }
  defstruct [:key, :value]

  field(:key, 1, type: :string)
  field(:value, 2, type: :string)
end

defmodule InternalApi.Artifacthub.CountArtifactsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          category: integer,
          category_id: String.t(),
          artifact_id: String.t()
        }
  defstruct [:category, :category_id, :artifact_id]

  field(:category, 1, type: InternalApi.Artifacthub.CountArtifactsRequest.Category, enum: true)
  field(:category_id, 2, type: :string)
  field(:artifact_id, 3, type: :string)
end

defmodule InternalApi.Artifacthub.CountArtifactsRequest.Category do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:PROJECT, 0)
  field(:WORKFLOW, 1)
  field(:JOB, 2)
end

defmodule InternalApi.Artifacthub.CountArtifactsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          artifact_count: integer
        }
  defstruct [:artifact_count]

  field(:artifact_count, 5, type: :int32)
end

defmodule InternalApi.Artifacthub.CountBucketsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.Artifacthub.CountBucketsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          bucket_count: integer
        }
  defstruct [:bucket_count]

  field(:bucket_count, 1, type: :int32)
end

defmodule InternalApi.Artifacthub.UpdateCORSRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          bucket_name: String.t()
        }
  defstruct [:bucket_name]

  field(:bucket_name, 1, type: :string)
end

defmodule InternalApi.Artifacthub.UpdateCORSResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          next_bucket_name: String.t()
        }
  defstruct [:next_bucket_name]

  field(:next_bucket_name, 1, type: :string)
end

defmodule InternalApi.Artifacthub.ListItem do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          is_directory: boolean
        }
  defstruct [:name, :is_directory]

  field(:name, 1, type: :string)
  field(:is_directory, 2, type: :bool)
end

defmodule InternalApi.Artifacthub.Artifact do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          bucket_name: String.t(),
          artifact_token: String.t()
        }
  defstruct [:id, :bucket_name, :artifact_token]

  field(:id, 1, type: :string)
  field(:bucket_name, 2, type: :string)
  field(:artifact_token, 4, type: :string)
end

defmodule InternalApi.Artifacthub.GenerateTokenRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          artifact_id: String.t(),
          job_id: String.t(),
          workflow_id: String.t(),
          project_id: String.t(),
          duration: non_neg_integer
        }
  defstruct [:artifact_id, :job_id, :workflow_id, :project_id, :duration]

  field(:artifact_id, 1, type: :string)
  field(:job_id, 2, type: :string)
  field(:workflow_id, 3, type: :string)
  field(:project_id, 4, type: :string)
  field(:duration, 5, type: :uint32)
end

defmodule InternalApi.Artifacthub.GenerateTokenResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          token: String.t()
        }
  defstruct [:token]

  field(:token, 1, type: :string)
end

defmodule InternalApi.Artifacthub.ArtifactService.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.Artifacthub.ArtifactService"

  rpc(
    :HealthCheck,
    InternalApi.Artifacthub.HealthCheckRequest,
    InternalApi.Artifacthub.HealthCheckResponse
  )

  rpc(:Create, InternalApi.Artifacthub.CreateRequest, InternalApi.Artifacthub.CreateResponse)

  rpc(
    :Describe,
    InternalApi.Artifacthub.DescribeRequest,
    InternalApi.Artifacthub.DescribeResponse
  )

  rpc(:Destroy, InternalApi.Artifacthub.DestroyRequest, InternalApi.Artifacthub.DestroyResponse)

  rpc(
    :ListPath,
    InternalApi.Artifacthub.ListPathRequest,
    InternalApi.Artifacthub.ListPathResponse
  )

  rpc(
    :DeletePath,
    InternalApi.Artifacthub.DeletePathRequest,
    InternalApi.Artifacthub.DeletePathResponse
  )

  rpc(
    :UpdateRetentionPolicy,
    InternalApi.Artifacthub.UpdateRetentionPolicyRequest,
    InternalApi.Artifacthub.UpdateRetentionPolicyResponse
  )

  rpc(
    :GenerateToken,
    InternalApi.Artifacthub.GenerateTokenRequest,
    InternalApi.Artifacthub.GenerateTokenResponse
  )

  rpc(:Cleanup, InternalApi.Artifacthub.CleanupRequest, InternalApi.Artifacthub.CleanupResponse)

  rpc(
    :GetSignedURL,
    InternalApi.Artifacthub.GetSignedURLRequest,
    InternalApi.Artifacthub.GetSignedURLResponse
  )

  rpc(
    :ListBuckets,
    InternalApi.Artifacthub.ListBucketsRequest,
    InternalApi.Artifacthub.ListBucketsResponse
  )

  rpc(
    :CountArtifacts,
    InternalApi.Artifacthub.CountArtifactsRequest,
    InternalApi.Artifacthub.CountArtifactsResponse
  )

  rpc(
    :CountBuckets,
    InternalApi.Artifacthub.CountBucketsRequest,
    InternalApi.Artifacthub.CountBucketsResponse
  )

  rpc(
    :UpdateCORS,
    InternalApi.Artifacthub.UpdateCORSRequest,
    InternalApi.Artifacthub.UpdateCORSResponse
  )
end

defmodule InternalApi.Artifacthub.ArtifactService.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.Artifacthub.ArtifactService.Service
end
