defmodule InternalClients.Projecthub.RequestFormatter do
  @moduledoc """
  Module formats the request using data received into protobuf
  messages suitable for gRPC communication with Projecthub service.
  """

  alias InternalApi.Projecthub, as: API
  import InternalClients.Common

  def form_request({API.ListKeysetRequest, params}) do
    {:ok,
     %API.ListKeysetRequest{
       metadata: %API.RequestMeta{org_id: from_params!(params, :organization_id)},
       page_token: from_params(params, :page_token, ""),
       direction: String.to_atom(from_params(params, :direction)),
       page_size: from_params(params, :page_size, 30),
       owner_id: from_params(params, :owner_uuid),
       repo_url: from_params(params, :repo_url)
     }}
  end

  def form_request({API.DescribeManyRequest, params}) do
    {:ok,
     %API.DescribeManyRequest{
       metadata: %API.RequestMeta{org_id: from_params!(params, :organization_id)},
       ids: from_params!(params, :project_ids)
     }}
  end

  def form_request({API.DescribeRequest, params}) do
    {:ok,
     %API.DescribeRequest{
       metadata: %API.RequestMeta{org_id: from_params!(params, :organization_id)},
       name: from_params(params, :name),
       id: from_params(params, :id)
     }}
  rescue
    error in ArgumentError ->
      {:error, {:user, error.message}}
  end

  def form_request({API.CreateRequest, params}) do
    {:ok,
     %API.CreateRequest{
       metadata: %API.RequestMeta{
         org_id: from_params!(params, :organization_id),
         user_id: from_params!(params, :user_id)
       },
       project: form_request({API.Project, params})
     }}
  end

  def form_request({API.UpdateRequest, params}) do
    {:ok,
     %API.UpdateRequest{
       metadata: %API.RequestMeta{
         org_id: from_params!(params, :organization_id),
         user_id: from_params!(params, :user_id)
       },
       project: form_request({API.Project, params}),
       omit_schedulers_and_tasks: true
     }}
  end

  def form_request({API.DestroyRequest, params}) do
    {:ok,
     %API.DestroyRequest{
       metadata: %API.RequestMeta{
         org_id: from_params!(params, :organization_id),
         user_id: from_params!(params, :user_id)
       },
       name: from_params(params, :project_name),
       id: from_params(params, :project_id)
     }}
  end

  def form_request({API.Project, params}) do
    %API.Project{
      metadata: project_metadata(params),
      spec: project_spec(params)
    }
  end

  defp project_metadata(params) do
    %API.Project.Metadata{
      name: from_params!(params.spec, :name),
      id: from_params(params.metadata, :id),
      owner_id: from_params!(params, :user_id),
      org_id: from_params!(params, :organization_id),
      description: from_params!(params.spec, :description)
    }
  end

  defp project_spec(params) do
    %API.Project.Spec{
      repository: project_repository(params),
      visibility: String.to_atom(from_params(params.spec, :visibility, "PRIVATE"))
    }
  end

  defp project_repository(params) do
    %API.Project.Spec.Repository{
      url: from_params!(params.spec.repository, :url),
      integration_type: String.to_atom(from_params!(params.spec.repository, :integration_type)),
      forked_pull_requests: repo_forked_pull_requests(params),
      whitelist: %API.Project.Spec.Repository.Whitelist{
        branches: from_params(params.spec.repository, :whitelist_branches, []),
        tags: from_params(params.spec.repository, :whitelist_tags, [])
      },
      run_on: Enum.map(from_params(params.spec.repository, :run_on, []), &String.to_atom/1),
      pipeline_file: from_params(params.spec.repository, :pipeline_file, ""),
      status: repo_status(params)
    }
  end

  defp repo_forked_pull_requests(params) do
    %API.Project.Spec.Repository.ForkedPullRequests{
      allowed_secrets:
        from_params(params.spec.repository.forked_pull_requests, :allowed_secrets, []),
      allowed_contributors:
        from_params(params.spec.repository.forked_pull_requests, :allowed_contributors, [])
    }
  end

  defp repo_status(params) do
    %API.Project.Spec.Repository.Status{
      pipeline_files:
        Enum.map(
          from_params(params.spec.repository.status, :pipeline_files, []),
          &pipeline_file/1
        )
    }
  end

  defp pipeline_file(pipeline_file) do
    %API.Project.Spec.Repository.Status.PipelineFile{
      path: from_params!(pipeline_file, :path),
      level: String.to_atom(from_params!(pipeline_file, :level))
    }
  end
end
