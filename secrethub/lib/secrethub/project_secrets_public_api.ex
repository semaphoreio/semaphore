defmodule Secrethub.ProjectSecretsPublicApi do
  require Logger

  use GRPC.Server, service: Semaphore.ProjectSecrets.V1.ProjectSecretsApi.Service
  use Sentry.Grpc, service: Semaphore.ProjectSecrets.V1.ProjectSecretsApi.Service

  alias Secrethub.ProjectSecrets.PublicAPIActions, as: Actions
  alias Secrethub.Auth
  alias Semaphore.ProjectSecrets.V1, as: API
  alias Secrethub.Audit

  def list_secrets(req, call) do
    {org_id, user_id} = call |> extract_headers
    project_id = req.project_id_or_name

    Logger.info("Listing project secrets #{inspect(org_id)} #{inspect(user_id)} #{inspect(req)}")

    with {:ok, :enabled} <- filter_on_feature_flag(org_id),
         {:ok, project_id} <- ensure_project_id(project_id, meta(call)),
         {:ok, :authorized} <- Auth.can_manage?(org_id, user_id, project_id),
         {:ok, req} <- ensure_req_project_id(req, project_id) do
      Actions.list_secrets(req, meta(call))
    else
      {:error, :permission_denied} ->
        raise GRPC.RPCError,
          status: :permission_denied,
          message: "User is not authorized to perform this operation"

      {:error, :not_enabled} ->
        raise GRPC.RPCError,
          status: :failed_precondition,
          message: "Project level secrets are not enabled for this organization"
    end
  end

  def get_secret(req, call) do
    {org_id, user_id} = call |> extract_headers
    project_id = req.project_id_or_name

    Logger.info("Get project secret #{org_id} #{user_id} #{project_id} #{req.secret_id_or_name}")

    with {:ok, :enabled} <- filter_on_feature_flag(org_id),
         {:ok, project_id} <- ensure_project_id(project_id, meta(call)),
         {:ok, :authorized} <- Auth.can_manage?(org_id, user_id, project_id),
         {:ok, req} <- ensure_req_project_id(req, project_id) do
      Actions.get_secret(req, meta(call))
    else
      {:error, :permission_denied} ->
        raise GRPC.RPCError,
          status: :permission_denied,
          message: "User is not authorized to perform this operation"

      {:error, :not_enabled} ->
        raise GRPC.RPCError,
          status: :failed_precondition,
          message: "Project level secrets are not enabled for this organization"
    end
  end

  def create_secret(secret, call) do
    {org_id, user_id} = call |> extract_headers
    project_id = secret.metadata && secret.metadata.project_id_or_name

    with {:ok, :enabled} <- filter_on_feature_flag(org_id),
         {:ok, project_id} <- ensure_project_id(project_id, meta(call)),
         {:ok, :authorized} <- Auth.can_manage?(org_id, user_id, project_id),
         {:ok, secret} <- ensure_req_project_id(secret, project_id) do
      resp = Actions.create_secret(secret, meta(call))

      call
      |> Audit.new(:Secret, :Added)
      |> Audit.add(
        description: "Added secret #{secret.metadata.name} to the project #{project_id}"
      )
      |> Audit.add(resource_name: secret.metadata.name)
      |> Audit.add(:resource_id, resp.metadata.id)
      |> Audit.log()

      resp
    else
      {:error, :permission_denied} ->
        raise GRPC.RPCError,
          status: :permission_denied,
          message: "User is not authorized to perform this operation"

      {:error, :not_enabled} ->
        raise GRPC.RPCError,
          status: :failed_precondition,
          message: "Project level secrets are not enabled for this organization"
    end
  end

  def update_secret(req, call) do
    {org_id, user_id} = call |> extract_headers
    project_id = req.project_id_or_name

    Logger.info("Update Secrets #{org_id} #{user_id} #{req.secret_id_or_name}")

    with {:ok, :enabled} <- filter_on_feature_flag(org_id),
         {:ok, project_id} <- ensure_project_id(project_id, meta(call)),
         {:ok, :authorized} <- Auth.can_manage?(org_id, user_id, project_id),
         {:ok, req} <- ensure_req_project_id(req, project_id) do
      resp = Actions.update_secret(req, meta(call))

      call
      |> Audit.new(:Secret, :Modified)
      |> Audit.add(
        description: "Modified secret #{req.secret_id_or_name} in the project: #{project_id}"
      )
      |> Audit.add(resource_name: resp.metadata.name)
      |> Audit.add(:resource_id, resp.metadata.id)
      |> Audit.log()

      resp
    else
      {:error, :permission_denied} ->
        raise GRPC.RPCError,
          status: :permission_denied,
          message: "User is not authorized to perform this operation"

      {:error, :not_enabled} ->
        raise GRPC.RPCError,
          status: :failed_precondition,
          message: "Project level secrets are not enabled for this organization"
    end
  end

  def delete_secret(req, call) do
    {org_id, user_id} = call |> extract_headers
    project_id = req.project_id_or_name

    id_or_name = req.secret_id_or_name

    Logger.info("Delete Secrets #{org_id} #{user_id} #{id_or_name}")

    with {:ok, :enabled} <- filter_on_feature_flag(org_id),
         {:ok, project_id} <- ensure_project_id(project_id, meta(call)),
         {:ok, :authorized} <- Auth.can_manage?(org_id, user_id, project_id),
         {:ok, req} <- ensure_req_project_id(req, project_id) do
      resp = Actions.delete_secret(req, meta(call))

      call
      |> Audit.new(:Secret, :Removed)
      |> Audit.add(
        description: "Deleted secret #{req.secret_id_or_name} in the project: #{project_id}"
      )
      |> Audit.add(resource_name: req.secret_id_or_name)
      |> Audit.log()

      resp
    else
      {:error, :permission_denied} ->
        raise GRPC.RPCError,
          status: :permission_denied,
          message: "User is not authorized to perform this operation"

      {:error, :not_enabled} ->
        raise GRPC.RPCError,
          status: :failed_precondition,
          message: "Project level secrets are not enabled for this organization"
    end
  end

  defp extract_headers(call) do
    call
    |> GRPC.Stream.get_headers()
    |> Map.take(["x-semaphore-org-id", "x-semaphore-user-id"])
    |> Map.values()
    |> List.to_tuple()
  end

  defp meta(call) do
    {org_id, user_id} = extract_headers(call)
    render_content = FeatureProvider.feature_enabled?(:secrets_exposed_content, param: org_id)

    %{org_id: org_id, user_id: user_id, render_content: render_content}
  end

  defp filter_on_feature_flag(""), do: {:error, :not_enabled}

  defp filter_on_feature_flag(org_id) do
    if FeatureProvider.feature_enabled?(:project_level_secrets, param: org_id) do
      {:ok, :enabled}
    else
      {:error, :not_enabled}
    end
  end

  defp uuid?(string) do
    case Ecto.UUID.cast(string) do
      {:ok, _} -> true
      _ -> false
    end
  end

  defp ensure_project_id("", _params), do: {:error, :project_not_found}

  defp ensure_project_id(project_id_or_name, %{org_id: org_id, user_id: user_id}) do
    case uuid?(project_id_or_name) do
      true -> {:ok, project_id_or_name}
      false -> find_project_id_by_name(project_id_or_name, org_id, user_id)
    end
  end

  defp find_project_id_by_name(project_name, org_id, user_id) do
    case Secrethub.ProjecthubClient.find_by_name(project_name, org_id, user_id) do
      {:ok, project} -> {:ok, project.id}
      {:error, :not_found} -> {:error, :project_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp ensure_req_project_id(req = %API.Secret{}, project_id) do
    {:ok, %{req | metadata: %{req.metadata | project_id_or_name: project_id}}}
  end

  defp ensure_req_project_id(req, project_id) do
    {:ok, %{req | project_id_or_name: project_id}}
  end
end
