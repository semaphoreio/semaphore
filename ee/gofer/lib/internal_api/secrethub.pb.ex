defmodule InternalApi.Secrethub.ResponseMeta.Code do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :OK, 0
  field :NOT_FOUND, 2
  field :FAILED_PRECONDITION, 3
end

defmodule InternalApi.Secrethub.Secret.SecretLevel do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :ORGANIZATION, 0
  field :PROJECT, 1
  field :DEPLOYMENT_TARGET, 2
end

defmodule InternalApi.Secrethub.Secret.OrgConfig.ProjectsAccess do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :ALL, 0
  field :ALLOWED, 1
  field :NONE, 2
end

defmodule InternalApi.Secrethub.Secret.OrgConfig.JobAttachAccess do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :JOB_ATTACH_YES, 0
  field :JOB_ATTACH_NO, 2
end

defmodule InternalApi.Secrethub.Secret.OrgConfig.JobDebugAccess do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :JOB_DEBUG_YES, 0
  field :JOB_DEBUG_NO, 2
end

defmodule InternalApi.Secrethub.ListKeysetRequest.Order do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :BY_NAME_ASC, 0
  field :BY_CREATE_TIME_ASC, 1
end

defmodule InternalApi.Secrethub.RequestMeta do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :api_version, 1, type: :string, json_name: "apiVersion"
  field :kind, 2, type: :string
  field :req_id, 3, type: :string, json_name: "reqId"
  field :org_id, 4, type: :string, json_name: "orgId"
  field :user_id, 5, type: :string, json_name: "userId"
end

defmodule InternalApi.Secrethub.ResponseMeta.Status do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :code, 1, type: InternalApi.Secrethub.ResponseMeta.Code, enum: true
  field :message, 2, type: :string
end

defmodule InternalApi.Secrethub.ResponseMeta do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :api_version, 1, type: :string, json_name: "apiVersion"
  field :kind, 2, type: :string
  field :req_id, 3, type: :string, json_name: "reqId"
  field :org_id, 4, type: :string, json_name: "orgId"
  field :user_id, 5, type: :string, json_name: "userId"
  field :status, 6, type: InternalApi.Secrethub.ResponseMeta.Status
end

defmodule InternalApi.Secrethub.PaginationRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :page, 1, type: :int32
  field :page_size, 2, type: :int32, json_name: "pageSize"
end

defmodule InternalApi.Secrethub.PaginationResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :page_number, 1, type: :int32, json_name: "pageNumber"
  field :page_size, 2, type: :int32, json_name: "pageSize"
  field :total_entries, 3, type: :int32, json_name: "totalEntries"
  field :total_pages, 4, type: :int32, json_name: "totalPages"
end

defmodule InternalApi.Secrethub.Secret.Metadata do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :name, 1, type: :string
  field :id, 2, type: :string
  field :org_id, 3, type: :string, json_name: "orgId"
  field :level, 4, type: InternalApi.Secrethub.Secret.SecretLevel, enum: true
  field :created_by, 5, type: :string, json_name: "createdBy"
  field :updated_by, 6, type: :string, json_name: "updatedBy"
  field :last_checkout, 7, type: InternalApi.Secrethub.CheckoutMetadata, json_name: "lastCheckout"
  field :created_at, 8, type: Google.Protobuf.Timestamp, json_name: "createdAt"
  field :updated_at, 9, type: Google.Protobuf.Timestamp, json_name: "updatedAt"
  field :checkout_at, 10, type: Google.Protobuf.Timestamp, json_name: "checkoutAt"
  field :description, 11, type: :string
end

defmodule InternalApi.Secrethub.Secret.EnvVar do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :name, 1, type: :string
  field :value, 2, type: :string
end

defmodule InternalApi.Secrethub.Secret.File do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :path, 1, type: :string
  field :content, 2, type: :string
end

