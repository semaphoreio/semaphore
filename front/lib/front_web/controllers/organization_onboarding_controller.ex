defmodule FrontWeb.OrganizationOnboardingController do
  alias Front.Models.OrganizationOnboarding
  use FrontWeb, :controller

  plug(:single_tenant_check)
  plug(:put_layout, "me.html")

  def new(conn, _params) do
    Watchman.benchmark("organization_onboarding.show.duration", fn ->
      user_id = conn.assigns.user_id
      user = Front.Models.User.find(user_id)

      render(
        conn,
        "new.html",
        js: :organizationOnboarding,
        title: "Welcome to Semaphore",
        signup: true,
        user: user
      )
    end)
  end

  def create(conn, params) do
    Watchman.benchmark("organization_onboarding.create.duration", fn ->
      user_id = conn.assigns.user_id

      params
      |> Map.put("user_id", user_id)
      |> OrganizationOnboarding.new()
      |> OrganizationOnboarding.create_organization()
      |> case do
        {:ok, organization} ->
          conn
          |> put_status(200)
          |> json(%{
            location: wait_path(conn, organization.id)
          })

        {:error, message} ->
          conn
          |> put_status(422)
          |> json(%{message: message})
      end
    end)
  end

  def wait_for_organization(conn, params) do
    Watchman.benchmark("organization_onboarding.create.duration", fn ->
      org_id = params["org_id"]
      user_id = conn.assigns.user_id

      OrganizationOnboarding.wait_for_organization(org_id, user_id)
      |> case do
        :ok ->
          org = Front.Models.Organization.find(org_id)

          conn
          |> put_status(201)
          |> json(%{
            location: FrontWeb.LayoutView.organization_url(conn, org.username)
          })

        _ ->
          conn
          |> put_status(200)
          |> json(%{
            location: wait_path(conn, org_id)
          })
      end
    end)
  end

  defp single_tenant_check(conn, _) do
    if Application.fetch_env!(:front, :single_tenant) do
      conn
      |> Front.Auth.render404()
    else
      conn
    end
  end

  defp wait_path(conn, org_id) do
    me_host = Application.get_env(:front, :me_host)
    domain = Application.get_env(:front, :domain)

    # Dev environment only
    if me_host == nil do
      wait_for_organization_path(conn, :wait_for_organization, org_id: org_id)
    else
      "https://#{me_host}#{domain}/wait?org_id=#{org_id}"
    end
  end
end
