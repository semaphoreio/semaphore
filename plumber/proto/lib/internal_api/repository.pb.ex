defmodule InternalApi.Repository.DescribeRevisionRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          repository_id: String.t(),
          revision: InternalApi.Repository.Revision.t()
        }
  defstruct [:repository_id, :revision]

  field(:repository_id, 1, type: :string)
  field(:revision, 2, type: InternalApi.Repository.Revision)
end

defmodule InternalApi.Repository.DescribeRevisionResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          commit: InternalApi.Repository.Commit.t()
        }
  defstruct [:commit]

  field(:commit, 1, type: InternalApi.Repository.Commit)
end

defmodule InternalApi.Repository.Commit do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          sha: String.t(),
          msg: String.t(),
          author_name: String.t(),
          author_uuid: String.t(),
          author_avatar_url: String.t()
        }
  defstruct [:sha, :msg, :author_name, :author_uuid, :author_avatar_url]

  field(:sha, 1, type: :string)
  field(:msg, 2, type: :string)
  field(:author_name, 3, type: :string)
  field(:author_uuid, 4, type: :string)
  field(:author_avatar_url, 5, type: :string)
end

defmodule InternalApi.Repository.DeployKey do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          title: String.t(),
          fingerprint: String.t(),
          created_at: Google.Protobuf.Timestamp.t(),
          public_key: String.t()
        }
  defstruct [:title, :fingerprint, :created_at, :public_key]

  field(:title, 1, type: :string)
  field(:fingerprint, 2, type: :string)
  field(:created_at, 3, type: Google.Protobuf.Timestamp)
  field(:public_key, 4, type: :string)
end

defmodule InternalApi.Repository.DescribeRemoteRepositoryRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user_id: String.t(),
          integration_type: integer,
          url: String.t()
        }
  defstruct [:user_id, :integration_type, :url]

  field(:user_id, 1, type: :string)
  field(:integration_type, 2, type: InternalApi.RepositoryIntegrator.IntegrationType, enum: true)
  field(:url, 3, type: :string)
end

defmodule InternalApi.Repository.DescribeRemoteRepositoryResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          remote_repository: InternalApi.Repository.RemoteRepository.t()
        }
  defstruct [:remote_repository]

  field(:remote_repository, 1, type: InternalApi.Repository.RemoteRepository)
end

defmodule InternalApi.Repository.CheckDeployKeyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          repository_id: String.t()
        }
  defstruct [:repository_id]

  field(:repository_id, 1, type: :string)
end

defmodule InternalApi.Repository.CheckDeployKeyResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          deploy_key: InternalApi.Repository.DeployKey.t()
        }
  defstruct [:deploy_key]

  field(:deploy_key, 1, type: InternalApi.Repository.DeployKey)
end

defmodule InternalApi.Repository.RegenerateDeployKeyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          repository_id: String.t()
        }
  defstruct [:repository_id]

  field(:repository_id, 1, type: :string)
end

defmodule InternalApi.Repository.RegenerateDeployKeyResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          deploy_key: InternalApi.Repository.DeployKey.t()
        }
  defstruct [:deploy_key]

  field(:deploy_key, 1, type: InternalApi.Repository.DeployKey)
end

defmodule InternalApi.Repository.Webhook do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          url: String.t()
        }
  defstruct [:url]

  field(:url, 1, type: :string)
end

defmodule InternalApi.Repository.CheckWebhookRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          repository_id: String.t()
        }
  defstruct [:repository_id]

  field(:repository_id, 1, type: :string)
end

defmodule InternalApi.Repository.CheckWebhookResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          webhook: InternalApi.Repository.Webhook.t()
        }
  defstruct [:webhook]

  field(:webhook, 1, type: InternalApi.Repository.Webhook)
end

defmodule InternalApi.Repository.RegenerateWebhookRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          repository_id: String.t()
        }
  defstruct [:repository_id]

  field(:repository_id, 1, type: :string)
end

defmodule InternalApi.Repository.RegenerateWebhookResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          webhook: InternalApi.Repository.Webhook.t()
        }
  defstruct [:webhook]

  field(:webhook, 1, type: InternalApi.Repository.Webhook)
end

