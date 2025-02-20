defmodule InternalClients.Projecthub.ResponseFormatter do
  @moduledoc """
  Module parses the response from Projecthub service and transforms it
  from protobuf messages into more suitable format for internal use or HTTP responses.
  API clients.
  """

  alias InternalApi.Projecthub, as: API
  alias InternalApi.Projecthub.ResponseMeta.Status
  alias PublicAPI.Util.ToTuple

  def process_response(
        {:ok,
         r = %API.ListKeysetResponse{metadata: %API.ResponseMeta{status: %Status{code: :OK}}}}
      ) do
    {:ok, list_from_pb(r)}
  end

  def process_response(
        {:ok, r = %API.DescribeResponse{metadata: %API.ResponseMeta{status: %Status{code: :OK}}}}
      ) do
    {:ok, project_from_pb(r.project)}
  end

  def process_response(
        {:ok,
         r = %API.DescribeManyResponse{metadata: %API.ResponseMeta{status: %Status{code: :OK}}}}
      ) do
    {:ok, Enum.map(r.projects, &project_from_pb/1)}
  end

  def process_response(
        {:ok, r = %API.CreateResponse{metadata: %API.ResponseMeta{status: %Status{code: :OK}}}}
      ) do
    {:ok, project_from_pb(r.project)}
  end

  def process_response(
        {:ok, r = %API.UpdateResponse{metadata: %API.ResponseMeta{status: %Status{code: :OK}}}}
      ) do
    {:ok, project_from_pb(r.project)}
  end

  def process_response(
        {:ok, %API.DestroyResponse{metadata: %API.ResponseMeta{status: %Status{code: :OK}}}}
      ) do
    {:ok, nil}
  end

  def process_response({:ok, r = %{metadata: %{status: %Status{code: :NOT_FOUND}}}}) do
    ToTuple.not_found_error(%{
      message: r.metadata.status.message
    })
  end

  def process_response({:ok, r = %{metadata: %{status: %Status{code: :INVALID_ARGUMENT}}}}) do
    ToTuple.user_error(%{
      message: r.metadata.status.message
    })
  end

  def process_response({:ok, r = %{metadata: %{status: %Status{code: :FAILED_PRECONDITION}}}}) do
    ToTuple.user_error(%{
      message: r.metadata.status.message
    })
  end

  def process_response({:ok, _r = %{metadata: %{status: %Status{code: _other_code}}}}) do
    ToTuple.internal_error(%{
      message: "Unexpected error occurred"
    })
  end

  def process_response(error), do: error

  defp list_from_pb(response = %API.ListKeysetResponse{}) do
    %{
      next_page_token: response.next_page_token,
      prev_page_token: response.previous_page_token,
      entries: Enum.map(response.projects, &project_from_pb/1)
    }
  end

  defp project_from_pb(projects) when is_list(projects) do
    Enum.map(projects, &project_from_pb/1)
  end

  defp project_from_pb(project = %API.Project{}) do
    %{
      apiVersion: "v2",
      kind: "Project",
      metadata: metadata_from_pb(project),
      spec: spec_from_pb(project)
    }
  end

  defp metadata_from_pb(%{metadata: metadata, spec: spec}) do
    %{
      id: metadata.id,
      name: metadata.name,
      description: metadata.description,
      org_id: metadata.org_id,
      created_by: InternalClients.Common.User.from_id(metadata.owner_id),
      connected: spec.repository.connected
    }
  end

  defp spec_from_pb(%{metadata: metadata, spec: spec}) do
    %{
      name: metadata.name,
      description: metadata.description,
      visibility: Atom.to_string(spec.visibility),
      repository: %{
        url: spec.repository.url,
        integration_type: Atom.to_string(spec.repository.integration_type),
        forked_pull_requests: forked_pull_requests_from_pb(spec.repository.forked_pull_requests),
        whitelist: whitelist_from_pb(spec.repository.whitelist),
        run_on: Enum.map(spec.repository.run_on, &Atom.to_string/1),
        pipeline_file: spec.repository.pipeline_file,
        status: %{
          pipeline_files:
            Enum.map(spec.repository.status.pipeline_files, &pipeline_file_from_pb/1)
        }
      }
    }
  end

  defp whitelist_from_pb(nil), do: %{branches: [], tags: []}

  defp whitelist_from_pb(whitelist) do
    %{
      branches: whitelist.branches || [],
      tags: whitelist.tags || []
    }
  end

  defp forked_pull_requests_from_pb(nil), do: %{allowed_secrets: [], allowed_contributors: []}

  defp forked_pull_requests_from_pb(forked_pull_requests) do
    %{
      allowed_secrets: Map.get(forked_pull_requests, :allowed_secrets, []),
      allowed_contributors: Map.get(forked_pull_requests, :allowed_contributors, [])
    }
  end

  defp pipeline_file_from_pb(pipeline_file) do
    %{
      path: pipeline_file.path,
      level: Atom.to_string(pipeline_file.level)
    }
  end
end
