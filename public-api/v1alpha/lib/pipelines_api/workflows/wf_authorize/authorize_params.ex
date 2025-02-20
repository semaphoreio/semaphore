defmodule PipelinesAPI.Workflows.WfAuthorize.AuthorizeParams do
  @moduledoc false

  use Plug.Builder
  alias InternalApi.PlumberWF.WorkflowService
  alias InternalApi.PlumberWF.DescribeRequest
  alias Util.Proto

  defp url(), do: System.get_env("PPL_GRPC_URL")
  defp opts(), do: [{:timeout, Application.get_env(:pipelines_api, :grpc_timeout)}]

  def get_initial_ppl_id(conn, _opts) do
    case is_binary(conn.params["project_id"]) do
      false ->
        describe_request = %{wf_id: conn.params["wf_id"]} |> DescribeRequest.new()
        {:ok, channel} = GRPC.Stub.connect(url())
        {:ok, describe_resp} = channel |> WorkflowService.Stub.describe(describe_request, opts())
        {:ok, %{status: %{code: code}, workflow: workflow}} = describe_resp |> Proto.to_map()

        process_response(code, workflow, conn)

      _ ->
        conn
    end
  end

  defp process_response(:OK, workflow, conn) do
    %{initial_ppl_id: initial_ppl_id} = workflow
    params = Map.put(conn.params, "pipeline_id", initial_ppl_id)
    Map.put(conn, :params, params)
  end

  defp process_response(:FAILED_PRECONDITION, _workflow, conn) do
    conn |> resp(404, "Not Found") |> halt
  end
end
