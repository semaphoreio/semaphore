defmodule PipelinesAPI.Workflows.Schedule do
  @moduledoc """
  Module is responsible for creating workflows by creating hook on RepoProxy
  service that will trigger a workflow on Plumber
  """

  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.Pipelines.Common
  alias PipelinesAPI.WorkflowClient
  alias PipelinesAPI.ProjectClient
  alias Plug.Conn

  use Plug.Builder

  import PipelinesAPI.Workflows.WfAuthorize, only: [wf_authorize_create: 2]

  plug(:wf_authorize_create)
  plug(:schedule)

  def schedule(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["wf_schedule"], fn ->
      case find_repository(conn) do
        {:ok, params} ->
          params
          |> add_requester_id(conn)
          |> add_organization_id(conn)
          |> WorkflowClient.schedule()
          |> Common.respond(conn)

        error ->
          Common.respond(error, conn)
      end
    end)
  end

  defp add_requester_id(params, conn) do
    requester_id = Conn.get_req_header(conn, "x-semaphore-user-id") |> Enum.at(0, "")
    Map.put(params, "requester_id", requester_id)
  end

  defp add_organization_id(params, conn) do
    organization_id = Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, "")
    Map.put(params, "organization_id", organization_id)
  end

  defp find_repository(conn = %{params: %{"project_id" => project_id}})
       when is_binary(project_id) and project_id != "" do
    case ProjectClient.describe(project_id) do
      {:ok, project} -> {:ok, Map.put(conn.params, "repository", project.spec.repository)}
      {:error, _reason} -> {:error, {:user, "Invalid request - missing parameter 'project_id'."}}
    end
  end
end
