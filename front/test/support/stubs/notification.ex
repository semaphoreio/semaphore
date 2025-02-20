defmodule Support.Stubs.Notification do
  alias Support.Stubs.{DB, UUID}

  def init do
    DB.add_table(:notifications, [:id, :org_id, :name, :api_model])

    __MODULE__.Grpc.init()
  end

  def create_default(org) do
    create(org)
  end

  def create(org) do
    alias Semaphore.Notifications.V1alpha.Notification

    meta =
      Notification.Metadata.new(
        name: "Notification #1",
        id: UUID.gen(),
        create_time: 1_549_885_252,
        update_time: 1_549_885_252
      )

    spec =
      Notification.Spec.new(
        rules: [
          Notification.Spec.Rule.new(
            name: "First Rule",
            filter:
              Notification.Spec.Rule.Filter.new(
                blocks: [],
                branches: ["development"],
                pipelines: [],
                projects: ["about-some-switches"],
                results: ["failed"],
                states: []
              ),
            notify:
              Notification.Spec.Rule.Notify.new(
                email:
                  Notification.Spec.Rule.Notify.Email.new(
                    bcc: [],
                    cc: [],
                    content: "",
                    subject: "",
                    status: Notification.Spec.Rule.Notify.Status.value(:ACTIVE)
                  ),
                slack:
                  Notification.Spec.Rule.Notify.Slack.new(
                    channels: ["@octocat"],
                    endpoint: "https://hooks.slack.com/services/xxxx",
                    message: "",
                    status: Notification.Spec.Rule.Notify.Status.value(:ACTIVE)
                  ),
                webhook: nil
              )
          ),
          Notification.Spec.Rule.new(
            filter:
              Notification.Spec.Rule.Filter.new(
                blocks: [],
                branches: ["master"],
                pipelines: [],
                projects: ["test-switch", "all-about-switches"],
                results: ["passed"],
                states: []
              ),
            name: "Second Rule",
            notify:
              Notification.Spec.Rule.Notify.new(
                email:
                  Notification.Spec.Rule.Notify.Email.new(
                    bcc: [],
                    cc: [],
                    content: "",
                    subject: "",
                    status: Notification.Spec.Rule.Notify.Status.value(:ACTIVE)
                  ),
                slack:
                  Notification.Spec.Rule.Notify.Slack.new(
                    channels: ["@bmarkons"],
                    endpoint: "https://hooks.slack.com/services/xxxx",
                    message: "",
                    status: Notification.Spec.Rule.Notify.Status.value(:ACTIVE)
                  ),
                webhook: nil
              )
          )
        ]
      )

    api_model = Notification.new(metadata: meta, spec: spec)

    DB.insert(:notifications, %{
      id: meta.id,
      org_id: org.id,
      name: meta.name,
      api_model: api_model
    })
  end

  defmodule Grpc do
    def init do
      GrpcMock.stub(NotificationMock, :list_notifications, &__MODULE__.list_notifications/2)
      GrpcMock.stub(NotificationMock, :get_notification, &__MODULE__.get_notification/2)
      GrpcMock.stub(NotificationMock, :create_notification, &__MODULE__.create_notification/2)
      GrpcMock.stub(NotificationMock, :update_notification, &__MODULE__.update_notification/2)
      GrpcMock.stub(NotificationMock, :delete_notification, &__MODULE__.delete_notification/2)
    end

    def list_notifications(_req, call) do
      {org_id, _} = call |> extract_headers

      notifications = org_notifications(org_id) |> DB.extract(:api_model)

      Semaphore.Notifications.V1alpha.ListNotificationsResponse.new(
        notifications: notifications,
        next_page_token: ""
      )
    end

    def get_notification(req, call) do
      case find(req, call) do
        {:ok, notification} ->
          notification.api_model

        {:error, message} ->
          raise GRPC.RPCError, status: 5, message: message
      end
    end

    def create_notification(notification, call) do
      {org_id, _} = call |> extract_headers

      DB.insert(:notifications, %{
        id: notification.metadata.id,
        org_id: org_id,
        name: notification.metadata.name,
        api_model: notification
      })

      notification
    end

    def update_notification(req, call) do
      case find(req, call) do
        {:ok, notification} ->
          new_notification = %{
            id: req.notification.metadata.id,
            name: req.notification.metadata.name,
            api_model: req.notification,
            org_id: notification.org_id
          }

          DB.update(:notifications, new_notification)

          new_notification.api_model

        {:error, message} ->
          raise GRPC.RPCError, status: :not_found, message: message
      end
    end

    def delete_notification(req, call) do
      case find(req, call) do
        {:ok, notification} ->
          DB.delete(:notifications, notification.id)

          Semaphore.Notifications.V1alpha.Empty.new()

        {:error, message} ->
          raise GRPC.RPCError, status: 5, message: message
      end
    end

    defp find(req, call) do
      {org_id, _} = call |> extract_headers

      case Enum.find(org_notifications(org_id), fn s ->
             s.id == req.notification_id_or_name || s.name == req.notification_id_or_name
           end) do
        nil ->
          {:error, "Notification #{req.notification_id_or_name} not found"}

        notification ->
          {:ok, notification}
      end
    end

    defp org_notifications(org_id) do
      DB.find_all_by(:notifications, :org_id, org_id)
    end

    defp extract_headers(call) do
      call
      |> GRPC.Stream.get_headers()
      |> Map.take(["x-semaphore-org-id", "x-semaphore-user-id"])
      |> Map.values()
      |> List.to_tuple()
    end
  end
end
