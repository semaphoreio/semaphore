defmodule Support.FakeServices.RepositoryService do
  @moduledoc false

  alias InternalApi.Repository
  alias Support.MemoryDb

  use GRPC.Server, service: InternalApi.Repository.RepositoryService.Service

  def list(request, _stream) do
    repositories =
      MemoryDb.all({:repository_hub, :repositories})
      |> Enum.filter(fn record ->
        record.repository.project_id == request.project_id
      end)
      |> Enum.map(& &1.repository)

    Repository.ListResponse.new(repositories: repositories)
  end

  def fail(action, repository_id, error \\ nil) do
    MemoryDb.add({:repository_hub, :fails}, %{
      action: action,
      repository_id: repository_id,
      error: error
    })
  end

  def create(request, _stream) do
    id = Ecto.UUID.generate()

    repository = new_repository(request)

    record =
      MemoryDb.add({:repository_hub, :repositories}, %{
        id: id,
        repository: repository
      })

    Repository.CreateResponse.new(repository: record.repository)
  end

  def describe(request, _stream) do
    record =
      MemoryDb.find({:repository_hub, :repositories}, fn repository ->
        repository.project_id == request.project_id
      end)

    Repository.CreateResponse.new(repository: record.repository)
  end

  def regenerate_webhook(request, _stream) do
    MemoryDb.find({:repository_hub, :fails}, fn fail ->
      fail.action == :regenerate_webhook && fail.repository_id == request.repository_id
    end)
    |> case do
      nil ->
        webhook = new_webhook(request)

        record =
          MemoryDb.add({:repository_hub, :webhooks}, %{
            id: request.repository_id,
            webhook: webhook
          })

        Repository.CheckWebhookResponse.new(webhook: record.webhook)

      %{error: nil} ->
        raise GRPC.RPCError, status: GRPC.Status.failed_precondition(), message: "Error"

      %{error: error} ->
        raise GRPC.RPCError, status: error.status, message: error.message
    end
  end

  def check_webhook(request, _stream) do
    MemoryDb.find({:repository_hub, :webhooks}, fn webhook ->
      webhook.id == request.repository_id
    end)
    |> case do
      %{webhook: webhook} ->
        Repository.CheckWebhookResponse.new(webhook: webhook)

      _ ->
        raise GRPC.RPCError, status: GRPC.Status.not_found(), message: "not found"
    end
  end

  def regenerate_deploy_key(request, _stream) do
    deploy_key = new_deploy_key(request)

    record =
      MemoryDb.add({:repository_hub, :deploy_keys}, %{
        id: request.repository_id,
        deploy_key: deploy_key
      })

    Repository.CheckWebhookResponse.new(deploy_key: record.deploy_key)
  end

  def check_deploy_key(request, _stream) do
    MemoryDb.find({:repository_hub, :deploy_keys}, fn deploy_key ->
      deploy_key.id == request.repository_id
    end)
    |> case do
      %{deploy_key: deploy_key} ->
        Repository.CheckDeployKeyResponse.new(deploy_key: deploy_key)

      _ ->
        raise GRPC.RPCError, status: GRPC.Status.not_found(), message: "not found"
    end
  end

  def describe_many(request, _stream) do
    project_ids = request.project_ids
    repository_ids = request.repository_ids

    repositories =
      MemoryDb.all({:repository_hub, :repositories})
      |> Enum.filter(fn record ->
        record.repository.project_id in project_ids or
          record.repository.id in repository_ids
      end)
      |> Enum.map(& &1.repository)

    Repository.DescribeManyResponse.new(repositories: repositories)
  end

  def update(request, _stream) do
    record =
      MemoryDb.find({:repository_hub, :repositories}, fn record ->
        record.repository.id == request.repository_id
      end)

    Repository.UpdateResponse.new(repository: record.repository)
  end

  def get_files(req, stream) do
    FunRegistry.run!(Support.FakeServices.Repohub, :get_files, [req, stream])
  end

  @spec new_repository(Repository.CreateRequest.t()) :: Repository.Repository.t()
  defp new_repository(%Repository.CreateRequest{} = request) do
    id = Ecto.UUID.generate()

    Repository.Repository.new(%{
      id: id,
      name: "project-#{id}",
      owner: "owner",
      provider:
        request.integration_type
        |> Atom.to_string()
        |> String.downcase(),
      url: request.repository_url,
      project_id: request.project_id,
      pipeline_file: request.pipeline_file,
      whitelist: request.whitelist,
      commit_status: request.commit_status,
      private: false
    })
  end

  defp new_deploy_key(request) do
    Repository.DeployKey.new(%{
      title: "repository-#{request.repository_id}-key",
      fingerprint: "exaple_fingerprint",
      created_at: proto_now()
    })
  end

  defp new_webhook(request) do
    Repository.Webhook.new(%{
      url: "https://example/project/repository-#{request.repository_id}-hook"
    })
  end

  def proto_now do
    Google.Protobuf.Timestamp.new(seconds: DateTime.to_unix(DateTime.utc_now()))
  end
end
