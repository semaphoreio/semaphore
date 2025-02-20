defmodule InternalClients.Secrets.RequestFormatter do
  @moduledoc """
  Module serves to format data received from API client via HTTP into
  protobuf messages suitable for gRPC communication with Secrethub service.
  """

  alias InternalApi.Secrethub, as: API
  import InternalClients.Common

  # List keyset

  def form_request({API.ListKeysetRequest, params}) do
    {:ok,
     %API.ListKeysetRequest{
       metadata: metadata(params),
       page_size: from_params(params, :page_size),
       page_token: from_params(params, :page_token),
       order: String.to_atom(from_params(params, :order)),
       secret_level: from_params!(params, :secret_level),
       project_id: from_params(params, :project_id)
     }}
  rescue
    error in ArgumentError ->
      {:error, {:user, error.message}}
  end

  def form_request({API.DescribeRequest, params}) do
    {:ok,
     %API.DescribeRequest{
       metadata: metadata(params),
       id: from_params(params, :id),
       name: from_params(params, :name),
       secret_level: from_params!(params, :secret_level),
       project_id: from_params(params, :project_id),
       deployment_target_id: from_params(params, :deployment_target_id)
     }}
  end

  def form_request({API.DestroyRequest, params}) do
    {:ok,
     %API.DestroyRequest{
       metadata: metadata(params),
       id: from_params(params, :id),
       name: from_params(params, :name),
       secret_level: from_params!(params, :secret_level),
       project_id: from_params(params, :project_id)
     }}
  end

  def form_request({API.CreateRequest, params}) do
    {:ok,
     %API.CreateRequest{
       metadata: metadata(params),
       secret: form_request({API.Secret, params})
     }}
  end

  def form_request({API.UpdateRequest, params}) do
    {:ok,
     %API.UpdateRequest{
       metadata: metadata(params),
       secret: form_request({API.Secret, params})
     }}
  end

  def form_request({API.GetKeyRequest, _}) do
    {:ok, %API.GetKeyRequest{}}
  end

  def form_request({API.Secret, params}) do
    %API.Secret{
      metadata: secret_metadata(params),
      data: secret_data(params.spec.data),
      org_config: Map.get(params, :access_config) |> secret_org_config(),
      project_config: secret_project_config(params)
    }
  end

  defp metadata(params) do
    %API.RequestMeta{
      user_id: from_params!(params, :user_id),
      org_id: from_params!(params, :organization_id)
    }
  end

  defp secret_metadata(params) do
    %API.Secret.Metadata{
      id: from_params(params, :id),
      name: from_params!(params.spec, :name),
      org_id: from_params!(params, :organization_id),
      level: from_params!(params, :secret_level),
      created_by: from_params!(params, :user_id),
      updated_by: from_params!(params, :user_id),
      description: from_params(params.spec, :description)
    }
  end

  defp secret_data(data) do
    %API.Secret.Data{
      env_vars: env_vars(data.env_vars),
      files: files(data.files)
    }
  end

  defp secret_org_config(nil), do: nil

  defp secret_org_config(params) do
    %API.Secret.OrgConfig{
      projects_access: String.to_existing_atom(from_params(params, :project_access, "ALL")),
      project_ids: from_params(params, :project_ids),
      debug_access: :"JOB_DEBUG_#{from_params(params, :debug_access, "YES")}",
      attach_access: :"JOB_ATTACH_#{from_params(params, :attach_access, "YES")}"
    }
  end

  defp secret_project_config(params) do
    %API.Secret.ProjectConfig{
      project_id: from_params(params, :project_id)
    }
  end

  defp env_vars(params), do: Enum.map(params, &env_var/1)
  defp files(files), do: Enum.map(files, &file/1)

  defp env_var(%{name: name, value: value}), do: %API.Secret.EnvVar{name: name, value: value}
  defp file(%{path: path, content: content}), do: %API.Secret.File{path: path, content: content}
end
