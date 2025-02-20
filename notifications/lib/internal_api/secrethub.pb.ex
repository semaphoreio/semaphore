defmodule InternalApi.Secrethub.ResponseMeta.Code do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3
  @type t :: integer | :OK | :NOT_FOUND | :FAILED_PRECONDITION

  field(:OK, 0)

  field(:NOT_FOUND, 2)

  field(:FAILED_PRECONDITION, 3)
end

defmodule InternalApi.Secrethub.Secret.SecretLevel do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3
  @type t :: integer | :ORGANIZATION | :PROJECT | :DEPLOYMENT_TARGET

  field(:ORGANIZATION, 0)

  field(:PROJECT, 1)

  field(:DEPLOYMENT_TARGET, 2)
end

defmodule InternalApi.Secrethub.Secret.OrgConfig.ProjectsAccess do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3
  @type t :: integer | :ALL | :ALLOWED | :NONE

  field(:ALL, 0)

  field(:ALLOWED, 1)

  field(:NONE, 2)
end

defmodule InternalApi.Secrethub.Secret.OrgConfig.JobAttachAccess do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3
  @type t :: integer | :JOB_ATTACH_YES | :JOB_ATTACH_NO

  field(:JOB_ATTACH_YES, 0)

  field(:JOB_ATTACH_NO, 2)
end

defmodule InternalApi.Secrethub.Secret.OrgConfig.JobDebugAccess do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3
  @type t :: integer | :JOB_DEBUG_YES | :JOB_DEBUG_NO

  field(:JOB_DEBUG_YES, 0)

  field(:JOB_DEBUG_NO, 2)
end

defmodule InternalApi.Secrethub.ListKeysetRequest.Order do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3
  @type t :: integer | :BY_NAME_ASC | :BY_CREATE_TIME_ASC

  field(:BY_NAME_ASC, 0)

  field(:BY_CREATE_TIME_ASC, 1)
end

defmodule InternalApi.Secrethub.RequestMeta do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          api_version: String.t(),
          kind: String.t(),
          req_id: String.t(),
          org_id: String.t(),
          user_id: String.t()
        }

  defstruct [:api_version, :kind, :req_id, :org_id, :user_id]

  field(:api_version, 1, type: :string)
  field(:kind, 2, type: :string)
  field(:req_id, 3, type: :string)
  field(:org_id, 4, type: :string)
  field(:user_id, 5, type: :string)
end

defmodule InternalApi.Secrethub.ResponseMeta.Status do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          code: InternalApi.Secrethub.ResponseMeta.Code.t(),
          message: String.t()
        }

  defstruct [:code, :message]

  field(:code, 1, type: InternalApi.Secrethub.ResponseMeta.Code, enum: true)
  field(:message, 2, type: :string)
end

defmodule InternalApi.Secrethub.ResponseMeta do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          api_version: String.t(),
          kind: String.t(),
          req_id: String.t(),
          org_id: String.t(),
          user_id: String.t(),
          status: InternalApi.Secrethub.ResponseMeta.Status.t() | nil
        }

  defstruct [:api_version, :kind, :req_id, :org_id, :user_id, :status]

  field(:api_version, 1, type: :string)
  field(:kind, 2, type: :string)
  field(:req_id, 3, type: :string)
  field(:org_id, 4, type: :string)
  field(:user_id, 5, type: :string)
  field(:status, 6, type: InternalApi.Secrethub.ResponseMeta.Status)
end

defmodule InternalApi.Secrethub.PaginationRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          page: integer,
          page_size: integer
        }

  defstruct [:page, :page_size]

  field(:page, 1, type: :int32)
  field(:page_size, 2, type: :int32)
end

defmodule InternalApi.Secrethub.PaginationResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          page_number: integer,
          page_size: integer,
          total_entries: integer,
          total_pages: integer
        }

  defstruct [:page_number, :page_size, :total_entries, :total_pages]

  field(:page_number, 1, type: :int32)
  field(:page_size, 2, type: :int32)
  field(:total_entries, 3, type: :int32)
  field(:total_pages, 4, type: :int32)
end

