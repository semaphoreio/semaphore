defmodule FrontWeb.SupportController do
  use FrontWeb, :controller
  require Logger

  alias Front.{Async, Auth, Support}
  alias Front.Clients.Billing

  alias Front.Models.{
    Organization,
    SupportRequest,
    User
  }

  plug(FrontWeb.Plugs.OnPremBlocker)

  plug(FrontWeb.Plugs.OrganizationAuthorization)

  plug(
    FrontWeb.Plugs.Header
    when action in [:new, :thanks, :submit]
  )

  def thanks(conn, _params) do
    user = conn.assigns.user_id |> User.find()

    render(
      conn,
      "thanks.html",
      user: user
    )
  end

  def new(conn, _params) do
    redirect(conn, external: Front.Zendesk.new_ticket_location())
  end

  def submit(conn, params) do
    user_id = conn.assigns.user_id
    org_id = conn.assigns.organization_id

    fetch_user = Async.run(fn -> User.find(user_id) end)
    fetch_billing = Async.run(fn -> Billing.organization_status(org_id) end)
    fetch_org = Async.run(fn -> Organization.find(org_id) end)

    fetch_auth = Async.run(fn -> Auth.manage_people?(user_id, org_id) end)
    # it's been decided to use manage_people function here
    # for the sake of consistency with the Billing section in sidebar

    {:ok, billing_status} = Async.await(fetch_billing)
    {:ok, user} = Async.await(fetch_user)

    input = parse_support_form_data(params, user.email, billing_status)

    with {:ok, _} <- SupportRequest.create(input) do
      conn
      |> put_flash(:notice, "Message sent.")
      |> redirect(to: support_path(conn, :thanks))
    else
      {:error, "failed-to-submit", changeset} ->
        {:ok, can_manage_billing} = Async.await(fetch_auth)
        {:ok, org} = Async.await(fetch_org)

        conn
        |> put_flash(:alert, "Failed to send the message, please try again.")
        |> put_status(422)
        |> render(
          "new.html",
          user: user,
          changeset: changeset,
          support_request: input,
          plan: billing_status.plan,
          able_to_manage_billing: can_manage_billing,
          billing_url: billing_url(org),
          js: :support
        )

      {:error, changeset} ->
        {:ok, can_manage_billing} = Async.await(fetch_auth)
        {:ok, org} = Async.await(fetch_org)

        conn
        |> put_flash(:alert, "Failed to send the message.")
        |> put_status(422)
        |> render(
          "new.html",
          user: user,
          changeset: changeset,
          support_request: input,
          plan: billing_status.plan,
          able_to_manage_billing: can_manage_billing,
          billing_url: billing_url(org)
        )
    end
  end

  defp parse_support_form_data(params, email, billing_status) do
    %{
      topic: params["topic"],
      subject: params["subject"],
      body: params["body"],
      provided_link: params["provided_link"],
      email: email,
      tags: construct_tags(params),
      plan: billing_status.plan,
      segment: Support.Segment.determine(billing_status)
    }
    |> manage_attachment_input(params)
  end

  defp construct_tags(params) do
    case params["urgent"] do
      "true" -> ["urgent"]
      _ -> []
    end
  end

  # sobelow_skip ["Traversal.FileModule"]
  defp manage_attachment_input(base_input, params) do
    attachment =
      if params["attachment"] do
        attachment = params["attachment"]

        file = File.read!(attachment.path)

        %{
          file_name: attachment.filename,
          file_type: attachment.content_type,
          file_data: Base.encode64(file),
          file_size: Kernel.byte_size(file)
        }
      else
        %{
          file_name: "",
          file_type: "",
          file_data: "",
          file_size: 0
        }
      end

    Map.merge(base_input, attachment)
  end

  defp billing_url(org) do
    "https://billing.#{Application.get_env(:front, :domain)}/?organization=#{org.username}"
  end
end
