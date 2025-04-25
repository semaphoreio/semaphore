defmodule RepositoryHub.Server do
  require Logger

  alias InternalApi.Repository.{
    RepositoryService,
    DescribeRequest,
    DescribeResponse,
    DescribeManyRequest,
    DescribeManyResponse,
    DescribeRemoteRepositoryRequest,
    DescribeRemoteRepositoryResponse,
    UpdateRequest,
    UpdateResponse,
    DeleteRequest,
    DeleteResponse,
    ListRequest,
    ListResponse,
    GetFileRequest,
    GetFileResponse,
    GetFilesRequest,
    GetFilesResponse,
    GetChangedFilePathsRequest,
    GetChangedFilePathsResponse,
    CommitRequest,
    CommitResponse,
    GetSshKeyRequest,
    GetSshKeyResponse,
    ListAccessibleRepositoriesRequest,
    ListAccessibleRepositoriesResponse,
    ListCollaboratorsRequest,
    ListCollaboratorsResponse,
    CreateBuildStatusRequest,
    CreateRequest,
    CreateResponse,
    CheckWebhookRequest,
    CheckWebhookResponse,
    RegenerateWebhookRequest,
    RegenerateWebhookResponse,
    CheckDeployKeyRequest,
    CheckDeployKeyResponse,
    RegenerateDeployKeyRequest,
    RegenerateDeployKeyResponse,
    ForkRequest,
    ForkResponse,
    DescribeRevisionRequest,
    DescribeRevisionResponse,
    VerifyWebhookSignatureRequest,
    VerifyWebhookSignatureResponse
  }

  alias RepositoryHub.Server

  alias RepositoryHub.Adapters

  alias GRPC.Server.Stream, as: ServerStream

  use GRPC.Server, service: RepositoryService.Service
  import RepositoryHub.Toolkit

  @spec describe(DescribeRequest.t(), ServerStream.t()) :: DescribeResponse.t()
  def describe(request, _stream) do
    execute(request, Server.DescribeAction)
  end

  @spec describe_many(DescribeManyRequest.t(), ServerStream.t()) :: DescribeManyResponse.t()
  def describe_many(request, _stream) do
    execute(request, Server.DescribeManyAction)
  end

  @spec list(ListRequest.t(), ServerStream.t()) :: ListResponse.t()
  def list(request, _stream) do
    execute(request, Server.ListAction)
  end

  @spec create(CreateRequest.t(), ServerStream.t()) :: CreateResponse.t()
  def create(request, _stream) do
    execute(request, Server.CreateAction)
    |> tap(fn _ ->
      Logger.metadata()
      |> Keyword.fetch(:ctx)
      |> unwrap(fn
        "bbo" ->
          wrap({"bitbucket", "oauth"})

        "gho" ->
          wrap({"github", "oauth"})

        "gha" ->
          wrap({"github", "app"})

        "git" ->
          wrap({"git", "git"})

        _ ->
          :error
      end)
      |> unwrap(fn {provider, integration} ->
        Watchman.increment({"RepositoryHub.GitRepositories", [provider, integration]})
      end)
    end)
  end

  @spec delete(DeleteRequest.t(), ServerStream.t()) :: DeleteResponse.t()
  def delete(request, _stream) do
    execute(request, Server.DeleteAction)
  end

  @spec clear_external_data(ClearExternalDataRequest.t(), ServerStream.t()) :: ClearExternalDataResponse.t()
  def clear_external_data(request, _stream) do
    execute(request, Server.ClearExternalDataAction)
  end

  @spec get_file(GetFileRequest.t(), ServerStream.t()) :: GetFileResponse.t()
  def get_file(request, _stream) do
    execute(request, Server.GetFileAction)
  end

  @spec get_files(GetFilesRequest.t(), ServerStream.t()) :: GetFilesResponse.t()
  def get_files(_request, _stream) do
    raise GRPC.RPCError,
      status: GRPC.Status.unimplemented(),
      message: "GetFiles action is not implemented in this service. You probably want to use RepoHub instead."
  end

  @spec get_changed_file_paths(GetChangedFilePathsRequest.t(), ServerStream.t()) :: GetChangedFilePathsResponse.t()
  def get_changed_file_paths(_request, _stream) do
    raise GRPC.RPCError,
      status: GRPC.Status.unimplemented(),
      message:
        "GetChangedFilePaths action is not implemented in this service. You probably want to use RepoHub instead."
  end

  @spec commit(CommitRequest.t(), ServerStream.t()) :: CommitResponse.t()
  def commit(_request, _stream) do
    raise GRPC.RPCError,
      status: GRPC.Status.unimplemented(),
      message: "Commit action is not implemented in this service. You probably want to use RepoHub instead."
  end

  @spec get_ssh_key(GetSshKeyRequest.t(), ServerStream.t()) :: GetSshKeyResponse.t()
  def get_ssh_key(request, _stream) do
    execute(request, Server.GetSshKeyAction)
  end

  @spec list_accessible_repositories(ListAccessibleRepositoriesRequest.t(), ServerStream.t()) ::
          ListAccessibleRepositoriesResponse.t()
  def list_accessible_repositories(request, _stream) do
    execute(request, Server.ListAccessibleRepositoriesAction)
  end

  @spec list_collaborators(ListCollaboratorsRequest.t(), ServerStream.t()) :: ListCollaboratorsResponse.t()
  def list_collaborators(request, stream) do
    execute(request, stream, Server.ListCollaboratorsAction)
  end

  @spec create_build_status(CreateBuildStatusRequest.t(), ServerStream.t()) :: %{}
  def create_build_status(request, _stream) do
    execute(request, Server.CreateBuildStatusAction)
  end

  @spec check_deploy_key(CheckDeployKeyRequest.t(), ServerStream.t()) :: CheckDeployKeyResponse.t()
  def check_deploy_key(request, _stream) do
    execute(request, Server.CheckDeployKeyAction)
  end

  @spec regenerate_deploy_key(RegenerateDeployKeyRequest.t(), ServerStream.t()) :: RegenerateDeployKeyResponse.t()
  def regenerate_deploy_key(request, _stream) do
    execute(request, Server.RegenerateDeployKeyAction)
  end

  @spec check_webhook(CheckWebhookRequest.t(), ServerStream.t()) :: CheckWebhookResponse.t()
  def check_webhook(request, _stream) do
    execute(request, Server.CheckWebhookAction)
  end

  @spec regenerate_webhook(RegenerateWebhookRequest.t(), ServerStream.t()) :: RegenerateWebhookResponse.t()
  def regenerate_webhook(request, _stream) do
    execute(request, Server.RegenerateWebhookAction)
  end

  @spec fork(ForkRequest.t(), ServerStream.t()) :: ForkResponse.t()
  def fork(request, _stream) do
    execute(request, Server.ForkAction)
  end

  @spec update(UpdateRequest.t(), ServerStream.t()) :: UpdateResponse.t()
  def update(request, _stream) do
    execute(request, Server.UpdateAction)
  end

  @spec describe_remote_repository(DescribeRemoteRepositoryRequest.t(), ServerStream.t()) ::
          DescribeRemoteRepositoryResponse.t()
  def describe_remote_repository(request, _stream) do
    execute(request, Server.DescribeRemoteRepositoryAction)
  end

  @spec describe_revision(DescribeRevisionRequest.t(), ServerStream.t()) ::
          DescribeRevisionResponse.t()
  def describe_revision(request, _stream) do
    execute(request, Server.DescribeRevisionAction)
  end

  @spec verify_webhook_signature(VerifyWebhookSignatureRequest.t(), ServerStream.t()) ::
          VerifyWebhookSignatureResponse.t()
  def verify_webhook_signature(request, _stream) do
    execute(request, Server.VerifyWebhookSignatureAction)
  end

  defp execute(request, stream \\ nil, action) do
    Adapters.pick(request)
    |> unwrap(fn adapter ->
      Logger.metadata(ctx: adapter.short_name)

      request
      |> validate_action(adapter, action)
      |> execute_action(stream, adapter, action)
    end)
    |> handle_response()
  rescue
    e in GRPC.RPCError ->
      reraise(e, __STACKTRACE__)

    e ->
      log_error([
        "❗ Exception",
        inspect(e),
        inspect(__STACKTRACE__)
      ])

      reraise(
        GRPC.RPCError,
        [status: GRPC.Status.internal(), message: "Unhandled error. Please contact support."],
        __STACKTRACE__
      )
  end

  defp validate_action(request, adapter, action) do
    action.validate(adapter, request)
    |> unwrap_error(fn
      error when is_bitstring(error) ->
        fail_with(:precondition, error)

      error ->
        error(error)
    end)
    |> unwrap(fn validated_request ->
      validated_request
    end)
  end

  defp execute_action(validated_request, nil, adapter, action) do
    validated_request
    |> unwrap(fn validated_request ->
      action.execute(adapter, validated_request)
    end)
  end

  defp execute_action(validated_request, stream, adapter, action) do
    validated_request
    |> unwrap(fn validated_request ->
      action.execute(adapter, validated_request, stream)
    end)
  end

  defp handle_response(response) do
    response
    |> unwrap_error(fn
      %{message: message, status: status} ->
        raise(GRPC.RPCError, status: status, message: message)

      :rate_limit ->
        raise(GRPC.RPCError,
          status: GRPC.Status.resource_exhausted(),
          message: "Limit of API calls to external provider reached"
        )

      error when is_bitstring(error) ->
        log_error([
          "❗ Unhandled error",
          inspect(error)
        ])

        raise(GRPC.RPCError, status: GRPC.Status.failed_precondition(), message: error)

      error ->
        log_error([
          "❗ Unhandled error",
          inspect(error)
        ])

        raise(GRPC.RPCError, status: GRPC.Status.unknown(), message: "Unhandled error. Please contact support.")
    end)
    |> unwrap(fn response ->
      response
    end)
  end
end