defmodule InternalApi.Secrethub.Secret.Metadata do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          id: String.t(),
          org_id: String.t(),
          level: InternalApi.Secrethub.Secret.SecretLevel.t(),
          created_by: String.t(),
          updated_by: String.t(),
          last_checkout: InternalApi.Secrethub.CheckoutMetadata.t() | nil,
          created_at: Google.Protobuf.Timestamp.t() | nil,
          updated_at: Google.Protobuf.Timestamp.t() | nil,
          checkout_at: Google.Protobuf.Timestamp.t() | nil,
          description: String.t()
        }

  defstruct [
    :name,
    :id,
    :org_id,
    :level,
    :created_by,
    :updated_by,
    :last_checkout,
    :created_at,
    :updated_at,
    :checkout_at,
    :description
  ]

  field(:name, 1, type: :string)
  field(:id, 2, type: :string)
  field(:org_id, 3, type: :string)
  field(:level, 4, type: InternalApi.Secrethub.Secret.SecretLevel, enum: true)
  field(:created_by, 5, type: :string)
  field(:updated_by, 6, type: :string)
  field(:last_checkout, 7, type: InternalApi.Secrethub.CheckoutMetadata)
  field(:created_at, 8, type: Google.Protobuf.Timestamp)
  field(:updated_at, 9, type: Google.Protobuf.Timestamp)
  field(:checkout_at, 10, type: Google.Protobuf.Timestamp)
  field(:description, 11, type: :string)
end

defmodule InternalApi.Secrethub.Secret.EnvVar do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          value: String.t()
        }

  defstruct [:name, :value]

  field(:name, 1, type: :string)
  field(:value, 2, type: :string)
end

defmodule InternalApi.Secrethub.Secret.File do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          path: String.t(),
          content: String.t()
        }

  defstruct [:path, :content]

  field(:path, 1, type: :string)
  field(:content, 2, type: :string)
end

defmodule InternalApi.Secrethub.Secret.Data do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          env_vars: [InternalApi.Secrethub.Secret.EnvVar.t()],
          files: [InternalApi.Secrethub.Secret.File.t()]
        }

  defstruct [:env_vars, :files]

  field(:env_vars, 1, repeated: true, type: InternalApi.Secrethub.Secret.EnvVar)
  field(:files, 2, repeated: true, type: InternalApi.Secrethub.Secret.File)
end

defmodule InternalApi.Secrethub.Secret.OrgConfig do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          projects_access: InternalApi.Secrethub.Secret.OrgConfig.ProjectsAccess.t(),
          project_ids: [String.t()],
          debug_access: InternalApi.Secrethub.Secret.OrgConfig.JobDebugAccess.t(),
          attach_access: InternalApi.Secrethub.Secret.OrgConfig.JobAttachAccess.t()
        }

  defstruct [:projects_access, :project_ids, :debug_access, :attach_access]

  field(:projects_access, 1,
    type: InternalApi.Secrethub.Secret.OrgConfig.ProjectsAccess,
    enum: true
  )

  field(:project_ids, 2, repeated: true, type: :string)
  field(:debug_access, 3, type: InternalApi.Secrethub.Secret.OrgConfig.JobDebugAccess, enum: true)

  field(:attach_access, 4,
    type: InternalApi.Secrethub.Secret.OrgConfig.JobAttachAccess,
    enum: true
  )
end

defmodule InternalApi.Secrethub.Secret.ProjectConfig do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_id: String.t()
        }

  defstruct [:project_id]

  field(:project_id, 1, type: :string)
end

defmodule InternalApi.Secrethub.Secret.DTConfig do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          deployment_target_id: String.t()
        }

  defstruct [:deployment_target_id]

  field(:deployment_target_id, 1, type: :string)
end

defmodule InternalApi.Secrethub.Secret do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Secrethub.Secret.Metadata.t() | nil,
          data: InternalApi.Secrethub.Secret.Data.t() | nil,
          org_config: InternalApi.Secrethub.Secret.OrgConfig.t() | nil,
          project_config: InternalApi.Secrethub.Secret.ProjectConfig.t() | nil,
          dt_config: InternalApi.Secrethub.Secret.DTConfig.t() | nil
        }

  defstruct [:metadata, :data, :org_config, :project_config, :dt_config]

  field(:metadata, 1, type: InternalApi.Secrethub.Secret.Metadata)
  field(:data, 2, type: InternalApi.Secrethub.Secret.Data)
  field(:org_config, 3, type: InternalApi.Secrethub.Secret.OrgConfig)
  field(:project_config, 4, type: InternalApi.Secrethub.Secret.ProjectConfig)
  field(:dt_config, 5, type: InternalApi.Secrethub.Secret.DTConfig)
end

