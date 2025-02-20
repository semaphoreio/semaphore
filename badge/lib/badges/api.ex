defmodule Badges.Api do
  use Plug.Router

  use Plug.ErrorHandler
  use Sentry.Plug

  plug(Badges.RequestLogger)
  plug(:match)
  plug(:dispatch)

  require Logger

  get "/is_alive" do
    send_resp(conn, 200, "OK")
  end

  get "badges/:project_name/branches/*branch_name" do
    Watchman.benchmark("http.branch", fn ->
      branch_name = branch_name |> Enum.join("/")

      if String.ends_with?(branch_name, ".svg") do
        branch_name = branch_name |> String.replace_suffix(".svg", "")

        render_badge(conn, project_name, branch_name)
      else
        render404(conn, "Badge not found")
      end
    end)
  end

  get "badges/:project_name" do
    Watchman.benchmark("http.default_branch", fn ->
      if String.ends_with?(project_name, ".svg") do
        branch_name = "master"
        project_name = project_name |> String.replace_suffix(".svg", "")

        render_badge(conn, project_name, branch_name)
      else
        render404(conn, "Badge not found")
      end
    end)
  end

  match _ do
    render404(conn, "Badge not found")
  end

  defp render_badge(conn, project, branch) do
    conn = Plug.Conn.fetch_query_params(conn)

    org_id = conn |> Plug.Conn.get_req_header("x-semaphore-org-id") |> hd()
    project_id = conn.params["key"]
    style = conn.params["style"] || "semaphore"

    Sentry.Context.set_extra_context(%{
      org_id: org_id,
      project_id: project_id,
      style: style,
      project: inspect(project),
      branch: inspect(branch)
    })

    case fetch_variant(org_id, project, branch, project_id) do
      {:ok, variant} ->
        case Badges.Svg.render(variant, style) do
          {:ok, badge} ->
            conn
            |> put_resp_content_type("image/svg+xml")
            |> send_resp(200, badge)

          {:error, :badge_not_found} ->
            render404(conn, "Badge not found")
        end

      {:error, :project_not_found} ->
        render404(
          conn,
          "Project not found - for private projects check: https://docs.semaphoreci.com/article/166-status-badges#private-projects-on-semaphore"
        )

      _ ->
        render404(conn, "Badge not found")
    end
  end

  defp fetch_variant(org_id, project, branch, project_id) do
    Badges.Cache.fetch!(["badge", org_id, project, branch, project_id], :timer.seconds(5), fn ->
      case Badges.Badge.variant(org_id, project, branch, project_id) do
        {:ok, badge} -> {:commit, {:ok, badge}}
        {:error, error} -> {:ignore, {:error, error}}
      end
    end)
  end

  defp render404(conn, message) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(404, message)
  end
end
