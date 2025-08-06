defmodule Notifications.Workers.Coordinator.Api do
  def find_hook(hook_id) do
    alias InternalApi.RepoProxy.RepoProxyService.Stub
    alias InternalApi.RepoProxy.DescribeRequest

    req = DescribeRequest.new(hook_id: hook_id)
    endpoint = Application.fetch_env!(:notifications, :repo_proxy_endpoint)
    {:ok, channel} = GRPC.Stub.connect(endpoint)

    {:ok, res} = Stub.describe(channel, req, timeout: 30_000)

    if res.status.code == :OK do
      res.hook
    else
      nil
    end
  end

  def find_project(project_id) do
    alias InternalApi.Projecthub
    alias Projecthub.ProjectService.Stub

    meta = Projecthub.RequestMeta.new()
    req = Projecthub.DescribeRequest.new(metadata: meta, id: project_id)

    endpoint = Application.fetch_env!(:notifications, :projecthub_endpoint)
    {:ok, channel} = GRPC.Stub.connect(endpoint)

    {:ok, res} = Stub.describe(channel, req, timeout: 30_000)

    case res.metadata.status.code do
      :OK -> res.project
      _ -> nil
    end
  end

  def find_pipeline(pipeline_id) do
    alias InternalApi.Plumber.PipelineService.Stub

    req = InternalApi.Plumber.DescribeRequest.new(ppl_id: pipeline_id, detailed: true)
    endpoint = Application.get_env(:notifications, :pipeline_endpoint)
    {:ok, channel} = GRPC.Stub.connect(endpoint)

    {:ok, res} = Stub.describe(channel, req, timeout: 30_000)

    case res.response_status.code do
      :OK -> {res.pipeline, res.blocks}
      :BAD_PARAM -> nil
    end
  end

  def find_workflow(workflow_id) do
    alias InternalApi.PlumberWF.WorkflowService.Stub

    req = InternalApi.PlumberWF.DescribeRequest.new(wf_id: workflow_id)

    endpoint = Application.get_env(:notifications, :workflow_endpoint)
    {:ok, channel} = GRPC.Stub.connect(endpoint)

    {:ok, res} = Stub.describe(channel, req, timeout: 30_000)

    case res.status.code do
      :OK -> res.workflow
      _ -> nil
    end
  end

  def find_organization(id) do
    alias InternalApi.Organization.OrganizationService.Stub

    req = InternalApi.Organization.DescribeRequest.new(org_id: id)

    endpoint = Application.get_env(:notifications, :organization_endpoint)
    {:ok, channel} = GRPC.Stub.connect(endpoint)

    {:ok, res} = Stub.describe(channel, req, timeout: 30_000)

    case res.status.code do
      :OK -> res.organization
      :BAD_PARAM -> nil
    end
  end
end