defmodule InternalApi.Secrethub.EncryptedData do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          key_id: String.t(),
          aes256_key: String.t(),
          init_vector: String.t(),
          payload: String.t()
        }

  defstruct [:key_id, :aes256_key, :init_vector, :payload]

  field(:key_id, 1, type: :string)
  field(:aes256_key, 2, type: :string)
  field(:init_vector, 3, type: :string)
  field(:payload, 4, type: :string)
end

defmodule InternalApi.Secrethub.ListRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Secrethub.RequestMeta.t() | nil,
          pagination: InternalApi.Secrethub.PaginationRequest.t() | nil,
          project_id: String.t(),
          secret_level: InternalApi.Secrethub.Secret.SecretLevel.t()
        }

  defstruct [:metadata, :pagination, :project_id, :secret_level]

  field(:metadata, 1, type: InternalApi.Secrethub.RequestMeta)
  field(:pagination, 2, type: InternalApi.Secrethub.PaginationRequest)
  field(:project_id, 3, type: :string)
  field(:secret_level, 4, type: InternalApi.Secrethub.Secret.SecretLevel, enum: true)
end

defmodule InternalApi.Secrethub.ListResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Secrethub.ResponseMeta.t() | nil,
          pagination: InternalApi.Secrethub.PaginationResponse.t() | nil,
          secrets: [InternalApi.Secrethub.Secret.t()]
        }

  defstruct [:metadata, :pagination, :secrets]

  field(:metadata, 1, type: InternalApi.Secrethub.ResponseMeta)
  field(:pagination, 2, type: InternalApi.Secrethub.PaginationResponse)
  field(:secrets, 3, repeated: true, type: InternalApi.Secrethub.Secret)
end

defmodule InternalApi.Secrethub.ListKeysetRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Secrethub.RequestMeta.t() | nil,
          page_size: integer,
          page_token: String.t(),
          order: InternalApi.Secrethub.ListKeysetRequest.Order.t(),
          secret_level: InternalApi.Secrethub.Secret.SecretLevel.t(),
          project_id: String.t(),
          deployment_target_id: String.t(),
          ignore_contents: boolean
        }

  defstruct [
    :metadata,
    :page_size,
    :page_token,
    :order,
    :secret_level,
    :project_id,
    :deployment_target_id,
    :ignore_contents
  ]

  field(:metadata, 1, type: InternalApi.Secrethub.RequestMeta)
  field(:page_size, 2, type: :int32)
  field(:page_token, 3, type: :string)
  field(:order, 4, type: InternalApi.Secrethub.ListKeysetRequest.Order, enum: true)
  field(:secret_level, 5, type: InternalApi.Secrethub.Secret.SecretLevel, enum: true)
  field(:project_id, 6, type: :string)
  field(:deployment_target_id, 7, type: :string)
  field(:ignore_contents, 8, type: :bool)
end

defmodule InternalApi.Secrethub.ListKeysetResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Secrethub.ResponseMeta.t() | nil,
          secrets: [InternalApi.Secrethub.Secret.t()],
          next_page_token: String.t()
        }

  defstruct [:metadata, :secrets, :next_page_token]

  field(:metadata, 1, type: InternalApi.Secrethub.ResponseMeta)
  field(:secrets, 2, repeated: true, type: InternalApi.Secrethub.Secret)
  field(:next_page_token, 3, type: :string)
end

defmodule InternalApi.Secrethub.DescribeRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Secrethub.RequestMeta.t() | nil,
          id: String.t(),
          name: String.t(),
          secret_level: InternalApi.Secrethub.Secret.SecretLevel.t(),
          project_id: String.t(),
          deployment_target_id: String.t()
        }

  defstruct [:metadata, :id, :name, :secret_level, :project_id, :deployment_target_id]

  field(:metadata, 1, type: InternalApi.Secrethub.RequestMeta)
  field(:id, 2, type: :string)
  field(:name, 3, type: :string)
  field(:secret_level, 4, type: InternalApi.Secrethub.Secret.SecretLevel, enum: true)
  field(:project_id, 5, type: :string)
  field(:deployment_target_id, 6, type: :string)
end

defmodule InternalApi.Secrethub.DescribeResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Secrethub.ResponseMeta.t() | nil,
          secret: InternalApi.Secrethub.Secret.t() | nil
        }

  defstruct [:metadata, :secret]

  field(:metadata, 1, type: InternalApi.Secrethub.ResponseMeta)
  field(:secret, 2, type: InternalApi.Secrethub.Secret)
end

