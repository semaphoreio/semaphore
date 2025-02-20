defmodule Projecthub.RepositoryHubClient do
  @moduledoc """
  Wrapper for Projecthub API Calls
  """
  alias Projecthub.Util.GRPC.{
    ClientMetricsInterceptor,
    ClientRequestIdInterceptor,
    ClientLoggerInterceptor,
    ClientRunAsyncInterceptor
  }

  use Projecthub.GrpcClient,
    service: InternalApi.Repository.RepositoryService,
    endpoint: Application.fetch_env!(:projecthub, :repositoryhub_grpc_endpoint),
    interceptors: [
      {ClientMetricsInterceptor, "external.repository_hub"},
      ClientRequestIdInterceptor,
      ClientLoggerInterceptor,
      ClientRunAsyncInterceptor
    ]

  alias InternalApi.Repository.{
    CreateRequest,
    CreateResponse,
    CheckDeployKeyRequest,
    CheckWebhookRequest,
    RegenerateDeployKeyRequest,
    RegenerateDeployKeyResponse,
    RegenerateWebhookRequest,
    RegenerateWebhookResponse,
    DescribeRequest,
    DescribeManyResponse,
    DeleteRequest,
    DescribeManyRequest,
    DescribeManyResponse,
    UpdateRequest,
    UpdateResponse,
    DescribeRemoteRepositoryRequest,
    DescribeRemoteRepositoryResponse,
    ForkRequest,
    ForkResponse
  }

  @type opts() :: [
          timeout: non_neg_integer()
        ]

  @type rpc_request(response_type) :: response_type | Map.t()
  @type rpc_response(response_type) :: {:ok, response_type} | {:error, GRPC.RPCError.t()}

  @spec create(rpc_request(CreateRequest.t()), opts()) :: rpc_response(CreateResponse.t())
  def create(request, opts \\ []),
    do:
      request
      |> decorate(CreateRequest)
      |> grpc_call(:create, with_default_opts(opts))

  @spec describe(rpc_request(DescribeRequest.t()), opts()) :: rpc_response(DescribeResponse.t())
  def describe(request, opts \\ []),
    do:
      request
      |> decorate(DescribeRequest)
      |> grpc_call(:describe, with_default_opts(opts))

  @spec describe_many(rpc_request(DescribeManyRequest.t()), opts()) :: rpc_response(DescribeManyResponse.t())
  def describe_many(request, opts \\ []),
    do:
      request
      |> decorate(DescribeManyRequest)
      |> grpc_call(:describe_many, with_default_opts(opts))

  @spec regenerate_deploy_key(rpc_request(RegenerateDeployKeyRequest.t()), opts()) ::
          rpc_response(RegenerateDeployKeyResponse.t())
  def regenerate_deploy_key(request, opts \\ []),
    do:
      request
      |> decorate(RegenerateDeployKeyRequest)
      |> grpc_call(:regenerate_deploy_key, with_default_opts(opts))

  @spec regenerate_webhook(rpc_request(RegenerateWebhookRequest.t()), opts()) ::
          rpc_response(RegenerateWebhookResponse.t())
  def regenerate_webhook(request, opts \\ []),
    do:
      request
      |> decorate(RegenerateWebhookRequest)
      |> grpc_call(:regenerate_webhook, with_default_opts(opts))

  @spec check_deploy_key(rpc_request(CheckDeployKeyRequest.t()), opts()) :: rpc_response(CheckDeployKeyResponse.t())
  def check_deploy_key(request, opts \\ []),
    do:
      request
      |> decorate(CheckDeployKeyRequest)
      |> grpc_call(:check_deploy_key, with_default_opts(opts))

  @spec check_webhook(rpc_request(CheckWebhookRequest.t()), opts()) :: rpc_response(CheckWebhookResponse.t())
  def check_webhook(request, opts \\ []),
    do:
      request
      |> decorate(CheckWebhookRequest)
      |> grpc_call(:check_webhook, with_default_opts(opts))

  @spec delete(rpc_request(DeleteRequest.t()), opts()) :: rpc_response(DeleteResponse.t())
  def delete(request, opts \\ []),
    do:
      request
      |> decorate(DeleteRequest)
      |> grpc_call(:delete, with_default_opts(opts))

  @spec update(rpc_request(UpdateRequest.t()), opts()) :: rpc_response(UpdateResponse.t())
  def update(request, opts \\ []),
    do:
      request
      |> decorate(UpdateRequest)
      |> grpc_call(:update, with_default_opts(opts))

  @spec describe_remote_repository(rpc_request(DescribeRemoteRepositoryRequest.t()), opts()) ::
          rpc_response(DescribeRemoteRepositoryResponse.t())
  def describe_remote_repository(request, opts \\ []),
    do:
      request
      |> decorate(DescribeRemoteRepositoryRequest)
      |> grpc_call(:describe_remote_repository, with_default_opts(opts))

  @spec fork(rpc_request(ForkRequest.t()), opts()) :: rpc_response(ForkResponse.t())
  def fork(request, opts \\ []),
    do:
      request
      |> decorate(ForkRequest)
      |> grpc_call(:fork, with_default_opts(opts))

  defp with_default_opts(current_opts) do
    super(current_opts)
    |> Keyword.merge(timeout: :timer.seconds(30))
    |> Keyword.merge(current_opts)
  end
end