defmodule InternalApi.Repository.ForkRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user_id: String.t(),
          integration_type: integer,
          url: String.t()
        }
  defstruct [:user_id, :integration_type, :url]

  field(:user_id, 1, type: :string)
  field(:integration_type, 2, type: InternalApi.RepositoryIntegrator.IntegrationType, enum: true)
  field(:url, 3, type: :string)
end

defmodule InternalApi.Repository.ForkResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          remote_repository: InternalApi.Repository.RemoteRepository.t()
        }
  defstruct [:remote_repository]

  field(:remote_repository, 1, type: InternalApi.Repository.RemoteRepository)
end

defmodule InternalApi.Repository.ListAccessibleRepositoriesRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user_id: String.t(),
          integration_type: integer,
          page_token: String.t(),
          only_public: boolean
        }
  defstruct [:user_id, :integration_type, :page_token, :only_public]

  field(:user_id, 1, type: :string)
  field(:integration_type, 2, type: InternalApi.RepositoryIntegrator.IntegrationType, enum: true)
  field(:page_token, 3, type: :string)
  field(:only_public, 4, type: :bool)
end

defmodule InternalApi.Repository.ListAccessibleRepositoriesResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          repositories: [InternalApi.Repository.RemoteRepository.t()],
          next_page_token: String.t()
        }
  defstruct [:repositories, :next_page_token]

  field(:repositories, 1, repeated: true, type: InternalApi.Repository.RemoteRepository)
  field(:next_page_token, 2, type: :string)
end

defmodule InternalApi.Repository.ListCollaboratorsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          repository_id: String.t(),
          page_token: String.t()
        }
  defstruct [:repository_id, :page_token]

  field(:repository_id, 1, type: :string)
  field(:page_token, 2, type: :string)
end

defmodule InternalApi.Repository.ListCollaboratorsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          collaborators: [InternalApi.Repository.Collaborator.t()],
          next_page_token: String.t()
        }
  defstruct [:collaborators, :next_page_token]

  field(:collaborators, 1, repeated: true, type: InternalApi.Repository.Collaborator)
  field(:next_page_token, 2, type: :string)
end

defmodule InternalApi.Repository.Collaborator do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          login: String.t(),
          permission: integer
        }
  defstruct [:id, :login, :permission]

  field(:id, 1, type: :string)
  field(:login, 2, type: :string)
  field(:permission, 3, type: InternalApi.Repository.Collaborator.Permission, enum: true)
end

defmodule InternalApi.Repository.Collaborator.Permission do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:ADMIN, 0)
  field(:WRITE, 1)
  field(:READ, 2)
end

defmodule InternalApi.Repository.CreateBuildStatusRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          repository_id: String.t(),
          commit_sha: String.t(),
          status: integer,
          url: String.t(),
          description: String.t(),
          context: String.t()
        }
  defstruct [:repository_id, :commit_sha, :status, :url, :description, :context]

  field(:repository_id, 1, type: :string)
  field(:commit_sha, 2, type: :string)
  field(:status, 3, type: InternalApi.Repository.CreateBuildStatusRequest.Status, enum: true)
  field(:url, 4, type: :string)
  field(:description, 5, type: :string)
  field(:context, 6, type: :string)
end

defmodule InternalApi.Repository.CreateBuildStatusRequest.Status do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:SUCCESS, 0)
  field(:PENDING, 1)
  field(:FAILURE, 2)
  field(:STOPPED, 3)
end

defmodule InternalApi.Repository.CreateBuildStatusResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          code: integer
        }
  defstruct [:code]

  field(:code, 1, type: InternalApi.Repository.CreateBuildStatusResponse.Code, enum: true)
end

defmodule InternalApi.Repository.CreateBuildStatusResponse.Code do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:CUSTOM, 0)
  field(:OK, 1)
  field(:VALIDATION_FAILED, 2)
  field(:SERVICE_ERROR, 3)
  field(:UNAUTHORIZED, 4)
  field(:ACCOUNT_SUSPENDED, 5)
end

defmodule InternalApi.Repository.DescribeRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          repository_id: String.t(),
          include_private_ssh_key: boolean
        }
  defstruct [:repository_id, :include_private_ssh_key]

  field(:repository_id, 1, type: :string)
  field(:include_private_ssh_key, 2, type: :bool)
