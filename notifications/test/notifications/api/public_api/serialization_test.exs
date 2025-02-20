defmodule Notifications.Api.PublicApi.SerializationTest do
  use Notifications.DataCase

  @org_id Ecto.UUID.generate()
  @user_id Ecto.UUID.generate()

  @options [
    metadata: %{
      "x-semaphore-user-id" => @user_id,
      "x-semaphore-org-id" => @org_id
    }
  ]

  alias Notifications.Models.Notification

  setup do
    create_notif("test")

    {:ok, notif} = Notification.find_by_id_or_name(@org_id, "test")
    n = Notifications.Api.PublicApi.Serialization.serialize(notif)

    {:ok, %{n: n}}
  end

  test "it serializes a the metadata", %{n: n} do
    assert n.metadata.name == "test"
    assert !is_nil(n.metadata.id)
    assert !is_nil(n.metadata.create_time)
    assert !is_nil(n.metadata.update_time)
  end

  test "it serializes the spec", %{n: n} do
    assert length(n.spec.rules) == 1

    rule = hd(n.spec.rules)

    assert rule.name == "Example Rule"
  end

  test "it serializes slack", %{n: n} do
    s = hd(n.spec.rules).notify.slack

    assert s.channels == ["#general", "#product-hq"]
    assert s.endpoint == "https://slack.com/api/dsasdf3243/34123412h1j2h34kj2"
    assert s.message == "Slack notification!"
  end

  test "it serializes emails", %{n: n} do
    e = hd(n.spec.rules).notify.email

    assert e.bcc == ["devs@example.com"]
    assert e.cc == ["devops@example.com"]
    assert e.content == "Email notification 101"
    assert e.subject == "Hi there"
  end

  test "it serializes webhooks", %{n: n} do
    webhook = hd(n.spec.rules).notify.webhook

    assert webhook.endpoint == "https://githu.com/api/comments"
  end

  test "it serializes filters", %{n: n} do
    filter = hd(n.spec.rules).filter

    assert filter.projects == ["cli", "/^s2-*/"]
    assert filter.branches == ["master", "/^release-.*$/"]
    assert filter.pipelines == [".semaphore/semaphore.yml", "/^.semaphore/stg-*.yml/"]
    assert filter.blocks == []
  end

  def create_notif(name) do
    alias Semaphore.Notifications.V1alpha.NotificationsApi.Stub

    GrpcMock.stub(
      RBACMock,
      :list_user_permissions,
      fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          permissions: ["organization.notifications.manage"]
        )
      end
    )

    {:ok, channel} = GRPC.Stub.connect("localhost:50051")

    req = Support.Factories.Notification.api_model(name)
    {:ok, _} = Stub.create_notification(channel, req, @options)
  end
end
