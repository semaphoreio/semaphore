defmodule InternalApi.Artifacthub.CountArtifactsRequest.Category do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:PROJECT, 0)
  field(:WORKFLOW, 1)
  field(:JOB, 2)
end

defmodule InternalApi.Artifacthub.HealthCheckRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"
end

defmodule InternalApi.Artifacthub.HealthCheckResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"
end

defmodule InternalApi.Artifacthub.RetentionPolicy.RetentionPolicyRule do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:selector, 1, type: :string)
  field(:age, 2, type: :int64)
end

defmodule InternalApi.Artifacthub.RetentionPolicy do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:project_level_retention_policies, 1,
    repeated: true,
    type: InternalApi.Artifacthub.RetentionPolicy.RetentionPolicyRule,
    json_name: "projectLevelRetentionPolicies"
  )

  field(:workflow_level_retention_policies, 2,
    repeated: true,
    type: InternalApi.Artifacthub.RetentionPolicy.RetentionPolicyRule,
    json_name: "workflowLevelRetentionPolicies"
  )

  field(:job_level_retention_policies, 3,
    repeated: true,
    type: InternalApi.Artifacthub.RetentionPolicy.RetentionPolicyRule,
    json_name: "jobLevelRetentionPolicies"
  )

  field(:scheduled_for_cleaning_at, 4,
    type: Google.Protobuf.Timestamp,
    json_name: "scheduledForCleaningAt"
  )

  field(:last_cleaned_at, 5, type: Google.Protobuf.Timestamp, json_name: "lastCleanedAt")
end

defmodule InternalApi.Artifacthub.UpdateRetentionPolicyRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:artifact_id, 1, type: :string, json_name: "artifactId")

  field(:retention_policy, 2,
    type: InternalApi.Artifacthub.RetentionPolicy,
    json_name: "retentionPolicy"
  )
end

defmodule InternalApi.Artifacthub.UpdateRetentionPolicyResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:retention_policy, 1,
    type: InternalApi.Artifacthub.RetentionPolicy,
    json_name: "retentionPolicy"
  )
end

defmodule InternalApi.Artifacthub.CreateRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:request_token, 1, type: :string, json_name: "requestToken")

  field(:retention_policy, 2,
    type: InternalApi.Artifacthub.RetentionPolicy,
    json_name: "retentionPolicy"
  )
end

defmodule InternalApi.Artifacthub.CreateResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:artifact, 1, type: InternalApi.Artifacthub.Artifact)
end

defmodule InternalApi.Artifacthub.DescribeRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:artifact_id, 1, type: :string, json_name: "artifactId")
  field(:include_retention_policy, 2, type: :bool, json_name: "includeRetentionPolicy")
end

defmodule InternalApi.Artifacthub.DescribeResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:artifact, 1, type: InternalApi.Artifacthub.Artifact)

  field(:retention_policy, 2,
    type: InternalApi.Artifacthub.RetentionPolicy,
    json_name: "retentionPolicy"
  )
end

defmodule InternalApi.Artifacthub.DestroyRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:artifact_id, 1, type: :string, json_name: "artifactId")
end

defmodule InternalApi.Artifacthub.DestroyResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"
end

defmodule InternalApi.Artifacthub.ListPathRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:artifact_id, 1, type: :string, json_name: "artifactId")
  field(:path, 2, type: :string)
  field(:unwrap_directories, 3, type: :bool, json_name: "unwrapDirectories")
end

defmodule InternalApi.Artifacthub.ListPathResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:items, 1, repeated: true, type: InternalApi.Artifacthub.ListItem)
end

defmodule InternalApi.Artifacthub.DeletePathRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:artifact_id, 1, type: :string, json_name: "artifactId")
  field(:path, 2, type: :string)
end

defmodule InternalApi.Artifacthub.DeletePathResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"
end

defmodule InternalApi.Artifacthub.CleanupRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"
end

defmodule InternalApi.Artifacthub.CleanupResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"
end

defmodule InternalApi.Artifacthub.GetSignedURLRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:artifact_id, 1, type: :string, json_name: "artifactId")
  field(:path, 2, type: :string)
  field(:method, 3, type: :string)
end

defmodule InternalApi.Artifacthub.GetSignedURLResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:url, 1, type: :string)
end

defmodule InternalApi.Artifacthub.ListBucketsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:ids, 1, repeated: true, type: :string)
end

defmodule InternalApi.Artifacthub.ListBucketsResponse.BucketNamesForIdsEntry do
  @moduledoc false

  use Protobuf, map: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:key, 1, type: :string)
  field(:value, 2, type: :string)
end

defmodule InternalApi.Artifacthub.ListBucketsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:bucket_names_for_ids, 1,
    repeated: true,
    type: InternalApi.Artifacthub.ListBucketsResponse.BucketNamesForIdsEntry,
    json_name: "bucketNamesForIds",
    map: true
  )
end

defmodule InternalApi.Artifacthub.CountArtifactsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:category, 1, type: InternalApi.Artifacthub.CountArtifactsRequest.Category, enum: true)
  field(:category_id, 2, type: :string, json_name: "categoryId")
  field(:artifact_id, 3, type: :string, json_name: "artifactId")
end

defmodule InternalApi.Artifacthub.CountArtifactsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:artifact_count, 5, type: :int32, json_name: "artifactCount")
end

defmodule InternalApi.Artifacthub.CountBucketsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"
end

defmodule InternalApi.Artifacthub.CountBucketsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:bucket_count, 1, type: :int32, json_name: "bucketCount")
end

defmodule InternalApi.Artifacthub.UpdateCORSRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:bucket_name, 1, type: :string, json_name: "bucketName")
end

defmodule InternalApi.Artifacthub.UpdateCORSResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:next_bucket_name, 1, type: :string, json_name: "nextBucketName")
end

defmodule InternalApi.Artifacthub.ListItem do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:name, 1, type: :string)
  field(:is_directory, 2, type: :bool, json_name: "isDirectory")
end

defmodule InternalApi.Artifacthub.Artifact do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:id, 1, type: :string)
  field(:bucket_name, 2, type: :string, json_name: "bucketName")
  field(:artifact_token, 4, type: :string, json_name: "artifactToken")
end

defmodule InternalApi.Artifacthub.GenerateTokenRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:artifact_id, 1, type: :string, json_name: "artifactId")
  field(:job_id, 2, type: :string, json_name: "jobId")
  field(:workflow_id, 3, type: :string, json_name: "workflowId")
  field(:project_id, 4, type: :string, json_name: "projectId")
  field(:duration, 5, type: :uint32)
end

defmodule InternalApi.Artifacthub.GenerateTokenResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:token, 1, type: :string)
end

defmodule InternalApi.Artifacthub.ArtifactService.Service do
  @moduledoc false

  use GRPC.Service,
    name: "InternalApi.Artifacthub.ArtifactService",
    protoc_gen_elixir_version: "0.12.0"

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