end

defmodule InternalApi.Repository.DescribeResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          repository: InternalApi.Repository.Repository.t(),
          private_ssh_key: String.t()
        }
  defstruct [:repository, :private_ssh_key]

  field(:repository, 1, type: InternalApi.Repository.Repository)
  field(:private_ssh_key, 2, type: :string)
end

defmodule InternalApi.Repository.DescribeManyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          repository_ids: [String.t()],
          project_ids: [String.t()]
        }
  defstruct [:repository_ids, :project_ids]

  field(:repository_ids, 1, repeated: true, type: :string)
  field(:project_ids, 2, repeated: true, type: :string)
end

defmodule InternalApi.Repository.DescribeManyResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          repositories: [InternalApi.Repository.Repository.t()]
        }
  defstruct [:repositories]

  field(:repositories, 1, repeated: true, type: InternalApi.Repository.Repository)
end

defmodule InternalApi.Repository.ListRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_id: String.t()
        }
  defstruct [:project_id]

  field(:project_id, 1, type: :string)
end

defmodule InternalApi.Repository.ListResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          repositories: [InternalApi.Repository.Repository.t()]
        }
  defstruct [:repositories]

  field(:repositories, 1, repeated: true, type: InternalApi.Repository.Repository)
end

defmodule InternalApi.Repository.Repository do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          owner: String.t(),
          private: boolean,
          provider: String.t(),
          url: String.t(),
          project_id: String.t(),
          pipeline_file: String.t(),
          integration_type: integer,
          commit_status: InternalApi.Projecthub.Project.Spec.Repository.Status.t(),
          whitelist: InternalApi.Projecthub.Project.Spec.Repository.Whitelist.t(),
          hook_id: String.t(),
          default_branch: String.t(),
          connected: boolean
        }
  defstruct [
    :id,
    :name,
    :owner,
    :private,
    :provider,
    :url,
    :project_id,
    :pipeline_file,
    :integration_type,
    :commit_status,
    :whitelist,
    :hook_id,
    :default_branch,
    :connected
  ]

  field(:id, 1, type: :string)
  field(:name, 2, type: :string)
  field(:owner, 3, type: :string)
  field(:private, 4, type: :bool)
  field(:provider, 5, type: :string)
  field(:url, 6, type: :string)
  field(:project_id, 7, type: :string)
  field(:pipeline_file, 8, type: :string)
  field(:integration_type, 9, type: InternalApi.RepositoryIntegrator.IntegrationType, enum: true)
  field(:commit_status, 10, type: InternalApi.Projecthub.Project.Spec.Repository.Status)
  field(:whitelist, 11, type: InternalApi.Projecthub.Project.Spec.Repository.Whitelist)
  field(:hook_id, 12, type: :string)
  field(:default_branch, 13, type: :string)
  field(:connected, 14, type: :bool)
end

defmodule InternalApi.Repository.RemoteRepository do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          description: String.t(),
          url: String.t(),
          full_name: String.t(),
          addable: boolean,
          reason: String.t()
        }
  defstruct [:id, :name, :description, :url, :full_name, :addable, :reason]

  field(:id, 1, type: :string)
  field(:name, 2, type: :string)
  field(:description, 3, type: :string)
  field(:url, 4, type: :string)
  field(:full_name, 5, type: :string)
  field(:addable, 6, type: :bool)
  field(:reason, 7, type: :string)
end

defmodule InternalApi.Repository.Revision do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          commit_sha: String.t(),
          reference: String.t()
        }
  defstruct [:commit_sha, :reference]

  field(:commit_sha, 1, type: :string)
  field(:reference, 2, type: :string)
end

defmodule InternalApi.Repository.GetFileRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          repository_id: String.t(),
          commit_sha: String.t(),
          path: String.t()
        }
  defstruct [:repository_id, :commit_sha, :path]

  field(:repository_id, 1, type: :string)
  field(:commit_sha, 2, type: :string)
  field(:path, 3, type: :string)
end

defmodule InternalApi.Repository.GetFileResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          file: InternalApi.Repository.File.t()
        }
  defstruct [:file]

  field(:file, 1, type: InternalApi.Repository.File)
end

