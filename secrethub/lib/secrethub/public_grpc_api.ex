defmodule Secrethub.PublicGrpcApi do
  require Logger

  use GRPC.Server, service: Semaphore.Secrets.V1beta.SecretsApi.Service
  use Sentry.Grpc, service: Semaphore.Secrets.V1beta.SecretsApi.Service

  alias Semaphore.Secrets.V1beta.{
    Empty,
    ListSecretsResponse,
    Secret
  }

  alias Secrethub.{Auth, Audit}

  def list_secrets(req, call) do
    alias Secrethub.PublicGrpcApi.ListSecrets, as: LS

    {org_id, user_id} = extract_headers(call)

    Logger.info("Listing #{inspect(org_id)} #{inspect(user_id)} #{inspect(req)}")

    with {:ok, page_size} <- LS.extract_page_size(req),
         {:ok, :authorized} <- Auth.can_manage?(org_id, user_id),
         {:ok, secrets, next_page_token} <-
           LS.query(org_id, "", page_size, req.order, req.page_token, false) do
      ListSecretsResponse.new(
        secrets: Enum.map(secrets, &serialize(&1, org_id)),
        next_page_token: next_page_token
      )
    else
      {:error, :permission_denied} ->
        raise GRPC.RPCError,
          status: :permission_denied,
          message: "Can't list secrets in organization"

      {:error, :precondition_failed, message} ->
        raise GRPC.RPCError, status: :invalid_argument, message: message
    end
  end

  def get_secret(req, call) do
    {org_id, user_id} = call |> extract_headers

    Logger.info("Get Secrets #{org_id} #{user_id} #{req.secret_id_or_name}")

    id_or_name = req.secret_id_or_name

    with {:ok, secret} <- Secrethub.Secret.find_by_id_or_name(org_id, id_or_name),
         {:ok, :authorized} <- Auth.can_manage?(org_id, user_id) do
      serialize(secret, org_id)
    else
      {:error, reason} when reason in [:not_found, :permission_denied] ->
        raise GRPC.RPCError, status: :not_found, message: "Secret #{id_or_name} not found"

      {:error, :unknown, message} ->
        raise GRPC.RPCError, status: :unknown, message: message
    end
  end

  def create_secret(secret, call) do
    {org_id, user_id} = call |> extract_headers

    name = secret.metadata.name
    content = Secrethub.Utils.to_map_with_string_keys(secret)

    org_config = Map.get(secret, :org_config)

    can_manage_policy? = Auth.can_manage_settings?(org_id, user_id)

    permissions =
      org_config
      |> filter_on_feature_flag(org_id)
      |> filter_on_user_permissions(can_manage_policy?)
      |> Secrethub.Utils.permissions_from_org_config()

    with {:ok, :authorized} <- Auth.can_manage?(org_id, user_id),
         {:ok, secret} <- Secrethub.Secret.save(org_id, user_id, name, "", content, permissions) do
      call
      |> Audit.new(:Secret, :Added)
      |> Audit.add(description: "Added secret #{secret.name}")
      |> Audit.add(resource_name: secret.name)
      |> Audit.add(:resource_id, secret.id)
      |> Audit.log()

      serialize(secret, org_id)
    else
      {:error, :permission_denied} ->
        raise GRPC.RPCError,
          status: :permission_denied,
          message: "You are not authorized to create secrets"

      {:error, :failed_precondition, message} ->
        raise GRPC.RPCError, status: :invalid_argument, message: message

      {:error, :unknown, message} ->
        raise GRPC.RPCError, status: :unknown, message: message
    end
  end

  def update_secret(req, call) do
    {org_id, user_id} = call |> extract_headers

    updateable? = FeatureProvider.feature_enabled?(:secrets_exposed_content, param: org_id)

    id_or_name = req.secret_id_or_name

    new_name = req.secret.metadata.name
    new_content = Secrethub.Utils.to_map_with_string_keys(req.secret)

    org_config = Map.get(req.secret, :org_config)

    can_manage_policy? = Auth.can_manage_settings?(org_id, user_id)

    permissions =
      org_config
      |> filter_on_feature_flag(org_id)
      |> filter_on_user_permissions(can_manage_policy?)

    Logger.info("Update Secrets #{org_id} #{user_id} #{id_or_name}")

    with {:updateable?, true} <- {:updateable?, updateable?},
         {:ok, secret} <- Secrethub.Secret.find_by_id_or_name(org_id, id_or_name),
         {:ok, :authorized} <- Auth.can_manage?(org_id, user_id),
         consolidated_org_config <- Secrethub.Utils.consolidate_org_configs(permissions, secret),
         {:ok, new_secret} <-
           Secrethub.Secret.update(
             org_id,
             user_id,
             secret,
             Map.merge(
               %{
                 name: new_name,
                 content: new_content
               },
               consolidated_org_config
             )
           ) do
      call
      |> Audit.new(:Secret, :Modified)
      |> Audit.add(description: "Updated secret #{secret.name}")
      |> Audit.add(resource_name: secret.name)
      |> Audit.add(:resource_id, secret.id)
      |> Audit.log()

      serialize(new_secret, org_id)
    else
      {:updateable?, false} ->
        raise GRPC.RPCError,
          status: :failed_precondition,
          message: "Secret can not be updated with API"

      {:error, :failed_precondition, message} ->
        raise GRPC.RPCError, status: :invalid_argument, message: message

      {:error, :permission_denied} ->
        raise GRPC.RPCError, status: :not_found, message: "Secret #{id_or_name} not found"

      {:error, :not_found} ->
        raise GRPC.RPCError, status: :not_found, message: "Secret #{id_or_name} not found"

      {:error, :unknown, message} ->
        raise GRPC.RPCError, status: :unknown, message: message
    end
  end

  def delete_secret(req, call) do
    {org_id, user_id} = call |> extract_headers

    id_or_name = req.secret_id_or_name

    Logger.info("Delete Secrets #{org_id} #{user_id} #{id_or_name}")

    with {:ok, secret} <- Secrethub.Secret.find_by_id_or_name(org_id, id_or_name),
         {:ok, :authorized} <- Auth.can_manage?(org_id, user_id),
         {:ok, _} <- Secrethub.Secret.delete(secret) do
      call
      |> Audit.new(:Secret, :Removed)
      |> Audit.add(description: "Deleted secret #{secret.name}")
      |> Audit.add(resource_name: secret.name)
      |> Audit.add(:resource_id, secret.id)
      |> Audit.log()

      Empty.new()
    else
      {:error, :failed_precondition, message} ->
        raise GRPC.RPCError, status: :invalid_argument, message: message

      {:error, :permission_denied} ->
        raise GRPC.RPCError, status: :not_found, message: "Secret #{id_or_name} not found"

      {:error, :not_found} ->
        raise GRPC.RPCError, status: :not_found, message: "Secret #{id_or_name} not found"

      {:error, :unknown, message} ->
        raise GRPC.RPCError, status: :unknown, message: message
    end
  end

  defp extract_headers(call) do
    call
    |> GRPC.Stream.get_headers()
    |> Map.take(["x-semaphore-org-id", "x-semaphore-user-id"])
    |> Map.values()
    |> List.to_tuple()
  end

  def serialize(secret, org_id) do
    alias Semaphore.Secrets.V1beta.Secret

    org_config = maybe_serialize_org_config(secret, org_id)
    render_content = FeatureProvider.feature_enabled?(:secrets_exposed_content, param: org_id)
    content = secret.content

    Secret.new(
      metadata:
        Secret.Metadata.new(
          id: secret.id,
          name: secret.name,
          create_time: unix_timestamp(secret.inserted_at),
          update_time: unix_timestamp(secret.updated_at),
          checkout_at: unix_timestamp(secret.used_at),
          content_included: render_content
        ),
      data: serialize_data(content, render_content),
      org_config: org_config
    )
  end

  defp serialize_data(%{env_vars: env_vars, files: files}, render_content) do
    render = _serialize_data_content_render(render_content)
    alias Semaphore.Secrets.V1beta.Secret

    Secret.Data.new(
      env_vars:
        Enum.map(env_vars || [], fn e ->
          Secret.EnvVar.new(
            name: e.name || "",
            value: render.(e.value)
          )
        end),
      files:
        Enum.map(files || [], fn f ->
          Secret.File.new(
            path: f.path || "",
            content: render.(f.content)
          )
        end)
    )
  end

  defp _serialize_data_content_render(true), do: fn content -> content || "" end

  defp _serialize_data_content_render(false), do: fn _content -> "" end

  defp maybe_serialize_org_config(secret, org_id) do
    if FeatureProvider.feature_enabled?(:secrets_access_policy, param: org_id) do
      serialize_org_config(secret, org_id)
    else
      nil
    end
  end

  defp serialize_org_config(secret, _org_id) do
    alias Semaphore.Secrets.V1beta.Secret

    secret
    |> Map.take(~w(all_projects project_ids job_debug job_attach)a)
    |> Secrethub.Utils.to_org_config_params()
    |> Secret.OrgConfig.new()
  end

  defp filter_on_feature_flag(nil, _org_id), do: nil

  defp filter_on_feature_flag(secret, org_id) do
    if FeatureProvider.feature_enabled?(:secrets_access_policy, param: org_id) do
      secret
      |> Map.take(~w(projects_access project_ids debug_access attach_access)a)
    else
      nil
    end
  end

  defp filter_on_user_permissions(nil, _user_id), do: nil

  defp filter_on_user_permissions(org_config, {:ok, :authorized}) do
    org_config
  end

  defp filter_on_user_permissions(_org_config, {:error, :permission_denied}) do
    nil
  end

  defp unix_timestamp(nil), do: nil

  defp unix_timestamp(ecto_time) do
    ecto_time |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()
  end
end