defmodule InternalApi.Secrethub.CheckoutMetadata do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          job_id: String.t(),
          pipeline_id: String.t(),
          workflow_id: String.t(),
          hook_id: String.t(),
          project_id: String.t(),
          user_id: String.t()
        }

  defstruct [:job_id, :pipeline_id, :workflow_id, :hook_id, :project_id, :user_id]

  field(:job_id, 1, type: :string)
  field(:pipeline_id, 2, type: :string)
  field(:workflow_id, 3, type: :string)
  field(:hook_id, 4, type: :string)
  field(:project_id, 5, type: :string)
  field(:user_id, 6, type: :string)
end

defmodule InternalApi.Secrethub.CheckoutRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Secrethub.RequestMeta.t() | nil,
          checkout_metadata: InternalApi.Secrethub.CheckoutMetadata.t() | nil,
          name: String.t(),
          project_id: String.t(),
          deployment_target_id: String.t()
        }

  defstruct [:metadata, :checkout_metadata, :name, :project_id, :deployment_target_id]

  field(:metadata, 1, type: InternalApi.Secrethub.RequestMeta)
  field(:checkout_metadata, 2, type: InternalApi.Secrethub.CheckoutMetadata)
  field(:name, 3, type: :string)
  field(:project_id, 4, type: :string)
  field(:deployment_target_id, 5, type: :string)
end

defmodule InternalApi.Secrethub.CheckoutResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Secrethub.ResponseMeta.t() | nil,
          secret: InternalApi.Secrethub.Secret.t() | nil
        }

  defstruct [:metadata, :secret]

  field(:metadata, 1, type: InternalApi.Secrethub.ResponseMeta)
  field(:secret, 2, type: InternalApi.Secrethub.Secret)
end

defmodule InternalApi.Secrethub.CheckoutManyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Secrethub.RequestMeta.t() | nil,
          checkout_metadata: InternalApi.Secrethub.CheckoutMetadata.t() | nil,
          names: [String.t()],
          project_id: String.t(),
          deployment_target_id: String.t()
        }

  defstruct [:metadata, :checkout_metadata, :names, :project_id, :deployment_target_id]

  field(:metadata, 1, type: InternalApi.Secrethub.RequestMeta)
  field(:checkout_metadata, 2, type: InternalApi.Secrethub.CheckoutMetadata)
  field(:names, 3, repeated: true, type: :string)
  field(:project_id, 4, type: :string)
  field(:deployment_target_id, 5, type: :string)
end

defmodule InternalApi.Secrethub.CheckoutManyResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Secrethub.ResponseMeta.t() | nil,
          secrets: [InternalApi.Secrethub.Secret.t()]
        }

  defstruct [:metadata, :secrets]

  field(:metadata, 1, type: InternalApi.Secrethub.ResponseMeta)
  field(:secrets, 2, repeated: true, type: InternalApi.Secrethub.Secret)
end

defmodule InternalApi.Secrethub.DescribeManyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Secrethub.RequestMeta.t() | nil,
          ids: [String.t()],
          names: [String.t()],
          project_id: String.t(),
          deployment_target_id: String.t(),
          secret_level: InternalApi.Secrethub.Secret.SecretLevel.t()
        }

  defstruct [:metadata, :ids, :names, :project_id, :deployment_target_id, :secret_level]

  field(:metadata, 1, type: InternalApi.Secrethub.RequestMeta)
  field(:ids, 2, repeated: true, type: :string)
  field(:names, 3, repeated: true, type: :string)
  field(:project_id, 4, type: :string)
  field(:deployment_target_id, 5, type: :string)
  field(:secret_level, 6, type: InternalApi.Secrethub.Secret.SecretLevel, enum: true)
end

defmodule InternalApi.Secrethub.DescribeManyResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Secrethub.ResponseMeta.t() | nil,
          secrets: [InternalApi.Secrethub.Secret.t()]
        }

  defstruct [:metadata, :secrets]

  field(:metadata, 1, type: InternalApi.Secrethub.ResponseMeta)
  field(:secrets, 2, repeated: true, type: InternalApi.Secrethub.Secret)
end

defmodule InternalApi.Secrethub.CreateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Secrethub.RequestMeta.t() | nil,
          secret: InternalApi.Secrethub.Secret.t() | nil
        }

  defstruct [:metadata, :secret]

  field(:metadata, 1, type: InternalApi.Secrethub.RequestMeta)
  field(:secret, 2, type: InternalApi.Secrethub.Secret)
end