defmodule InternalApi.Repository.GetFilesRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          repository_id: String.t(),
          revision: InternalApi.Repository.Revision.t(),
          selectors: [InternalApi.Repository.GetFilesRequest.Selector.t()],
          include_content: boolean
        }
  defstruct [:repository_id, :revision, :selectors, :include_content]

  field(:repository_id, 1, type: :string)
  field(:revision, 2, type: InternalApi.Repository.Revision)
  field(:selectors, 3, repeated: true, type: InternalApi.Repository.GetFilesRequest.Selector)
  field(:include_content, 4, type: :bool)
end

defmodule InternalApi.Repository.GetFilesRequest.Selector do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          glob: String.t(),
          content_regex: String.t()
        }
  defstruct [:glob, :content_regex]

  field(:glob, 1, type: :string)
  field(:content_regex, 2, type: :string)
end

defmodule InternalApi.Repository.GetFilesResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          files: [InternalApi.Repository.File.t()]
        }
  defstruct [:files]

  field(:files, 1, repeated: true, type: InternalApi.Repository.File)
end

defmodule InternalApi.Repository.File do
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

defmodule InternalApi.Repository.GetChangedFilePathsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          head_rev: InternalApi.Repository.Revision.t(),
          base_rev: InternalApi.Repository.Revision.t(),
          repository_id: String.t(),
          comparison_type: integer
        }
  defstruct [:head_rev, :base_rev, :repository_id, :comparison_type]

  field(:head_rev, 1, type: InternalApi.Repository.Revision)
  field(:base_rev, 2, type: InternalApi.Repository.Revision)
  field(:repository_id, 3, type: :string)

  field(:comparison_type, 4,
    type: InternalApi.Repository.GetChangedFilePathsRequest.ComparisonType,
    enum: true
  )
end

defmodule InternalApi.Repository.GetChangedFilePathsRequest.ComparisonType do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:HEAD_TO_MERGE_BASE, 0)
  field(:HEAD_TO_HEAD, 1)
end

defmodule InternalApi.Repository.GetChangedFilePathsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          changed_file_paths: [String.t()]
        }
  defstruct [:changed_file_paths]

  field(:changed_file_paths, 1, repeated: true, type: :string)
end

defmodule InternalApi.Repository.GetSshKeyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          repository_id: String.t()
        }
  defstruct [:repository_id]

  field(:repository_id, 1, type: :string)
end

defmodule InternalApi.Repository.GetSshKeyResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          private_ssh_key: String.t()
        }
  defstruct [:private_ssh_key]

  field(:private_ssh_key, 1, type: :string)
end

defmodule InternalApi.Repository.CommitRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          repository_id: String.t(),
          user_id: String.t(),
          branch_name: String.t(),
          commit_message: String.t(),
          changes: [InternalApi.Repository.CommitRequest.Change.t()]
        }
  defstruct [:repository_id, :user_id, :branch_name, :commit_message, :changes]

  field(:repository_id, 1, type: :string)
  field(:user_id, 2, type: :string)
  field(:branch_name, 3, type: :string)
  field(:commit_message, 4, type: :string)
  field(:changes, 5, repeated: true, type: InternalApi.Repository.CommitRequest.Change)
end

defmodule InternalApi.Repository.CommitRequest.Change do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          action: integer,
          file: InternalApi.Repository.File.t()
        }
  defstruct [:action, :file]

  field(:action, 1, type: InternalApi.Repository.CommitRequest.Change.Action, enum: true)
  field(:file, 2, type: InternalApi.Repository.File)
end

defmodule InternalApi.Repository.CommitRequest.Change.Action do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:ADD_FILE, 0)
  field(:MODIFY_FILE, 1)
  field(:DELETE_FILE, 2)
end

defmodule InternalApi.Repository.CommitResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          revision: InternalApi.Repository.Revision.t()
        }
  defstruct [:revision]

  field(:revision, 1, type: InternalApi.Repository.Revision)
end