defmodule InternalApi.Secrethub.Secret.Data do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :env_vars, 1,
    repeated: true,
    type: InternalApi.Secrethub.Secret.EnvVar,
    json_name: "envVars"

  field :files, 2, repeated: true, type: InternalApi.Secrethub.Secret.File
end

defmodule InternalApi.Secrethub.Secret.OrgConfig do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :projects_access, 1,
    type: InternalApi.Secrethub.Secret.OrgConfig.ProjectsAccess,
    json_name: "projectsAccess",
    enum: true

  field :project_ids, 2, repeated: true, type: :string, json_name: "projectIds"

  field :debug_access, 3,
    type: InternalApi.Secrethub.Secret.OrgConfig.JobDebugAccess,
    json_name: "debugAccess",
    enum: true

  field :attach_access, 4,
    type: InternalApi.Secrethub.Secret.OrgConfig.JobAttachAccess,
    json_name: "attachAccess",
    enum: true
end

defmodule InternalApi.Secrethub.Secret.ProjectConfig do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :project_id, 1, type: :string, json_name: "projectId"
end

defmodule InternalApi.Secrethub.Secret.DTConfig do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :deployment_target_id, 1, type: :string, json_name: "deploymentTargetId"
end

defmodule InternalApi.Secrethub.Secret do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :metadata, 1, type: InternalApi.Secrethub.Secret.Metadata
  field :data, 2, type: InternalApi.Secrethub.Secret.Data
  field :org_config, 3, type: InternalApi.Secrethub.Secret.OrgConfig, json_name: "orgConfig"

  field :project_config, 4,
    type: InternalApi.Secrethub.Secret.ProjectConfig,
    json_name: "projectConfig"

  field :dt_config, 5, type: InternalApi.Secrethub.Secret.DTConfig, json_name: "dtConfig"
end

defmodule InternalApi.Secrethub.EncryptedData do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :key_id, 1, type: :string, json_name: "keyId"
  field :aes256_key, 2, type: :string, json_name: "aes256Key"
  field :init_vector, 3, type: :string, json_name: "initVector"
  field :payload, 4, type: :string
end

defmodule InternalApi.Secrethub.ListRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :metadata, 1, type: InternalApi.Secrethub.RequestMeta
  field :pagination, 2, type: InternalApi.Secrethub.PaginationRequest
  field :project_id, 3, type: :string, json_name: "projectId"

  field :secret_level, 4,
    type: InternalApi.Secrethub.Secret.SecretLevel,
    json_name: "secretLevel",
    enum: true
end

defmodule InternalApi.Secrethub.ListResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :metadata, 1, type: InternalApi.Secrethub.ResponseMeta
  field :pagination, 2, type: InternalApi.Secrethub.PaginationResponse
  field :secrets, 3, repeated: true, type: InternalApi.Secrethub.Secret
end

defmodule InternalApi.Secrethub.ListKeysetRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :metadata, 1, type: InternalApi.Secrethub.RequestMeta
  field :page_size, 2, type: :int32, json_name: "pageSize"
  field :page_token, 3, type: :string, json_name: "pageToken"
  field :order, 4, type: InternalApi.Secrethub.ListKeysetRequest.Order, enum: true

  field :secret_level, 5,
    type: InternalApi.Secrethub.Secret.SecretLevel,
    json_name: "secretLevel",
    enum: true

  field :project_id, 6, type: :string, json_name: "projectId"
  field :deployment_target_id, 7, type: :string, json_name: "deploymentTargetId"
  field :ignore_contents, 8, type: :bool, json_name: "ignoreContents"
end

defmodule InternalApi.Secrethub.ListKeysetResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :metadata, 1, type: InternalApi.Secrethub.ResponseMeta
  field :secrets, 2, repeated: true, type: InternalApi.Secrethub.Secret
  field :next_page_token, 3, type: :string, json_name: "nextPageToken"
end

