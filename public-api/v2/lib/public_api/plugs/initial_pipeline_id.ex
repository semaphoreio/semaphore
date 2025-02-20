defmodule PublicAPI.Plugs.InitialPplId do
  @moduledoc """
  Plug for setting initial pipeline id from workflow id.
  """
  alias Plug.Conn
  alias InternalClients.Workflow, as: WorkflowClient

  def init(opts), do: opts

  def call(conn = %Plug.Conn{}, _opts) do
    with false <- is_binary(Map.get(conn.params, :project_id)),
         {:wf_id, true} <- {:wf_id, is_binary(conn.params.wf_id)} do
      {:ok, %{status: %{code: code}, workflow: workflow}} =
        conn.params.wf_id
        |> WorkflowClient.WFRequestFormatter.form_describe_request()
        |> WorkflowClient.WFGrpcClient.describe()

      process_response(code, workflow, conn)
    else
      {:wf_id, false} ->
        conn
        |> Conn.resp(400, "Bad Request")
        |> Conn.halt()

      _ ->
        conn
    end
  end

  defp process_response(:OK, workflow, conn) do
    %{initial_ppl_id: initial_ppl_id} = workflow
    params = Map.put(conn.params, :pipeline_id, initial_ppl_id)
    Map.put(conn, :params, params)
  end

  defp process_response(:FAILED_PRECONDITION, _workflow, conn) do
    PublicAPI.Util.ToTuple.not_found_error("Pipeline not found")
    |> PublicAPI.Util.Response.respond(conn)
    |> Conn.halt()
  end
end