defmodule InternalApi.Secrethub.CreateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Secrethub.ResponseMeta.t() | nil,
          secret: InternalApi.Secrethub.Secret.t() | nil
        }

  defstruct [:metadata, :secret]

  field(:metadata, 1, type: InternalApi.Secrethub.ResponseMeta)
  field(:secret, 2, type: InternalApi.Secrethub.Secret)
end

defmodule InternalApi.Secrethub.UpdateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Secrethub.RequestMeta.t() | nil,
          secret: InternalApi.Secrethub.Secret.t() | nil
        }

  defstruct [:metadata, :secret]

  field(:metadata, 1, type: InternalApi.Secrethub.RequestMeta)
  field(:secret, 2, type: InternalApi.Secrethub.Secret)
end

defmodule InternalApi.Secrethub.UpdateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Secrethub.ResponseMeta.t() | nil,
          secret: InternalApi.Secrethub.Secret.t() | nil
        }

  defstruct [:metadata, :secret]

  field(:metadata, 1, type: InternalApi.Secrethub.ResponseMeta)
  field(:secret, 2, type: InternalApi.Secrethub.Secret)
end

defmodule InternalApi.Secrethub.DestroyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Secrethub.RequestMeta.t() | nil,
          id: String.t(),
          name: String.t(),
          secret_level: InternalApi.Secrethub.Secret.SecretLevel.t(),
          project_id: String.t(),
          deployment_target_id: String.t()
        }

  defstruct [:metadata, :id, :name, :secret_level, :project_id, :deployment_target_id]

  field(:metadata, 1, type: InternalApi.Secrethub.RequestMeta)
  field(:id, 2, type: :string)
  field(:name, 3, type: :string)
  field(:secret_level, 4, type: InternalApi.Secrethub.Secret.SecretLevel, enum: true)
  field(:project_id, 5, type: :string)
  field(:deployment_target_id, 6, type: :string)
end

defmodule InternalApi.Secrethub.DestroyResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Secrethub.ResponseMeta.t() | nil,
          id: String.t()
        }

  defstruct [:metadata, :id]

  field(:metadata, 1, type: InternalApi.Secrethub.ResponseMeta)
  field(:id, 2, type: :string)
end

defmodule InternalApi.Secrethub.GenerateOpenIDConnectTokenRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          expires_in: integer,
          subject: String.t(),
          project_id: String.t(),
          workflow_id: String.t(),
          pipeline_id: String.t(),
          job_id: String.t(),
          repository_name: String.t(),
          user_id: String.t(),
          git_tag: String.t(),
          git_ref: String.t(),
          git_ref_type: String.t(),
          git_branch_name: String.t(),
          git_pull_request_number: String.t(),
          org_username: String.t(),
          job_type: String.t(),
          git_pull_request_branch: String.t()
        }

  defstruct [
    :org_id,
    :expires_in,
    :subject,
    :project_id,
    :workflow_id,
    :pipeline_id,
    :job_id,
    :repository_name,
    :user_id,
    :git_tag,
    :git_ref,
    :git_ref_type,
    :git_branch_name,
    :git_pull_request_number,
    :org_username,
    :job_type,
    :git_pull_request_branch
  ]

  field(:org_id, 1, type: :string)
  field(:expires_in, 2, type: :int64)
  field(:subject, 3, type: :string)
  field(:project_id, 4, type: :string)
  field(:workflow_id, 5, type: :string)
  field(:pipeline_id, 6, type: :string)
  field(:job_id, 7, type: :string)
  field(:repository_name, 8, type: :string)
  field(:user_id, 9, type: :string)
  field(:git_tag, 10, type: :string)
  field(:git_ref, 11, type: :string)
  field(:git_ref_type, 12, type: :string)
  field(:git_branch_name, 13, type: :string)
  field(:git_pull_request_number, 14, type: :string)
  field(:org_username, 15, type: :string)
  field(:job_type, 16, type: :string)
  field(:git_pull_request_branch, 17, type: :string)
end

defmodule InternalApi.Secrethub.GenerateOpenIDConnectTokenResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          token: String.t()
        }

  defstruct [:token]

  field(:token, 1, type: :string)
end

defmodule InternalApi.Secrethub.GetKeyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3
  @type t :: %__MODULE__{}

  defstruct []
end

defmodule InternalApi.Secrethub.GetKeyResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          key: String.t()
        }

  defstruct [:id, :key]

  field(:id, 1, type: :string)
  field(:key, 2, type: :string)
end

