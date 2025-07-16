defmodule PipelinesAPI.Pipelines.Authorize do
  @moduledoc """
    Plugs that check authorization and if authorization fails stop remaining plugs in the pipeline
  """
  use Plug.Builder

  alias PipelinesAPI.Util.ToTuple
  alias PipelinesAPI.PipelinesClient
  alias PipelinesAPI.RBACClient
  alias LogTee, as: LT
  alias Plug.Conn
  alias PipelinesAPI.Util.Auth

  def authorize_read_list(conn, opts) do
    authorize_read(conn, opts)
  end

  def authorize_read(conn, _opts) do
    authorize("project.view", conn)
  end

  def authorize_create(conn, _opts) do
    authorize("project.job.rerun", conn)
  end

  def authorize_create_with_ppl_in_payload(conn, opts) do
    if has_pipeline_id_in_payload?(conn) do
      authorize_create(conn, opts)
    else
      conn
    end
  end

  def authorize_update(conn, _opts) do
    authorize("project.job.stop", conn)
  end

  defp has_pipeline_id_in_payload?(conn), do: conn.params["pipeline_id"]

  defp authorize(permission, conn) do
    user_id = Conn.get_req_header(conn, "x-semaphore-user-id") |> Enum.at(0, "")
    org_id = Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, "")

    with {:ok, project_id} <- get_project_id(conn, org_id),
         ids <- collect_ids(user_id, org_id, project_id),
         {:ok, permissions} <- RBACClient.list_user_permissions(ids) do
      authorize_or_halt(permissions, permission, conn)
    else
      {:error, {:internal, _}} = error ->
        LT.error(error, "Plug.Authorize")
        conn |> authorization_failed(:internal)

      error ->
        LT.error(error, "Plug.Authorize")
        conn |> authorization_failed(:user)
    end
  end

  defp get_project_id(%{params: %{"pipeline_id" => ppl_id}}, org_id) do
    with {:ok, %{pipeline: pipeline}} <-
           PipelinesClient.describe(ppl_id, %{"detailed" => "false"}) do
      if pipeline.organization_id == org_id do
        {:ok, pipeline.project_id}
      else
        "User does not have access to this project" |> ToTuple.user_error()
      end
    end
  end

  defp get_project_id(conn = %{params: %{"project_id" => project_id}}, _org_id) do
    IO.puts("PROJECT ID")
    IO.inspect(project_id)
    org_id = Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, "")
    IO.inspect(org_id)

    case Auth.project_belongs_to_org(org_id, project_id) do
      :ok -> {:ok, project_id}
      error -> error
    end
  end

  defp get_project_id(_, _), do: {:ok, ""}

  defp collect_ids(user_id, org_id, project_id) do
    %{user_id: user_id, org_id: org_id, project_id: project_id}
  end

  defp authorize_or_halt(permissions, permission, conn) do
    if Enum.member?(permissions, permission) do
      conn
    else
      conn |> authorization_failed(:user)
    end
  end

  defp authorization_failed(conn, :user), do: conn |> resp(404, "Not Found") |> halt
  defp authorization_failed(conn, :internal), do: conn |> resp(500, "Internal error") |> halt
end