defmodule InternalApi.Secrethub.DescribeRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :metadata, 1, type: InternalApi.Secrethub.RequestMeta
  field :id, 2, type: :string
  field :name, 3, type: :string

  field :secret_level, 4,
    type: InternalApi.Secrethub.Secret.SecretLevel,
    json_name: "secretLevel",
    enum: true

  field :project_id, 5, type: :string, json_name: "projectId"
  field :deployment_target_id, 6, type: :string, json_name: "deploymentTargetId"
end

defmodule InternalApi.Secrethub.DescribeResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :metadata, 1, type: InternalApi.Secrethub.ResponseMeta
  field :secret, 2, type: InternalApi.Secrethub.Secret
end

defmodule InternalApi.Secrethub.CheckoutMetadata do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :job_id, 1, type: :string, json_name: "jobId"
  field :pipeline_id, 2, type: :string, json_name: "pipelineId"
  field :workflow_id, 3, type: :string, json_name: "workflowId"
  field :hook_id, 4, type: :string, json_name: "hookId"
  field :project_id, 5, type: :string, json_name: "projectId"
  field :user_id, 6, type: :string, json_name: "userId"
end

defmodule InternalApi.Secrethub.CheckoutRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :metadata, 1, type: InternalApi.Secrethub.RequestMeta

  field :checkout_metadata, 2,
    type: InternalApi.Secrethub.CheckoutMetadata,
    json_name: "checkoutMetadata"

  field :name, 3, type: :string
  field :project_id, 4, type: :string, json_name: "projectId"
  field :deployment_target_id, 5, type: :string, json_name: "deploymentTargetId"
end

defmodule InternalApi.Secrethub.CheckoutResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :metadata, 1, type: InternalApi.Secrethub.ResponseMeta
  field :secret, 2, type: InternalApi.Secrethub.Secret
end

defmodule InternalApi.Secrethub.CheckoutManyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :metadata, 1, type: InternalApi.Secrethub.RequestMeta

  field :checkout_metadata, 2,
    type: InternalApi.Secrethub.CheckoutMetadata,
    json_name: "checkoutMetadata"

  field :names, 3, repeated: true, type: :string
  field :project_id, 4, type: :string, json_name: "projectId"
  field :deployment_target_id, 5, type: :string, json_name: "deploymentTargetId"
end

defmodule InternalApi.Secrethub.CheckoutManyResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :metadata, 1, type: InternalApi.Secrethub.ResponseMeta
  field :secrets, 2, repeated: true, type: InternalApi.Secrethub.Secret
end

defmodule InternalApi.Secrethub.DescribeManyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :metadata, 1, type: InternalApi.Secrethub.RequestMeta
  field :ids, 2, repeated: true, type: :string
  field :names, 3, repeated: true, type: :string
  field :project_id, 4, type: :string, json_name: "projectId"
  field :deployment_target_id, 5, type: :string, json_name: "deploymentTargetId"

  field :secret_level, 6,
    type: InternalApi.Secrethub.Secret.SecretLevel,
    json_name: "secretLevel",
    enum: true
end

defmodule InternalApi.Secrethub.DescribeManyResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :metadata, 1, type: InternalApi.Secrethub.ResponseMeta
  field :secrets, 2, repeated: true, type: InternalApi.Secrethub.Secret
end

defmodule InternalApi.Secrethub.CreateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :metadata, 1, type: InternalApi.Secrethub.RequestMeta
  field :secret, 2, type: InternalApi.Secrethub.Secret
end

defmodule InternalApi.Secrethub.CreateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :metadata, 1, type: InternalApi.Secrethub.ResponseMeta
  field :secret, 2, type: InternalApi.Secrethub.Secret
end

defmodule InternalApi.Secrethub.UpdateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :metadata, 1, type: InternalApi.Secrethub.RequestMeta
  field :secret, 2, type: InternalApi.Secrethub.Secret
end

defmodule InternalApi.Secrethub.UpdateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :metadata, 1, type: InternalApi.Secrethub.ResponseMeta
  field :secret, 2, type: InternalApi.Secrethub.Secret