defmodule InternalApi.Secrethub.CreateEncryptedRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Secrethub.RequestMeta.t() | nil,
          secret: InternalApi.Secrethub.Secret.t() | nil,
          encrypted_data: InternalApi.Secrethub.EncryptedData.t() | nil
        }

  defstruct [:metadata, :secret, :encrypted_data]

  field(:metadata, 1, type: InternalApi.Secrethub.RequestMeta)
  field(:secret, 2, type: InternalApi.Secrethub.Secret)
  field(:encrypted_data, 3, type: InternalApi.Secrethub.EncryptedData)
end

defmodule InternalApi.Secrethub.CreateEncryptedResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Secrethub.ResponseMeta.t() | nil,
          secret: InternalApi.Secrethub.Secret.t() | nil,
          encrypted_data: InternalApi.Secrethub.EncryptedData.t() | nil
        }

  defstruct [:metadata, :secret, :encrypted_data]

  field(:metadata, 1, type: InternalApi.Secrethub.ResponseMeta)
  field(:secret, 2, type: InternalApi.Secrethub.Secret)
  field(:encrypted_data, 3, type: InternalApi.Secrethub.EncryptedData)
end

defmodule InternalApi.Secrethub.UpdateEncryptedRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Secrethub.RequestMeta.t() | nil,
          secret: InternalApi.Secrethub.Secret.t() | nil,
          encrypted_data: InternalApi.Secrethub.EncryptedData.t() | nil
        }

  defstruct [:metadata, :secret, :encrypted_data]

  field(:metadata, 1, type: InternalApi.Secrethub.RequestMeta)
  field(:secret, 2, type: InternalApi.Secrethub.Secret)
  field(:encrypted_data, 3, type: InternalApi.Secrethub.EncryptedData)
end

defmodule InternalApi.Secrethub.UpdateEncryptedResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Secrethub.ResponseMeta.t() | nil,
          secret: InternalApi.Secrethub.Secret.t() | nil,
          encrypted_data: InternalApi.Secrethub.EncryptedData.t() | nil
        }

  defstruct [:metadata, :secret, :encrypted_data]

  field(:metadata, 1, type: InternalApi.Secrethub.ResponseMeta)
  field(:secret, 2, type: InternalApi.Secrethub.Secret)
  field(:encrypted_data, 3, type: InternalApi.Secrethub.EncryptedData)
end

defmodule InternalApi.Secrethub.SecretService.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.Secrethub.SecretService"

  rpc(:List, InternalApi.Secrethub.ListRequest, InternalApi.Secrethub.ListResponse)

  rpc(
    :ListKeyset,
    InternalApi.Secrethub.ListKeysetRequest,
    InternalApi.Secrethub.ListKeysetResponse
  )

  rpc(:Describe, InternalApi.Secrethub.DescribeRequest, InternalApi.Secrethub.DescribeResponse)

  rpc(
    :DescribeMany,
    InternalApi.Secrethub.DescribeManyRequest,
    InternalApi.Secrethub.DescribeManyResponse
  )

  rpc(:Create, InternalApi.Secrethub.CreateRequest, InternalApi.Secrethub.CreateResponse)

  rpc(:Update, InternalApi.Secrethub.UpdateRequest, InternalApi.Secrethub.UpdateResponse)

  rpc(:Destroy, InternalApi.Secrethub.DestroyRequest, InternalApi.Secrethub.DestroyResponse)

  rpc(
    :GenerateOpenIDConnectToken,
    InternalApi.Secrethub.GenerateOpenIDConnectTokenRequest,
    InternalApi.Secrethub.GenerateOpenIDConnectTokenResponse
  )

  rpc(
    :CreateEncrypted,
    InternalApi.Secrethub.CreateEncryptedRequest,
    InternalApi.Secrethub.CreateEncryptedResponse
  )

  rpc(
    :UpdateEncrypted,
    InternalApi.Secrethub.UpdateEncryptedRequest,
    InternalApi.Secrethub.UpdateEncryptedResponse
  )

  rpc(:GetKey, InternalApi.Secrethub.GetKeyRequest, InternalApi.Secrethub.GetKeyResponse)

  rpc(:Checkout, InternalApi.Secrethub.CheckoutRequest, InternalApi.Secrethub.CheckoutResponse)

  rpc(
    :CheckoutMany,
    InternalApi.Secrethub.CheckoutManyRequest,
    InternalApi.Secrethub.CheckoutManyResponse
  )
end

defmodule InternalApi.Secrethub.SecretService.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.Secrethub.SecretService.Service
end