defmodule InternalApi.Repository.CreateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_id: String.t(),
          user_id: String.t(),
          pipeline_file: String.t(),
          repository_url: String.t(),
          request_id: String.t(),
          only_public: boolean,
          integration_type: integer,
          commit_status: InternalApi.Projecthub.Project.Spec.Repository.Status.t(),
          whitelist: InternalApi.Projecthub.Project.Spec.Repository.Whitelist.t(),
          default_branch: String.t()
        }
  defstruct [
    :project_id,
    :user_id,
    :pipeline_file,
    :repository_url,
    :request_id,
    :only_public,
    :integration_type,
    :commit_status,
    :whitelist,
    :default_branch
  ]

  field(:project_id, 1, type: :string)
  field(:user_id, 2, type: :string)
  field(:pipeline_file, 3, type: :string)
  field(:repository_url, 4, type: :string)
  field(:request_id, 5, type: :string)
  field(:only_public, 6, type: :bool)
  field(:integration_type, 7, type: InternalApi.RepositoryIntegrator.IntegrationType, enum: true)
  field(:commit_status, 8, type: InternalApi.Projecthub.Project.Spec.Repository.Status)
  field(:whitelist, 9, type: InternalApi.Projecthub.Project.Spec.Repository.Whitelist)
  field(:default_branch, 10, type: :string)
end

defmodule InternalApi.Repository.CreateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          repository: InternalApi.Repository.Repository.t()
        }
  defstruct [:repository]

  field(:repository, 1, type: InternalApi.Repository.Repository)
end

defmodule InternalApi.Repository.DeleteRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          repository_id: String.t()
        }
  defstruct [:repository_id]

  field(:repository_id, 1, type: :string)
end

defmodule InternalApi.Repository.DeleteResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          repository: InternalApi.Repository.Repository.t()
        }
  defstruct [:repository]

  field(:repository, 1, type: InternalApi.Repository.Repository)
end

defmodule InternalApi.Repository.UpdateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          repository_id: String.t(),
          url: String.t(),
          pipeline_file: String.t(),
          integration_type: integer,
          commit_status: InternalApi.Projecthub.Project.Spec.Repository.Status.t(),
          whitelist: InternalApi.Projecthub.Project.Spec.Repository.Whitelist.t(),
          default_branch: String.t()
        }
  defstruct [
    :repository_id,
    :url,
    :pipeline_file,
    :integration_type,
    :commit_status,
    :whitelist,
    :default_branch
  ]

  field(:repository_id, 1, type: :string)
  field(:url, 2, type: :string)
  field(:pipeline_file, 3, type: :string)
  field(:integration_type, 4, type: InternalApi.RepositoryIntegrator.IntegrationType, enum: true)
  field(:commit_status, 5, type: InternalApi.Projecthub.Project.Spec.Repository.Status)
  field(:whitelist, 6, type: InternalApi.Projecthub.Project.Spec.Repository.Whitelist)
  field(:default_branch, 7, type: :string)
end

defmodule InternalApi.Repository.UpdateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          repository: InternalApi.Repository.Repository.t()
        }
  defstruct [:repository]

  field(:repository, 1, type: InternalApi.Repository.Repository)
end

defmodule InternalApi.Repository.RemoteRepositoryChanged do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          remote_id: String.t(),
          repository_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t()
        }
  defstruct [:remote_id, :repository_id, :timestamp]

  field(:remote_id, 1, type: :string)
  field(:repository_id, 2, type: :string)
  field(:timestamp, 3, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Repository.VerifyWebhookSignatureRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          organization_id: String.t(),
          repository_id: String.t(),
          payload: String.t(),
          signature: String.t()
        }
  defstruct [:organization_id, :repository_id, :payload, :signature]

  field(:organization_id, 1, type: :string)
  field(:repository_id, 2, type: :string)
  field(:payload, 3, type: :string)
  field(:signature, 4, type: :string)
end

defmodule InternalApi.Repository.VerifyWebhookSignatureResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          valid: boolean
        }
  defstruct [:valid]

  field(:valid, 1, type: :bool)
end

defmodule InternalApi.Repository.ClearExternalDataRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          repository_id: String.t()
        }
  defstruct [:repository_id]

  field(:repository_id, 1, type: :string)
end

defmodule InternalApi.Repository.ClearExternalDataResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          repository: InternalApi.Repository.Repository.t()
        }
  defstruct [:repository]

  field(:repository, 1, type: InternalApi.Repository.Repository)
end

