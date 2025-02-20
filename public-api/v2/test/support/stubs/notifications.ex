defmodule Support.Stubs.Notifications do
  alias Support.Stubs.{DB, UUID}

  def init do
    DB.add_table(:notifications, [:id, :org_id, :name, :api_model])

    __MODULE__.Grpc.init()
  end

  def create_default(org) do
    create(org)
  end

  def create(org, params \\ []) do
    alias InternalApi.Notifications.Notification
    name = Keyword.get(params, :name, "Notification #1")

    rules = [
      %Notification.Rule{
        name: "First Rule",
        filter: %Notification.Rule.Filter{
          blocks: [],
          branches: ["development"],
          pipelines: [],
          projects: ["about-some-switches"],
          results: [:FAILED],
          states: []
        },
        notify: %Notification.Rule.Notify{
          email: %Notification.Rule.Notify.Email{
            bcc: [],
            cc: ["some@email.com"],
            content: "",
            subject: "",
            status: Notification.Rule.Notify.Status.value(:ACTIVE)
          },
          slack: %Notification.Rule.Notify.Slack{
            channels: ["@milana"],
            endpoint: "https://hooks.slack.com/services/xxxx",
            message: "",
            status: Notification.Rule.Notify.Status.value(:ACTIVE)
          },
          webhook: nil
        }
      },
      %Notification.Rule{
        filter: %Notification.Rule.Filter{
          blocks: [],
          branches: ["master"],
          pipelines: [],
          projects: ["test-switch", "all-about-switches"],
          results: [:PASSED],
          states: []
        },
        name: "Second Rule",
        notify: %Notification.Rule.Notify{
          email: %Notification.Rule.Notify.Email{
            bcc: [],
            cc: ["some@email.com"],
            content: "",
            subject: "",
            status: Notification.Rule.Notify.Status.value(:ACTIVE)
          },
          slack: %Notification.Rule.Notify.Slack{
            channels: ["@bmarkons"],
            endpoint: "https://hooks.slack.com/services/xxxx",
            message: "",
            status: Notification.Rule.Notify.Status.value(:ACTIVE)
          },
          webhook: nil
        }
      }
    ]

    api_model = %Notification{
      name: name,
      id: UUID.gen(),
      create_time: %Google.Protobuf.Timestamp{seconds: 1_549_885_252, nanos: 0},
      update_time: %Google.Protobuf.Timestamp{seconds: 1_549_885_252, nanos: 0},
      org_id: org.id,
      rules: rules
    }

    DB.insert(:notifications, %{
      id: api_model.id,
      org_id: org.id,
      name: api_model.name,
      api_model: api_model
    })
  end

  defmodule Grpc do
    def init do
      GrpcMock.stub(NotificationsMock, :list, &__MODULE__.list/2)
      GrpcMock.stub(NotificationsMock, :describe, &__MODULE__.describe/2)
      GrpcMock.stub(NotificationsMock, :create, &__MODULE__.create/2)
      GrpcMock.stub(NotificationsMock, :update, &__MODULE__.update/2)
      GrpcMock.stub(NotificationsMock, :destroy, &__MODULE__.destroy/2)
    end

    def mock_wrong_org(wrong_org_id) do
      GrpcMock.stub(NotificationsMock, :describe, fn req, _opts ->
        case find(req) do
          {:ok, notification} ->
            notification = %{notification.api_model | org_id: wrong_org_id}
            %InternalApi.Notifications.DescribeResponse{notification: notification}

          {:error, message} ->
            raise GRPC.RPCError, status: :not_found, message: message
        end
      end)
    end

    def list(req, _call) do
      org_id = req.metadata.org_id

      notifications = org_notifications(org_id) |> DB.extract(:api_model)

      %InternalApi.Notifications.ListResponse{
        notifications: notifications,
        next_page_token: ""
      }
    end

    def describe(req, _call) do
      case find(req) do
        {:ok, notification} ->
          %InternalApi.Notifications.DescribeResponse{notification: notification.api_model}

        {:error, message} ->
          raise GRPC.RPCError, status: :not_found, message: message
      end
    end

    def create(req, _call) do
      org_id = req.metadata.org_id

      id = UUID.gen()

      DB.insert(:notifications, %{
        id: id,
        org_id: org_id,
        name: req.notification.name,
        api_model: req.notification
      })

      %InternalApi.Notifications.CreateResponse{
        notification: %{
          req.notification
          | id: id,
            create_time: %Google.Protobuf.Timestamp{seconds: 1_549_885_252, nanos: 0},
            org_id: org_id
        }
      }
    end

    def update(req, _call) do
      case find(req) do
        {:ok, notification} ->
          new_notification = %{
            id: notification.id,
            name: req.notification.name,
            api_model: req.notification,
            org_id: notification.org_id
          }

          DB.update(:notifications, new_notification)

          %InternalApi.Notifications.UpdateResponse{
            notification: %{
              new_notification.api_model
              | id: notification.id,
                create_time: %Google.Protobuf.Timestamp{seconds: 1_549_885_252, nanos: 0},
                update_time: %Google.Protobuf.Timestamp{seconds: 1_549_885_252, nanos: 0},
                org_id: notification.org_id
            }
          }

        {:error, message} ->
          raise GRPC.RPCError, status: :not_found, message: message
      end
    end

    def destroy(req, _call) do
      case find(req) do
        {:ok, notification} ->
          DB.delete(:notifications, notification.id)

          %InternalApi.Notifications.DestroyResponse{id: notification.id}

        {:error, message} ->
          raise GRPC.RPCError, status: 5, message: message
      end
    end

    defp find(req) do
      org_id = req.metadata.org_id

      case Enum.find(org_notifications(org_id), fn s ->
             s.id == req.id || s.name == req.name
           end) do
        nil ->
          {:error, "Notification not found"}

        notification ->
          {:ok, notification}
      end
    end

    defp org_notifications(org_id) do
      DB.find_all_by(:notifications, :org_id, org_id)
    end
  end
end