end

defmodule InternalApi.Secrethub.DestroyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :metadata, 1, type: InternalApi.Secrethub.RequestMeta
  field :id, 2, type: :string
  field :name, 3, type: :string

  field :secret_level, 4,
    type: InternalApi.Secrethub.Secret.SecretLevel,
    json_name: "secretLevel",
    enum: true

  field :project_id, 5, type: :string, json_name: "projectId"
  field :deployment_target_id, 6, type: :string, json_name: "deploymentTargetId"
end

defmodule InternalApi.Secrethub.DestroyResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :metadata, 1, type: InternalApi.Secrethub.ResponseMeta
  field :id, 2, type: :string
end

defmodule InternalApi.Secrethub.GenerateOpenIDConnectTokenRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :org_id, 1, type: :string, json_name: "orgId"
  field :expires_in, 2, type: :int64, json_name: "expiresIn"
  field :subject, 3, type: :string
  field :project_id, 4, type: :string, json_name: "projectId"
  field :workflow_id, 5, type: :string, json_name: "workflowId"
  field :pipeline_id, 6, type: :string, json_name: "pipelineId"
  field :job_id, 7, type: :string, json_name: "jobId"
  field :repository_name, 8, type: :string, json_name: "repositoryName"
  field :user_id, 9, type: :string, json_name: "userId"
  field :git_tag, 10, type: :string, json_name: "gitTag"
  field :git_ref, 11, type: :string, json_name: "gitRef"
  field :git_ref_type, 12, type: :string, json_name: "gitRefType"
  field :git_branch_name, 13, type: :string, json_name: "gitBranchName"
  field :git_pull_request_number, 14, type: :string, json_name: "gitPullRequestNumber"
  field :org_username, 15, type: :string, json_name: "orgUsername"
  field :job_type, 16, type: :string, json_name: "jobType"
  field :git_pull_request_branch, 17, type: :string, json_name: "gitPullRequestBranch"
  field :repo_slug, 18, type: :string, json_name: "repoSlug"
  field :triggerer, 19, type: :string
  field :project_name, 20, type: :string, json_name: "projectName"
end

defmodule InternalApi.Secrethub.GenerateOpenIDConnectTokenResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :token, 1, type: :string
end

defmodule InternalApi.Secrethub.GetKeyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"
end

defmodule InternalApi.Secrethub.GetKeyResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :id, 1, type: :string
  field :key, 2, type: :string
end

defmodule InternalApi.Secrethub.CreateEncryptedRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :metadata, 1, type: InternalApi.Secrethub.RequestMeta
  field :secret, 2, type: InternalApi.Secrethub.Secret
  field :encrypted_data, 3, type: InternalApi.Secrethub.EncryptedData, json_name: "encryptedData"
end

defmodule InternalApi.Secrethub.CreateEncryptedResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :metadata, 1, type: InternalApi.Secrethub.ResponseMeta
  field :secret, 2, type: InternalApi.Secrethub.Secret
  field :encrypted_data, 3, type: InternalApi.Secrethub.EncryptedData, json_name: "encryptedData"
end

defmodule InternalApi.Secrethub.UpdateEncryptedRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :metadata, 1, type: InternalApi.Secrethub.RequestMeta
  field :secret, 2, type: InternalApi.Secrethub.Secret
  field :encrypted_data, 3, type: InternalApi.Secrethub.EncryptedData, json_name: "encryptedData"
end

defmodule InternalApi.Secrethub.UpdateEncryptedResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :metadata, 1, type: InternalApi.Secrethub.ResponseMeta
  field :secret, 2, type: InternalApi.Secrethub.Secret
  field :encrypted_data, 3, type: InternalApi.Secrethub.EncryptedData, json_name: "encryptedData"
end

defmodule InternalApi.Secrethub.GetJWTConfigRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :org_id, 1, type: :string, json_name: "orgId"
  field :project_id, 2, type: :string, json_name: "projectId"
