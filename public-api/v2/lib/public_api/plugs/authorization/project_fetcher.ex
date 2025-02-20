defmodule PublicAPI.Plugs.Authorization.ProjectFetcher do
  @moduledoc """
  Plug that fetches the project and checks if it belongs to the scoped organization.

  Side effect:
    - puts project_id if found into conn.assigns
  """

  require Logger

  alias Plug.Conn
  alias LogTee, as: LT
  alias InternalClients.Projecthub, as: ProjecthubClient
  alias InternalClients.Pipelines, as: PipelinesClient

  @unauthorized_internal_error_message "Project not found, semaphore may be experiencing issues"
  @unauthorized_user_error_message "Project not found"

  def authorize(conn, _opts) do
    org_id = conn.assigns[:organization_id] || ""

    Logger.debug("Authorizing project for org: #{org_id}")

    get_project_id(conn, org_id)
    |> case do
      {:ok, project_id} ->
        conn
        |> Conn.assign(:project_id, project_id)
        |> Conn.assign(:authorized_project, true)

      {:error, {:internal, _}} = error ->
        LT.error(error, "Plug.Authorize.internal")

        PublicAPI.Util.ToTuple.internal_error(@unauthorized_internal_error_message)
        |> PublicAPI.Util.Response.respond(conn |> Conn.assign(:authorized_project, false))
        |> Conn.halt()

      _error ->
        Watchman.increment({"Plug.Authorize.project_authorization_failed", ["user"]})

        PublicAPI.Util.ToTuple.not_found_error(@unauthorized_user_error_message)
        |> PublicAPI.Util.Response.respond(conn |> Conn.assign(:authorized_project, false))
        |> Conn.halt()
    end
  end

  defp get_project_id(%{params: %{project_id: project_id}}, org_id) do
    PublicAPI.Cache.fetch("project_by_id_#{org_id}_#{project_id}", ttl(), fn ->
      ProjecthubClient.describe(%{id: project_id, organization_id: org_id})
      |> case do
        {:ok, %{metadata: %{id: id, org_id: p_org_id}}} when p_org_id == org_id ->
          {:ok, id}

        {:ok, _} ->
          Logger.warning(
            "Fetched a project that does not belong to the org: #{org_id} project_id: #{project_id}",
            trace: "Plug.Authorize.project_id_#{org_id}_#{project_id}"
          )

          "The project does not belong to requester organization"
          |> PublicAPI.Util.ToTuple.user_error()

        {:error, {_, error}} ->
          Logger.error(error, trace: "Plug.Authorize.project_id_#{org_id}_#{project_id}")

          "The project does not exist" |> PublicAPI.Util.ToTuple.user_error()
      end
    end)
  end

  defp get_project_id(%{params: %{pipeline_id: ppl_id}}, org_id) do
    PublicAPI.Cache.fetch("project_by_ppl_id_#{org_id}_#{ppl_id}", ttl(), fn ->
      PipelinesClient.describe(%{pipeline_id: ppl_id, detailed: false})
      |> case do
        {:ok, %{pipeline: %{project_id: id, organization_id: ppl_org_id}}}
        when ppl_org_id == org_id ->
          {:ok, id}

        {:ok, %{pipeline: pipeline}} ->
          Logger.warning(
            "Looking by pipeline owned by different organization, owner: #{pipeline.organization_id}",
            trace: "Plug.Authorize.pipeline_id_#{org_id}_#{ppl_id}"
          )

          "Pipeline not found" |> PublicAPI.Util.ToTuple.user_error()

        {:error, {_, error}} ->
          Logger.error(error, trace: "Plug.Authorize.pipeline_id_#{org_id}_#{ppl_id}")

          "Pipeline not found" |> PublicAPI.Util.ToTuple.user_error()
      end
    end)
  end

  defp get_project_id(%{params: %{project_name: project_name}}, org_id) do
    PublicAPI.Cache.fetch("project_by_name_#{org_id}_#{project_name}", ttl(), fn ->
      ProjecthubClient.describe(%{name: project_name, organization_id: org_id})
      |> case do
        {:ok, %{metadata: %{id: id, org_id: p_org_id}}} when p_org_id == org_id ->
          {:ok, id}

        {:ok, _} ->
          Logger.warning(
            "Fetched a project that does not belong to the org: #{org_id} project_name: #{project_name}",
            trace: "Plug.Authorize.project_id_by_name"
          )

          "Project not found" |> PublicAPI.Util.ToTuple.user_error()

        {:error, error} ->
          Logger.error("Lookup for project #{org_id} #{project_name} #{inspect(error)}",
            trace: "Plug.Authorize.project_id_by_name"
          )

          PublicAPI.Util.ToTuple.not_found_error(error)
      end
    end)
  end

  # wrappers that check in body_params instead of params
  defp get_project_id(%{body_params: %{project_id: project_id}}, org_id),
    do: get_project_id(%{params: %{project_id: project_id}}, org_id)

  defp get_project_id(%{body_params: %{pipeline_id: ppl_id}}, org_id),
    do: get_project_id(%{params: %{pipeline_id: ppl_id}}, org_id)

  defp get_project_id(%{body_params: %{project_name: project_name}}, org_id),
    do: get_project_id(%{params: %{project_name: project_name}}, org_id)

  defp get_project_id(_, _),
    do: PublicAPI.Util.ToTuple.user_error("Project not found, invalid request")

  defp ttl(), do: Application.get_env(:public_api, :cache_timeout)
end
