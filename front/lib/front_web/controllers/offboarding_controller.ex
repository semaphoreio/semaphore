defmodule FrontWeb.OffboardingController do
  use FrontWeb, :controller
  require Logger

  alias Front.{Async, Audit, Models}

  plug(
    FrontWeb.Plugs.ProjectAuthorization
    when action not in [:offboarding, :show]
  )

  plug(FrontWeb.Plugs.PeopleAuthorization)

  plug(
    FrontWeb.Plugs.OrganizationAuthorization
    when action in [:offboarding]
  )

  plug(FrontWeb.Plugs.Header when action in [:show])

  def show(conn, %{"user_id" => user_id}) do
    Watchman.benchmark("offboarding.show.duration", fn ->
      org_id = conn.assigns.organization_id

      case Models.Project.list_by_owner(org_id, user_id) do
        {:error, _} ->
          conn
          |> put_flash(:alert, "There was an issue with lising user's projects")
          |> redirect(to: people_path(conn, :organization))

        {:ok, []} ->
          conn
          |> put_flash(:notice, "Member doesn't have any projects.")
          |> redirect(to: people_path(conn, :organization))

        {:ok, projects} ->
          fetch_org = Async.run(fn -> Models.Organization.find(org_id) end)
          fetch_user = Async.run(fn -> Models.User.find(user_id) end)

          {:ok, organization} = Async.await(fetch_org)
          {:ok, user} = Async.await(fetch_user)

          render(
            conn,
            "show.html",
            organization: organization,
            user: user,
            projects: projects,
            js: "offboarding",
            title: "Offboarding People・#{organization.name}",
            layout: {FrontWeb.LayoutView, "organization.html"}
          )
      end
    end)
  end

  def transfer(conn, _) do
    user_id = conn.assigns.user_id
    project = conn.assigns.project
    org_id = conn.assigns.organization_id
    new_owner_id = user_id

    conn
    |> Audit.new(:Project, :Modified)
    |> Audit.add(description: "Changed Project Owner.")
    |> Audit.add(resource_id: project.id)
    |> Audit.add(resource_name: project.name)
    |> Audit.metadata(new_owner_id: new_owner_id)
    |> Audit.log()

    changeset = Models.Project.owner_changeset(project, %{"owner_id" => new_owner_id})

    with {:ok, data} <- Ecto.Changeset.apply_action(changeset, :update),
         {:ok, _} <- Models.Project.change_owner(org_id, project.id, data.owner_id, user_id) do
      conn
      |> put_layout(false)
      |> assign(:success, true)
      |> render("transferred.html")
    else
      {:error, message} when is_binary(message) ->
        conn
        |> put_layout(false)
        |> assign(:success, false)
        |> assign(:message, message)
        |> render("transferred.html")

      {:error, _owner_changeset} ->
        conn
        |> put_layout(false)
        |> assign(:success, false)
        |> assign(:message, "Transfering failed")
        |> render("transferred.html")
    end
  end

  def remove(conn, _) do
    user_id = conn.assigns.user_id
    project = conn.assigns.project
    org_id = conn.assigns.organization_id

    conn
    |> Audit.new(:Project, :Removed)
    |> Audit.add(description: "Removing a project")
    |> Audit.add(resource_id: project.id)
    |> Audit.add(resource_name: project.name)
    |> Audit.log()

    case Models.Project.destroy(project.id, user_id, org_id) do
      {:ok, _} ->
        conn
        |> put_layout(false)
        |> assign(:success, true)
        |> render("removed.html")

      _ ->
        conn
        |> put_layout(false)
        |> assign(:success, false)
        |> assign(:message, "Removing failed")
        |> render("removed.html")
    end
  end
end
