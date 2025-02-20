defmodule InternalClients.Secrets.ResponseFormatter do
  @moduledoc """
  Module parses the response from Secrethub service
  """
  alias InternalApi.Secrethub, as: API

  def process_response(
        {:ok,
         r = %API.ListKeysetResponse{
           metadata: %API.ResponseMeta{status: %API.ResponseMeta.Status{code: :OK}}
         }}
      ) do
    {:ok, list_from_pb(r)}
  end

  def process_response(
        {:ok,
         r = %API.DescribeResponse{
           metadata: %API.ResponseMeta{status: %API.ResponseMeta.Status{code: :OK}}
         }}
      ) do
    {:ok, secret_from_pb(r.secret)}
  end

  def process_response(
        {:ok,
         %API.DescribeResponse{
           metadata: %API.ResponseMeta{status: %API.ResponseMeta.Status{code: :NOT_FOUND}}
         }}
      ) do
    {:error, {:not_found, "Secret not found"}}
  end

  def process_response(
        {:ok,
         r = %API.DestroyResponse{
           metadata: %API.ResponseMeta{status: %API.ResponseMeta.Status{code: :OK}}
         }}
      ) do
    {:ok, %{secret_id: r.id}}
  end

  def process_response(
        {:ok,
         %API.DestroyResponse{
           metadata: %API.ResponseMeta{status: %API.ResponseMeta.Status{code: :NOT_FOUND}}
         }}
      ) do
    {:error, {:not_found, "Secret not found"}}
  end

  def process_response(
        {:ok,
         r = %API.CreateResponse{
           metadata: %API.ResponseMeta{status: %API.ResponseMeta.Status{code: :OK}}
         }}
      ) do
    {:ok, secret_from_pb(r.secret)}
  end

  def process_response(
        {:ok,
         %API.CreateResponse{
           metadata: %API.ResponseMeta{
             status: %API.ResponseMeta.Status{code: :FAILED_PRECONDITION, message: msg}
           }
         }}
      ) do
    {:error, {:user, msg}}
  end

  def process_response(
        {:ok,
         r = %API.UpdateResponse{
           metadata: %API.ResponseMeta{status: %API.ResponseMeta.Status{code: :OK}}
         }}
      ) do
    {:ok, secret_from_pb(r.secret)}
  end

  def process_response(
        {:ok,
         %API.UpdateResponse{
           metadata: %API.ResponseMeta{
             status: %API.ResponseMeta.Status{code: :FAILED_PRECONDITION, message: msg}
           }
         }}
      ) do
    {:error, {:user, msg}}
  end

  def process_response(
        {:ok,
         %API.UpdateResponse{
           metadata: %API.ResponseMeta{status: %API.ResponseMeta.Status{code: :NOT_FOUND}}
         }}
      ) do
    {:error, {:not_found, "Secret you are trying to update was not found"}}
  end

  def process_response({:ok, %API.GetKeyResponse{id: id, key: key}}) do
    {:ok, %{id: id, key: key}}
  end

  def process_response({:error, {:user, message}}), do: {:error, {:user, message}}
  def process_response({:error, error}), do: {:error, {:internal, error}}

  defp list_from_pb(response = %API.ListKeysetResponse{}) do
    %{
      next_page_token: response.next_page_token,
      entries: Enum.map(response.secrets, &secret_from_pb/1)
    }
  end

  defp secret_from_pb(secret = %API.Secret{}) do
    %{
      apiVersion: "v2",
      kind: kind(secret.metadata.level),
      metadata: secret_metadata_from_pb(secret.metadata) |> maybe_meta(secret),
      spec: secret_spec_from_pb(secret)
    }
  end

  defp kind(level) do
    case level do
      :ORGANIZATION -> "Secret"
      :PROJECT -> "ProjectSecret"
      :DEPLOYMENT_TARGET -> "DeploymentTargetSecret"
    end
  end

  defp secret_metadata_from_pb(metadata = %API.Secret.Metadata{}) do
    %{
      id: metadata.id,
      org_id: metadata.org_id,
      name: metadata.name,
      created_at: PublicAPI.Util.Timestamps.to_timestamp(metadata.created_at),
      updated_at: PublicAPI.Util.Timestamps.to_timestamp(metadata.updated_at),
      last_used_at: PublicAPI.Util.Timestamps.to_timestamp(metadata.checkout_at),
      created_by: InternalClients.Common.User.from_id(metadata.created_by),
      updated_by: InternalClients.Common.User.from_id(metadata.updated_by),
      description: metadata.description,
      last_used_by:
        metadata.last_checkout &&
          OpenApiSpex.Cast.cast(
            PublicAPI.Schemas.Secrets.Checkout.schema(),
            metadata.last_checkout
          )
    }
  end

  defp maybe_meta(metadata, %API.Secret{metadata: %{level: :ORGANIZATION}}), do: metadata

  defp maybe_meta(metadata, secret = %API.Secret{metadata: %{level: :DEPLOYMENT_TARGET}}),
    do: Map.put(metadata, :project_id, secret.dt_config.deployment_target_id)

  defp maybe_meta(metadata, secret = %API.Secret{metadata: %{level: :PROJECT}}),
    do: Map.put(metadata, :project_id, secret.project_config.project_id)

  defp secret_spec_from_pb(secret = %API.Secret{}) do
    %{
      name: secret.metadata.name,
      description: secret.metadata.description,
      data: %{
        env_vars: Enum.map(secret.data.env_vars, &env_var_from_pb/1),
        files: Enum.map(secret.data.files, &file_from_pb/1)
      },
      access_config: access_config(secret.org_config)
    }
  end

  defp access_config(nil), do: %{}

  defp access_config(org_config) do
    %{
      project_access: project_access_from_pb(org_config.projects_access),
      project_ids: org_config.project_ids,
      debug_access: from_enum(org_config.debug_access),
      attach_access: from_enum(org_config.attach_access)
    }
  end

  defp env_var_from_pb(env_var = %API.Secret.EnvVar{}) do
    %{
      name: env_var.name,
      value: value_md5(env_var.value)
    }
  end

  defp file_from_pb(file = %API.Secret.File{}) do
    %{path: file.path, content: value_md5(file.content)}
  end

  defp value_md5(value) do
    :erlang.md5(value)
    |> Base.encode64()
  end

  defp project_access_from_pb(enum) do
    enum
    |> case do
      :ALL -> "ALL"
      :ALLOWED -> "SELECTED"
      :NONE -> "NONE"
    end
  end

  defp from_enum(enum) when enum in [:JOB_DEBUG_YES, :JOB_ATTACH_YES], do: "YES"
  defp from_enum(_enum), do: "NO"
end
