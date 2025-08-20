defmodule FrontWeb.NotificationsController do
  require Logger
  use FrontWeb, :controller

  alias Front.Async
  alias Front.Audit
  alias Front.Models.{Notification, Organization, User}

  plug(FrontWeb.Plugs.FetchPermissions, scope: "org")
  plug(FrontWeb.Plugs.PageAccess, permissions: "organization.view")
  plug(FrontWeb.Plugs.Header when action in [:index, :edit, :new, :create, :update])
  plug(:put_layout, :organization_settings)

  def index(conn, _params) do
    Watchman.benchmark("notifications.index.duration", fn ->
      user_id = conn.assigns.user_id
      org_id = conn.assigns.organization_id

      fetch_notifications = Async.run(fn -> Notification.list(user_id, org_id) end)
      fetch_organization = Async.run(fn -> Organization.find(org_id) end)

      {:ok, organization} = Async.await(fetch_organization)
      {:ok, notifications} = Async.await(fetch_notifications)
      notifications = add_user_data_to_notifications(notifications)

      render(
        conn,
        "index.html",
        organization: organization,
        notifications: notifications,
        title: "Notifications・#{organization.name}",
        permissions: conn.assigns.permissions
      )
    end)
  end

  def new(conn, _params) do
    Watchman.benchmark("notifications.new.duration", fn ->
      org_id = conn.assigns.organization_id
      organization = Organization.find(org_id)

      render(
        conn,
        "form.html",
        form_title: "Create Notification",
        js: "notification",
        action: notifications_path(conn, :create),
        method: :post,
        notification: empty_notification(),
        title: "New Notification・#{organization.name}",
        cancel_path: notifications_path(conn, :index),
        errors: %{},
        organization: organization,
        permissions: conn.assigns.permissions,
        can_view_settings: true
      )
    end)
  end

  # credo:disable-for-next-line
  def create(conn, params) do
    Watchman.benchmark("notifications.create.duration", fn ->
      org_id = conn.assigns.organization_id
      user_id = conn.assigns.user_id

      notification_params = parse_form_input(params)

      if conn.assigns.permissions["organization.notifications.manage"] || false do
        case Notification.create(user_id, org_id, notification_params) do
          {:ok, _notification} ->
            conn
            |> Audit.new(:Notification, :Added)
            |> Audit.add(description: "Added a notification")
            |> Audit.add(resource_name: notification_params.name)
            |> Audit.log()

            conn
            |> put_flash(:notice, "Notification created.")
            |> redirect(to: notifications_path(conn, :index))

          {:error, %{status: 5}} ->
            conn
            |> render_404

          {:error, %{status: :not_found}} ->
            conn
            |> render_404

          {:error, %{status: :invalid_argument, message: message}} ->
            conn
            |> put_flash(:alert, URI.decode(message))
            |> redirect(to: notifications_path(conn, :new))

          {:error, %{status: 3, message: message}} ->
            conn
            |> put_flash(:alert, URI.decode(message))
            |> redirect(to: notifications_path(conn, :new))

          {:error, %{message: message, status: 9}} ->
            organization = Organization.find(org_id)

            conn
            |> put_status(422)
            |> put_flash(:alert, "Failed to create notification.")
            |> render(
              "form.html",
              form_title: "Create Notification",
              js: "notification",
              action: notifications_path(conn, :create),
              method: :post,
              organization: organization,
              org_restricted: organization.restricted,
              cancel_path: notifications_path(conn, :index),
              notification: empty_notification(),
              title: "New Notification・#{organization.name}",
              errors: %{name: %{message: message}},
              can_view_settings: true
            )

          {:error, response} ->
            Logger.error("Create notification returned error: #{inspect(response)}")

            conn
            |> put_flash(:alert, "Failed to create notification.")
            |> redirect(to: notifications_path(conn, :new))
        end
      else
        conn
        |> put_flash(:alert, "Insufficient permissions.")
        |> redirect(to: notifications_path(conn, :index))
      end
    end)
  end

  # credo:disable-for-next-line
  def update(conn, params) do
    Watchman.benchmark("notifications.update.duration", fn ->
      id = params["id"]
      org_id = conn.assigns.organization_id
      user_id = conn.assigns.user_id

      notification_params = parse_form_input(params)

      if conn.assigns.permissions["organization.notifications.manage"] || false do
        case Notification.update(user_id, org_id, notification_params) do
          {:ok, _notification} ->
            conn
            |> Audit.new(:Notification, :Modified)
            |> Audit.add(description: "Modified a notification")
            |> Audit.add(resource_id: id)
            |> Audit.add(resource_name: notification_params.name)
            |> Audit.log()

            conn
            |> put_flash(:notice, "Notification updated.")
            |> redirect(to: notifications_path(conn, :index))

          {:error, %{status: 5}} ->
            conn
            |> render_404

          {:error, %{status: :not_found}} ->
            conn
            |> render_404

          {:error, %{status: :invalid_argument, message: message}} ->
            conn
            |> put_flash(:alert, URI.decode(message))
            |> redirect(to: notifications_path(conn, :edit, id))

          {:error, %{status: 3, message: message}} ->
            conn
            |> put_flash(:alert, URI.decode(message))
            |> redirect(to: notifications_path(conn, :edit, id))

          {:error, %{message: message, status: 9}} ->
            fetch_notification = Async.run(fn -> Notification.find(id, user_id, org_id) end)
            fetch_organization = Async.run(fn -> Organization.find(org_id) end)

            {:ok, {:ok, notification}} = Async.await(fetch_notification)
            {:ok, organization} = Async.await(fetch_organization)

            conn
            |> put_status(422)
            |> put_flash(:alert, "Failed to update notification.")
            |> render(
              "form.html",
              form_title: "Update Notification",
              js: "notification",
              action: notifications_path(conn, :update, id),
              method: :put,
              organization: organization,
              org_restricted: organization.restricted,
              cancel_path: notifications_path(conn, :index),
              notification: notification,
              title: "Editing #{notification.metadata.name}・#{organization.name}",
              errors: %{name: %{message: message}},
              can_view_settings: true
            )

          {:error, response} ->
            Logger.error("Edit notification: #{id} returned error: #{inspect(response)}")

            conn
            |> put_flash(:alert, "Failed to update notification.")
            |> redirect(to: notifications_path(conn, :edit, id))
        end
      else
        conn
        |> put_flash(:alert, "Insufficient permissions.")
        |> redirect(to: notifications_path(conn, :index))
      end
    end)
  end

  def edit(conn, params) do
    Watchman.benchmark("notifications.edit.duration", fn ->
      id = params["id"]
      org_id = conn.assigns.organization_id
      user_id = conn.assigns.user_id

      case Notification.find(id, user_id, org_id) do
        {:ok, notification} ->
          organization = Organization.find(org_id)

          render(
            conn,
            "form.html",
            form_title: "Edit Notification",
            js: "notification",
            action: notifications_path(conn, :update, id),
            method: :put,
            notification: notification,
            title: "Editing #{notification.metadata.name}・#{organization.name}",
            cancel_path: notifications_path(conn, :index),
            errors: %{},
            organization: organization,
            org_restricted: organization.restricted,
            permissions: conn.assigns.permissions,
            can_view_settings: true
          )

        {:error, %{status: 5}} ->
          conn
          |> render_404

        {:error, %{status: :not_found}} ->
          conn
          |> render_404
      end
    end)
  end

  def destroy(conn, params) do
    Watchman.benchmark("notifications.destroy.duration", fn ->
      id = params["id"]
      user_id = conn.assigns.user_id
      org_id = conn.assigns.organization_id

      if conn.assigns.permissions["organization.notifications.manage"] || false do
        case Notification.delete(id, user_id, org_id) do
          {:ok, _} ->
            conn
            |> put_flash(:notice, "Notification deleted.")
            |> redirect(to: notifications_path(conn, :index))

          {:error, %{status: 5}} ->
            conn
            |> render_404

          {:error, %{status: :not_found}} ->
            conn
            |> render_404

          {:error, response} ->
            Logger.error("Delete notification: #{id} returned error: #{inspect(response)}")

            conn
            |> put_flash(:alert, "Failed to delete notification.")
            |> redirect(to: notifications_path(conn, :index))
        end
      else
        conn
        |> put_flash(:alert, "Insufficient permissions.")
        |> redirect(to: notifications_path(conn, :index))
      end
    end)
  end

  defp render_404(conn) do
    conn
    |> put_status(:not_found)
    |> put_layout(false)
    |> put_view(FrontWeb.ErrorView)
    |> render("404.html")
  end

  defp add_user_data_to_notifications(notifications) when is_list(notifications) do
    import Enum

    creators =
      notifications
      |> map(& &1.metadata.creator_id)
      |> reject(&(&1 == ""))
      |> uniq()
      |> User.find_many()

    map(notifications, fn n ->
      if n.metadata.creator_id != "" do
        default_username = Application.get_env(:front, :default_user_name)
        creator = find(creators, &(&1.id == n.metadata.creator_id)) || %{name: default_username}
        %{n | metadata: Map.put(n.metadata, :creator, creator)}
      else
        n
      end
    end)
  end

  def get_rule_identifiers(params) do
    params
    |> Map.keys()
    |> Enum.filter(&String.starts_with?(&1, "rule"))
  end

  def parse_form_input(params) do
    rules_data =
      params
      |> get_rule_identifiers
      |> Enum.map(fn rule -> params[rule] |> parse_rule_data end)

    %{
      id: params["id"],
      name: params["name"],
      rules: rules_data
    }
  end

  def parse_rule_data(params) do
    %{
      projects: params["projects"] |> parse_entry,
      branches: params["branches"] |> parse_entry,
      blocks: params["blocks"] |> parse_entry,
      pipelines: params["pipelines"] |> parse_entry,
      results: params["results"] |> parse_entry,
      rule_name: params["name"],
      slack_channels: params["slack_channels"] |> parse_entry,
      slack_endpoint: params["slack_endpoint"],
      webhook_endpoint: params["webhook_endpoint"],
      webhook_secret: params["webhook_secret"]
    }
  end

  def parse_entry(nil), do: []
  def parse_entry(""), do: []

  def parse_entry(string) do
    string
    |> String.split(",")
    |> Enum.map(&String.trim(&1))
  end

  def empty_notification do
    alias Semaphore.Notifications.V1alpha.Notification

    %Notification{
      metadata: %Notification.Metadata{name: ""},
      spec: %Notification.Spec{
        rules: [
          %Notification.Spec.Rule{
            filter: %Notification.Spec.Rule.Filter{
              blocks: [],
              branches: [],
              pipelines: [],
              projects: [],
              results: [],
              states: []
            },
            name: "",
            notify: %Notification.Spec.Rule.Notify{
              email: %Notification.Spec.Rule.Notify.Email{
                bcc: [],
                cc: [],
                content: "",
                subject: ""
              },
              slack: %Notification.Spec.Rule.Notify.Slack{
                channels: [],
                endpoint: "",
                message: ""
              },
              webhook: %Notification.Spec.Rule.Notify.Webhook{
                endpoint: "",
                secret: ""
              }
            }
          }
        ]
      }
    }
  end
end
