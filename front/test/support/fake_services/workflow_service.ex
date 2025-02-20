defmodule Support.FakeServices.WorkflowService do
  use GRPC.Server, service: InternalApi.PlumberWF.WorkflowService.Service

  def list(req, stream) do
    FunRegistry.run!(__MODULE__, :list, [req, stream])
  end

  def list_keyset(req, stream) do
    FunRegistry.run!(__MODULE__, :list_keyset, [req, stream])
  end

  def list_grouped_ks(req, stream) do
    FunRegistry.run!(__MODULE__, :list_grouped_ks, [req, stream])
  end

  def list_latest_workflows(req, stream) do
    FunRegistry.run!(__MODULE__, :list_latest_workflows, [req, stream])
  end

  def list_grouped(req, stream) do
    FunRegistry.run!(__MODULE__, :list_grouped, [req, stream])
  end

  def get_path(req, stream) do
    FunRegistry.run!(__MODULE__, :get_path, [req, stream])
  end

  def describe(req, stream) do
    FunRegistry.run!(__MODULE__, :describe, [req, stream])
  end

  def reschedule(req, stream) do
    FunRegistry.run!(__MODULE__, :reschedule, [req, stream])
  end
end
