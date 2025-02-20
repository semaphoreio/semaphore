defmodule PublicAPI.Plugs.ObjectFilter do
  @behaviour Plug
  @moduledoc """
  Plug for object ownership verification.
  Matches the organization_id from the request with the organization_id in the loaded resource.
  If the resource does not contain organization_id, it fetches the project and checks if it belongs to the organization.
  In some cases project will already be loaded in conn.private.project, so first check if project is preloaded.
  """

  import PublicAPI.Util.PlugContextHelper
  require Logger

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    org_id = conn.assigns[:organization_id]
    user_id = conn.assigns[:user_id]
    maybe_project_id = conn.assigns[:project_id]

    resource = get_response(conn) || get_resource(conn)

    validate_resource({org_id, maybe_project_id}, resource)
    |> case do
      :ok ->
        conn

      :not_found ->
        PublicAPI.Util.ToTuple.not_found_error("Not found")
        |> PublicAPI.Util.Response.respond(conn)
        |> Plug.Conn.halt()

      {:forbidden, owner_org} ->
        Watchman.increment("public_api.object_filter.invalid_resource")

        Logger.error(
          "Resource does not belong to the organization, user that tried to access the resource: #{user_id}, org_id: #{org_id}, tried to access a resource owned by: #{owner_org}" <>
            log_message(conn)
        )

        PublicAPI.Util.ToTuple.not_found_error("Not found")
        |> PublicAPI.Util.Response.respond(conn)
        |> Plug.Conn.halt()
    end
  end

  defp validate_resource(request_ids, {:ok, resource = %PublicAPI.Util.Page{}}) do
    Enum.reduce_while(resource.entries, :ok, fn entry, _ ->
      case validate_resource(request_ids, {:ok, entry}) do
        :ok ->
          {:cont, :ok}

        {:forbidden, owner_org_id} ->
          {:halt, {:forbidden, owner_org_id}}
      end
    end)
  end

  defp validate_resource(request_ids, {:ok, resource}) when is_list(resource) do
    validate_resource(request_ids, {:ok, %PublicAPI.Util.Page{entries: resource}})
  end

  defp validate_resource({request_org_id, request_project_id}, {:ok, resource}) do
    # first check org ownership, if response doesn't have org_id, check project ownership
    # if org ownership is ok, check project ownership
    validate_org(request_org_id, resource)
    |> case do
      :ok ->
        validate_project({request_org_id, request_project_id}, resource)

      {:forbidden, owner_org} ->
        {:forbidden, owner_org}
    end
  end

  defp validate_resource(_request_ids, {:error, _}), do: :not_found

  defp validate_org(request_org_id, resource) do
    case resource do
      %{metadata: %{organization: %{id: ^request_org_id}}} ->
        :ok

      %{metadata: %{organization: %{id: real_owner}}} ->
        {:forbidden, real_owner}

      %{metadata: %{org_id: ^request_org_id}} ->
        :ok

      %{metadata: %{org_id: real_owner}} ->
        {:forbidden, real_owner}

      _ ->
        # there is no org_id in resource
        :ok
    end
  end

  def validate_project({request_org_id, request_project_id}, resource) do
    case resource do
      %{metadata: %{project_id: project_id}} ->
        validate_project_ownership({request_org_id, request_project_id}, project_id)

      %{pipeline: %{project_id: project_id}} ->
        validate_project_ownership({request_org_id, request_project_id}, project_id)

      %{project_id: project_id} ->
        validate_project_ownership({request_org_id, request_project_id}, project_id)

      _ ->
        # there is no project_id in resource
        :ok
    end
  end

  defp validate_project_ownership(
         {_request_org_id, request_project_id},
         response_project_id
       )
       when request_project_id == response_project_id and not is_nil(response_project_id),
       do: :ok

  defp validate_project_ownership(
         {_request_org_id, _request_project_id},
         response_project_id
       ),
       do: {:forbidden, response_project_id}

  defp log_message(conn) do
    " request: #{conn.method} #{conn.request_path} from #{inspect(conn.remote_ip)}"
  end
end