end

defmodule InternalApi.Secrethub.GetJWTConfigResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :org_id, 1, type: :string, json_name: "orgId"
  field :project_id, 2, type: :string, json_name: "projectId"
  field :claims, 3, repeated: true, type: InternalApi.Secrethub.ClaimConfig
  field :is_active, 4, type: :bool, json_name: "isActive"
end

defmodule InternalApi.Secrethub.UpdateJWTConfigRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :org_id, 1, type: :string, json_name: "orgId"
  field :project_id, 2, type: :string, json_name: "projectId"
  field :claims, 3, repeated: true, type: InternalApi.Secrethub.ClaimConfig
  field :is_active, 4, type: :bool, json_name: "isActive"
end

defmodule InternalApi.Secrethub.UpdateJWTConfigResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :org_id, 1, type: :string, json_name: "orgId"
  field :project_id, 2, type: :string, json_name: "projectId"
end

defmodule InternalApi.Secrethub.ClaimConfig do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :name, 1, type: :string
  field :description, 2, type: :string
  field :is_active, 3, type: :bool, json_name: "isActive"
  field :is_mandatory, 4, type: :bool, json_name: "isMandatory"
  field :is_aws_tag, 5, type: :bool, json_name: "isAwsTag"
  field :is_system_claim, 6, type: :bool, json_name: "isSystemClaim"
end

defmodule InternalApi.Secrethub.SecretService.Service do
  @moduledoc false
  use GRPC.Service,
    name: "InternalApi.Secrethub.SecretService",
    protoc_gen_elixir_version: "0.10.0"

  rpc :List, InternalApi.Secrethub.ListRequest, InternalApi.Secrethub.ListResponse

  rpc :ListKeyset,
      InternalApi.Secrethub.ListKeysetRequest,
      InternalApi.Secrethub.ListKeysetResponse

  rpc :Describe, InternalApi.Secrethub.DescribeRequest, InternalApi.Secrethub.DescribeResponse

  rpc :DescribeMany,
      InternalApi.Secrethub.DescribeManyRequest,
      InternalApi.Secrethub.DescribeManyResponse

  rpc :Create, InternalApi.Secrethub.CreateRequest, InternalApi.Secrethub.CreateResponse

  rpc :Update, InternalApi.Secrethub.UpdateRequest, InternalApi.Secrethub.UpdateResponse

  rpc :Destroy, InternalApi.Secrethub.DestroyRequest, InternalApi.Secrethub.DestroyResponse

  rpc :GenerateOpenIDConnectToken,
      InternalApi.Secrethub.GenerateOpenIDConnectTokenRequest,
      InternalApi.Secrethub.GenerateOpenIDConnectTokenResponse

  rpc :CreateEncrypted,
      InternalApi.Secrethub.CreateEncryptedRequest,
      InternalApi.Secrethub.CreateEncryptedResponse

  rpc :UpdateEncrypted,
      InternalApi.Secrethub.UpdateEncryptedRequest,
      InternalApi.Secrethub.UpdateEncryptedResponse

  rpc :GetKey, InternalApi.Secrethub.GetKeyRequest, InternalApi.Secrethub.GetKeyResponse

  rpc :Checkout, InternalApi.Secrethub.CheckoutRequest, InternalApi.Secrethub.CheckoutResponse

  rpc :CheckoutMany,
      InternalApi.Secrethub.CheckoutManyRequest,
      InternalApi.Secrethub.CheckoutManyResponse

  rpc :GetJWTConfig,
      InternalApi.Secrethub.GetJWTConfigRequest,
      InternalApi.Secrethub.GetJWTConfigResponse

  rpc :UpdateJWTConfig,
      InternalApi.Secrethub.UpdateJWTConfigRequest,
      InternalApi.Secrethub.UpdateJWTConfigResponse
end

defmodule InternalApi.Secrethub.SecretService.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.Secrethub.SecretService.Service
end
