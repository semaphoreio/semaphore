defmodule PublicAPI.Plugs.Authorization do
  @moduledoc """
  Authorization builder plug.
  This will generate a plug pipeline based on the provided options.

  It will invoke the `PublicAPI.Plugs.Authorize.ProjectFetcher` plug if any of the permissions is project-scoped
  and the `PublicAPI.Plugs.Authorization.PermissionsChecker` plug always.
  """
  use Plug.Builder, copy_opts_to_assign: :builder_opts
  require Logger

  alias PublicAPI.Plugs.Authorization.ProjectFetcher
  alias PublicAPI.Plugs.Authorization.PermissionsChecker

  @impl true
  def init(opts) do
    [
      permissions: ["organization.view"],
      project_authorization: with_project_permission?(opts[:permissions])
    ]
    |> Keyword.merge(opts)
  end

  defp with_project_permission?(permissions) do
    Enum.any?(permissions, fn permission ->
      String.starts_with?(permission, "project.")
    end)
  end

  @impl true
  def call(conn, opts) do
    conn
    |> Plug.Conn.assign(:permissions, opts[:permissions])
    |> maybe_fetch_project(opts[:project_authorization])
    |> call_plug(PermissionsChecker, opts[:permissions])
  end

  defp maybe_fetch_project(conn, false), do: conn

  defp maybe_fetch_project(conn, true) do
    conn
    |> call_plug(ProjectFetcher, [])
  end

  defp call_plug(conn = %{halted: false}, plug, opts) do
    plug.authorize(conn, opts)
  end

  defp call_plug(conn, _plug, _opts) do
    conn
  end
end