defmodule InternalApi.Repository.RegenerateWebhookSecretRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          repository_id: String.t()
        }
  defstruct [:repository_id]

  field(:repository_id, 1, type: :string)
end

defmodule InternalApi.Repository.RegenerateWebhookSecretResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          secret: String.t()
        }
  defstruct [:secret]

  field(:secret, 1, type: :string)
end

defmodule InternalApi.Repository.RepositoryService.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.Repository.RepositoryService"

  rpc(:Describe, InternalApi.Repository.DescribeRequest, InternalApi.Repository.DescribeResponse)

  rpc(
    :DescribeMany,
    InternalApi.Repository.DescribeManyRequest,
    InternalApi.Repository.DescribeManyResponse
  )

  rpc(:List, InternalApi.Repository.ListRequest, InternalApi.Repository.ListResponse)
  rpc(:Create, InternalApi.Repository.CreateRequest, InternalApi.Repository.CreateResponse)
  rpc(:Update, InternalApi.Repository.UpdateRequest, InternalApi.Repository.UpdateResponse)
  rpc(:Delete, InternalApi.Repository.DeleteRequest, InternalApi.Repository.DeleteResponse)
  rpc(:GetFile, InternalApi.Repository.GetFileRequest, InternalApi.Repository.GetFileResponse)
  rpc(:GetFiles, InternalApi.Repository.GetFilesRequest, InternalApi.Repository.GetFilesResponse)

  rpc(
    :GetChangedFilePaths,
    InternalApi.Repository.GetChangedFilePathsRequest,
    InternalApi.Repository.GetChangedFilePathsResponse
  )

  rpc(:Commit, InternalApi.Repository.CommitRequest, InternalApi.Repository.CommitResponse)

  rpc(
    :GetSshKey,
    InternalApi.Repository.GetSshKeyRequest,
    InternalApi.Repository.GetSshKeyResponse
  )

  rpc(
    :ListAccessibleRepositories,
    InternalApi.Repository.ListAccessibleRepositoriesRequest,
    InternalApi.Repository.ListAccessibleRepositoriesResponse
  )

  rpc(
    :ListCollaborators,
    InternalApi.Repository.ListCollaboratorsRequest,
    InternalApi.Repository.ListCollaboratorsResponse
  )

  rpc(
    :CreateBuildStatus,
    InternalApi.Repository.CreateBuildStatusRequest,
    InternalApi.Repository.CreateBuildStatusResponse
  )

  rpc(
    :CheckDeployKey,
    InternalApi.Repository.CheckDeployKeyRequest,
    InternalApi.Repository.CheckDeployKeyResponse
  )

  rpc(
    :RegenerateDeployKey,
    InternalApi.Repository.RegenerateDeployKeyRequest,
    InternalApi.Repository.RegenerateDeployKeyResponse
  )

  rpc(
    :CheckWebhook,
    InternalApi.Repository.CheckWebhookRequest,
    InternalApi.Repository.CheckWebhookResponse
  )

  rpc(
    :RegenerateWebhook,
    InternalApi.Repository.RegenerateWebhookRequest,
    InternalApi.Repository.RegenerateWebhookResponse
  )

  rpc(:Fork, InternalApi.Repository.ForkRequest, InternalApi.Repository.ForkResponse)

  rpc(
    :DescribeRemoteRepository,
    InternalApi.Repository.DescribeRemoteRepositoryRequest,
    InternalApi.Repository.DescribeRemoteRepositoryResponse
  )

  rpc(
    :DescribeRevision,
    InternalApi.Repository.DescribeRevisionRequest,
    InternalApi.Repository.DescribeRevisionResponse
  )

  rpc(
    :VerifyWebhookSignature,
    InternalApi.Repository.VerifyWebhookSignatureRequest,
    InternalApi.Repository.VerifyWebhookSignatureResponse
  )

  rpc(
    :ClearExternalData,
    InternalApi.Repository.ClearExternalDataRequest,
    InternalApi.Repository.ClearExternalDataResponse
  )

  rpc(
    :RegenerateWebhookSecret,
    InternalApi.Repository.RegenerateWebhookSecretRequest,
    InternalApi.Repository.RegenerateWebhookSecretResponse
  )
end

defmodule InternalApi.Repository.RepositoryService.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.Repository.RepositoryService.Service
end
